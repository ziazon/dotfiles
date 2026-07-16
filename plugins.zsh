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
_evalcache direnv direnv hook zsh

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


# --- zinit (plugin manager) ---------------------------------------------------
# Only for plugins Homebrew can't provide. Anything installable with `brew` is
# declared in the Brewfile instead: zinit compiling a tool from source (or
# fetching a release binary) duplicates the formula, and the big source clones
# are what made a fresh setup fail with `fatal: expected 'packfile'`.
ZINIT_HOME="$HOME/.local/share/zinit/zinit.git"
if [[ ! -f $ZINIT_HOME/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}zdharma-continuum/zinit%F{220}…%f"
    command mkdir -p "${ZINIT_HOME:h}" && command chmod g-rwX "${ZINIT_HOME:h}"
    # Shallow: zinit's own history is never needed here, and a smaller transfer
    # is far less likely to die mid-clone on a fresh machine.
    command git clone --depth=1 https://github.com/zdharma-continuum/zinit "$ZINIT_HOME" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

# A failed clone must not take the shell down with it — without this guard the
# `source` below aborts .zshrc, so aliases/bindings never load and the shell is
# left half-configured.
if [[ -f $ZINIT_HOME/zinit.zsh ]]; then
    source "$ZINIT_HOME/zinit.zsh"
    autoload -Uz _zinit
    (( ${+_comps} )) && _comps[zinit]=_zinit

    # Turbo (`wait`) defers these until after the first prompt, keeping startup
    # at ~0.45s. Neither registers completions via compdef, so the tuned
    # compinit above stands alone — no zicompinit/zicdreplay here.
    # zsh-completions is deliberately absent: brew's formula is that same
    # project, already on FPATH before compinit (see above).
    # autosuggestions binds itself from a precmd hook, which a deferred load
    # would miss for the first prompt; atload re-runs its starter to fix that.
    zinit wait lucid depth"1" for \
        atload"!_zsh_autosuggest_start" \
            zsh-users/zsh-autosuggestions \
        zdharma-continuum/fast-syntax-highlighting
else
    print -P "%F{160} zinit missing — continuing without plugins.%f%b"
fi

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
