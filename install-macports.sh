#!/usr/bin/env bash
#
# Slim installer for Intel Macs, where Homebrew no longer installs.
#   1. Installs the CLI tools in ./ports.txt via MacPorts
#   2. Installs the tmux plugin manager
#   3. Wires up the shell (configure.zsh)
#
# Safe to re-run: ports already installed are skipped.

PORT_BIN=/opt/local/bin/port
export PATH="/opt/local/bin:/opt/local/sbin:$PATH"

touch "$HOME/.zshrc"

warnings=()

warn() {
  warnings+=("$1")
  printf '\033[38;5;214mWARNING: %s\033[0m\n' "$1"
}

[ -x "$PORT_BIN" ] || { printf 'MacPorts is not installed; run bootstrap.sh first.\n' >&2; exit 1; }

sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# --- Packages -----------------------------------------------------------------
sudo "$PORT_BIN" -N selfupdate || warn "port selfupdate failed."

ports=()
while IFS= read -r line; do
  line="${line%%#*}"
  line="$(printf '%s' "$line" | tr -d '[:space:]')"
  [ -n "$line" ] && ports+=("$line")
done <"$HOME/.env/ports.txt"

for p in "${ports[@]}"; do
  if "$PORT_BIN" -q installed "$p" 2>/dev/null | grep -q active; then
    continue
  fi
  printf '\033[38;5;111mInstalling %s\033[0m\n' "$p"
  sudo "$PORT_BIN" -N install "$p" || warn "port failed to install $p."
done

# Use MacPorts zsh as the login shell when it is installed.
if [ -x /opt/local/bin/zsh ] && ! grep -qx /opt/local/bin/zsh /etc/shells; then
  echo /opt/local/bin/zsh | sudo tee -a /etc/shells >/dev/null
fi

# --- tmux plugin manager ------------------------------------------------------
mkdir -p "$HOME/.tmux"
rm -rf "$HOME/.env/.tmux/plugins/tpm"
git clone https://github.com/tmux-plugins/tpm "$HOME/.env/.tmux/plugins/tpm" ||
  warn "failed to clone tpm."

# --- Wire up the shell --------------------------------------------------------
/bin/zsh "$HOME/.env/configure.zsh"

if [ "${#warnings[@]}" -gt 0 ]; then
  printf '\033[38;5;160mINSTALL COMPLETED WITH PROBLEMS:\033[0m\n'
  for warning in "${warnings[@]}"; do
    printf '\033[38;5;214m- %s\033[0m\n' "$warning"
  done
else
  printf '\033[38;5;111mInstall completed cleanly.\033[0m\n'
fi
