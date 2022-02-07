#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

sudo apt-get update && sudo apt-get install -yqq daemonize dbus-user-session fontconfig

read -r -d '' WSLINITSCRIPT << EOM
sudo daemonize /usr/bin/unshare --fork --pid --mount-proc /lib/systemd/systemd --system-unit=basic.target
exec sudo nsenter -t \$(pidof -s systemd) -a su - $LOGNAME
EOM

echo "$WSLINITSCRIPT" | sudo tee /etc/init-wsl > /dev/null

./../ubuntu-install.sh

zsh ./../configure.zsh
