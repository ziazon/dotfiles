# Aliases
alias cppcompile='c++ -std=c++11 -stdlib=libc++'

alias zshconfig="${EDITOR:-vim} ~/.zshrc"

alias reload="exec zsh --login"

alias nuke="print '🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥' && git reset --hard && git clean -df && print '🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥'"

alias updatedb="sudo /usr/libexec/locate.updatedb"

alias flushdns="sudo killall -HUP mDNSResponder;sudo killall mDNSResponderHelper;sudo dscacheutil -flushcache"

alias python-env="python -m venv .venv"

# alias cat="bat"
alias ls="eza -g --ignore-glob __pycache__"
alias ll='ls -la'
alias diff="prettydiff"
# alias ps="procs"
alias tree="eza -Tla --extended --git-ignore -I=.git"
alias du='dust'
alias ag='rg'


# Easier navigation: .., ..., ...., ....., ~ and -
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ~="cd ~"
alias -- -="cd -"

# Get week number
alias week='date +%V'

# Stopwatch
alias timer='echo "Timer started. Stop with Ctrl-D." && date && time cat && date'

# IP addresses
alias ip="dig +short myip.opendns.com @resolver1.opendns.com"
alias localip="ipconfig getifaddr en0"
alias ips="ifconfig -a | grep -o 'inet6\? \(addr:\)\?\s\?\(\(\([0-9]\+\.\)\{3\}[0-9]\+\)\|[a-fA-F0-9:]\+\)' | awk '{ sub(/inet6? (addr:)? ?/, \"\"); print }'"

# View HTTP traffic
alias sniff="sudo ngrep -d 'en1' -t '^(GET|POST) ' 'tcp and port 80'"
alias httpdump="sudo tcpdump -i en1 -n -s 0 -w - | grep -a -o -E \"Host\: .*|GET \/.*\""


# Recursively delete `.DS_Store` files
alias cleanup="find . -type f -name '*.DS_Store' -ls -delete"

# URL-encode strings
alias urlencode='python3 -c "import sys; from urllib.parse import quote_plus; print(quote_plus(sys.argv[1]));"'

# Usage: `mergepdf input{1,2,3}.pdf output.pdf`
alias mergepdf='pdfunite'

alias plistbuddy="/usr/libexec/PlistBuddy"

alias badge="tput bel"

alias map="xargs -n1"

alias mute="osascript -e 'set volume output muted true'"
alias volume="osascript -e 'set volume 7'"

# Prune leaked Codex plugin MCP hosts (sites + codex-security) that the shared
# codex app-server daemon spawns per task and never reaps. Safe with multiple
# sessions open: keeps the newest host per plugin, never kills anything <5min
# old or currently busy. `--dry-run` to preview, `--keep 0 --min-age 0` to nuke
# every idle host. `codex-mcp-ps` just lists the current hosts.
alias codex-mcp-cleanup="$HOME/.claude/scripts/codex-mcp-cleanup.sh"
alias codex-mcp-ps="pgrep -f 'mcp/server\.mjs' | xargs -I{} sh -c 'printf \"%-7s \" {}; ps -o etime=,%cpu= -p {}'"
