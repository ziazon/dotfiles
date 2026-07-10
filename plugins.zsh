# Cache the output of slow `<tool> init` commands instead of spawning the tool
# on every shell. The cache regenerates whenever the tool's binary is newer
# than the cached script, so upgrades pick up new init code automatically.
_evalcache() {
  local name="$1"; shift
  local cache="$HOME/.cache/zsh-evalcache/$name.zsh"
  local bin
  bin="$(command -v "$1")" || return 0
  if [ ! -s "$cache" ] || [ "$bin" -nt "$cache" ]; then
    command mkdir -p "${cache%/*}"
    # Write to a unique temp file and move atomically on success only, so a
    # failing init command or racing shells can't leave a partial cache.
    local tmp
    tmp="$(command mktemp "${cache}.XXXXXX")" || return 0
    if "$@" > "$tmp"; then
      command mv -f "$tmp" "$cache"
    else
      command rm -f "$tmp"
    fi
  fi
  [ -s "$cache" ] && source "$cache"
}

_evalcache starship starship init zsh --print-full-init
_evalcache pyenv-init pyenv init - zsh
_evalcache pyenv-virtualenv-init pyenv virtualenv-init - zsh

# --- nvm: lazy-loaded ----------------------------------------------------------
# Sourcing nvm.sh eagerly costs 1-2s. The default node (v22) is already first on
# PATH via ~/.nvm-default-path.zsh (sourced from ~/.zshenv + ~/.zprofile), so
# nvm.sh only needs to load when a shell actually calls `nvm`, or enters a repo
# whose .nvmrc pins a different node (handled by load-nvmrc below).
_nvm_source() {
  [ -n "$_NVM_SOURCED" ] && return
  typeset -g _NVM_SOURCED=1
  unfunction nvm 2>/dev/null
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" --no-use
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}
nvm() { _nvm_source; nvm "$@"; }
# --- end nvm lazy-load ----------------------------------------------------------

# Brew's zsh-completions must be on fpath BEFORE compinit runs or they never
# register. vars.zsh (sourced just before this file) computed BREW_PREFIX.
# compaudit requires $BREW_PREFIX/share to not be group-writable — if a brew
# update restores g-w, full compinit shows a one-time "insecure directories?"
# prompt; fix with: chmod g-w "$BREW_PREFIX/share".
if [ -n "$BREW_PREFIX" ]; then
    FPATH=$BREW_PREFIX/share/zsh-completions:$FPATH
fi

# compinit used to run as a hidden side effect of sourcing nvm's
# bash_completion at startup; with nvm lazy-loaded it must run explicitly, or
# every bash-style `complete` below silently fails. Full (slow) init at most
# once a day; otherwise trust the existing dump (-C, ~20ms). Anonymous
# function scopes extendedglob, which the (#q) qualifier requires.
if ! command -v compdef >/dev/null 2>&1; then
  () {
    setopt localoptions extendedglob
    local zcd="${ZDOTDIR:-$HOME}/.zcompdump"
    autoload -Uz compinit
    if [[ -n $zcd(#qN.mh-24) ]]; then
      compinit -C
    else
      # compinit only rewrites the dump when its content changes; touch it
      # (on success only, so a compaudit abort can't arm the fast path with
      # a bad dump) to re-arm the 24h window above.
      compinit && command touch "$zcd"
    fi
  }
fi

autoload -U +X bashcompinit && bashcompinit
for _hc in consul vault nomad; do
  if command -v "$_hc" >/dev/null 2>&1; then
    complete -o nospace -C "$(command -v "$_hc")" "$_hc"
  fi
done
unset _hc

function _makefile_targets {
    local curr_arg;
    local targets;

    targets=''
    if [[ -e "$(pwd)/Makefile" ]]; then
        targets=$( \
            grep -oE '^[a-zA-Z0-9_-]+:' Makefile \
            | sed 's/://' \
            | tr '\n' ' ' \
        )
    fi

    curr_arg=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=( $(compgen -W "${targets[@]}" -- $curr_arg ) );
}

complete -F _makefile_targets make

# fzf key bindings + completion (fzf >= 0.48)
command -v fzf >/dev/null 2>&1 && source <(fzf --zsh)


### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

# Binary release in archive, from GitHub-releases page.
# After automatic unpacking it provides program "fzf".
zinit ice from"gh-r" as"program"
zinit light junegunn/fzf

# One other binary release, it needs renaming from `docker-compose-Linux-x86_64`.
# This is done by ice-mod `mv'{from} -> {to}'. There are multiple packages per
# single version, for OS X, Linux and Windows – so ice-mod `bpick' is used to
# select Linux package – in this case this is actually not needed, Zinit will
# grep operating system name and architecture automatically when there's no `bpick'.
zinit ice from"gh-r" as"program" mv"docker* -> docker-compose" bpick"*linux*"
zinit load docker/compose

# Vim repository on GitHub – a typical source code that needs compilation – Zinit
# can manage it for you if you like, run `./configure` and other `make`, etc. stuff.
# Ice-mod `pick` selects a binary program to add to $PATH. You could also install the
# package under the path $ZPFX, see: https://zdharma-continuum.github.io/zinit/wiki/Compiling-programs
zinit ice as"program" atclone"rm -f src/auto/config.cache; ./configure" \
    atpull"%atclone" make pick"src/vim"
zinit light vim/vim

# Scripts that are built at install (there's single default make target, "install",
# and it constructs scripts by `cat'ing a few files). The make'' ice could also be:
# `make"install PREFIX=$ZPFX"`, if "install" wouldn't be the only, default target.
zinit ice as"program" pick"$ZPFX/bin/git-*" make"PREFIX=$ZPFX"
zinit light tj/git-extras

# For GNU ls (the binaries can be gls, gdircolors, e.g. on OS X when installing the
# coreutils package from Homebrew; you can also use https://github.com/ogham/exa)
zinit ice atclone"dircolors -b LS_COLORS > c.zsh" atpull'%atclone' pick"c.zsh" nocompile'!'
zinit light trapd00r/LS_COLORS

zinit from"gh-r" as"program" mv"direnv* -> direnv" \
  atclone'./direnv hook zsh > zhook.zsh' atpull'%atclone' \
  pick"direnv" src="zhook.zsh" for \
  direnv/direnv

autoload -U add-zsh-hook

# Locate the nearest .nvmrc up the tree without loading nvm (mirrors
# nvm_find_nvmrc, pure zsh — no process spawns).
_find-nvmrc() {
  local dir="$PWD"
  while [ -n "$dir" ]; do
    if [ -s "$dir/.nvmrc" ]; then print -r -- "$dir/.nvmrc"; return 0; fi
    [ "$dir" = "/" ] && return 1
    dir="${dir:h}"
  done
  return 1
}

# chpwd hook: keep node in sync with .nvmrc. Fast path: if the active node
# already satisfies .nvmrc (or there's no .nvmrc and nvm was never loaded, so
# we're on the default), do nothing — nvm.sh never loads. Only a real version
# mismatch pays the one-time nvm load. `--silent` (used by the startup call in
# ~/.zshrc) suppresses the switch chatter like the old startup block did.
load-nvmrc() {
  local silent=""
  [ "$1" = "--silent" ] && silent=1
  local nvmrc_path
  nvmrc_path="$(_find-nvmrc)"

  if [ -n "$nvmrc_path" ]; then
    local want
    IFS= read -r want < "$nvmrc_path"
    want="${want//[[:space:]]/}"
    local wantv="${want#v}"
    local have="${$(command node --version 2>/dev/null)#v}"
    if [ -n "$have" ]; then
      case "$have" in
        "$wantv"|"$wantv".*) return 0 ;;
      esac
    fi

    _nvm_source
    local node_version="$(nvm version)"
    local nvmrc_node_version=$(nvm version "$want")

    if [ "$nvmrc_node_version" = "N/A" ]; then
      nvm install
    elif [ "$nvmrc_node_version" != "$node_version" ]; then
      if [ -n "$silent" ]; then
        nvm use --silent >/dev/null 2>&1
      else
        nvm use
      fi
    fi
  elif [ -n "$_NVM_SOURCED" ]; then
    local node_version="$(nvm version)"
    if [ "$node_version" != "$(nvm version default)" ]; then
      if [ -n "$silent" ]; then
        nvm use --silent default >/dev/null 2>&1
      else
        echo "Reverting to nvm default version"
        nvm use default
      fi
    fi
  fi
}
add-zsh-hook chpwd load-nvmrc
