# Brewfile — declarative package manifest for `brew bundle`.
# Regenerate a snapshot of the current machine with:  brew bundle dump --force
# Install everything with:                            brew bundle --file=~/.env/Brewfile
#
# Grouped by purpose. Reflects the tools actually in use on this machine.

## Taps
tap "hashicorp/tap"      # terraform/consul/nomad/vault live here (moved out of core)

## Shell & terminal
brew "zsh"
brew "zsh-completions"
brew "starship"          # cross-shell prompt
brew "tmux"
brew "herdr"             # agent multiplexer for the terminal
brew "direnv"            # per-directory env via .envrc
brew "fzf"               # fuzzy finder
brew "fzy"
brew "tree"
brew "watch"

## Core CLI utilities
brew "bat"
brew "dust"              # du-dust crate
brew "eza"
brew "procs"
brew "ripgrep"           # provides rg
brew "grep"              # GNU grep (gnubin)
brew "findutils"         # GNU find/xargs/locate (gnubin)
brew "wget"
brew "rsync"             # macOS only ships openrsync
brew "jq"
brew "httpie"
brew "pv"
brew "rename"
brew "rlwrap"
brew "xclip"
brew "socat"
brew "ssh-copy-id"
brew "ucspi-tcp"
brew "lynx"
brew "magic-wormhole"    # send files/text between machines
brew "speedtest-cli"

## Git & dev tooling
brew "git"
brew "gh"                # GitHub CLI
brew "git-delta"         # nicer git diffs
brew "git-flow"
brew "git-lfs"
brew "bfg"               # scrub secrets/large files from git history
brew "ctags"
brew "cmake"
brew "automake"
brew "binutils"
brew "shellcheck"
brew "shfmt"
brew "yamllint"
brew "cookiecutter"

## Languages & runtimes
brew "pyenv"             # python version manager
brew "pyenv-virtualenv"
brew "go"
brew "openjdk@11"
brew "perl"
brew "php"
brew "lua"
brew "r"
brew "rhino"             # JavaScript engine
brew "pnpm"
brew "yarn"

## Python ecosystem
brew "black"
brew "ipython"
brew "pipx"
brew "pillow"
brew "docutils"
brew "sphinx-doc"

## Databases & services
brew "postgresql@17", restart_service: :changed
brew "postgis"
brew "mysql"
brew "mysql-client"
brew "redis", restart_service: :changed
brew "rabbitmq"
brew "nats-streaming-server"
brew "nginx"
brew "pgcli"             # postgres CLI with autocomplete

## Cloud, infra & Kubernetes
brew "doctl"             # DigitalOcean CLI
brew "helm"
brew "kops"
brew "kubectx"
brew "minikube"
brew "mkcert"            # local trusted TLS certs
brew "golang-migrate"
brew "s3cmd"
brew "circleci"
brew "newman"            # Postman collection runner

## HashiCorp stack (openbay-stack infra: shell completions wired in plugins.zsh)
brew "hashicorp/tap/terraform"
brew "hashicorp/tap/consul"
brew "hashicorp/tap/nomad"
brew "hashicorp/tap/vault"

## Media, images & documents
brew "ffmpeg"
brew "imagemagick"
brew "poppler"
brew "graphviz"
brew "pngcheck"
brew "webkit2png"
brew "woff2"
brew "pigz"
brew "udunits"

## Security / network analysis
brew "nmap"
brew "ngrep"
brew "aircrack-ng"
brew "hydra"
brew "john"
brew "sqlmap"
brew "binwalk"
brew "foremost"
brew "fcrackzip"
# hashpump and tcptrace were dropped from homebrew-core.
brew "cifer"
brew "dex2jar"
brew "dns2tcp"
brew "knock"
brew "tcpflow"
brew "tcpreplay"

## Editors
brew "neovim"
brew "vim"

## Other
brew "libressl"
brew "subversion"
brew "certbot"
brew "ansible"
brew "ansible-lint"
brew "docker"
brew "docker-compose"
brew "colima"            # run `colima start` to bring up the container engine

## Casks — GUI apps, editors, terminals & AI tooling
cask "cursor"            # primary IDE
cask "ghostty"           # primary terminal
cask "claude"            # Claude desktop app
cask "claude-code"       # Claude Code CLI
cask "codex"             # OpenAI Codex CLI
cask "chatgpt"           # OpenAI ChatGPT desktop app
cask "gitkraken"
cask "google-chrome"     # claude-in-chrome MCP tools attach to this profile
cask "postman"
cask "gpg-suite"
cask "karabiner-elements"
cask "monitorcontrol"    # controls external monitor brightness and volume
cask "rectangle"
cask "slack"
cask "virtualbox"
cask "xquartz"
cask "font-fira-code"
cask "font-source-code-pro-for-powerline"
