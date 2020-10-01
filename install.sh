#!/bin/sh

touch $HOME/.zshrc

#install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

# install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# install packages/libs
brew tap johanhaleby/kubetail
brew tap homebrew/cask-fonts

brew install svn

brew cask install docker
brew cask install font-fira-code
brew cask install font-source-code-pro-for-powerline
brew cask install gpg-suite
brew cask install google-chrome
brew cask install iterm2
brew cask install karabiner-elements
brew cask install rectangle
brew cask install virtualbox
brew cask install xquartz

brew install circleci
brew install cmake
brew install cookiecutter
brew install ctags
brew install direnv
brew install docker-compose
brew install findutils
brew install fzf
brew install fzy
brew install gcc
brew install gd
brew install gh
brew install git
brew install git-delta
brew install git-flow
brew install git-lfs
brew install glib
brew install gmp
brew install gnupg
brew install gnutls
brew install golang
brew install graphviz
brew install grep
brew install gts
brew install helm
brew install httpie
brew install jq
brew install kops
brew install kubectx
brew install kubernetes-cli
brew install kubernetes-helm
brew install kubetail
brew install libpq
brew install libressl
brew install lua
brew install minikube
brew install neovim
brew install newman
brew install openjdk
brew install pgcli
brew install pipx
brew install pyenv
brew install pyenv-virtualenv
brew install readline
brew install rlwrap
brew install ruby
brew install shellcheck
brew install shfmt
brew install sphinx-doc
brew install starship
brew install terraform
brew install tmux
brew install unixodbc
brew install vim
brew install watch
brew install webp
brew install xclip
brew install xz
brew install yarn
brew install zlib
brew install zplug
brew install zsh
brew install zsh-completions

curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python3

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

nvm install v12.18.4 # use nvm ls-remote to get current version first

npm i -g @nestjs/cli
npm i -g @vue/cli
npm i -g aws-cdk
npm i -g eslint
npm i -g gulp
npm i -g init-module
npm i -g madge
npm i -g npm-check-updates
npm i -g pug-lint
npm i -g pyright
npm i -g sort-package-json
npm i -g typeorm
npm i -g typesync
npm i -g vue-language-server

# install cli packages in rust
cargo install bat
cargo install du-dust
cargo install exa
cargo install prettydiff
cargo install procs
cargo install ripgrep

# install Zinit for zsh plugin managmenet
sh -c "$(curl -fsSL https://raw.githubusercontent.com/zdharma/zinit/master/doc/install.sh)"

# install aws cli
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg" && sudo installer -pkg AWSCLIV2.pkg -target /

rm -f AWSCLIV2.pkg

# install services
brew install nginx
brew install postgresql
brew install rabbitmq
brew install redis
brew install mysql

compaudit | xargs chmod g-w

UPDATEZSHRC=1

read -r -d '' ZSHRCINIT <<- EOM
### Begin Env Init
source "\$HOME/.env/settings.zsh"
source "\$HOME/.env/vars.zsh"
source "\$HOME/.env/plugins.zsh"
source "\$HOME/.env/functions.zsh"
source "\$HOME/.env/aliases.zsh"
source "\$HOME/.env/bindings.zsh"
[ -s "\$HOME/.env/work-stuff.zsh" ] && \. "\$HOME/.env/work-stuff.zsh"
### End Env Init
EOM

if [ "$(grep -F "${ZSHRCINIT}" $HOME/.zshrc)" = "${ZSHRCINIT}" ]; then
  echo "\033[38;5;160mEnv init already added to $HOME/.zshrc\033[0m"
  UPDATEZSHRC=0
fi

if [ $UPDATEZSHRC -eq 1 ]; then
  echo "\033[38;5;82mInstalling Env init to $HOME/.zshrc\033[0m"
  echo "\n$ZSHRCINIT" >> $HOME/.zshrc
fi

cat $HOME/.env/starship.toml > $HOME/.config/starship.toml

echo "\033[38;5;111mLoading changes to $HOME/.zshrc to shell\033[0m"
zsh $HOME/.zshrc

echo "\033[38;5;111mInstall python 3.7.8\033[0m"
pyenv install 3.7.8

echo "\033[38;5;111mSet python 3.7.8 as system default\033[0m"
pyenv global 3.7.8


echo "\033[38;5;111minstall git-lfs\033[0m"
git lfs install
git lfs install --system

echo "\033[38;5;111mSet poetry virtualenvs to be stored in project\033[0m"
poetry config virtualenvs.in-project true

# zsh zinit self-update
echo "\033[38;5;82mSetup Complete\033[0m"
