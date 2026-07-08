#!/bin/zsh
#
# Wire the shell up to this repo: inject the env init block into ~/.zshrc and
# symlink the config files brew/tmux/starship expect in their default locations.
# Idempotent — safe to re-run.

compaudit | xargs chmod g-w 2>/dev/null

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

if grep -qF "### Begin Env Init" "$HOME/.zshrc"; then
  echo "\033[38;5;160mEnv init already present in $HOME/.zshrc\033[0m"
else
  echo "\033[38;5;82mAdding Env init to $HOME/.zshrc\033[0m"
  echo "\n$ZSHRCINIT" >> "$HOME/.zshrc"
fi

# Symlinks (arch/location-independent). -f overwrites, -n avoids nesting.
mkdir -p "$HOME/.config"
ln -sfn "$HOME/.env/starship.toml" "$HOME/.config/starship.toml"
ln -sfn "$HOME/.env/tmux.conf" "$HOME/.tmux.conf"

echo "\033[38;5;111mInstalling git-lfs\033[0m"
git lfs install

if command -v poetry >/dev/null 2>&1 && command -v brew >/dev/null 2>&1; then
  echo "\033[38;5;111mAdding poetry zsh completion\033[0m"
  poetry completions zsh > "$(brew --prefix)/share/zsh/site-functions/_poetry"
  echo "\033[38;5;111mStoring poetry virtualenvs in-project\033[0m"
  poetry config virtualenvs.in-project true
fi

echo "\033[38;5;82mSetup complete. Open a new terminal or run: exec zsh\033[0m"
