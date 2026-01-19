#!/bin/bash

# Check if running as root/sudo
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root or with sudo"
    exit 1
fi

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
    fonts-powerline \
    openjdk-17-jdk \
    qemu-kvm \
    libvirt-daemon-system \
    libvirt-clients \
    bridge-utils \
    snapd \
    build-essential libssl-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev curl git \
    libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

# AWS CLI
apt remove -y awscli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
mkdir ~/.aws
cp ./aws_foo_config ~/.aws/config

# Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker $(logname)

# ## Add Docker's official GPG key:
# apt-get update
# apt-get install -y ca-certificates curl
# install -m 0755 -d /etc/apt/keyrings
# curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
# chmod a+r /etc/apt/keyrings/docker.asc

# ## Add the repository to Apt sources:
# for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do apt-get remove $pkg; done
# echo \
#   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
#   $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
#   tee /etc/apt/sources.list.d/docker.list > /dev/null
# apt-get update
# apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Watchman
wget -O watchman.tar.gz https://github.com/facebook/watchman/archive/refs/tags/v2024.12.23.00.tar.gz
tar -xvzf watchman.tar.gz && cd watchman-2024.12.23.00
./install-system-packages.sh
./autogen.sh

# Slides
snap install slides