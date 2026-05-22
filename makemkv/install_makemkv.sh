#!/usr/bin/env bash
#
########################################
# MakeMKV Installer Script
########################################
#
# Description:
#   This script automatically installs MakeMKV on Debian/Ubuntu systems.
#   It downloads the latest MakeMKV source packages, installs required
#   dependencies, compiles both makemkv-oss and makemkv-bin, and installs
#   them system-wide.
#
# Requirements:
#   - Debian or Ubuntu-based Linux distribution
#   - sudo privileges
#   - Internet connection (or cached version for offline mode)
#
# What it does:
#   1. Checks if the system is Debian/Ubuntu
#   2. Ensures wget or curl is installed
#   3. Installs required build dependencies via apt
#   4. Detects latest MakeMKV version (online or cached)
#   5. Downloads MakeMKV source packages
#   6. Builds makemkv-oss
#   7. Builds makemkv-bin
#   8. Installs both packages
#
# Version:
#   Auto-detected latest MakeMKV version (with caching + offline fallback)
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

CACHE_FILE="${HOME}/.cache/makemkv_version"

########################################
# VERSION DETECTION (ROBUST)
########################################

fetch_latest_version() {
    echo "Detecting latest MakeMKV version..."

    mkdir -p "${HOME}/.cache"

    local page=""
    page=$(curl -fsSL \
        --connect-timeout 10 \
        --max-time 20 \
        --retry 3 \
        --retry-delay 2 \
        "https://www.makemkv.com/download/" || true)

    local latest_version=""

    if [[ -n "$page" ]]; then
        latest_version=$(
            echo "$page" \
            | grep -oE 'makemkv-bin-[0-9]+\.[0-9]+\.[0-9]+' \
            | sed 's/makemkv-bin-//' \
            | sort -V \
            | tail -n 1
        )
    fi

    if [[ -z "$latest_version" ]]; then
        echo "Warning: online detection failed, trying cache..."

        if [[ -f "$CACHE_FILE" ]]; then
            latest_version=$(cat "$CACHE_FILE")
            echo "Using cached version: $latest_version"
        else
            echo "ERROR: No internet and no cached version available"
            exit 1
        fi
    else
        echo "$latest_version" > "$CACHE_FILE"
        echo "Cached version: $latest_version"
    fi

    MAKEMKV_VERSION="$latest_version"

    BIN_URL="https://www.makemkv.com/download/makemkv-bin-${MAKEMKV_VERSION}.tar.gz"
    OSS_URL="https://www.makemkv.com/download/makemkv-oss-${MAKEMKV_VERSION}.tar.gz"

    echo "Detected MakeMKV version: $MAKEMKV_VERSION"
}

########################################
# OS CHECK
########################################

if [[ ! -f /etc/os-release ]]; then
    echo "ERROR: Cannot detect OS"
    exit 1
fi

source /etc/os-release

if [[ "${ID:-}" != "debian" && "${ID:-}" != "ubuntu" ]]; then
    if [[ "${ID_LIKE:-}" != *debian* && "${ID_LIKE:-}" != *ubuntu* ]]; then
        echo "ERROR: Only Debian/Ubuntu supported"
        exit 1
    fi
fi

echo "Detected OS: ${PRETTY_NAME:-unknown}"

########################################
# SUDO CHECK
########################################

sudo -v

########################################
# ENSURE DOWNLOAD TOOL
########################################

if ! command -v curl >/dev/null 2>&1; then
    echo "Installing curl..."
    sudo apt update
    sudo apt install -y curl
fi

########################################
# DEPENDENCIES
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
    qtbase5-dev \
    libcurl4-openssl-dev

########################################
# GET VERSION
########################################

fetch_latest_version

########################################
# DOWNLOAD FUNCTION
########################################

download_file() {
    local url="$1"
    local output="$2"

    echo "Downloading: $url"

    curl -L \
        --connect-timeout 10 \
        --max-time 60 \
        --retry 3 \
        --retry-delay 2 \
        -o "$output" "$url"
}

########################################
# BUILD
########################################

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

cd "$WORKDIR"

echo "Using temp dir: $WORKDIR"

download_file "$OSS_URL" "makemkv-oss.tar.gz"
download_file "$BIN_URL" "makemkv-bin.tar.gz"

echo "Building makemkv-oss..."

tar -xvzf makemkv-oss.tar.gz
cd makemkv-oss-*

./configure
make -j"$(nproc)"
sudo make install

cd "$WORKDIR"

echo "Building makemkv-bin..."

tar -xvzf makemkv-bin.tar.gz
cd makemkv-bin-*

make -j"$(nproc)"
sudo make install

########################################
# DONE
########################################

echo "Installation complete!"
echo "MakeMKV version: $MAKEMKV_VERSION"
echo "Run: makemkv"