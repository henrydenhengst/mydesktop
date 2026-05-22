#!/usr/bin/env bash

# MakeMKV installer for Debian/Ubuntu only
#
# Supported:
#   - Debian
#   - Ubuntu
#
# This script intentionally refuses to run on:
#   - Arch
#   - Fedora
#   - openSUSE
#   - Alpine
#   - Other unsupported distros
#
# Usage:
#   chmod +x install_makemkv.sh
#   ./install_makemkv.sh
#
# Required files in the same directory:
#   makemkv-oss-x.x.x.tar.gz
#   makemkv-bin-x.x.x.tar.gz

set -euo pipefail

########################################
# OS CHECK
########################################

if [[ ! -f /etc/os-release ]]; then
    echo "ERROR: Cannot determine Linux distribution."
    exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release

SUPPORTED=false

case "${ID:-}" in
    ubuntu|debian)
        SUPPORTED=true
        ;;
esac

# Also allow derivatives based on Debian/Ubuntu
if [[ "${SUPPORTED}" == "false" ]]; then
    if [[ "${ID_LIKE:-}" =~ (debian|ubuntu) ]]; then
        SUPPORTED=true
    fi
fi

if [[ "${SUPPORTED}" != "true" ]]; then
    echo "ERROR: Unsupported Linux distribution."
    echo
    echo "Detected:"
    echo "  ID=${ID:-unknown}"
    echo "  ID_LIKE=${ID_LIKE:-unknown}"
    echo
    echo "This installer only supports Debian and Ubuntu based systems."
    echo "Example supported distros:"
    echo "  - Debian"
    echo "  - Ubuntu"
    echo "  - Linux Mint"
    echo "  - Pop!_OS"
    echo
    echo "Refusing to continue."
    exit 1
fi

########################################
# START
########################################

echo "=== MakeMKV Installer ==="
echo "Detected distro: ${PRETTY_NAME:-Unknown}"

sudo -v

echo
echo ">>> Installing dependencies..."

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
# FIND ARCHIVES
########################################

echo
echo ">>> Searching for source archives..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

OSS_ARCHIVE=$(find "${SCRIPT_DIR}" -maxdepth 1 -type f -name "makemkv-oss-*.tar.gz" | head -n 1)
BIN_ARCHIVE=$(find "${SCRIPT_DIR}" -maxdepth 1 -type f -name "makemkv-bin-*.tar.gz" | head -n 1)

if [[ -z "${OSS_ARCHIVE}" ]]; then
    echo "ERROR: makemkv-oss archive not found."
    exit 1
fi

if [[ -z "${BIN_ARCHIVE}" ]]; then
    echo "ERROR: makemkv-bin archive not found."
    exit 1
fi

echo "Found archives:"
echo "  $(basename "${OSS_ARCHIVE}")"
echo "  $(basename "${BIN_ARCHIVE}")"

########################################
# TEMP BUILD DIR
########################################

WORKDIR=$(mktemp -d)

cleanup() {
    echo
    echo ">>> Cleaning temporary build files..."
    rm -rf "${WORKDIR}"
}

trap cleanup EXIT

echo
echo ">>> Build directory:"
echo "    ${WORKDIR}"

cd "${WORKDIR}"

########################################
# BUILD OSS
########################################

echo
echo ">>> Extracting makemkv-oss..."

tar -xvzf "${OSS_ARCHIVE}"

OSS_DIR=$(find . -maxdepth 1 -type d -name "makemkv-oss-*" | head -n 1)

if [[ -z "${OSS_DIR}" ]]; then
    echo "ERROR: Failed to extract makemkv-oss."
    exit 1
fi

cd "${OSS_DIR}"

echo
echo ">>> Configuring makemkv-oss..."
./configure

echo
echo ">>> Compiling makemkv-oss..."
make -j"$(nproc)"

echo
echo ">>> Installing makemkv-oss..."
sudo make install

cd "${WORKDIR}"

########################################
# BUILD BIN
########################################

echo
echo ">>> Extracting makemkv-bin..."

tar -xvzf "${BIN_ARCHIVE}"

BIN_DIR=$(find . -maxdepth 1 -type d -name "makemkv-bin-*" | head -n 1)

if [[ -z "${BIN_DIR}" ]]; then
    echo "ERROR: Failed to extract makemkv-bin."
    exit 1
fi

cd "${BIN_DIR}"

echo
echo ">>> Compiling makemkv-bin..."
make -j"$(nproc)"

echo
echo ">>> Installing makemkv-bin..."
sudo make install

########################################
# DONE
########################################

echo
echo "=== MakeMKV installation completed ==="
echo
echo "Run with:"
echo "  makemkv"
echo
echo "Important:"
echo "  - DVD support is free."
echo "  - Blu-ray/UHD support is shareware."
echo "  - Community beta keys are usually posted on the MakeMKV forum."