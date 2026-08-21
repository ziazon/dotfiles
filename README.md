# Local Env Setup

What I use to set up new macOS machines — shell config, dotfiles, and a
declarative package manifest.

## Install

On a machine with nothing but macOS and Xcode, run:

```bash
/bin/bash -c \
  "$(curl -fsSL \
    https://raw.githubusercontent.com/ziazon/dotfiles/main/bootstrap.sh)"
```

### Bootstrap options

`bootstrap.sh` honors these environment variables:

- `GIT_NAME`: global Git author name. When unset, uses the existing global Git
  name or prompts for one.
- `GIT_EMAIL`: global Git author email. When unset, uses the existing global Git
  email or prompts for one.
- `ENV_REPO`: dotfiles repository to clone. When unset, uses the origin of an
  existing `~/.env` worktree, then falls back to this repository.
- `AI_TEAM_REPO`: optional shared-context repository. When unset, that clone and
  installer are skipped.
- `SSH_KEY`: SSH private-key path. When unset, uses `~/.ssh/id_ed25519`.

Set them inline before the same curl invocation, for example:

```bash
GIT_NAME="Your Name" GIT_EMAIL=you@example.com \
  AI_TEAM_REPO=git@github.com:you/ai-team.git \
  /bin/bash -c \
  "$(curl -fsSL \
    https://raw.githubusercontent.com/ziazon/dotfiles/main/bootstrap.sh)"
```

`bootstrap.sh` checks the Xcode command line tools, installs Rosetta,
Homebrew, git, and `gh`, configures git identity and an SSH key,
authenticates with GitHub, clones the dotfiles repo and, when `AI_TEAM_REPO` is
set, the shared-context repo, then hands off to `install.sh`.
It is idempotent and needs your sudo password plus a browser login partway
through. Pass `--dry-run` to preview every action without changing the machine.
Pass `--config-only` to set up a second user account on an already-configured
machine. It checks out the dotfiles, configures git identity, adds the per-user
Homebrew shell init, and runs `configure.zsh`, with no package installation, no
sudo, and no GitHub login. This mode also implies `--no-ai-team`.

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
