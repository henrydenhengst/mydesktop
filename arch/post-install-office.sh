#!/bin/bash
set -euo pipefail

echo "--- OFFICE / PRODUCTIVITY POST-INSTALL START ---"

USERNAME="${SUDO_USER:-$USER}"

if [[ "$EUID" -ne 0 ]]; then
  echo "Run with sudo!"
  exit 1
fi

echo "Target user: $USERNAME"

# --- Update ---
echo "--- Updating system ---"
pacman -Syu --noconfirm

# --- Office suite ---
echo "--- Installing office suite ---"
pacman -S --noconfirm --needed \
  libreoffice-fresh \
  hunspell hunspell-en_us hunspell-nl \
  hyphen hyphen-en hyphen-nl

# --- PDF / Documents ---
echo "--- Installing document tools ---"
pacman -S --noconfirm --needed \
  okular evince \
  pdfarranger \
  poppler \
  imagemagick

# --- Notes & productivity ---
echo "--- Installing productivity tools ---"
pacman -S --noconfirm --needed \
  obsidian \
  joplin-desktop \
  zathura zathura-pdf-mupdf

# --- Communication ---
echo "--- Installing communication tools ---"
pacman -S --noconfirm --needed \
  thunderbird \
  telegram-desktop \
  signal-desktop \
  zoom

# --- Browser stack ---
echo "--- Installing browsers ---"
pacman -S --noconfirm --needed \
  firefox chromium

# --- File management ---
echo "--- Installing file tools ---"
pacman -S --noconfirm --needed \
  dolphin \
  ark file-roller \
  gvfs gvfs-mtp gvfs-smb \
  samba cifs-utils

# --- Printing / scanning ---
echo "--- Installing printing & scanning ---"
pacman -S --noconfirm --needed \
  cups cups-pdf \
  system-config-printer \
  sane simple-scan

# --- Fonts ---
echo "--- Installing fonts ---"
pacman -S --noconfirm --needed \
  ttf-dejavu \
  ttf-liberation \
  noto-fonts noto-fonts-cjk noto-fonts-emoji

# --- Utilities ---
echo "--- Installing utilities ---"
pacman -S --noconfirm --needed \
  flameshot \
  xclip wl-clipboard \
  unzip zip p7zip \
  keepassxc \
  gnome-keyring seahorse

# --- Cloud / sync ---
echo "--- Installing sync tools ---"
pacman -S --noconfirm --needed \
  nextcloud-client \
  syncthing

# --- Services ---
echo "--- Enabling services ---"
systemctl enable --now cups
systemctl enable --now bluetooth

# --- Syncthing for user ---
sudo -u "$USERNAME" systemctl --user enable syncthing.service || true

# --- Locale tweak (NL friendly) ---
echo "--- Configuring locale preferences ---"
cat >> /home/$USERNAME/.config/locale.conf <<'EOF'
LC_TIME=nl_NL.UTF-8
LC_NUMERIC=nl_NL.UTF-8
LC_MONETARY=nl_NL.UTF-8
EOF

# --- XDG user dirs ---
echo "--- Setting up user directories ---"
sudo -u "$USERNAME" xdg-user-dirs-update

# --- Default apps tweaks ---
echo "--- Setting useful aliases ---"
cat >> /home/$USERNAME/.bashrc <<'EOF'

# === OFFICE / PRODUCTIVITY ===

alias open='xdg-open'
alias pdf='okular'
alias edit='kate'
alias notes='obsidian'
EOF

# --- Permissions ---
chown -R $USERNAME:$USERNAME /home/$USERNAME

echo "--- OFFICE INSTALL COMPLETE ---"
echo "Reboot recommended for full integration."