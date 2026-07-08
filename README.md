# Local Env Setup

What I use to set up new macOS machines — shell config, dotfiles, and a
declarative package manifest.

## Install

First, install the Xcode command line tools:

```bash
xcode-select --install
```

If that fails, check **System Settings > General > Software Update** for a
Command Line Tools update.

Then clone this repo to `~/.env` and run the installer:

```bash
cd ~
git clone git@github.com:jubairsaidi/dotfiles.git .env && cd .env
./install.sh
```

`install.sh` is idempotent — safe to re-run. It:

1. Installs **Homebrew** (arch-aware: `/opt/homebrew` on Apple Silicon,
   `/usr/local` on Intel).
2. Installs every formula and cask in [`Brewfile`](Brewfile) via `brew bundle`.
3. Installs language toolchains: Rust (rustup), Python 3.12 (pyenv),
   Node LTS (nvm), and Go tools.
4. Installs the [zinit](https://github.com/zdharma-continuum/zinit) zsh plugin
   manager and wires up the shell via [`configure.zsh`](configure.zsh).

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

| File            | Purpose                                              |
| --------------- | ---------------------------------------------------- |
| `Brewfile`      | Declarative formula/cask manifest (`brew bundle`)    |
| `install.sh`    | One-shot machine bootstrap                           |
| `configure.zsh` | Injects shell init into `~/.zshrc`, creates symlinks |
| `settings.zsh`  | zsh options (history, `setopt`)                      |
| `vars.zsh`      | Environment variables and `PATH`                     |
| `plugins.zsh`   | zinit plugins, completions, prompt, fzf, nvm hook    |
| `functions.zsh` | Shell functions                                      |
| `aliases.zsh`   | Aliases                                              |
| `bindings.zsh`  | Key bindings                                         |
| `starship.toml` | [starship](https://starship.rs) prompt config        |
| `tmux.conf`     | tmux config (+ TPM plugins)                          |
| `work-stuff.zsh`| Machine-local secrets/overrides (git-ignored)        |
