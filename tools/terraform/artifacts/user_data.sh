#!/bin/bash

echo "[TASK 1] Enable ssh password authentication"
sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl reload sshd

echo "[TASK 2] Prepare packages"
apt update
apt install rsync docker.io openvswitch-switch -y

echo "[TASK 3] Prepare docker"
usermod -a -G docker debian

echo "[TASK 4] Prefetch docker images"
docker image pull ghcr.io/infraguys/debian_lab

echo "[TASK 5] Clone git repo with labs"
cd /home/debian
git clone https://github.com/infraguys/highload_linux_network_labs.git
chown debian:debian -R ./highload_linux_network_labs
cd -

echo "[TASK 6] Add some bash configurations"

cat <<EOT | tee -a /home/debian/.bashrc /root/.bashrc

# some more aliases
alias ll='ls -alhF'
alias la='ls -A'
alias l='ls -CF'

# SYNC_HISTORY
# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth
HISTTIMEFORMAT="%Y.%m.%d %H:%M:%S "

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=20000
HISTFILESIZE=20000

# save each command to history file
PROMPT_COMMAND='history -a'

EOT
