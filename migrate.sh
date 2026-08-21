#!/usr/bin/env bash
#
# Pull a developer's working state from an old Mac onto a newly bootstrapped Mac.
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

trap 'err "Migration failed at line $LINENO."; err "Fix the problem, then re-run migrate.sh; transfers are additive."' ERR

usage() {
	cat <<'EOF'
Usage: migrate.sh --from USER@HOST [options]

  --from USER@HOST   Source machine, reachable over SSH (required)
  --set LIST         Comma-separated: projects,configs,secrets (default: all)
  --no-rewrite       Transfer only; skip the path-rewrite phase
  --rewrite-only     Skip transfer; run rewrite against what is already local
  --dry-run          Preview everything; change nothing
  --help

Exit 23/24 from rsync is expected and non-fatal when active source files move.
Re-running is incremental and picks up files that changed or vanished.
EOF
}

FROM=""
SETS="projects,configs,secrets"
no_rewrite=false
rewrite_only=false
dry_run=false

while [ "$#" -gt 0 ]; do
	case "$1" in
	--from)
		[ "$#" -ge 2 ] || {
			err "--from requires USER@HOST"
			usage >&2
			exit 2
		}
		FROM="$2"
		shift
		;;
	--set)
		[ "$#" -ge 2 ] || {
			err "--set requires a comma-separated list"
			usage >&2
			exit 2
		}
		SETS="$2"
		shift
		;;
	--no-rewrite) no_rewrite=true ;;
	--rewrite-only) rewrite_only=true ;;
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

if [ -z "$FROM" ] && ! "$rewrite_only"; then
	err "--from USER@HOST is required"
	usage >&2
	exit 2
fi
if "$no_rewrite" && "$rewrite_only"; then
	die "--no-rewrite and --rewrite-only cannot be used together."
fi

SELECTED_SETS=()
old_ifs="$IFS"
IFS=,
for selected_set in $SETS; do
	case "$selected_set" in
	projects | configs | secrets) SELECTED_SETS+=("$selected_set") ;;
	*)
		err "unknown set: $selected_set"
		usage >&2
		exit 2
		;;
	esac
done
IFS="$old_ifs"
[ "${#SELECTED_SETS[@]}" -gt 0 ] || {
	err "--set must name at least one set"
	usage >&2
	exit 2
}

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

classify_rsync_status() {
	local set_name="$1"
	local status="$2"
	case "$status" in
	0)
		SET_COMPLETED+=("$set_name")
		;;
	23 | 24)
		warn "$set_name completed with rsync exit $status: some source files changed or vanished during transfer; re-running will pick them up."
		SET_WARNINGS+=("$set_name")
		;;
	*)
		FAILURES+=("$set_name failed with rsync exit $status")
		SET_FAILURES+=("$set_name (rsync exit $status)")
		;;
	esac
}

merge_rsync_status() {
	local status="$1"
	case "$status" in
	0) ;;
	23 | 24)
		case "$SET_RSYNC_STATUS" in
		0) SET_RSYNC_STATUS="$status" ;;
		esac
		;;
	*) SET_RSYNC_STATUS="$status" ;;
	esac
}

set_selected() {
	local wanted="$1"
	local item
	if [ "${#SELECTED_SETS[@]}" -gt 0 ]; then
		for item in "${SELECTED_SETS[@]}"; do
			[ "$item" = "$wanted" ] && return 0
		done
	fi
	return 1
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

remote_dir_exists() {
	local relative_path="$1"
	# shellcheck disable=SC2029
	ssh "$FROM" "test -d \"\$HOME/$relative_path\""
}

remote_file_exists() {
	local relative_path="$1"
	# shellcheck disable=SC2029
	ssh "$FROM" "test -f \"\$HOME/$relative_path\""
}

sync_dir() {
	local remote_path="$1"
	local local_path="$2"
	shift 2
	run mkdir -p "$local_path"
	if "$dry_run"; then
		if run_status "$RSYNC_BIN" -n -aH --partial --info=progress2 --human-readable "$@" \
			"$FROM:$remote_path/" "$local_path/"; then
			LAST_RSYNC_STATUS=0
		else
			LAST_RSYNC_STATUS=$?
		fi
	else
		if run_status "$RSYNC_BIN" -aH --partial --info=progress2 --human-readable "$@" \
			"$FROM:$remote_path/" "$local_path/"; then
			LAST_RSYNC_STATUS=0
		else
			LAST_RSYNC_STATUS=$?
		fi
	fi
}

write_lines() {
	local file="$1"
	shift
	printf '%s\n' "$@" >"$file"
}

append_dependency() {
	local file="$1"
	local directory="$2"
	local command="$3"
	printf '\ncd %q && %s\n' "$directory" "$command" >>"$file"
}

cleanup() {
	if [ "${#TEMP_FILES[@]}" -gt 0 ]; then
		run rm -f "${TEMP_FILES[@]}"
	fi
}

SUMMARY=()
FAILURES=()
SET_COMPLETED=()
SET_WARNINGS=()
SET_FAILURES=()
SET_SKIPPED=()
REPAIRED_WORKTREES=()
TEMP_FILES=()
LAST_RSYNC_STATUS=0
SET_RSYNC_STATUS=0
trap cleanup EXIT

info "Phase 0/6: Preflight"
[ "$(uname -s)" = "Darwin" ] || die "migrate.sh supports macOS only."
command -v ssh >/dev/null 2>&1 || die "ssh is required."
command -v git >/dev/null 2>&1 || die "git is required."

if [ -n "$FROM" ]; then
	if ! ssh -o BatchMode=yes "$FROM" true; then
		die "Could not connect to $FROM. Remote Login may be off on the source Mac (System Settings > General > Sharing > Remote Login), or this machine's SSH key is not authorised there."
	fi
	SRC_HOME="$(ssh "$FROM" 'printf %s "$HOME"')"
	[ -n "$SRC_HOME" ] || die "Could not resolve the source home directory."
else
	die "--rewrite-only still needs --from USER@HOST to resolve the source home directory."
fi
DST_HOME="$HOME"

RSYNC_BIN="$(command -v rsync 2>/dev/null || true)"
if [ -n "$RSYNC_BIN" ] && "$RSYNC_BIN" --version 2>/dev/null | head -n 1 | grep -qi openrsync; then
	RSYNC_BIN=""
fi
if [ -z "$RSYNC_BIN" ] && command -v brew >/dev/null 2>&1; then
	brew_rsync="$(brew --prefix)/bin/rsync"
	if [ -x "$brew_rsync" ] && ! "$brew_rsync" --version 2>/dev/null | head -n 1 | grep -qi openrsync; then
		RSYNC_BIN="$brew_rsync"
	fi
fi
[ -n "$RSYNC_BIN" ] || die "GNU rsync is required; run 'brew install rsync'."

if [ "$SRC_HOME" = "$DST_HOME" ]; then
	rewrite_needed=false
else
	rewrite_needed=true
fi
info "Source: $FROM:$SRC_HOME"
info "Destination: $DST_HOME"
info "Sets: $SETS"
info "Rewrite needed: $rewrite_needed"
info "rsync: $RSYNC_BIN"

if ! "$rewrite_only" && set_selected projects; then
	info "Phase 1/6: Projects"
	# These exclusions include architecture-specific dependency/build caches. In
	# particular, node_modules, .venv, and target may contain Intel binaries that
	# are actively wrong after a move to Apple Silicon, rather than merely stale.
	# Keep .git because branches, stashes, and unpushed commits live there. Keep
	# dist and build because they may be tracked; excluding them can dirty a clone.
	projects_excludes="${TMPDIR:-/tmp}/migrate-projects-excludes.$$"
	TEMP_FILES+=("$projects_excludes")
	run write_lines "$projects_excludes" \
		node_modules/ .venv/ venv/ __pycache__/ .pytest_cache/ .mypy_cache/ \
		.ruff_cache/ target/ .next/ .nuxt/ .output/ .turbo/ .parcel-cache/ \
		coverage/ .pnpm-store/ .yarn/cache/ Pods/ .gradle/ .DS_Store '*.log'
	sync_dir "$SRC_HOME/projects" "$DST_HOME/projects" --exclude-from="$projects_excludes"
	classify_rsync_status projects "$LAST_RSYNC_STATUS"
else
	SET_SKIPPED+=("projects")
fi

if ! "$rewrite_only" && set_selected configs; then
	info "Phase 2/6: Configs"
	SET_RSYNC_STATUS=0
	for config_dir in .claude .codex .cursor .gemini .copilot .gitkraken .gk .config; do
		if ! remote_dir_exists "$config_dir"; then
			record "skipped: $config_dir (not present on source)"
			continue
		fi
		excludes="${TMPDIR:-/tmp}/migrate-config-excludes.$$"
		if [ "${#TEMP_FILES[@]}" -eq 0 ] || ! array_contains "$excludes" "${TEMP_FILES[@]}"; then
			TEMP_FILES+=("$excludes")
		fi
		case "$config_dir" in
		.claude)
			run write_lines "$excludes" sessions/ logs/ cache/ shell-snapshots/ file-history/ telemetry/ uploads/ paste-cache/ plugins/cache/ statsig/ '*.bak*' '*.tmp.*' .DS_Store
			;;
		.codex)
			run write_lines "$excludes" 'logs_*.sqlite*' sessions/ archived_sessions/ cache/ .tmp/ ipc/ '*.bak*'
			;;
		.cursor)
			run write_lines "$excludes" Cache/ CachedData/ logs/ CachedExtensionVSIXs/
			;;
		*) run write_lines "$excludes" .DS_Store ;;
		esac
		sync_dir "$SRC_HOME/$config_dir" "$DST_HOME/$config_dir" --exclude-from="$excludes"
		merge_rsync_status "$LAST_RSYNC_STATUS"
		record "transferred: $config_dir"
	done

	if remote_dir_exists .ai-team; then
		if ! ai_team_status="$(ssh "$FROM" 'git -C "$HOME/.ai-team" status --porcelain')"; then
			die "Could not inspect the source .ai-team git status."
		fi
		if [ -z "$ai_team_status" ]; then
			record "skipped: .ai-team (git clone is authoritative)"
		else
			sync_dir "$SRC_HOME/.ai-team" "$DST_HOME/.ai-team"
			merge_rsync_status "$LAST_RSYNC_STATUS"
			warn "uncommitted .ai-team shared-context changes were carried over; commit them."
		fi
	else
		record "skipped: .ai-team (not present on source)"
	fi
	classify_rsync_status configs "$SET_RSYNC_STATUS"
else
	SET_SKIPPED+=("configs")
fi

if ! "$rewrite_only" && set_selected secrets; then
	info "Phase 3/6: Secrets"
	SET_RSYNC_STATUS=0
	for secret_file in .env/work-stuff.zsh .claude/hooks/pushover.env; do
		if remote_file_exists "$secret_file"; then
			run mkdir -p "$(dirname "$DST_HOME/$secret_file")"
			if "$dry_run"; then
				if run_status "$RSYNC_BIN" -n -a --human-readable "$FROM:$SRC_HOME/$secret_file" "$DST_HOME/$secret_file"; then
					LAST_RSYNC_STATUS=0
				else
					LAST_RSYNC_STATUS=$?
				fi
			else
				if run_status "$RSYNC_BIN" -a --human-readable "$FROM:$SRC_HOME/$secret_file" "$DST_HOME/$secret_file"; then
					LAST_RSYNC_STATUS=0
				else
					LAST_RSYNC_STATUS=$?
				fi
			fi
			merge_rsync_status "$LAST_RSYNC_STATUS"
			record "transferred: $secret_file"
		else
			record "skipped: $secret_file (not present on source)"
		fi
	done
	for secret_dir in .aws .gnupg; do
		if remote_dir_exists "$secret_dir"; then
			sync_dir "$SRC_HOME/$secret_dir" "$DST_HOME/$secret_dir"
			merge_rsync_status "$LAST_RSYNC_STATUS"
			record "transferred: $secret_dir"
		else
			record "skipped: $secret_dir (not present on source)"
		fi
	done
	if [ -d "$DST_HOME/.gnupg" ] || "$dry_run"; then
		run find "$DST_HOME/.gnupg" -type d -exec chmod 700 {} +
		run find "$DST_HOME/.gnupg" -type f -exec chmod 600 {} +
	fi
	info "Deliberately skipped ~/.ssh; this machine keeps its fresh per-machine key."
	record "skipped: .ssh (per-machine key retained)"
	classify_rsync_status secrets "$SET_RSYNC_STATUS"
else
	SET_SKIPPED+=("secrets")
fi

if "$no_rewrite"; then
	record "skipped: path rewrite (--no-rewrite)"
	REWRITE_OUTCOME="skipped (--no-rewrite)"
elif ! "$rewrite_needed"; then
	info "Phase 4/6: Rewrite is unnecessary because source and destination homes match."
	record "skipped: path rewrite (home directories match)"
	REWRITE_OUTCOME="skipped (home directories match)"
else
	info "Phase 4/6: Rewrite paths"
	encoded_src="$(printf '%s' "$SRC_HOME" | sed 's#[/.]#-#g')"
	encoded_dst="$(printf '%s' "$DST_HOME" | sed 's#[/.]#-#g')"
	claude_projects="$DST_HOME/.claude/projects"
	if [ -d "$claude_projects" ]; then
		for old_project_dir in "$claude_projects"/"$encoded_src"*; do
			[ -d "$old_project_dir" ] || continue
			old_name="$(basename "$old_project_dir")"
			new_name="$encoded_dst${old_name#"$encoded_src"}"
			new_project_dir="$claude_projects/$new_name"
			if [ -e "$new_project_dir" ]; then
				warn "Claude project directory collision: $new_project_dir; left both unchanged."
			else
				run mv "$old_project_dir" "$new_project_dir"
				record "renamed: Claude project directory $old_name"
			fi
		done
	fi

	changed_files=0
	sed_source="$(printf '%s' "$SRC_HOME" | sed 's/[][\\.^$*]/\\&/g; s/#/\\#/g')"
	sed_destination="$(printf '%s' "$DST_HOME" | sed 's/[\\&#]/\\&/g')"
	for config_dir in .claude .codex .cursor .gemini .copilot .gitkraken .gk .config; do
		[ -d "$DST_HOME/$config_dir" ] || continue
		while IFS= read -r -d '' config_file; do
			grep -Iq . "$config_file" || continue
			grep -qF "$SRC_HOME" "$config_file" || continue
			changed_files=$((changed_files + 1))
			if "$dry_run"; then
				info "Would rewrite: $config_file"
			else
				# macOS uses BSD sed; its in-place form requires an empty suffix.
				run sed -i '' "s#$sed_source#$sed_destination#g" "$config_file"
			fi
		done < <(find "$DST_HOME/$config_dir" -type f ! -path '*/.git/*' -print0)
	done
	record "rewritten: $changed_files config files"

	repaired_repos=0
	while IFS= read -r worktrees_admin; do
		main_repo="${worktrees_admin%/.git/worktrees}"
		worktree_paths=()
		for admin_dir in "$worktrees_admin"/*; do
			[ -d "$admin_dir" ] || continue
			gitdir_file="$admin_dir/gitdir"
			[ -f "$gitdir_file" ] || continue
			stale_git_file="$(sed -n '1p' "$gitdir_file")"
			worktree_path="${stale_git_file%/.git}"
			case "$worktree_path" in
			"$SRC_HOME"/*) worktree_path="$DST_HOME${worktree_path#"$SRC_HOME"}" ;;
			*)
				warn "worktree path is outside the source home; skipped: $worktree_path"
				continue
				;;
			esac
			worktree_paths+=("$worktree_path")
		done
		if [ "${#worktree_paths[@]}" -gt 0 ]; then
			if "$dry_run"; then
				run git -C "$main_repo" worktree repair "${worktree_paths[@]}"
				record "would repair: linked worktrees in $main_repo"
			elif run git -C "$main_repo" worktree repair "${worktree_paths[@]}"; then
				repaired_repos=$((repaired_repos + 1))
				for worktree_path in "${worktree_paths[@]}"; do
					REPAIRED_WORKTREES+=("$worktree_path")
				done
			else
				FAILURES+=("worktree repair failed: $main_repo")
			fi
		fi
	done < <(find "$DST_HOME/projects" -type d -path '*/.git/worktrees' -prune 2>/dev/null)
	record "repaired: $repaired_repos repositories with linked worktrees"
	REWRITE_OUTCOME="completed"
fi

info "Phase 5/6: Dependency report"
deps_script="$DST_HOME/migrate-reinstall-deps.sh"
run write_lines "$deps_script" '#!/usr/bin/env bash' \
	'# Generated by migrate.sh; review before running.' '' 'set -euo pipefail'
node_projects=0
python_projects=0
node_project_dirs=()
python_project_dirs=()
if [ -d "$DST_HOME/projects" ]; then
	for lockfile_name in pnpm-lock.yaml yarn.lock package-lock.json; do
		case "$lockfile_name" in
		pnpm-lock.yaml) install_command="pnpm install" ;;
		yarn.lock) install_command="yarn install" ;;
		package-lock.json) install_command="npm ci" ;;
		esac
		while IFS= read -r lockfile; do
			project_dir="$(dirname "$lockfile")"
			[ -d "$project_dir/node_modules" ] && continue
			if [ "${#node_project_dirs[@]}" -gt 0 ] && array_contains "$project_dir" "${node_project_dirs[@]}"; then
				continue
			fi
			run append_dependency "$deps_script" "$project_dir" "$install_command"
			node_project_dirs+=("$project_dir")
			node_projects=$((node_projects + 1))
		done < <(find "$DST_HOME/projects" -type f -name "$lockfile_name" -print)
	done
	while IFS= read -r python_file; do
		project_dir="$(dirname "$python_file")"
		[ -d "$project_dir/.venv" ] && continue
		if [ "${#python_project_dirs[@]}" -gt 0 ] && array_contains "$project_dir" "${python_project_dirs[@]}"; then
			continue
		fi
		python_project_dirs+=("$project_dir")
		python_projects=$((python_projects + 1))
	done < <(find "$DST_HOME/projects" -type f \( -name pyproject.toml -o -name requirements.txt \) -print)
fi
run chmod 755 "$deps_script"
record "reported: $node_projects Node dependency installs in $deps_script"
record "reported: $python_projects Python project files without .venv"

info "Phase 6/6: Verify and summarise"
REMAINING_FILES=()
if "$rewrite_needed" && ! "$no_rewrite"; then
	for config_dir in .claude .codex .cursor .gemini .copilot .gitkraken .gk .config; do
		[ -d "$DST_HOME/$config_dir" ] || continue
		while IFS= read -r -d '' config_file; do
			grep -Iq . "$config_file" || continue
			if grep -qF "$SRC_HOME" "$config_file"; then
				REMAINING_FILES+=("$config_file")
			fi
		done < <(find "$DST_HOME/$config_dir" -type f ! -path '*/.git/*' -print0)
	done
	remaining_count="${#REMAINING_FILES[@]}"
	record "verified: $remaining_count config files still contain the source home"
	if [ "$remaining_count" -gt 0 ]; then
		warn "Source paths remain after rewrite; showing up to five files."
		shown=0
		for file in "${REMAINING_FILES[@]}"; do
			printf '  %s\n' "$file"
			shown=$((shown + 1))
			[ "$shown" -ge 5 ] && break
		done
	fi
else
	record "skipped: source-path verification (rewrite not requested)"
fi

worktree_failures=0
if [ "${#REPAIRED_WORKTREES[@]}" -gt 0 ]; then
	for worktree_path in "${REPAIRED_WORKTREES[@]}"; do
		if ! git -C "$worktree_path" rev-parse --git-dir >/dev/null 2>&1; then
			FAILURES+=("worktree verification failed: $worktree_path")
			worktree_failures=$((worktree_failures + 1))
		fi
	done
fi
record "verified: $worktree_failures repaired worktree failures"

ok "Set outcomes:"
if [ "${#SET_COMPLETED[@]}" -gt 0 ]; then
	for set_name in "${SET_COMPLETED[@]}"; do
		printf '  completed: %s\n' "$set_name"
	done
fi
if [ "${#SET_WARNINGS[@]}" -gt 0 ]; then
	for set_name in "${SET_WARNINGS[@]}"; do
		printf '  completed with vanished-file warning: %s\n' "$set_name"
	done
fi
if [ "${#SET_FAILURES[@]}" -gt 0 ]; then
	for set_name in "${SET_FAILURES[@]}"; do
		printf '  failed: %s\n' "$set_name"
	done
fi
if [ "${#SET_SKIPPED[@]}" -gt 0 ]; then
	for set_name in "${SET_SKIPPED[@]}"; do
		printf '  skipped: %s\n' "$set_name"
	done
fi
printf '  path rewrite: %s\n' "$REWRITE_OUTCOME"

ok "Transferred, skipped, or verified:"
if [ "${#SUMMARY[@]}" -gt 0 ]; then
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
	"📋 restart running Claude Code sessions" \
	"📋 $DST_HOME/.ai-team/scripts/install.sh --tools all" \
	"📋 colima start" \
	"📋 run $deps_script"
