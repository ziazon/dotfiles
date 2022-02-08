#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

sudo apt -y remove command-not-found python3-commandnotfound
sudo apt update

curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo add-apt-repository ppa:longsleep/golang-backports
sudo apt-add-repository universe

sudo apt install software-properties-common
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt update

sudo apt -y install apt-transport-https ca-certificates curl software-properties-common build-essential gnupg lsb-release vault consul packer terraform nomad jq unzip golang-go golang-cfssl tmux zsh fonts-firacode git gh fzf git-lfs
sudo apt --fix-broken install

curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
sh -c "$(curl -fsSL https://starship.rs/install.sh)"
sh -c "$(curl -fsSL https://git.io/zinit-install)"

curl https://pyenv.run | bash
pyenv install 3.9.10
pyenv global 3.9.10

curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python -

rm -fr ~/.tmux/plugins/tpm && git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
mkdir ~/.config

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install 16
export PATH=$HOME/.cargo/bin:$PATH
export PATH=$PATH:/usr/local/go/bin
cargo install bat
cargo install du-dust
cargo install exa
cargo install prettydiff
cargo install procs
cargo install ripgrep
sh -c "$(curl -fsSL https://git.io/zinit-install)"
export GOPATH=$HOME/go
export PATH="$PATH:${GOPATH}/bin:${GOROOT}/bin"
go install github.com/jubairsaidi/nats-tail@latest

wget https://github.com/digitalocean/doctl/releases/download/v1.69.0/doctl-1.69.0-linux-amd64.tar.gz
wget https://release.gitkraken.com/linux/gitkraken-amd64.deb
wget https://github.com/nats-io/nats-server/releases/download/v2.7.2/nats-server-v2.7.2-amd64.deb

sudo dpkg -i gitkraken-amd64.deb
sudo dpkg -i nats-server-v2.7.2-amd64.deb
tar xf doctl-1.69.0-linux-amd64.tar.gz
sudo mv doctl /usr/local/bin

rm -f doctl-1.69.0-linux-amd64.tar.gz nats-server-v2.7.2-amd64.deb gitkraken-amd64.deb

git lfs install
git lfs install --system

ln -s $HOME/.env/starship.toml $HOME/.config/starship.toml
ln -s $HOME/.env/tmux.conf $HOME/.tmux.conf

poetry config virtualenvs.in-project true
