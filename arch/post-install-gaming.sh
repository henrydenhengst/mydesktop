#!/bin/bash
set -euo pipefail

echo "--- ULTIMATE GAMING POST-INSTALL START ---"

USERNAME="${SUDO_USER:-$USER}"

if [[ "$EUID" -ne 0 ]]; then
  echo "Run with sudo!"
  exit 1
fi

echo "Target user: $USERNAME"

# --- Update ---
echo "--- Updating system ---"
pacman -Syu --noconfirm

# --- Core gaming stack ---
echo "--- Installing core gaming stack ---"
pacman -S --noconfirm --needed \
  steam lutris heroic-games-launcher \
  wine winetricks \
  gamemode lib32-gamemode \
  mangohud lib32-mangohud goverlay \
  gamescope \
  vulkan-icd-loader lib32-vulkan-icd-loader \
  vulkan-tools mesa-demos \
  obs-studio discord

# --- Extra performance / system ---
echo "--- Installing performance tools ---"
pacman -S --noconfirm --needed \
  power-profiles-daemon irqbalance \
  earlyoom

# --- Emulators ---
echo "--- Installing emulators ---"
pacman -S --noconfirm --needed \
  retroarch retroarch-assets-xmb \
  dolphin-emu pcsx2 \
  rpcs3 \
  yuzu-mainline-bin || true

# --- Containers for game servers ---
echo "--- Installing container tools ---"
pacman -S --noconfirm --needed docker docker-compose

# --- Services ---
echo "--- Enabling services ---"
systemctl enable --now bluetooth
systemctl enable --now docker
systemctl enable --now irqbalance
systemctl enable --now power-profiles-daemon
systemctl enable --now earlyoom

# --- Docker permissions ---
usermod -aG docker "$USERNAME"

# --- GameMode config ---
echo "--- Configuring GameMode ---"
mkdir -p /home/$USERNAME/.config
cat > /home/$USERNAME/.config/gamemode.ini <<'EOF'
[general]
renice=10
softrealtime=auto

[gpu]
apply_gpu_optimisations=accept-responsibility
EOF

# --- MangoHud config ---
echo "--- Configuring MangoHud ---"
mkdir -p /home/$USERNAME/.config/MangoHud
cat > /home/$USERNAME/.config/MangoHud/MangoHud.conf <<'EOF'
fps
frametime
cpu_temp
gpu_temp
vram
ram
io_read
io_write
EOF

# --- Environment tweaks ---
echo "--- Applying environment optimizations ---"
cat >> /home/$USERNAME/.bashrc <<'EOF'

# === GAMING STACK ===

# MangoHud + GameMode
export MANGOHUD=1
export ENABLE_VKBASALT=0

# Vulkan shader cache
export __GL_SHADER_DISK_CACHE=1

# Proton / Steam
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/root"
export STEAM_COMPAT_DATA_PATH="$HOME/.steam/steamapps/compatdata"

# Wayland tweaks
export MOZ_ENABLE_WAYLAND=1
export SDL_VIDEODRIVER=wayland
export CLUTTER_BACKEND=wayland
EOF

# --- Optional directories ---
mkdir -p /home/$USERNAME/Games
mkdir -p /home/$USERNAME/Emulators

# --- Permissions ---
chown -R $USERNAME:$USERNAME /home/$USERNAME

echo "--- INSTALL COMPLETE ---"
echo "Reboot recommended."