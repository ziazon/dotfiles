#!/bin/zsh

compaudit | xargs chmod g-w

UPDATEZSHRC=1

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

if [ "$(grep -F "${ZSHRCINIT}" $HOME/.zshrc)" = "${ZSHRCINIT}" ]; then
  echo "\033[38;5;160mEnv init already added to $HOME/.zshrc\033[0m"
  UPDATEZSHRC=0
fi

if [ $UPDATEZSHRC -eq 1 ]; then
  echo "\033[38;5;82mInstalling Env init to $HOME/.zshrc\033[0m"
  echo "\n$ZSHRCINIT" >> $HOME/.zshrc
fi

ln -s $HOME/.env/starship.toml $HOME/.config/starship.toml
ln -s $HOME/.env/tmux.conf $HOME/.tmux.conf

echo "\033[38;5;111mLoading changes to $HOME/.zshrc to shell\033[0m"
zsh $HOME/.zshrc

echo "\033[38;5;111mInstall python 3.7.8\033[0m"
pyenv install 3.7.8

echo "\033[38;5;111mSet python 3.7.8 as system default\033[0m"
pyenv global 3.7.8

echo "\033[38;5;111mAdds poetry tab completion\033[0m"
poetry completions zsh > $(brew --prefix)/share/zsh/site-functions/_poetry

echo "\033[38;5;111minstall git-lfs\033[0m"
git lfs install
git lfs install --system

echo "\033[38;5;111mSet poetry virtualenvs to be stored in project\033[0m"
poetry config virtualenvs.in-project true

# zsh zinit self-update
echo "\033[38;5;82mSetup Complete\033[0m"
