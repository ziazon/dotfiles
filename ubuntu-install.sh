#!/bin/sh

touch $HOME/.zshrc

export DEBIAN_FRONTEND=noninteractive
sudo apt -y remove command-not-found python3-commandnotfound
sudo apt update
sudo apt -y install apt-transport-https ca-certificates curl software-properties-common build-essential gnupg lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo add-apt-repository ppa:longsleep/golang-backports
sudo apt-add-repository universe
sudo apt update

sudo apt -y install docker-ce docker-ce-cli containerd.io vault consul packer terraform nomad jq unzip golang-go golang-cfssl tmux zsh fonts-firacode git gh fzf

sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
sh -c "$(curl -fsSL https://starship.rs/install.sh)"
curl https://pyenv.run | bash
curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python -
sh -c "$(curl -fsSL https://git.io/zinit-install)"

rm -fr ./.tmux/plugins/tpm && git clone https://github.com/tmux-plugins/tpm ./.tmux/plugins/tpm


consul -autocomplete-install
vault -autocomplete-install
nomad -autocomplete-install

snap install doctl
mkdir ~/.config
snap connect doctl:dot-docker

usermod -a -G docker consul

snap install node --classic

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

nvm install 14
nvm use 14

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
