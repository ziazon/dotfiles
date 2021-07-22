export EDITOR='subl -w'
export PYENV_ROOT="$HOME/.pyenv"
export GOPATH=$HOME/go

if type brew &>/dev/null; then
  export GOROOT="$(brew --prefix golang)/libexec"
fi

export ZPLUG_HOME=/usr/local/opt/zplug

export PGDATABASE=postgres

# PATH
PATH="/usr/local/sbin:$PATH"
PATH="$HOME/.local/bin:$PATH"
if type brew &>/dev/null; then
  PATH="$(brew --prefix sqlite)/bin:$PATH"
fi
PATH="$PATH:${GOPATH}/bin:${GOROOT}/bin"
PATH="$HOME/.poetry/bin:$PATH"
PATH="$PYENV_ROOT/bin:$PATH"
PATH="/usr/local/opt/grep/libexec/gnubin:$PATH"
PATH="/usr/local/opt/findutils/libexec/gnubin:$PATH"

export PATH

export NVM_DIR="$HOME/.nvm"
