eval "$(starship init zsh)"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm

if type brew &>/dev/null; then
    FPATH=$(brew --prefix)/share/zsh-completions:$FPATH

    autoload -Uz compinit
    compinit
fi

autoload bashcompinit
bashcompinit

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

#compdef poetry

_poetry_ca3132fa68746262_complete()
{
    local state com cur

    cur=${words[${#words[@]}]}

    # lookup for command
    for word in ${words[@]:1}; do
        if [[ $word != -* ]]; then
            com=$word
            break
        fi
    done

    if [[ ${cur} == --* ]]; then
        state="option"
        opts=("--ansi:Force ANSI output" "--help:Display this help message" "--no-ansi:Disable ANSI output" "--no-interaction:Do not ask any interactive question" "--quiet:Do not output any message" "--verbose:Increase the verbosity of messages: \\\"-v\\\" for normal output, \\\"-vv\\\" for more verbose output and \\\"-vvv\\\" for debug" "--version:Display this application version")
    elif [[ $cur == $com ]]; then
        state="command"
        coms=("about:Shows information about Poetry." "add:Adds a new dependency to pyproject.toml." "build:Builds a package, as a tarball and a wheel by default." "cache:Interact with Poetry\'s cache" "check:Checks the validity of the pyproject.toml file." "config:Manages configuration settings." "debug:Debug various elements of Poetry." "env:Interact with Poetry\'s project environments." "export:Exports the lock file to alternative formats." "help:Display the manual of a command" "init:Creates a basic pyproject.toml file in the current directory." "install:Installs the project dependencies." "lock:Locks the project dependencies." "new:Creates a new Python project at <path\>." "publish:Publishes a package to a remote repository." "remove:Removes a package from the project dependencies." "run:Runs a command in the appropriate environment." "search:Searches for packages on remote repositories." "self:Interact with Poetry directly." "shell:Spawns a shell within the virtual environment." "show:Shows information about packages." "update:Update the dependencies as according to the pyproject.toml file." "version:Shows the version of the project or bumps it when a valid bump rule is provided.")
    fi

    case $state in
        (command)
            _describe 'command' coms
        ;;
        (option)
            case "$com" in

            (about)
            opts+=()
            ;;

            (add)
            opts+=("--allow-prereleases:Accept prereleases." "--dev:Add as a development dependency." "--dry-run:Output the operations but do not execute anything \(implicitly enables --verbose\)." "--extras:Extras to activate for the dependency." "--optional:Add as an optional dependency." "--platform:Platforms for which the dependency must be installed." "--python:Python version for which the dependency must be installed.")
            ;;

            (build)
            opts+=("--format:Limit the format to either sdist or wheel.")
            ;;

            (cache)
            opts+=()
            ;;

            (check)
            opts+=()
            ;;

            (config)
            opts+=("--list:List configuration settings." "--local:Set/Get from the project\'s local configuration." "--unset:Unset configuration setting.")
            ;;

            (debug)
            opts+=()
            ;;

            (env)
            opts+=()
            ;;

            (export)
            opts+=("--dev:Include development dependencies." "--extras:Extra sets of dependencies to include." "--format:Format to export to. Currently, only requirements.txt is supported." "--output:The name of the output file." "--with-credentials:Include credentials for extra indices." "--without-hashes:Exclude hashes from the exported file.")
            ;;

            (help)
            opts+=()
            ;;

            (init)
            opts+=("--author:Author name of the package." "--dependency:Package to require, with an optional version constraint, e.g. requests:\^2.10.0 or requests=2.11.1." "--description:Description of the package." "--dev-dependency:Package to require for development, with an optional version constraint, e.g. requests:\^2.10.0 or requests=2.11.1." "--license:License of the package." "--name:Name of the package.")
            ;;

            (install)
            opts+=("--dry-run:Output the operations but do not execute anything \(implicitly enables --verbose\)." "--extras:Extra sets of dependencies to install." "--no-dev:Do not install the development dependencies." "--no-root:Do not install the root package \(the current project\).")
            ;;

            (lock)
            opts+=()
            ;;

            (new)
            opts+=("--name:Set the resulting package name." "--src:Use the src layout for the project.")
            ;;

            (publish)
            opts+=("--build:Build the package before publishing." "--cert:Certificate authority to access the repository." "--client-cert:Client certificate to access the repository." "--password:The password to access the repository." "--repository:The repository to publish the package to." "--username:The username to access the repository.")
            ;;

            (remove)
            opts+=("--dev:Remove a package from the development dependencies." "--dry-run:Output the operations but do not execute anything \(implicitly enables --verbose\).")
            ;;

            (run)
            opts+=()
            ;;

            (search)
            opts+=()
            ;;

            (self)
            opts+=()
            ;;

            (shell)
            opts+=()
            ;;

            (show)
            opts+=("--all:Show all packages \(even those not compatible with current system\)." "--latest:Show the latest version." "--no-dev:Do not list the development dependencies." "--outdated:Show the latest version but only for packages that are outdated." "--tree:List the dependencies as a tree.")
            ;;

            (update)
            opts+=("--dry-run:Output the operations but do not execute anything \(implicitly enables --verbose\)." "--lock:Do not perform operations \(only update the lockfile\)." "--no-dev:Do not update the development dependencies.")
            ;;

            (version)
            opts+=()
            ;;

            esac

            _describe 'option' opts
        ;;
        *)
            # fallback to file completion
            _arguments '*:file:_files'
    esac
}

_poetry_ca3132fa68746262_complete "$@"
compdef _poetry_ca3132fa68746262_complete /Users/jubairs/.poetry/bin/poetry


[ -f $HOME/.env/.fzf.zsh ] && source $HOME/.env/.fzf.zsh

# Two regular plugins loaded without investigating.
zinit light zsh-users/zsh-autosuggestions
zinit light zdharma/fast-syntax-highlighting

# Plugin history-search-multi-word loaded with investigating.
zinit load zdharma/history-search-multi-word

# # Load the pure theme, with zsh-async library that's bundled with it.
# zinit ice pick"async.zsh" src"pure.zsh"
# zinit light sindresorhus/pure

# A glance at the new for-syntax – load all of the above
# plugins with a single command. For more information see:
# https://zdharma.org/zinit/wiki/For-Syntax/
zinit for \
    light-mode  zsh-users/zsh-autosuggestions \
    light-mode  zdharma/fast-syntax-highlighting \
                zdharma/history-search-multi-word
    # light-mode pick"async.zsh" src"pure.zsh" \
    #             sindresorhus/pure

# Binary release in archive, from GitHub-releases page.
# After automatic unpacking it provides program "fzf".
zinit ice from"gh-r" as"program"
zinit load junegunn/fzf-bin

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
# package under the path $ZPFX, see: http://zdharma.org/zinit/wiki/Compiling-programs
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

zinit as"program" make'!' atclone'./direnv hook zsh > zhook.zsh' \
    atpull'%atclone' pick"direnv" src"zhook.zsh" for \
        direnv/direnv