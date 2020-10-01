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

brew cask install \
docker \
font-fira-code \
font-source-code-pro-for-powerline \
google-chrome \
iterm2 \
karabiner-elements \
rectangle \
virtualbox \
xquartz

brew install \
circleci \
cmake \
cookiecutter \
ctags \
direnv \
docker-compose \
findutils \
fzf \
fzy \
gcc \
gd \
gh \
git \
git-delta \
git-flow \
git-lfs \
glib \
gmp \
gnupg \
gnutls \
golang \
graphviz \
grep \
gts \
helm \
httpie \
jq \
kops \
kubectx \
kubernetes-cli \
kubernetes-helm \
kubetail \
libpq \
libressl \
lua \
minikube \
neovim \
newman \
openjdk \
pgcli \
pipx \
pyenv \
pyenv-virtualenv \
readline \
rlwrap \
ruby \
shellcheck \
shfmt \
sphinx-doc \
starship \
terraform \
tmux \
unixodbc \
vim \
watch \
webp \
xclip \
xz \
yarn \
zlib \
zplug \
zsh \
zsh-completions

curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python3

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

nvm install v12.18.4 # use nvm ls-remote to get current version first

npm i -g \
@nestjs/cli \
@vue/cli \
aws-cdk \
eslint \
gulp \
init-module \
madge \
npm-check-updates \
pug-lint \
pyright \
sort-package-json \
typeorm \
typesync \
vue-language-server

# install cli packages in rust
cargo install \
bat \
du-dust \
exa \
prettydiff \
procs \
ripgrep

# install Zinit for zsh plugin managmenet
sh -c "$(curl -fsSL https://raw.githubusercontent.com/zdharma/zinit/master/doc/install.sh)"

# install aws cli
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg" && sudo installer -pkg AWSCLIV2.pkg -target /

rm -f AWSCLIV2.pkg

# install services
brew install nginx \
postgresql \
rabbitmq \
redis \
mysql


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

echo "\033[38;5;111mSet poetry virtualenvs to be stored in project\033[0m"
poetry config virtualenvs.in-project true

# zsh zinit self-update
echo "\033[38;5;82mSetup Complete\033[0m"
