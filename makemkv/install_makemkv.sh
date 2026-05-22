#!/usr/bin/env bash

set -euo pipefail

########################################
# CONFIG
########################################

MAKEMKV_VERSION="1.18.3"

BIN_URL="https://www.makemkv.com/download/makemkv-bin-${MAKEMKV_VERSION}.tar.gz"
OSS_URL="https://www.makemkv.com/download/makemkv-oss-${MAKEMKV_VERSION}.tar.gz"

########################################
# OS CHECK (Debian/Ubuntu only)
########################################

if [[ ! -f /etc/os-release ]]; then
    echo "ERROR: Cannot detect OS"
    exit 1
fi

source /etc/os-release

if [[ "${ID:-}" != "debian" && "${ID:-}" != "ubuntu" && "${ID_LIKE:-}" != *"debian"* && "${ID_LIKE:-}" != *"ubuntu"* ]]; then
    echo "ERROR: Only Debian/Ubuntu supported"
    echo "Detected: ${ID:-unknown}"
    exit 1
fi

echo "Detected OS: ${PRETTY_NAME:-unknown}"

########################################
# SUDO CHECK
########################################

sudo -v

########################################
# ENSURE DOWNLOAD TOOLS
########################################

echo "Checking for wget/curl..."

if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
    echo "No wget or curl found. Installing..."
    sudo apt update
    sudo apt install -y wget curl
fi

########################################
# INSTALL BUILD DEPENDENCIES
########################################

echo "Installing build dependencies..."

sudo apt update
sudo apt install -y \
    build-essential \
    pkg-config \
    libc6-dev \
    libssl-dev \
    libexpat1-dev \
    libavcodec-dev \
    libgl1-mesa-dev \
    qtbase5-dev

########################################
# DOWNLOAD FUNCTION
########################################

download_file() {
    local url="$1"
    local output="$2"

    echo "Downloading: $url"

    if command -v curl >/dev/null 2>&1; then
        curl -L "$url" -o "$output"
    else
        wget -O "$output" "$url"
    fi
}

########################################
# DOWNLOAD SOURCES
########################################

WORKDIR=$(mktemp -d)
cd "$WORKDIR"

echo "Using temp dir: $WORKDIR"

download_file "$OSS_URL" "makemkv-oss.tar.gz"
download_file "$BIN_URL" "makemkv-bin.tar.gz"

########################################
# BUILD OSS
########################################

echo "Building makemkv-oss..."

tar -xvzf makemkv-oss.tar.gz
cd makemkv-oss-*

./configure
make -j"$(nproc)"
sudo make install

cd "$WORKDIR"

########################################
# BUILD BIN
########################################

echo "Building makemkv-bin..."

tar -xvzf makemkv-bin.tar.gz
cd makemkv-bin-*

make -j"$(nproc)"
sudo make install

########################################
# DONE
########################################

echo "Installation complete!"
echo "Run: makemkv"

rm -rf "$WORKDIR"