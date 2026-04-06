#!/bin/bash
set -euo pipefail
IFS=$'
\t'

LOGFILE="/tmp/arch_install.log"
exec > >(tee -a "$LOGFILE") 2>&1

trap 'echo "ERROR on line $LINENO. See $LOGFILE"' ERR

echo "--- ROBOT-001 INSTALL SCRIPT START ---"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command not found: $1"
    exit 1
  }
}

for cmd in lsblk awk grep ping timedatectl reflector wipefs sgdisk mkfs.vfat mkfs.btrfs mount umount arch-chroot blkid; do
  require_cmd "$cmd"
done

echo "--- Checking for Internet connectivity ---"
if ! ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
  echo "ERROR: No internet connection."
  exit 1
fi
echo "Internet connection OK."

echo "--- Detecting hardware ---"

DISKS=()
while IFS= read -r d; do
  DISKS+=("$d")
done < <(lsblk -dnpo NAME,TYPE,ROTA,TRAN | awk '$2=="disk" && $3=="0" && $4!="usb" {print $1}')

if [[ ${#DISKS[@]} -eq 0 ]]; then
  echo "ERROR: No suitable disk found."
  exit 1
fi

echo "Available target disks:"
select DISK in "${DISKS[@]}"; do
  if [[ -n "${DISK:-}" ]]; then
    break
  fi
  echo "Invalid selection."
done

echo "Target disk: $DISK"

if grep -qi 'GenuineIntel' /proc/cpuinfo; then
  MCODE="intel-ucode"
elif grep -qi 'AuthenticAMD' /proc/cpuinfo; then
  MCODE="amd-ucode"
else
  MCODE=""
fi

echo "CPU microcode package: ${MCODE:-none}"

if lspci | grep -qi nvidia; then
  GPU_PKG=(nvidia-dkms nvidia-utils lib32-nvidia-utils opencl-nvidia libva-nvidia-driver)
elif lspci | grep -qi amd; then
  GPU_PKG=(mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver)
else
  GPU_PKG=(mesa lib32-mesa vulkan-intel lib32-vulkan-intel libva-mesa-driver)
fi

echo "GPU packages: ${GPU_PKG[*]}"

HOSTNAME="arch-desktop"
USERNAME="henry"

read -rsp "Set password for $USERNAME: " PASSWORD
echo
read -rsp "Confirm password for $USERNAME: " PASSWORD2
echo

if [[ "$PASSWORD" != "$PASSWORD2" ]]; then
  echo "ERROR: Passwords do not match."
  exit 1
fi

timedatectl set-ntp true
reflector --latest 30 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

echo "WARNING: This will erase all data on $DISK!"
read -rp "Type 'YES' to continue: " CONFIRM
if [[ "$CONFIRM" != "YES" ]]; then
  echo "Aborted by user."
  exit 1
fi

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
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log
umount /mnt

MOUNT_OPTS="noatime,compress=zstd:3,discard=async,space_cache=v2"
mount -o "$MOUNT_OPTS,subvol=@" "$PART_ROOT" /mnt
mkdir -p /mnt/{boot,home,.snapshots,var/log}
mount -o "$MOUNT_OPTS,subvol=@home" "$PART_ROOT" /mnt/home
mount -o "$MOUNT_OPTS,subvol=@snapshots" "$PART_ROOT" /mnt/.snapshots
mount -o "$MOUNT_OPTS,subvol=@var_log" "$PART_ROOT" /mnt/var/log
mount "$PART_EFI" /mnt/boot

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

if [[ -n "$MCODE" ]]; then
  PKGS+=("$MCODE")
fi

PKGS+=("${GPU_PKG[@]}")

pacstrap /mnt "${PKGS[@]}"
genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash <<EOF
set -euo pipefail

ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc

sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
cat > /etc/locale.conf <<EOT
LANG=en_US.UTF-8
EOT

cat > /etc/hostname <<EOT
$HOSTNAME
EOT

cat >> /etc/hosts <<EOT
127.0.0.1 localhost
::1       localhost
127.0.1.1 $HOSTNAME.localdomain $HOSTNAME
EOT

useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

bootctl --path=/boot install

cat > /boot/loader/loader.conf <<EOT
default arch.conf
timeout 3
editor no
EOT

UUID=$(blkid -s UUID -o value "$PART_ROOT")

cat > /boot/loader/entries/arch.conf <<EOT
title   Arch Linux (Zen)
linux   /vmlinuz-linux-zen
EOT

if [[ -n "$MCODE" ]]; then
cat >> /boot/loader/entries/arch.conf <<EOT
initrd  /$MCODE.img
EOT
fi

cat >> /boot/loader/entries/arch.conf <<EOT
initrd  /initramfs-linux-zen.img
options root=UUID=$UUID rootflags=subvol=@ rw quiet
EOT

pacman -S --noconfirm snapper
snapper -c root create-config /
mkdir -p /.snapshots
chmod 750 /.snapshots
chown :wheel /.snapshots

systemctl enable NetworkManager bluetooth sddm

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
echo "Reboot in 5 seconds..."
sleep 5
reboot