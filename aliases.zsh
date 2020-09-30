# Aliases
alias cppcompile='c++ -std=c++11 -stdlib=libc++'

# Use sublimetext for editing config files
alias zshconfig="subl ~/.zshrc"

alias reload="exec zsh --login"

alias nuke="print '🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥' && git reset --hard && git clean -df && print '🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥'"

alias updatedb="sudo /usr/libexec/locate.updatedb"

alias flushdns="sudo killall -HUP mDNSResponder;sudo killall mDNSResponderHelper;sudo dscacheutil -flushcache"

alias python-env="python -m venv .venv"

# alias cat="bat"
alias ls="exa --ignore-glob __pycache__"
alias ll='ls -la'
alias diff="prettydiff"
# alias ps="procs"
alias tree="exa -Tla --extended --git-ignore -I=.git"
alias du='dust'
alias ag='rg'
