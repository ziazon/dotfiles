#!/usr/bin/env bash
#
# Bootstrap a new macOS machine.
#   1. Installs Homebrew (arch-aware: Apple Silicon -> /opt/homebrew, Intel -> /usr/local)
#   2. Installs everything in ./Brewfile via `brew bundle`
#   3. Installs language toolchains (Rust, Python via pyenv, Node via nvm, Go tools)
#   4. Installs the zinit zsh plugin manager and wires up the shell (configure.zsh)
#
# Safe to re-run: brew bundle is idempotent and version installs skip if present.

touch "$HOME/.zshrc"

# Keep sudo alive for the duration of the script.
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# --- Homebrew -----------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Put brew on PATH for this script, whichever prefix it landed in.
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# --- Packages (formulae + casks) ---------------------------------------------
brew bundle --file="$HOME/.env/Brewfile"

# --- tmux plugin manager ------------------------------------------------------
rm -rf "$HOME/.env/.tmux/plugins/tpm"
git clone https://github.com/tmux-plugins/tpm "$HOME/.env/.tmux/plugins/tpm"

# --- Rust ---------------------------------------------------------------------
if ! command -v rustc >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi
export PATH="$HOME/.cargo/bin:$PATH"

# Rust-based CLI tools (aliased in aliases.zsh)
cargo install bat du-dust eza prettydiff procs ripgrep

# --- Python (pyenv) -----------------------------------------------------------
echo "\033[38;5;111mInstalling Python 3.12 via pyenv\033[0m"
pyenv install --skip-existing 3.12
pyenv global 3.12

# Poetry (current installer; installs to ~/.local/bin)
curl -sSL https://install.python-poetry.org | python3 -

# --- Node (nvm) ---------------------------------------------------------------
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

nvm install --lts
nvm alias default 'lts/*'

# Global npm tooling
npm i -g markdownlint-cli2

# --- Go tools -----------------------------------------------------------------
go install golang.org/x/tools/gopls@latest
go install honnef.co/go/tools/cmd/staticcheck@latest

# --- zinit (zsh plugin manager) ----------------------------------------------
bash -c "$(curl -fsSL https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)"

# --- AWS CLI ------------------------------------------------------------------
if ! command -v aws >/dev/null 2>&1; then
  curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
  sudo installer -pkg AWSCLIV2.pkg -target /
  rm -f AWSCLIV2.pkg
fi

# --- Wire up the shell --------------------------------------------------------
zsh "$HOME/.env/configure.zsh"
