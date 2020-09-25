export EDITOR='subl -w'
export PYENV_ROOT="$HOME/.pyenv"

export GOPATH=$HOME/go
export GOROOT="$(brew --prefix golang)/libexec"

export ZPLUG_HOME=/usr/local/opt/zplug

# PATH
PATH="/usr/local/sbin:$PATH"
PATH="$HOME/.local/bin:$PATH"
PATH="$(brew --prefix sqlite)/bin:$PATH"
PATH="$PATH:${GOPATH}/bin:${GOROOT}/bin"
PATH="$HOME/.poetry/bin:$PATH"
PATH="$PYENV_ROOT/bin:$PATH"
PATH="/usr/local/opt/grep/libexec/gnubin:$PATH"

export PATH

export NVM_DIR="$HOME/.nvm"
