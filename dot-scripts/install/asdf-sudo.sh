#!/bin/bash

# Check if running as root/sudo
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root or with sudo"
    exit 1
fi

# Install asdf
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.15.0
. "$HOME/.asdf/asdf.sh"

# Node
asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
asdf install nodejs latest
asdf global nodejs latest

asdf plugin-add yarn
asdf install yarn latest
asdf global yarn latest

# Python 
apt update; apt install build-essential libssl-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev curl git \
    libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
asdf plugin-add python
asdf install python 3.12.8
asdf global python 3.12.8

# uv
asdf plugin add uv
asdf install uv latest
asdf set -u uv latest

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

# Java
asdf plugin-add java
asdf install java openjdk-17.0.2
asdf global java openjdk-17.0.2