#!/usr/bin/env bash
#
# Bootstrap a new macOS machine.
#   1. Installs Homebrew (arch-aware: Apple Silicon -> /opt/homebrew, Intel -> /usr/local)
#   2. Installs everything in ./Brewfile via `brew bundle`
#   3. Installs language toolchains (Rust, Python via pyenv, Node via nvm, Go tools)
#   4. Wires up the shell (configure.zsh); plugins.zsh self-installs zinit on first start
#
# Safe to re-run: brew bundle is idempotent and version installs skip if present.

touch "$HOME/.zshrc"

warnings=()

warn() {
  warnings+=("$1")
  printf '\033[38;5;214mWARNING: %s\033[0m\n' "$1"
}

# Keep sudo alive for the duration of the script.
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# --- Homebrew -----------------------------------------------------------------
if [ "$(uname -m)" = "arm64" ]; then
  BREW_PREFIX=/opt/homebrew
else
  BREW_PREFIX=/usr/local
fi
BREW_BIN="$BREW_PREFIX/bin/brew"

if ! "$BREW_BIN" --version >/dev/null 2>&1; then
  if [ "$(uname -m)" = "arm64" ] && [ -e /usr/local/bin/brew ]; then
    warn "Ignoring Intel Homebrew at /usr/local; installing native Homebrew at $BREW_PREFIX."
  fi
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Put native brew on PATH for this script.
if [ -x "$BREW_BIN" ]; then
  eval "$("$BREW_BIN" shellenv)"
fi

# HashiCorp's tap must be explicitly trusted before Homebrew can load its formulae.
if ! brew tap | grep -Fxq 'hashicorp/tap'; then
  brew tap hashicorp/tap || warn "failed to tap hashicorp/tap."
fi
# `brew trust --tap` is idempotent, so no guard is needed.
brew trust --tap hashicorp/tap || warn "failed to trust hashicorp/tap."

# --- Packages (formulae + casks) ---------------------------------------------
brew bundle --file="$HOME/.env/Brewfile"
brew_bundle_status=$?
brew_bundle_check_output="$(brew bundle check --file="$HOME/.env/Brewfile" --verbose 2>&1)"
brew_bundle_check_status=$?
printf '%s\n' "$brew_bundle_check_output"

# A transient per-entry failure can leave packages missing even after brew bundle continues.
if [ "$brew_bundle_check_status" -ne 0 ]; then
  printf '\033[38;5;214mHomebrew entries are missing; retrying brew bundle once.\033[0m\n'
  brew bundle --file="$HOME/.env/Brewfile"
  brew_bundle_status=$?
  brew_bundle_check_output="$(brew bundle check --file="$HOME/.env/Brewfile" --verbose 2>&1)"
  brew_bundle_check_status=$?
  printf '%s\n' "$brew_bundle_check_output"
fi

if [ "$brew_bundle_status" -ne 0 ] || [ "$brew_bundle_check_status" -ne 0 ]; then
  printf '\033[38;5;214mWARNING: Homebrew did not install every Brewfile entry:\033[0m\n'
  if [ "$brew_bundle_status" -ne 0 ]; then
    warn "brew bundle exited with status $brew_bundle_status."
  fi
  if [ "$brew_bundle_check_status" -ne 0 ]; then
    warn "brew bundle check reports missing entries: $brew_bundle_check_output"
  fi
fi

# --- tmux plugin manager ------------------------------------------------------
mkdir -p "$HOME/.tmux"
rm -rf "$HOME/.env/.tmux/plugins/tpm"
git clone https://github.com/tmux-plugins/tpm "$HOME/.env/.tmux/plugins/tpm"

# --- Rust ---------------------------------------------------------------------
if ! command -v rustc >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi
export PATH="$HOME/.cargo/bin:$PATH"

# Other Rust-based CLI tools are installed as Homebrew formulae.
if command -v cargo >/dev/null 2>&1; then
  # prettydiff 0.9.0 is library-only; 0.6.2 is the last version with the binary used by the diff alias.
  cargo install --locked prettydiff@0.6.2 || warn "cargo failed to install prettydiff@0.6.2."
else
  warn "cargo is missing; skipped installing Rust-based CLI tools."
fi

# --- Python (pyenv) -----------------------------------------------------------
printf '\033[38;5;111mInstalling Python 3.12 via pyenv\033[0m\n'
if command -v pyenv >/dev/null 2>&1; then
  pyenv install --skip-existing 3.12
  pyenv global 3.12
else
  warn "pyenv is missing; skipped installing and selecting Python 3.12."
fi

# Poetry (current installer; installs to ~/.local/bin)
curl -sSL https://install.python-poetry.org | python3 -
# configure.zsh needs poetry on PATH to configure completion and virtualenvs.
export PATH="$HOME/.local/bin:$PATH"

# --- Node (nvm) ---------------------------------------------------------------
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

nvm install --lts
nvm alias default 'lts/*'

# Global npm tooling
if command -v npm >/dev/null 2>&1; then
  npm i -g markdownlint-cli2
else
  warn "npm is missing; skipped installing markdownlint-cli2."
fi

# --- Go tools -----------------------------------------------------------------
if command -v go >/dev/null 2>&1; then
  go install golang.org/x/tools/gopls@latest
  go install honnef.co/go/tools/cmd/staticcheck@latest
else
  warn "go is missing; skipped installing gopls and staticcheck."
fi

# --- AWS CLI ------------------------------------------------------------------
if ! command -v aws >/dev/null 2>&1; then
  curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
  sudo installer -pkg AWSCLIV2.pkg -target /
  rm -f AWSCLIV2.pkg
fi

# --- Wire up the shell --------------------------------------------------------
zsh "$HOME/.env/configure.zsh"

if [ "${#warnings[@]}" -gt 0 ]; then
  printf '\033[38;5;160mINSTALL COMPLETED WITH PROBLEMS:\033[0m\n'
  for warning in "${warnings[@]}"; do
    printf '\033[38;5;214m- %s\033[0m\n' "$warning"
  done
else
  printf '\033[38;5;111mInstall completed cleanly.\033[0m\n'
fi
