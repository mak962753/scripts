#!/usr/bin/env sh

die() {
    echo "$*">&2
    exit 1
}


URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"

curl -L -C - --output-dir /tmp -O "$URL" || die "Failed to download NVIM package"


sudo rm -rf /opt/nvim
sudo tar -C /opt -xzvf /tmp/nvim-linux-x86_64.tar.gz
sudo mv /opt/nvim-linux-x86_64 /opt/nvim
rm /tmp/nvim-linux-x86_64.tar.gz

