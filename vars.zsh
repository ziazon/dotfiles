export EDITOR='vim'
export PYENV_ROOT="$HOME/.pyenv"
export GOPATH="$HOME/go"
export NVM_DIR="$HOME/.nvm"
export PGDATABASE=postgres

# Derive the brew prefix from the binary's location instead of spawning
# `brew --prefix` (x2, ~130ms). /opt/homebrew/bin/brew -> /opt/homebrew,
# /usr/local/bin/brew -> /usr/local. `opt/go` is brew's stable per-formula
# symlink (what `brew --prefix golang` resolves to), so no spawn needed there
# either.
BREW_PREFIX=""
if type brew &>/dev/null; then
  BREW_PREFIX="${$(whence -p brew):h:h}"
  export GOROOT="$BREW_PREFIX/opt/go/libexec"
fi

# PATH (later entries take precedence — they're prepended)
PATH="$PATH:${GOPATH}/bin"
if [ -n "$BREW_PREFIX" ]; then
  PATH="$PATH:${GOROOT}/bin"
  PATH="$BREW_PREFIX/opt/findutils/libexec/gnubin:$PATH"  # GNU find/xargs
  PATH="$BREW_PREFIX/opt/grep/libexec/gnubin:$PATH"       # GNU grep
  PATH="$BREW_PREFIX/opt/sqlite/bin:$PATH"
  # postgresql@NN is keg-only: brew links only <tool>-NN into bin, so the keg's
  # own bin has to be on PATH for a bare `psql`/`pg_dump`. Newest major wins.
  for pg_bin in "$BREW_PREFIX"/opt/postgresql@*/bin(NOn[1]); do
    PATH="$pg_bin:$PATH"
  done
  unset pg_bin
  PATH="$BREW_PREFIX/sbin:$PATH"
fi
PATH="$HOME/.cargo/bin:$PATH"     # rust tools (bat, eza, rg, ...)
PATH="$HOME/.local/bin:$PATH"     # poetry, pipx
PATH="$PYENV_ROOT/bin:$PATH"

export PATH
