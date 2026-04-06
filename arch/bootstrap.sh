#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

LOGFILE="/tmp/arch_install.log"
exec > >(tee -a "$LOGFILE") 2>&1
trap 'echo "ERROR on line $LINENO. See $LOGFILE"' ERR

echo "--- ROBOT-001 INSTALL SCRIPT START ---"

# --- Helper function for required commands ---
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "ERROR: required command not found: $1"; exit 1; }
}

# --- Required binaries check ---
for cmd in lsblk awk grep ping timedatectl reflector wipefs sgdisk mkfs.vfat mkfs.btrfs mount umount arch-chroot blkid partprobe udevadm lspci; do
  require_cmd "$cmd"
done

# --- Internet check ---
echo "--- Checking Internet connectivity ---"
if ! ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
  echo "ERROR: No internet connection."
  exit 1
fi
echo "Internet connection OK."

# --- Disk selection ---
echo "--- Detecting disks ---"
DISKS=()
while IFS= read -r d; do DISKS+=("$d"); done < <(lsblk -dnpo NAME,TYPE,ROTA,TRAN | awk '$2=="disk" && $3=="0" && $4!="usb" {print $1}')

if [[ ${#DISKS[@]} -eq 0 ]]; then
  echo "ERROR: No suitable disk found."
  exit 1
fi

echo "Available target disks:"
select DISK in "${DISKS[@]}"; do
  [[ -n "${DISK:-}" ]] && break
  echo "Invalid selection."
done
echo "Target disk: $DISK"

# --- CPU microcode ---
if grep -qi 'GenuineIntel' /proc/cpuinfo; then
  MCODE="intel-ucode"
elif grep -qi 'AuthenticAMD' /proc/cpuinfo; then
  MCODE="amd-ucode"
else
  MCODE=""
fi
echo "CPU microcode package: ${MCODE:-none}"

# --- GPU packages ---
if lspci | grep -qi nvidia; then
  GPU_PKG=(nvidia-dkms nvidia-utils lib32-nvidia-utils opencl-nvidia libva-nvidia-driver)
  GPU_PARAMS="nvidia-drm.modeset=1"
elif lspci | grep -qi amd; then
  GPU_PKG=(mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver)
  GPU_PARAMS=""
else
  GPU_PKG=(mesa lib32-mesa vulkan-intel lib32-vulkan-intel libva-mesa-driver)
  GPU_PARAMS=""
fi
echo "GPU packages: ${GPU_PKG[*]}"

# --- User config ---
HOSTNAME="arch-desktop"
USERNAME="henry"

read -rsp "Set password for $USERNAME: " PASSWORD
echo
read -rsp "Confirm password for $USERNAME: " PASSWORD2
echo
[[ "$PASSWORD" != "$PASSWORD2" ]] && { echo "ERROR: Passwords do not match."; exit 1; }

# --- Mirror optimization ---
timedatectl set-ntp true
reflector --latest 30 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# --- Confirm disk wipe ---
echo "WARNING: This will erase all data on $DISK!"
read -rp "Type 'YES' to continue: " CONFIRM
[[ "$CONFIRM" != "YES" ]] && { echo "Aborted by user."; exit 1; }

# --- Partition & Btrfs setup ---
wipefs -a "$DISK"
sgdisk -Z "$DISK"
sgdisk -o "$DISK"
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:EFI "$DISK"
sgdisk -n 2:0:0 -t 2:8300 -c 2:ROOT "$DISK"
partprobe "$DISK" || true
udevadm settle || true

PART_EFI="${DISK}1"
PART_ROOT="${DISK}2"
[[ "$DISK" == *"nvme"* || "$DISK" == *"mmcblk"* ]] && PART_EFI="${DISK}p1" && PART_ROOT="${DISK}p2"

mkfs.vfat -F 32 -n EFI "$PART_EFI"
mkfs.btrfs -f -L ROOT "$PART_ROOT"

mount "$PART_ROOT" /mnt
for sub in @ @home @snapshots @var_log; do btrfs subvolume create /mnt/$sub; done
umount /mnt

MOUNT_OPTS="noatime,compress=zstd:3,discard=async,space_cache=v2"
mount -o "$MOUNT_OPTS,subvol=@" "$PART_ROOT" /mnt
mkdir -p /mnt/{boot,home,.snapshots,var/log}
mount -o "$MOUNT_OPTS,subvol=@home" "$PART_ROOT" /mnt/home
mount -o "$MOUNT_OPTS,subvol=@snapshots" "$PART_ROOT" /mnt/.snapshots
mount -o "$MOUNT_OPTS,subvol=@var_log" "$PART_ROOT" /mnt/var/log
mount "$PART_EFI" /mnt/boot

# --- Pacstrap packages ---
PKGS=(
  base linux-zen linux-zen-headers linux-firmware base-devel
  btrfs-progs git sudo networkmanager
  plasma-meta kde-applications-meta sddm plasma-wayland-session
  firefox terminator kate okular vlc
  pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber
  xdg-desktop-portal-kde xdg-user-dirs-gtk
  ttf-jetbrains-mono-nerd ttf-font-awesome ttf-nerd-fonts-symbols-common
  noto-fonts noto-fonts-cjk noto-fonts-emoji
  network-manager-applet bluez bluez-utils bluedevil
  duf eza bat fd ripgrep ansible wget curl htop btop ffmpegthumbs
  reflector
)

[[ -n "$MCODE" ]] && PKGS+=("$MCODE")
PKGS+=("${GPU_PKG[@]}")

pacstrap /mnt "${PKGS[@]}"
genfstab -U /mnt >> /mnt/etc/fstab

# --- Chroot configuration ---
arch-chroot /mnt /bin/bash <<EOF
set -euo pipefail

# --- Timezone via Geo-IP ---
TZ=\$(curl -s https://ipapi.co/timezone || echo "UTC")
ln -sf /usr/share/zoneinfo/\$TZ /etc/localtime
hwclock --systohc

# --- Locale & hostname ---
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname
cat >> /etc/hosts <<EOT
127.0.0.1 localhost
::1       localhost
127.0.1.1 $HOSTNAME.localdomain $HOSTNAME
EOT

# --- User setup ---
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# --- Bootloader: systemd-boot ---
bootctl --path=/boot install
cat > /boot/loader/loader.conf <<EOT
default arch.conf
timeout 3
editor no
EOT

UUID=\$(blkid -s UUID -o value "$PART_ROOT")
cat > /boot/loader/entries/arch.conf <<EOT
title   Arch Linux (Zen)
linux   /vmlinuz-linux-zen
EOT
[[ -n "$MCODE" ]] && echo "initrd  /$MCODE.img" >> /boot/loader/entries/arch.conf
echo "initrd  /initramfs-linux-zen.img" >> /boot/loader/entries/arch.conf
echo "options root=UUID=$UUID rootflags=@ rw $GPU_PARAMS quiet" >> /boot/loader/entries/arch.conf

# --- Snapper ---
pacman -S --noconfirm snapper
snapper -c root create-config /
mkdir -p /.snapshots
chmod 750 /.snapshots
chown :wheel /.snapshots
systemctl enable snapper-timeline.timer snapper-cleanup.timer

# --- Enable services ---
systemctl enable NetworkManager bluetooth sddm

# --- Aliases & dotfiles ---
cat > /home/$USERNAME/.bashrc <<'EOT'
alias ls='eza --icons --group-directories-first'
alias ll='eza -l --icons --group-directories-first'
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

echo "--- INSTALL COMPLETE ---"
read -rp "Reboot now? (y/N): " REBOOT
[[ "$REBOOT" =~ ^[Yy]$ ]] && reboot || echo "Reboot skipped. You can reboot manually."