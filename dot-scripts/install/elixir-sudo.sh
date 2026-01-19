#!/bin/zsh

# Erlang deps
apt-get -y install build-essential autoconf m4 libncurses-dev libwxgtk3.2-dev libwxgtk-webview3.2-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev libssh-dev unixodbc-dev xsltproc fop libxml2-utils libncurses-dev openjdk-11-jdk
curl -O https://raw.githubusercontent.com/kerl/kerl/master/kerl -o /usr/local/bin/kerl
chmod a+x /usr/local/bin/kerl

# Erlang ASDF
asdf plugin add erlang
asdf install erlang latest
asdf global erlang latest

# Elixir ASDF
asdf plugin-add elixir
asdf install elixir latest
asdf global elixir latest