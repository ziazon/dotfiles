#!/usr/bin/env bash
#
# Bootstrap a new macOS machine from scratch.
#   1. Installs the Xcode CLT, Rosetta 2, Homebrew, git, and GitHub CLI
#   2. Configures git identity, an SSH key, and GitHub authentication
#   3. Clones ~/.env and the private ~/.ai-team shared-context repo
#   4. Runs install.sh, then installs and verifies the shared AI-team context
#
# Safe to re-run: every completed step is detected and skipped.
#
# Keep this script compatible with Bash 3.2: macOS ships 3.2 as /bin/bash, and
# the documented entry point invokes it. In particular, under `set -u`, Bash
# 3.2 treats expansion of an empty array ("${array[@]}") as an unbound variable.

set -euo pipefail

readonly COLOR_INFO=111
readonly COLOR_OK=82
readonly COLOR_WARN=214
readonly COLOR_ERR=160
# GitHub's published ED25519 host key fingerprint. Re-check it on GitHub's
# "SSH key fingerprints" documentation page before changing this value.
readonly GITHUB_ED25519_FP="SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU"

info() { printf '\033[38;5;%sm%s\033[0m\n' "$COLOR_INFO" "$*"; }
ok() { printf '\033[38;5;%sm%s\033[0m\n' "$COLOR_OK" "$*"; }
warn() { printf '\033[38;5;%sm%s\033[0m\n' "$COLOR_WARN" "$*"; }
err() { printf '\033[38;5;%sm%s\033[0m\n' "$COLOR_ERR" "$*" >&2; }
die() {
	err "$*"
	exit 1
}

trap 'err "Bootstrap failed at line $LINENO."; err "Re-run this script; it is idempotent."' ERR

usage() {
	cat <<'EOF'
Usage: bootstrap.sh [options]
  --no-ai-team   Skip cloning/installing the private ~/.ai-team repo
  --no-install   Stop after cloning; do not run ~/.env/install.sh
  --dry-run      Print every action without executing anything that mutates
  --help         Show this help
EOF
}

no_ai_team=false
no_install=false
dry_run=false

while [ "$#" -gt 0 ]; do
	case "$1" in
	--no-ai-team) no_ai_team=true ;;
	--no-install) no_install=true ;;
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

GIT_NAME="${GIT_NAME:-}"
GIT_EMAIL="${GIT_EMAIL:-}"
if [ -z "${ENV_REPO:-}" ] &&
	git -C "$HOME/.env" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	ENV_REPO="$(git -C "$HOME/.env" remote get-url origin 2>/dev/null || true)"
fi
ENV_REPO="${ENV_REPO:-git@github.com:ziazon/dotfiles.git}"
AI_TEAM_REPO="${AI_TEAM_REPO:-}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"

run() {
	printf '\033[38;5;%sm' "$COLOR_INFO"
	printf ' %q' "$@"
	printf '\033[0m\n'
	if "$dry_run"; then
		return 0
	fi
	"$@"
}

append_block() {
	local file="$1"
	local block="$2"
	printf '\n%s\n' "$block" >>"$file"
}

replace_block() {
	local file="$1"
	local block="$2"
	local start="$3"
	local end="$4"
	local temp
	temp="$(mktemp "${file}.tmp.XXXXXX")"
	cp -p "$file" "$temp"
	# Pass the multiline block through the environment because awk -v rejects raw newlines.
	if ! BLOCK="$block" awk -v start="$start" -v end="$end" '
		$0 == start {
			if (!replaced) {
				print ENVIRON["BLOCK"]
				replaced = 1
			}
			skipping = 1
			next
		}
		skipping && $0 == end {
			skipping = 0
			next
		}
		!skipping { print }
		END { if (skipping) exit 1 }
	' "$file" >"$temp"; then
		rm -f "$temp"
		return 1
	fi
	mv "$temp" "$file"
}

create_file() {
	local file="$1"
	local content="$2"
	printf '%s\n' "$content" >"$file"
}

record() {
	SUMMARY+=("$1")
}

brew_is_usable() { [ -x "$BREW_BIN" ] && "$BREW_BIN" --version >/dev/null 2>&1; }

update_env_checkout() {
	local directory="$1"
	local default_branch
	local env_head_after
	local env_head_before
	local env_upstream
	local local_commits
	local remote_head

	# Pruning makes a deleted upstream visible instead of preserving a reassuring stale ref.
	run git -C "$directory" fetch --prune origin
	if ! remote_head="$(git -C "$directory" ls-remote --symref origin HEAD 2>/dev/null)"; then
		remote_head=""
	fi
	default_branch="$(printf '%s\n' "$remote_head" | awk '$1 == "ref:" && $2 ~ /^refs\/heads\// { sub(/^refs\/heads\//, "", $2); print $2; exit }')"
	if [ -z "$default_branch" ]; then
		warn "$directory remote default branch could not be resolved; leaving it unchanged."
		record "not updated: ~/.env (remote default branch unresolved)"
		return 0
	fi
	# A real run fetches before this check; only dry-run can leave the resolved remote ref absent.
	if ! git -C "$directory" show-ref --verify --quiet "refs/remotes/origin/$default_branch"; then
		warn "$directory has not fetched origin/$default_branch yet; run again without --dry-run to fetch it."
		record "not updated: ~/.env (origin/$default_branch not fetched yet; run without --dry-run)"
		return 0
	fi

	if [ -n "$(git -C "$directory" status --porcelain)" ]; then
		warn "$directory has local changes; leaving it unchanged."
		record "not updated: ~/.env (local changes)"
		return 0
	fi

	env_upstream="$(git -C "$directory" rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null || true)"
	if [ "$env_upstream" = "origin/$default_branch" ]; then
		env_head_before="$(git -C "$directory" rev-parse HEAD)"
		if run git -C "$directory" merge --ff-only "$env_upstream"; then
			if "$dry_run" && [ "$env_head_before" != "$(git -C "$directory" rev-parse "$env_upstream")" ]; then
				if git -C "$directory" merge-base --is-ancestor HEAD "$env_upstream"; then
					record "would update: ~/.env"
				else
					warn "$directory could not be fast-forwarded to $env_upstream; leaving it unchanged."
					record "not updated: ~/.env (fast-forward failed)"
				fi
			else
				env_head_after="$(git -C "$directory" rev-parse HEAD)"
				if [ "$env_head_before" = "$env_head_after" ]; then
					record "already up to date: ~/.env"
				else
					record "updated: ~/.env"
				fi
			fi
		else
			warn "$directory could not be fast-forwarded to $env_upstream; leaving it unchanged."
			record "not updated: ~/.env (fast-forward failed)"
		fi
		return 0
	fi

	# Switching branches is safe only when every local HEAD commit is already on the default branch.
	local_commits="$(git -C "$directory" rev-list --count "origin/$default_branch..HEAD")"
	if [ "$local_commits" -ne 0 ]; then
		warn "$directory has local commits not on $default_branch; leaving it unchanged."
		record "not updated: ~/.env (local commits not on $default_branch)"
		return 0
	fi

	if git -C "$directory" show-ref --verify --quiet "refs/heads/$default_branch"; then
		run git -C "$directory" checkout "$default_branch"
		if ! run git -C "$directory" merge --ff-only "origin/$default_branch"; then
			warn "$directory could not be fast-forwarded to origin/$default_branch."
			record "not updated: ~/.env (fast-forward failed)"
			return 0
		fi
	else
		run git -C "$directory" checkout -b "$default_branch" --track "origin/$default_branch"
	fi
	if "$dry_run"; then
		record "would switch to $default_branch and update: ~/.env"
	else
		record "switched to $default_branch and updated: ~/.env"
	fi
}

repo_slug() {
	printf '%s\n' "$1" | sed -E \
		-e 's#^git@github\.com:##' \
		-e 's#^https://github\.com/##' \
		-e 's#\.git/?$##' \
		-e 's#/$##'
}

repo_is_expected() {
	local directory="$1"
	local expected="$2"
	local origin
	[ -d "$directory" ] || return 1
	git -C "$directory" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
	origin="$(git -C "$directory" remote get-url origin 2>/dev/null)" || return 1
	[ "$(repo_slug "$origin")" = "$(repo_slug "$expected")" ]
}

ensure_git_setting() {
	local key="$1"
	local desired="$2"
	local current
	current="$(git config --global --get "$key" 2>/dev/null || true)"
	if [ -z "$current" ]; then
		run git config --global "$key" "$desired"
		record "installed: git $key"
	elif [ "$current" = "$desired" ]; then
		record "already present: git $key"
	else
		warn "git $key is '$current'; leaving it unchanged (bootstrap default: '$desired')."
		record "skipped: git $key (existing value retained)"
	fi
}

resolve_git_identity() {
	local key="$1"
	local variable="$2"
	local label="$3"
	local value="${!variable}"
	local attempts=0
	local max_attempts=3
	if [ -n "$value" ]; then
		return 0
	fi
	value="$(git config --global --get "$key" 2>/dev/null || true)"
	if [ -n "$value" ]; then
		printf -v "$variable" '%s' "$value"
		return 0
	fi
	if "$dry_run"; then
		info "Would prompt for the global git $label ($key is not configured)."
		printf -v "$variable" '%s' "<prompted git $label>"
		return 0
	fi
	info "Your $label is needed to configure your global git identity."
	while [ "$attempts" -lt "$max_attempts" ]; do
		printf 'Git %s: ' "$label"
		IFS= read -r value || value=""
		if [ -n "$value" ]; then
			printf -v "$variable" '%s' "$value"
			return 0
		fi
		attempts=$((attempts + 1))
		warn "Git $label cannot be empty; try again."
	done
	die "Git identity is required. Re-run with GIT_NAME=... GIT_EMAIL=... set."
}

SUMMARY=()
FAILURES=()

[ "$(uname -s)" = "Darwin" ] || die "bootstrap.sh supports macOS only."

if "$dry_run"; then
	warn "Dry run: interactive steps are being previewed, not performed."
elif [ ! -t 0 ]; then
	if (: </dev/tty) 2>/dev/null; then
		exec </dev/tty
	else
		die "No terminal is available. Download bootstrap.sh and run it directly."
	fi
fi

info "Step 1/14: Xcode command line tools"
if xcode-select -p >/dev/null 2>&1; then
	record "already present: Xcode command line tools"
else
	warn "Xcode.app alone is not the command line tools; macOS will open their installer."
	run xcode-select --install
	if "$dry_run"; then
		record "would install: Xcode command line tools"
	else
		waited=0
		until xcode-select -p >/dev/null 2>&1; do
			if [ "$waited" -ge 1800 ]; then
				die "Finish the command line tools GUI installation, then re-run bootstrap.sh."
			fi
			info "Waiting for the command line tools installer..."
			sleep 15
			waited=$((waited + 15))
		done
		record "installed: Xcode command line tools"
	fi
fi

info "Step 2/14: Rosetta 2"
if [ "$(uname -m)" = "arm64" ] && [ ! -x /usr/libexec/rosetta/oahd ]; then
	run softwareupdate --install-rosetta --agree-to-license
	record "installed: Rosetta 2"
elif [ "$(uname -m)" = "arm64" ]; then
	record "already present: Rosetta 2"
fi

# Homebrew under the other architecture prefix cannot run natively and is never accepted.
if [ "$(uname -m)" = "arm64" ]; then
	BREW_PREFIX=/opt/homebrew
else
	BREW_PREFIX=/usr/local
fi
BREW_BIN="$BREW_PREFIX/bin/brew"

info "Step 3/14: Homebrew"
if brew_is_usable; then
	record "already present: Homebrew"
else
	if [ "$(uname -m)" = "arm64" ] && [ -e /usr/local/bin/brew ]; then
		warn "Ignoring Intel Homebrew at /usr/local; installing native Homebrew at $BREW_PREFIX."
		record "ignored: Intel Homebrew at /usr/local"
	fi
	if "$dry_run"; then
		# Show the literal command without downloading it.
		# shellcheck disable=SC2016
		info ' /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
	else
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	fi
	record "installed: Homebrew"
	if ! "$dry_run"; then
		brew_is_usable || die "Homebrew is not usable at $BREW_BIN after installation."
	fi
fi

if brew_is_usable; then
	eval "$("$BREW_BIN" shellenv)"
fi

ZPROFILE_MARKER="### Begin Homebrew Init"
read -r -d '' ZPROFILE_BLOCK <<EOF || true
$ZPROFILE_MARKER
eval "\$($BREW_BIN shellenv)"
### End Homebrew Init
EOF
if [ -f "$HOME/.zprofile" ] && grep -qF "$ZPROFILE_MARKER" "$HOME/.zprofile"; then
	if grep -qF "$BREW_BIN shellenv" "$HOME/.zprofile"; then
		record "already present: Homebrew init in ~/.zprofile"
	else
		run replace_block "$HOME/.zprofile" "$ZPROFILE_BLOCK" "$ZPROFILE_MARKER" "### End Homebrew Init"
		record "updated: Homebrew init in ~/.zprofile"
	fi
else
	run touch "$HOME/.zprofile"
	run append_block "$HOME/.zprofile" "$ZPROFILE_BLOCK"
	record "installed: Homebrew init in ~/.zprofile"
fi

info "Step 4/14: brew git and gh"
for formula in git gh; do
	if [ -x "$BREW_BIN" ] && "$BREW_BIN" list --formula "$formula" >/dev/null 2>&1; then
		record "already present: brew formula $formula"
	else
		run "$BREW_BIN" install "$formula"
		record "installed: brew formula $formula"
	fi
done

info "Step 5/14: git identity and defaults"
resolve_git_identity user.name GIT_NAME name
resolve_git_identity user.email GIT_EMAIL email
ensure_git_setting user.name "$GIT_NAME"
ensure_git_setting user.email "$GIT_EMAIL"
ensure_git_setting init.defaultBranch main
ensure_git_setting core.excludesfile "$HOME/.gitignore_global"
if [ -e "$HOME/.gitignore_global" ]; then
	record "already present: ~/.gitignore_global"
else
	run create_file "$HOME/.gitignore_global" .DS_Store
	record "installed: ~/.gitignore_global"
fi

info "Step 6/14: SSH key"
run mkdir -p "$HOME/.ssh"
run chmod 700 "$HOME/.ssh"
if [ -f "$SSH_KEY" ]; then
	record "already present: SSH key $SSH_KEY"
else
	run ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$SSH_KEY"
	record "installed: SSH key $SSH_KEY"
fi

SSH_CONFIG_MARKER="### Begin GitHub SSH"
read -r -d '' SSH_CONFIG_BLOCK <<EOF || true
$SSH_CONFIG_MARKER
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile $SSH_KEY
### End GitHub SSH
EOF
if [ -f "$HOME/.ssh/config" ] && grep -qF "$SSH_CONFIG_MARKER" "$HOME/.ssh/config"; then
	record "already present: GitHub SSH config"
else
	run touch "$HOME/.ssh/config"
	run chmod 600 "$HOME/.ssh/config"
	run append_block "$HOME/.ssh/config" "$SSH_CONFIG_BLOCK"
	record "installed: GitHub SSH config"
fi
if [ -f "$SSH_KEY" ] || ! "$dry_run"; then
	run ssh-add --apple-use-keychain "$SSH_KEY"
else
	info "Would add the newly generated SSH key to the Apple keychain."
fi

info "Step 7/14: GitHub CLI authentication"
if gh auth status >/dev/null 2>&1; then
	record "already present: GitHub CLI authentication"
else
	warn "GitHub authentication needs you: complete this step in your browser."
	run gh auth login
	record "installed: GitHub CLI authentication"
fi

if [ -f "$SSH_KEY.pub" ]; then
	ssh_key_body="$(awk '{print $2}' "$SSH_KEY.pub")"
	if gh ssh-key list 2>/dev/null | grep -qF "$ssh_key_body"; then
		record "already present: SSH public key on GitHub"
	else
		key_title="$(scutil --get ComputerName 2>/dev/null || hostname -s)"
		run gh ssh-key add "$SSH_KEY.pub" --title "$key_title"
		record "installed: SSH public key on GitHub"
	fi
elif "$dry_run"; then
	info "Would register the newly generated SSH public key with GitHub."
	record "would install: SSH public key on GitHub"
else
	die "SSH public key not found at $SSH_KEY.pub."
fi

info "Step 8/14: Seed GitHub SSH host key"
if ssh-keygen -F github.com >/dev/null 2>&1; then
	record "already present: github.com SSH host key"
else
	github_host_key_file="$(mktemp)"
	if ! ssh-keyscan -t ed25519 github.com >"$github_host_key_file"; then
		rm -f "$github_host_key_file"
		die "Could not retrieve GitHub's ED25519 SSH host key; check the network connection."
	fi
	if [ ! -s "$github_host_key_file" ]; then
		rm -f "$github_host_key_file"
		die "GitHub's ED25519 SSH host key scan returned no key; check the network connection."
	fi
	github_host_key_fp="$(ssh-keygen -lf "$github_host_key_file" | awk 'NR == 1 { print $2 }')"
	if [ "$github_host_key_fp" != "$GITHUB_ED25519_FP" ]; then
		rm -f "$github_host_key_file"
		die "GitHub SSH host key fingerprint mismatch: expected $GITHUB_ED25519_FP, received $github_host_key_fp. The connection may be intercepted; known_hosts was not changed."
	fi
	if [ ! -f "$HOME/.ssh/known_hosts" ]; then
		run touch "$HOME/.ssh/known_hosts"
		run chmod 600 "$HOME/.ssh/known_hosts"
	fi
	run append_block "$HOME/.ssh/known_hosts" "$(<"$github_host_key_file")"
	rm -f "$github_host_key_file"
	record "installed: github.com SSH host key"
fi

info "Step 9/14: Verify SSH to GitHub"
if "$dry_run"; then
	info " ssh -T git@github.com"
	record "would verify: SSH authentication to GitHub"
else
	info " ssh -T git@github.com"
	ssh_output="$(ssh -T git@github.com 2>&1 || true)"
	printf '%s\n' "$ssh_output"
	grep -qF "successfully authenticated" <<<"$ssh_output" || die "SSH authentication to GitHub failed; fix it before cloning."
	record "verified: SSH authentication to GitHub"
fi

info "Step 10/14: Clone ~/.env"
if [ -e "$HOME/.env" ]; then
	repo_is_expected "$HOME/.env" "$ENV_REPO" || die "$HOME/.env exists but is not the expected dotfiles repository."
	# A migrated home directory can carry a stale checkout whose months-old Brewfile breaks installation.
	info "$HOME/.env is already present; checking for updates."
	update_env_checkout "$HOME/.env"
else
	run git clone "$ENV_REPO" "$HOME/.env"
	record "installed: ~/.env"
fi

ai_team_ready=false
info "Step 11/14: Clone ~/.ai-team"
if "$no_ai_team"; then
	info "Skipping ~/.ai-team (--no-ai-team)."
	record "skipped: ~/.ai-team (--no-ai-team)"
elif [ -z "$AI_TEAM_REPO" ]; then
	info "No shared-context repo is configured; set AI_TEAM_REPO to enable it."
	record "skipped: ~/.ai-team (AI_TEAM_REPO is not set)"
elif [ -e "$HOME/.ai-team" ]; then
	repo_is_expected "$HOME/.ai-team" "$AI_TEAM_REPO" || die "$HOME/.ai-team exists but is not the expected shared-context repository."
	info "$HOME/.ai-team is already present; skipping clone."
	ai_team_ready=true
	record "already present: ~/.ai-team"
elif run git clone "$AI_TEAM_REPO" "$HOME/.ai-team"; then
	ai_team_ready=true
	record "installed: ~/.ai-team"
else
	warn "Could not clone the private ~/.ai-team repo; access may be denied. Continuing without it."
	FAILURES+=("$HOME/.ai-team clone failed (private repository access denied or unavailable)")
fi

info "Step 12/14: Run dotfiles installer"
if "$no_install"; then
	info "Skipping ~/.env/install.sh (--no-install)."
	record "skipped: ~/.env/install.sh (--no-install)"
else
	warn "install.sh asks for your sudo password immediately, then runs largely unattended for 45–90 minutes."
	run "$HOME/.env/install.sh"
	record "installed: dotfiles packages and shell configuration"
fi

info "Step 13/14: Install shared AI-team context"
if "$ai_team_ready"; then
	run "$HOME/.ai-team/scripts/install.sh" --tools all
	run "$HOME/.ai-team/scripts/verify.sh" --tools all
	record "installed and verified: shared AI-team context"
else
	record "skipped: shared AI-team installer"
fi

info "Step 14/14: Final summary"
ok "Installed or skipped because already present:"
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
	"📋 sign in to Claude Code and Codex" \
	"📋 re-add Claude Code plugin marketplaces" \
	"📋 copy ~/.claude/ (settings.json, hooks/, scripts/, commands/, personal/, projects/*/memory/) from the previous machine" \
	"📋 restore ~/.env/work-stuff.zsh" \
	"📋 import or regenerate the GPG signing key" \
	"📋 colima start"
warn "Open a new shell with 'exec zsh' before nvm, pyenv, and the new PATH are available."
