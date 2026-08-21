#!/usr/bin/env bash
#
# Pull every PostgreSQL database from an old Mac onto a newly bootstrapped Mac.
#
# Keep this script compatible with Bash 3.2: macOS ships 3.2 as /bin/bash. Under
# `set -u`, guard every array expansion because empty arrays are unbound there.

set -euo pipefail

readonly COLOR_INFO=111
readonly COLOR_OK=82
readonly COLOR_WARN=214
readonly COLOR_ERR=160

info() { printf '\033[38;5;%sm%s\033[0m\n' "$COLOR_INFO" "$*"; }
ok() { printf '\033[38;5;%sm%s\033[0m\n' "$COLOR_OK" "$*"; }
err() { printf '\033[38;5;%sm%s\033[0m\n' "$COLOR_ERR" "$*" >&2; }
die() {
	err "$*"
	exit 1
}

trap 'err "Migration failed at line $LINENO."; err "Fix the problem, then re-run pg-migrate.sh; completed dumps are resumable."' ERR

usage() {
	cat <<'EOF'
Usage: pg-migrate.sh --from USER@HOST [options]

  --from USER@HOST   Source machine, reachable over SSH (required)
  --only LIST        Comma-separated database names (default: all discovered)
  --exclude LIST     Comma-separated database names to skip
  --stage DIR        Where to land dump files (default: $HOME/pg-migration)
  --jobs N           Parallel restore jobs (default: CPU cores, max 8)
  --keep-dumps       Do not delete dump files after a successful restore
  --dry-run          Preview everything; change nothing
  --help
EOF
}

FROM=""
ONLY=""
EXCLUDE=""
STAGE="$HOME/pg-migration"
JOBS=""
keep_dumps=false
dry_run=false

while [ "$#" -gt 0 ]; do
	case "$1" in
	--from | --only | --exclude | --stage | --jobs)
		[ "$#" -ge 2 ] || {
			err "$1 requires a value"
			usage >&2
			exit 2
		}
		case "$1" in
		--from) FROM="$2" ;;
		--only) ONLY="$2" ;;
		--exclude) EXCLUDE="$2" ;;
		--stage) STAGE="$2" ;;
		--jobs) JOBS="$2" ;;
		esac
		shift
		;;
	--keep-dumps) keep_dumps=true ;;
	--dry-run) dry_run=true ;;
	--help | -h)
		usage
		exit 0
		;;
	*)
		err "unknown option: $1"
		usage >&2
		exit 2
		;;
	esac
	shift
done

if [ -z "$FROM" ]; then
	err "--from USER@HOST is required"
	usage >&2
	exit 2
fi
case "$JOBS" in
"") ;;
*[!0-9]* | 0)
	err "--jobs must be a positive integer"
	usage >&2
	exit 2
	;;
esac

run() {
	printf '\033[38;5;%sm' "$COLOR_INFO"
	printf ' %q' "$@"
	printf '\033[0m\n'
	if "$dry_run"; then
		return 0
	fi
	"$@"
}

run_status() {
	printf '\033[38;5;%sm' "$COLOR_INFO"
	printf ' %q' "$@"
	printf '\033[0m\n'
	if "$dry_run"; then
		return 0
	fi
	"$@" || return $?
}

record() {
	SUMMARY+=("$1")
}

warn() {
	printf '\033[38;5;%sm%s\033[0m\n' "$COLOR_WARN" "$*"
	record "warning: $*"
}

array_contains() {
	local wanted="$1"
	shift
	local item
	if [ "$#" -gt 0 ]; then
		for item in "$@"; do
			[ "$item" = "$wanted" ] && return 0
		done
	fi
	return 1
}

split_list() {
	local list="$1"
	local destination="$2"
	local item
	local old_ifs="$IFS"
	IFS=,
	for item in $list; do
		case "$destination" in
		only) ONLY_DATABASES+=("$item") ;;
		exclude) EXCLUDED_DATABASES+=("$item") ;;
		esac
	done
	IFS="$old_ifs"
}

sql_quote() {
	printf "'%s'" "$(printf '%s' "$1" | sed "s/'/''/g")"
}

shell_quote() {
	printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

format_bytes() {
	local bytes="$1"
	awk -v bytes="$bytes" 'BEGIN {
		split("B KB MB GB TB", units, " ")
		unit = 1
		while (bytes >= 1024 && unit < 5) { bytes /= 1024; unit++ }
		printf "%.1f %s", bytes, units[unit]
	}'
}

remote_psql() {
	local database="$1"
	local query="$2"
	local command
	command="psql -X -A -t -F '\t' -d $(shell_quote "$database") -c $(shell_quote "$query")"
	# shellcheck disable=SC2029
	ssh "$FROM" "$command"
}

remote_psql_default() {
	local query="$1"
	local command
	command="psql -X -A -t -F '\t' -c $(shell_quote "$query")"
	# shellcheck disable=SC2029
	ssh "$FROM" "$command"
}

database_selected() {
	local database="$1"
	if [ "${#ONLY_DATABASES[@]}" -gt 0 ] && ! array_contains "$database" "${ONLY_DATABASES[@]}"; then
		return 1
	fi
	if [ "${#EXCLUDED_DATABASES[@]}" -gt 0 ] && array_contains "$database" "${EXCLUDED_DATABASES[@]}"; then
		return 1
	fi
	return 0
}

classify_restore_status() {
	local database="$1"
	local status="$2"
	case "$status" in
	0)
		DATABASE_RESTORED+=("$database")
		DATABASE_OUTCOMES+=("restored: $database")
		return 0
		;;
	*)
		warn "$database restored with pg_restore exit $status; inspect its warnings."
		DATABASE_WARNINGS+=("$database")
		DATABASE_OUTCOMES+=("restored with warnings: $database (pg_restore exit $status)")
		return 0
		;;
	esac
}

cleanup() {
	if [ "${#TEMP_FILES[@]}" -gt 0 ]; then
		rm -f "${TEMP_FILES[@]}"
	fi
}

SUMMARY=()
FAILURES=()
ONLY_DATABASES=()
EXCLUDED_DATABASES=()
ALL_DATABASES=()
DATABASES=()
DATABASE_SIZES=()
DATABASE_RESTORED=()
DATABASE_WARNINGS=()
DATABASE_FAILURES=()
DATABASE_SKIPPED=()
DATABASE_OUTCOMES=()
VERIFY_DATABASES=()
VERIFY_SOURCE_TABLES=()
VERIFY_DESTINATION_TABLES=()
VERIFY_SOURCE_SIZES=()
VERIFY_DESTINATION_SIZES=()
VERIFY_RESULTS=()
TEMP_FILES=()
split_list "$ONLY" only
split_list "$EXCLUDE" exclude
trap cleanup EXIT

info "Phase 0/4: Preflight"
for command in pg_dump pg_restore psql ssh; do
	command -v "$command" >/dev/null 2>&1 || die "$command is required."
done
command -v pg_isready >/dev/null 2>&1 || die "pg_isready is required."
pg_isready >/dev/null 2>&1 || die "The local PostgreSQL server is not accepting connections."

if ! ssh -o BatchMode=yes "$FROM" true; then
	die "Could not connect to $FROM. Remote Login may be off on the source Mac, or this machine's SSH key is not authorised there."
fi

destination_version_num="$(psql -X -A -t -c 'SHOW server_version_num')"
source_version_num="$(remote_psql_default 'SHOW server_version_num')"
destination_major=$((destination_version_num / 10000))
source_major=$((source_version_num / 10000))
if [ "$source_major" -gt "$destination_major" ]; then
	die "Source PostgreSQL $source_major is newer than destination PostgreSQL $destination_major; restoring into an older major version is unsupported."
elif [ "$source_major" -lt "$destination_major" ]; then
	warn "Destination PostgreSQL $destination_major is newer than source PostgreSQL $source_major; this restore direction is supported."
fi

database_rows="$(remote_psql_default "SELECT datname, pg_database_size(datname) FROM pg_database WHERE datallowconn AND datname <> 'template0' ORDER BY pg_database_size(datname) ASC")"
while IFS="	" read -r database database_size; do
	[ -n "$database" ] || continue
	ALL_DATABASES+=("$database")
	if database_selected "$database"; then
		DATABASES+=("$database")
		DATABASE_SIZES+=("$database_size")
	fi
done <<EOF
$database_rows
EOF
[ "${#DATABASES[@]}" -gt 0 ] || die "No source databases matched the selection."
source_admin_database="${DATABASES[0]}"
destination_admin_database="$(psql -X -A -t -c 'SELECT current_database()')"

source_extensions="${TMPDIR:-/tmp}/pg-migrate-source-extensions.$$"
destination_extensions="${TMPDIR:-/tmp}/pg-migrate-destination-extensions.$$"
TEMP_FILES+=("$source_extensions" "$destination_extensions")
: >"$source_extensions"
psql -X -A -t -F "	" -c 'SELECT name, default_version FROM pg_available_extensions' >"$destination_extensions"
for database in "${ALL_DATABASES[@]}"; do
	while IFS="	" read -r extension installed_version; do
		[ -n "$extension" ] || continue
		printf '%s\t%s\t%s\n' "$extension" "$installed_version" "$database" >>"$source_extensions"
	done <<EOF
$(remote_psql "$database" 'SELECT extname, extversion FROM pg_extension ORDER BY extname')
EOF
done

missing_extensions=0
while IFS="	" read -r extension installed_version database; do
	available_row="$(awk -F "	" -v wanted="$extension" '$1 == wanted { print; exit }' "$destination_extensions")"
	if [ -z "$available_row" ]; then
		err "Missing extension $extension required by database $database."
		missing_extensions=$((missing_extensions + 1))
		continue
	fi
	available_version="${available_row#*	}"
	if [ "$installed_version" != "$available_version" ]; then
		warn "$extension version differs for $database: source $installed_version, destination default $available_version."
	fi
done <"$source_extensions"
[ "$missing_extensions" -eq 0 ] || die "$missing_extensions required extension check(s) failed."

total_bytes=0
for database_size in "${DATABASE_SIZES[@]}"; do
	total_bytes=$((total_bytes + database_size))
done
required_bytes=$((total_bytes + total_bytes * 30 / 100))
stage_probe="$STAGE"
while [ ! -e "$stage_probe" ] && [ "$stage_probe" != "/" ]; do
	stage_probe="$(dirname "$stage_probe")"
done
available_kb="$(df -k "$stage_probe" | awk 'NR == 2 { print $4 }')"
available_bytes=$((available_kb * 1024))
if [ "$available_bytes" -lt "$required_bytes" ]; then
	die "Not enough staging-disk space: need $(format_bytes "$required_bytes"), have $(format_bytes "$available_bytes")."
fi

if [ -z "$JOBS" ]; then
	JOBS="$(sysctl -n hw.ncpu 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || printf '1')"
fi
[ "$JOBS" -le 8 ] || JOBS=8

info "Source: $FROM (PostgreSQL $source_major)"
info "Destination: local PostgreSQL $destination_major"
info "Staging directory: $STAGE"
info "Restore jobs: $JOBS"
info "Databases selected (smallest first):"
index=0
for database in "${DATABASES[@]}"; do
	printf '  %s (%s)\n' "$database" "$(format_bytes "${DATABASE_SIZES[$index]}")"
	index=$((index + 1))
done
info "Total to transfer: $(format_bytes "$total_bytes")"
info "Required free space (data plus 30% for compressed dumps): $(format_bytes "$required_bytes")"

info "Phase 1/4: Globals"
if "$dry_run"; then
	info "Would stream source globals directly into local psql; role hashes will not be printed or staged."
	record "would restore: PostgreSQL globals"
else
	globals_stderr="${TMPDIR:-/tmp}/pg-migrate-globals-stderr.$$"
	TEMP_FILES+=("$globals_stderr")
	roles_before="$(psql -X -A -t -c 'SELECT count(*) FROM pg_roles')"
	set +e
	# Role password hashes are sensitive: stream them directly and capture errors.
	ssh "$FROM" 'pg_dumpall --globals-only' | psql -X 2>"$globals_stderr" >/dev/null
	globals_status=$?
	set -e
	roles_after="$(psql -X -A -t -c 'SELECT count(*) FROM pg_roles')"
	roles_created=$((roles_after - roles_before))
	genuine_errors="$(grep -Ev 'role ".*" already exists' "$globals_stderr" |
		grep -Ec '(^|: )(ERROR|FATAL):' || true)"
	[ "$globals_status" -eq 0 ] || genuine_errors=$((genuine_errors + 1))
	ok "Created $roles_created role(s); $genuine_errors genuine globals error(s)."
	if [ "$genuine_errors" -gt 0 ]; then
		warn "Globals reported $genuine_errors genuine error(s); sensitive output remains hidden."
	fi
fi

info "Phase 2/4: Transfer and restore"
run mkdir -p "$STAGE"
index=0
for database in "${DATABASES[@]}"; do
	dump_file="$STAGE/$database.dump"
	part_file="$dump_file.part"
	database_size="${DATABASE_SIZES[$index]}"
	index=$((index + 1))
	clean_restore=false
	info "Database: $database ($(format_bytes "$database_size"))"

	database_metadata="$(remote_psql "$source_admin_database" "SELECT pg_encoding_to_char(encoding), datcollate, datctype, pg_roles.rolname FROM pg_database JOIN pg_roles ON pg_roles.oid = datdba WHERE datname = $(sql_quote "$database")")"
	IFS="	" read -r database_encoding database_collation database_ctype database_owner <<EOF
$database_metadata
EOF
	local_exists="$(psql -X -A -t -c "SELECT count(*) FROM pg_database WHERE datname = $(sql_quote "$database")")"
	if [ "$local_exists" -eq 0 ]; then
		create_sql="SELECT format('CREATE DATABASE %I OWNER %I ENCODING %L LC_COLLATE %L LC_CTYPE %L TEMPLATE template0', $(sql_quote "$database"), $(sql_quote "$database_owner"), $(sql_quote "$database_encoding"), $(sql_quote "$database_collation"), $(sql_quote "$database_ctype")) \\gexec"
		if "$dry_run"; then
			info "Would create local database $database with source encoding, locale, and owner."
		elif ! printf '%s\n' "$create_sql" | psql -X -v ON_ERROR_STOP=1 -d "$destination_admin_database" >/dev/null; then
			FAILURES+=("$database creation failed")
			DATABASE_FAILURES+=("$database")
			DATABASE_OUTCOMES+=("failed: $database (could not create local database)")
			continue
		fi
	else
		local_tables="$(psql -X -A -t -d "$database" -c "SELECT count(*) FROM pg_class JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace WHERE relkind = 'r' AND nspname NOT IN ('pg_catalog', 'information_schema')")"
		if [ "$local_tables" -gt 0 ] && ! { [ "${#ONLY_DATABASES[@]}" -gt 0 ] && array_contains "$database" "${ONLY_DATABASES[@]}"; }; then
			warn "$database already exists locally and is not empty; skipping it. Use --only $database to restore it explicitly."
			DATABASE_SKIPPED+=("$database")
			DATABASE_OUTCOMES+=("skipped: $database (local database is not empty)")
			continue
		elif [ "$local_tables" -gt 0 ]; then
			clean_restore=true
			warn "$database was explicitly selected and is not empty; pg_restore will replace objects contained in the dump."
		fi
	fi

	if [ -f "$dump_file" ]; then
		info "Complete dump already exists; skipping transfer and resuming at restore: $dump_file"
		record "resumed: $database from completed dump"
	else
		# Only a successful stream is renamed to .dump. A dropped connection leaves
		# .part, so re-running costs only this database, never the completed ones.
		remote_dump="pg_dump -Fc -Z6 -d $(shell_quote "$database")"
		if "$dry_run"; then
			info "Would stream $database from $FROM to $part_file, then rename it to $dump_file."
		else
			rm -f "$part_file"
			set +e
			# shellcheck disable=SC2029
			ssh "$FROM" "$remote_dump" >"$part_file"
			dump_status=$?
			set -e
			if [ "$dump_status" -ne 0 ]; then
				FAILURES+=("$database dump failed with exit $dump_status")
				DATABASE_FAILURES+=("$database")
				DATABASE_OUTCOMES+=("failed: $database (dump exit $dump_status)")
				continue
			fi
			mv "$part_file" "$dump_file"
		fi
	fi

	if "$clean_restore"; then
		if run_status pg_restore -d "$database" -j "$JOBS" --no-privileges \
			--clean --if-exists "$dump_file"; then
			restore_status=0
		else
			restore_status=$?
		fi
	else
		if run_status pg_restore -d "$database" -j "$JOBS" --no-privileges "$dump_file"; then
			restore_status=0
		else
			restore_status=$?
		fi
	fi
	classify_restore_status "$database" "$restore_status"
	VERIFY_DATABASES+=("$database")
	if [ "$restore_status" -eq 0 ] && ! "$keep_dumps"; then
		run rm -f "$dump_file"
	fi
done

info "Phase 3/4: Verify"
if [ "${#VERIFY_DATABASES[@]}" -gt 0 ]; then
	for database in "${VERIFY_DATABASES[@]}"; do
		verification_query="SELECT (SELECT count(*) FROM pg_class JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace WHERE relkind = 'r' AND nspname NOT IN ('pg_catalog', 'information_schema')), pg_database_size(current_database())"
		IFS="	" read -r source_tables source_size <<EOF
$(remote_psql "$database" "$verification_query")
EOF
		if "$dry_run"; then
			destination_tables="-"
			destination_size=0
			verification_result="dry-run"
		else
			IFS="	" read -r destination_tables destination_size <<EOF
$(psql -X -A -t -F "	" -d "$database" -c "$verification_query")
EOF
			verification_result="ok (a smaller fresh restore is normal)"
			if [ "$source_tables" -ne "$destination_tables" ]; then
				verification_result="WARNING: table-count mismatch"
			elif [ "$destination_size" -lt $((source_size / 2)) ]; then
				verification_result="WARNING: destination is under 50% of source size"
			fi
		fi
		VERIFY_SOURCE_TABLES+=("$source_tables")
		VERIFY_DESTINATION_TABLES+=("$destination_tables")
		VERIFY_SOURCE_SIZES+=("$source_size")
		VERIFY_DESTINATION_SIZES+=("$destination_size")
		VERIFY_RESULTS+=("$verification_result")
	done
fi

info "Phase 4/4: Summary"
ok "Database outcomes:"
if [ "${#DATABASE_OUTCOMES[@]}" -gt 0 ]; then
	for outcome in "${DATABASE_OUTCOMES[@]}"; do
		printf '  %s\n' "$outcome"
	done
fi
ok "Verification (a smaller destination is normal after a fresh restore):"
printf '  %-24s %8s %8s %12s %12s %s\n' "database" "src tbl" "dst tbl" "src size" "dst size" "result"
if [ "${#VERIFY_DATABASES[@]}" -gt 0 ]; then
	index=0
	for database in "${VERIFY_DATABASES[@]}"; do
		if [ "${VERIFY_DESTINATION_SIZES[$index]}" -eq 0 ]; then
			destination_size_display="-"
		else
			destination_size_display="$(format_bytes "${VERIFY_DESTINATION_SIZES[$index]}")"
		fi
		printf '  %-24s %8s %8s %12s %12s %s\n' \
			"$database" "${VERIFY_SOURCE_TABLES[$index]}" \
			"${VERIFY_DESTINATION_TABLES[$index]}" \
			"$(format_bytes "${VERIFY_SOURCE_SIZES[$index]}")" \
			"$destination_size_display" "${VERIFY_RESULTS[$index]}"
		index=$((index + 1))
	done
fi
if [ "${#SUMMARY[@]}" -gt 0 ]; then
	ok "Warnings and notes:"
	for item in "${SUMMARY[@]}"; do
		printf '  %s\n' "$item"
	done
fi
if [ "${#FAILURES[@]}" -gt 0 ]; then
	for failure in "${FAILURES[@]}"; do
		warn "⚠ $failure"
	done
fi
printf '%s\n' \
	"📋 brew services restart postgresql@17 (if the server needs a restart)" \
	"📋 delete $STAGE when retained dumps are no longer needed"
