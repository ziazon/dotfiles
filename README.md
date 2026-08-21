# Local Env Setup

What I use to set up new macOS machines — shell config, dotfiles, and a
declarative package manifest.

## Install

On a machine with nothing but macOS and Xcode, run:

```bash
/bin/bash -c \
  "$(curl -fsSL \
    https://raw.githubusercontent.com/ziazon/dotfiles/master/bootstrap.sh)"
```

`bootstrap.sh` checks the Xcode command line tools, installs Rosetta,
Homebrew, git, and `gh`, configures git identity and an SSH key,
authenticates with GitHub, clones both repos, then hands off to `install.sh`.
It is idempotent and needs your sudo password plus a browser login partway
through. Pass `--dry-run` to preview every action without changing the machine.

If you already have the prerequisites and prefer to clone the repo yourself:

```bash
cd ~
git clone git@github.com:ziazon/dotfiles.git .env && cd .env
./install.sh
```

`install.sh` is idempotent — safe to re-run. It:

1. Installs **Homebrew** (arch-aware: `/opt/homebrew` on Apple Silicon,
   `/usr/local` on Intel).
2. Installs every formula and cask in [`Brewfile`](Brewfile) via `brew bundle`.
3. Installs language toolchains: Rust (rustup), Python 3.12 (pyenv),
   Node LTS (nvm), and Go tools.
4. Wires up the shell via [`configure.zsh`](configure.zsh). On first shell
   start, [`plugins.zsh`](plugins.zsh) installs the
   [zinit](https://github.com/zdharma-continuum/zinit) zsh plugin manager.

## Managing packages

The package list lives in [`Brewfile`](Brewfile). To install/sync:

```bash
brew bundle --file=~/.env/Brewfile
```

To snapshot the current machine back into the Brewfile:

```bash
brew bundle dump --file=~/.env/Brewfile --force
```

## Layout

| File             | Purpose                                                 |
| ---------------- | ------------------------------------------------------- |
| `Brewfile`       | Declarative formula/cask manifest (`brew bundle`)       |
| `bootstrap.sh`   | From-scratch bootstrap (macOS + Xcode only)             |
| `migrate.sh`     | Pull projects and config from an old Mac via SSH        |
| `pg-migrate.sh`  | Copy all PostgreSQL databases from an old Mac           |
| `install.sh`     | One-shot machine bootstrap                              |
| `configure.zsh`  | Injects shell init into `~/.zshrc`, creates symlinks    |
| `settings.zsh`   | zsh options (history, `setopt`)                         |
| `vars.zsh`       | Environment variables and `PATH`                        |
| `plugins.zsh`    | zinit setup/plugins, completions, prompt, fzf, nvm hook |
| `functions.zsh`  | Shell functions                                         |
| `aliases.zsh`    | Aliases                                                 |
| `bindings.zsh`   | Key bindings                                            |
| `starship.toml`  | [starship](https://starship.rs) prompt config           |
| `tmux.conf`      | tmux config (+ TPM plugins)                             |
| `work-stuff.zsh` | Machine-local secrets/overrides (git-ignored)           |
