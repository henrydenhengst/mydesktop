#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

LOGFILE="/tmp/arch_install.log"
exec > >(tee -a "$LOGFILE") 2>&1
trap 'echo "ERROR on line $LINENO. See $LOGFILE"' ERR

echo "--- ULTIMATE ROBOT-001 INSTALL SCRIPT START ---"

# --- Helper function ---
require_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: required command not found: $1"; exit 1; }; }

for cmd in lsblk awk grep ping timedatectl reflector wipefs sgdisk mkfs.vfat mkfs.btrfs mount umount arch-chroot blkid partprobe udevadm lspci git curl; do
  require_cmd "$cmd"
done

# --- Internet check ---
echo "--- Checking Internet ---"
ping -c1 -W2 1.1.1.1 >/dev/null 2>&1 || { echo "ERROR: No internet connection."; exit 1; }
echo "Internet OK."

# --- Disk selection ---
DISKS=()
while IFS= read -r d; do DISKS+=("/dev/$d"); done < <(lsblk -dnpo NAME,TYPE,ROTA,TRAN | awk '$2=="disk" && $3=="0" && $4!="usb" {print $1}')
[[ ${#DISKS[@]} -eq 0 ]] && { echo "ERROR: No suitable disk."; exit 1; }

PS3="Select disk: "
select DISK in "${DISKS[@]}"; do [[ -n "${DISK:-}" ]] && break; echo "Invalid."; done
echo "Target disk: $DISK"

# --- CPU microcode ---
if grep -q '^vendor_id.*GenuineIntel' /proc/cpuinfo; then MCODE="intel-ucode"; elif grep -q '^vendor_id.*AuthenticAMD' /proc/cpuinfo; then MCODE="amd-ucode"; else MCODE=""; fi
echo "CPU microcode: ${MCODE:-none}"

# --- GPU detection ---
GPU_PKG=()
GPU_PARAMS=""
if lspci | grep -qi nvidia; then
  if lspci | grep -qi intel; then
    echo "Hybrid GPU detected (Optimus Intel+NVIDIA)"
    GPU_PKG+=(nvidia nvidia-dkms nvidia-utils lib32-nvidia-utils opencl-nvidia libva-nvidia-driver bumblebee primus)
    GPU_PARAMS="nvidia-drm.modeset=1"
  else
    GPU_PKG+=(nvidia-dkms nvidia-utils lib32-nvidia-utils opencl-nvidia libva-nvidia-driver)
    GPU_PARAMS="nvidia-drm.modeset=1"
  fi
elif lspci | grep -qi amd; then GPU_PKG+=(mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver); else GPU_PKG+=(mesa lib32-mesa vulkan-intel lib32-vulkan-intel libva-mesa-driver); fi
echo "GPU packages: ${GPU_PKG[*]}"

# --- User ---
HOSTNAME="arch-desktop"
USERNAME="henry"

read -rsp $'Password for \u001B[1m$USERNAME\u001B[0m: ' PASSWORD; echo
read -rsp $'Confirm password: ' PASSWORD2; echo
[[ "$PASSWORD" != "$PASSWORD2" ]] && { echo "ERROR: Password mismatch."; exit 1; }

# --- Mirror ---
timedatectl set-ntp true
reflector --latest 30 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# --- Disk wipe confirm ---
echo "WARNING: All data on $DISK will be erased!"
read -rp "Type 'YES I AM SURE' to continue: " CONFIRM
[[ "$CONFIRM" != "YES I AM SURE" ]] && { echo "Aborted."; exit 1; }

# --- Partition & Btrfs ---
wipefs -a "$DISK"; sgdisk -Z "$DISK"; sgdisk -o "$DISK"
sgdisk -n1:0:+1G -t1:ef00 -c1:EFI "$DISK"
sgdisk -n2:0:0 -t2:8300 -c2:ROOT "$DISK"
partprobe "$DISK"; udevadm settle

PART_EFI="${DISK}1"; PART_ROOT="${DISK}2"
[[ "$DISK" == *"nvme"* || "$DISK" == *"mmcblk"* ]] && PART_EFI="${DISK}p1" && PART_ROOT="${DISK}p2"

mkfs.vfat -F32 -n EFI "$PART_EFI"
mkfs.btrfs -f -L ROOT "$PART_ROOT"

mount "$PART_ROOT" /mnt
for sub in @ @home @snapshots @var_log; do btrfs subvolume create /mnt/"$sub"; done
umount /mnt

MOUNT_OPTS="noatime,compress=zstd:3,discard=async,space_cache=v2"
mount -o "$MOUNT_OPTS,subvol=@" "$PART_ROOT" /mnt
mkdir -p /mnt/{boot,home,.snapshots,var/log}
mount -o "$MOUNT_OPTS,subvol=@home" "$PART_ROOT" /mnt/home
mount -o "$MOUNT_OPTS,subvol=@snapshots" "$PART_ROOT" /mnt/.snapshots
mount -o "$MOUNT_OPTS,subvol=@var_log" "$PART_ROOT" /mnt/var/log
mount "$PART_EFI" /mnt/boot

# --- Pacstrap ---
PKGS=(
  base linux-zen linux-zen-headers linux-firmware base-devel
  btrfs-progs git sudo networkmanager reflector
  plasma-meta kde-applications-meta sddm plasma-wayland-session
  firefox terminator kate okular vlc
  pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber
  xdg-desktop-portal-kde xdg-user-dirs-gtk
  ttf-jetbrains-mono-nerd ttf-font-awesome ttf-nerd-fonts-symbols-common
  noto-fonts noto-fonts-cjk noto-fonts-emoji
  network-manager-applet bluez bluez-utils bluedevil
  duf eza bat fd ripgrep ansible wget curl htop btop ffmpegthumbs
)
[[ -n "$MCODE" ]] && PKGS+=("$MCODE")
PKGS+=("${GPU_PKG[@]}")

pacstrap -K /mnt "${PKGS[@]}"
genfstab -U /mnt >> /mnt/etc/fstab

# --- Chroot ---
arch-chroot /mnt /bin/bash <<EOF
set -euo pipefail

# Timezone via GeoIP
TZ=\$(curl -s --max-time 5 https://ipapi.co/timezone || echo "Europe/Amsterdam")
ln -sf /usr/share/zoneinfo/\$TZ /etc/localtime
hwclock --systohc


# --- Locale & hostname ---
# Enable locales
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#nl_NL.UTF-8 UTF-8/nl_NL.UTF-8 UTF-8/' /etc/locale.gen

locale-gen

# Set locale (English system, Dutch formatting)
cat > /etc/locale.conf <<EOT
LANG=en_US.UTF-8
LC_TIME=nl_NL.UTF-8
LC_NUMERIC=nl_NL.UTF-8
LC_MONETARY=nl_NL.UTF-8
EOT

# Hostname
echo "$HOSTNAME" > /etc/hostname

# Hosts file
cat > /etc/hosts <<EOT
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain   $HOSTNAME
EOT

# User & sudo
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# Bootloader systemd-boot
bootctl --path=/boot install
cat > /boot/loader/loader.conf <<EOT
default	arch.conf
timeout	3
editor	no
console-mode	max
EOT

ROOT_UUID=\$(blkid -s UUID -o value "$PART_ROOT")
cat > /boot/loader/entries/arch.conf <<EOT
title	Arch Linux (Zen)
linux	/vmlinuz-linux-zen
EOT
[[ -n "$MCODE" ]] && echo "initrd	/$MCODE.img" >> /boot/loader/entries/arch.conf
echo "initrd	/initramfs-linux-zen.img" >> /boot/loader/entries/arch.conf
echo "options	root=UUID=\$ROOT_UUID rootflags=subvol=@ rw $GPU_PARAMS quiet splash zswap.enabled=1" >> /boot/loader/entries/arch.conf

# Snapper
pacman -S --noconfirm --needed snapper
snapper -c root create-config /
mkdir -p /.snapshots
chmod 750 /.snapshots
chown :wheel /.snapshots
systemctl enable --now snapper-timeline.timer snapper-cleanup.timer

# Services
systemctl enable NetworkManager bluetooth sddm

# Paru (AUR helper)
sudo -u $USERNAME bash -c "cd /tmp && git clone https://aur.archlinux.org/paru-bin.git && cd paru-bin && makepkg -si --noconfirm"

# Aliases & dotfiles
cat >> /home/$USERNAME/.bashrc <<'EOT'
alias ls='eza --icons --group-directories-first'
alias ll='eza -l --icons --group-directories-first'
alias la='eza -la --icons --group-directories-first'
alias cat='bat'
alias df='duf'
alias top='btop'
EOT

mkdir -p /home/$USERNAME/.config/terminator
cat > /home/$USERNAME/.config/terminator/config <<'EOT'
[global_config]
[profiles]
  [[default]]
    font = JetBrainsMono Nerd Font 10
    use_system_font = False
    show_titlebar = False
EOT

chown -R $USERNAME:$USERNAME /home/$USERNAME
EOF

umount -R /mnt
echo "--- ULTIMATE INSTALL COMPLETE! ---"
echo "Logfile: $LOGFILE"
read -rp "Reboot now? (y/N): " REBOOT
[[ "${REBOOT,,}" =~ ^[y] ]] && reboot || echo "Reboot skipped. Run 'reboot' manually."