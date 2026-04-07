#!/bin/bash
set -euo pipefail

echo "--- MULTIMEDIA / YOUTUBER POST-INSTALL START ---"

USERNAME="${SUDO_USER:-$USER}"

if [[ "$EUID" -ne 0 ]]; then
  echo "Run with sudo!"
  exit 1
fi

echo "Target user: $USERNAME"

# --- Update ---
echo "--- Updating system ---"
pacman -Syu --noconfirm

# --- Video editing ---
echo "--- Installing video editing tools ---"
pacman -S --noconfirm --needed \
  kdenlive \
  blender \
  obs-studio \
  shotcut

# --- Audio production ---
echo "--- Installing audio tools ---"
pacman -S --noconfirm --needed \
  audacity \
  ardour \
  calf \
  lsp-plugins \
  easyeffects \
  noise-suppression-for-voice

# --- Image editing / graphics ---
echo "--- Installing graphics tools ---"
pacman -S --noconfirm --needed \
  gimp \
  krita \
  inkscape \
  darktable

# --- Streaming / encoding ---
echo "--- Installing encoding & streaming tools ---"
pacman -S --noconfirm --needed \
  ffmpeg \
  handbrake \
  yt-dlp

# --- Fonts & assets ---
echo "--- Installing creator fonts ---"
pacman -S --noconfirm --needed \
  noto-fonts noto-fonts-emoji noto-fonts-cjk \
  ttf-dejavu ttf-liberation

# --- Camera / media tools ---
echo "--- Installing camera tools ---"
pacman -S --noconfirm --needed \
  v4l-utils \
  obs-v4l2sink

# --- PipeWire (pro audio/video stack) ---
echo "--- Installing PipeWire pro stack ---"
pacman -S --noconfirm --needed \
  pipewire pipewire-alsa pipewire-pulse pipewire-jack \
  wireplumber \
  helvum \
  qpwgraph

# --- GPU acceleration tools ---
echo "--- Installing GPU acceleration tools ---"
pacman -S --noconfirm --needed \
  libva-utils \
  intel-media-driver || true

# --- Utilities ---
echo "--- Installing utilities ---"
pacman -S --noconfirm --needed \
  flameshot \
  simplescreenrecorder \
  wl-clipboard xclip \
  unzip zip p7zip

# --- Directories ---
echo "--- Creating workspace directories ---"
mkdir -p /home/$USERNAME/{Videos,Audio,Projects,Thumbnails,Exports}

# --- Environment tuning ---
echo "--- Applying environment tuning ---"
cat >> /home/$USERNAME/.bashrc <<'EOF'

# === MULTIMEDIA / CONTENT CREATION ===

# FFmpeg threads (auto)
export FFMPEG_THREADS=0

# PipeWire low latency
export PIPEWIRE_LATENCY="128/48000"

# VAAPI (hardware accel)
export LIBVA_DRIVER_NAME=iHD

# OBS Wayland fix
export QT_QPA_PLATFORM=wayland
EOF

# --- Permissions ---
chown -R $USERNAME:$USERNAME /home/$USERNAME

echo "--- MULTIMEDIA INSTALL COMPLETE ---"
echo "Reboot recommended for full performance."