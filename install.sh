#!/bin/sh

touch $HOME/.zshrc

sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

#install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

# install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# install packages/libs
brew tap johanhaleby/kubetail
brew tap bramstein/webfonttools
brew tap homebrew/cask-fonts

brew install svn

brew install --cask docker
brew install --cask font-fira-code
brew install --cask font-source-code-pro-for-powerline
brew install --cask gpg-suite
brew install --cask google-chrome
brew install --cask iterm2
brew install --cask karabiner-elements
brew install --cask rectangle
brew install --cask virtualbox
brew install --cask visual-studio-code
brew install --cask gitkraken
brew install --cask slack
brew install --cask gitkraken
brew install --cask xquartz

brew install aircrack-ng
brew install ansible
brew install bfg
brew install binutils
brew install binwalk
brew install Caskroom/cask/java
brew install Caskroom/cask/xquartz
brew install cifer
brew install circleci
brew install cmake
brew install cookiecutter
brew install ctags
brew install dex2jar
brew install direnv
brew install dns2tcp
brew install docker-compose
brew install fcrackzip
brew install findutils
brew install foremost
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
brew install hashpump
brew install helm
brew install homebrew/x11/xpdf
brew install httpie
brew install hydra
brew install imagemagick
brew install john
brew install jq
brew install knock
brew install kops
brew install kubectx
brew install kubernetes-cli
brew install kubernetes-helm
brew install kubetail
brew install libpq
brew install libressl
brew install lua
brew install lynx
brew install minikube
brew install neovim
brew install netpbm
brew install newman
brew install nmap
brew install openjdk
brew install p7zip
brew install pgcli
brew install pigz
brew install pipx
brew install pngcheck
brew install pv
brew install pyenv
brew install pyenv-virtualenv
brew install readline
brew install rename
brew install rhino
brew install rlwrap
brew install ruby
brew install sfnt2woff
brew install sfnt2woff-zopfli
brew install shellcheck
brew install shfmt
brew install socat
brew install speedtest_cli
brew install sphinx-doc
brew install sqlmap
brew install ssh-copy-id
brew install starship
brew install tcpflow
brew install tcpreplay
brew install tcptrace
brew install terraform
brew install tmux
brew install tree
brew install ucspi-tcp
brew install unixodbc
brew install vim
brew install watch
brew install webkit2png
brew install webp
brew install woff2
brew install xclip
brew install xz
brew install yarn
brew install zlib
brew install zopfli
brew install zplug
brew install zsh
brew install zsh-completions

rm -fr ./.tmux/plugins/tpm && git clone https://github.com/tmux-plugins/tpm ./.tmux/plugins/tpm

curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python3

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

nvm install 16
nvm use 16

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
export $PATH=$HOME/.cargo/bin:$PATH

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

#install nats-tail useful util for nats-streaming-server
go get -u github.com/wallyqs/nats-tail

rm -f AWSCLIV2.pkg

# install services
brew install nginx
brew install postgresql
brew install rabbitmq
brew install nats-streaming-server
brew install redis
brew install mysql

zsh ./configure.zsh
