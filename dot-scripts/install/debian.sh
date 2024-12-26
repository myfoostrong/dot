#!/bin/bash

apt-get update && apt-get -y upgrade && apt-get -y dist-upgrade
apt-get install -y \
    vim \
    screen \
    python3 \
    git \
    autossh \
    curl \
    unzip \
    systemd \
    gnupg \
    software-properties-common \
    golang-go \
    zsh \
    wget \
    coreutils \
    nmap \
    llvm \
    gnutls-bin \
    gawk \
    fonts-powerline
    
# Terraform CLI
wget -O- https://apt.releases.hashicorp.com/gpg | \
gpg --dearmor | \
tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
tee /etc/apt/sources.list.d/hashicorp.list
apt update && apt install -y terraform

# AWS CLI
apt remove -y awscli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
mkdir ~/.aws
cp ./aws_foo_config ~/.aws/config

# Docker
echo "Setting up git ..."
# Add Docker's official GPG key:
apt-get update
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do apt-get remove $pkg; done
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Slides
snap install slides

# VSCode
echo "code code/add-microsoft-repo boolean true" | debconf-set-selections
apt-get install -y wget gpg
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |tee /etc/apt/sources.list.d/vscode.list > /dev/null
rm -f packages.microsoft.gpg
apt install -y apt-transport-https
apt update
apt install code # or code-insiders

# Install asdr
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.1
. "$HOME/.asdf/asdf.sh"

# Node
asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
asdf install nodejs latest
asdf global nodejs latest

# Python 
# curl https://pyenv.run | bash
# asdf plugin add python
# asdf install python 3.12.7
# asdf global python latest

# Erlang ASDF
apt-get -y install build-essential autoconf m4 libncurses-dev libwxgtk3.2-dev libwxgtk-webview3.2-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev libssh-dev unixodbc-dev xsltproc fop libxml2-utils libncurses-dev openjdk-11-jdk
curl -O https://raw.githubusercontent.com/kerl/kerl/master/kerl -o /usr/local/bin/kerl
chmod a+x /usr/local/bin/kerl
asdf plugin add erlang
asdf install erlang latest
asdf global erlang latest

# Elixir ASDF
asdf plugin-add elixir
asdf install elixir latest
asdf global elixir latest