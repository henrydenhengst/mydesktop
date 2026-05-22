#!/usr/bin/env bash
#
########################################
# MakeMKV Installer Script
########################################
#
# Description:
#   This script automatically installs MakeMKV on Debian/Ubuntu systems.
#   It downloads the specified MakeMKV source packages, installs required
#   dependencies, compiles both makemkv-oss and makemkv-bin, and installs
#   them system-wide.
#
# Requirements:
#   - Debian or Ubuntu-based Linux distribution
#   - sudo privileges
#   - Internet connection
#
# What it does:
#   1. Checks if the system is Debian/Ubuntu
#   2. Ensures wget or curl is installed
#   3. Installs required build dependencies via apt
#   4. Downloads MakeMKV source packages
#   5. Builds makemkv-oss
#   6. Builds makemkv-bin
#   7. Installs both packages
#
# Version:
#   MakeMKV: 1.18.3 (configurable via MAKEMKV_VERSION variable)
#
# Notes:
#   - DVD functionality is free to use.
#   - Blu-ray/UHD support requires a license after trial period.
#   - Temporary beta keys are sometimes available on the MakeMKV forums.
#
# Safety:
#   - Script is restricted to Debian/Ubuntu systems only.
#   - Uses sudo only for installation steps, not full script execution.
#
########################################
########################################
# Usage / After Installation
########################################
#
# Start MakeMKV:
#   makemkv
#
# If the command is not found, try:
#   /usr/bin/makemkv
#
# Typical workflow:
#   1. Insert a DVD / Blu-ray disc
#   2. Start MakeMKV
#   3. Select the optical drive
#   4. Wait for disc scan
#   5. Select titles (main movie usually largest file size)
#   6. Choose output folder
#   7. Click "Make MKV"
#
# Output:
#   - Files are saved as .mkv (video is not re-encoded)
#   - Only streams are remuxed (fast, no quality loss)
#
# Notes:
#   - DVDs: fully free
#   - Blu-ray / UHD: requires license after trial period
#   - A temporary beta key is often available on the MakeMKV forums
#
# Troubleshooting:
#   - If optical drive is not detected:
#       sudo modprobe sg
#
#   - If permission issues occur:
#       sudo usermod -aG cdrom $USER
#       (then log out and back in)
#
########################################

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