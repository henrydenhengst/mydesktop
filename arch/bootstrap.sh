#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

LOGFILE="/tmp/arch_install.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "--- ROBOT-001 INSTALL SCRIPT START ---"

# --- 0. INTERNET CHECK ---
echo "--- Checking for Internet connectivity ---"
if ! ping -c 1 google.com &>/dev/null; then
    echo "ERROR: No internet connection. Connect via 'iwctl' or Ethernet, then retry."
    exit 1
fi
echo "Internet connection OK."

# --- 1. HARDWARE DETECTIE ---
echo "--- Detecting hardware ---"

DISK=$(lsblk -bno NAME,SIZE,TYPE,ROTA,TRAN | awk '$3=="disk" && $4=="0" && $5!="usb" {print "/dev/"$1}' | sort -k2 -rn | head -n 1)
if [[ -z "$DISK" ]]; then
    echo "ERROR: No suitable disk found!"
    exit 1
fi
echo "Target disk: $DISK"

MCODE=$(grep -iq "Intel" /proc/cpuinfo && echo "intel-ucode" || echo "amd-ucode")
echo "CPU microcode package: $MCODE"

# GPU detectie: NVIDIA, AMD, Intel
if lspci | grep -iq nvidia; then
    GPU_PKG="nvidia-dkms nvidia-utils lib32-nvidia-utils opencl-nvidia libva-nvidia-driver"
elif lspci | grep -iq amd; then
    GPU_PKG="mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver"
else
    GPU_PKG="mesa lib32-mesa vulkan-intel lib32-vulkan-intel libva-mesa-driver"
fi
echo "GPU packages: $GPU_PKG"

# --- 2. USER CONFIG ---
HOSTNAME="arch-desktop"
USERNAME="henry"

# Vraag gebruiker om veilig wachtwoord
read -rsp "Set password for $USERNAME: " PASSWORD
echo

# --- 3. MIRROR OPTIMALISATIE ---
timedatectl set-ntp true
reflector --latest 30 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# --- 4. CONFIRMED DISK WIPE ---
echo "WARNING: This will erase all data on $DISK!"
read -rp "Type 'YES' to continue: " CONFIRM
if [[ "$CONFIRM" != "YES" ]]; then
    echo "Aborted by user."
    exit 1
fi

wipefs -a "$DISK"
sgdisk -Z "$DISK"

# Partition setup
sgdisk -n 1:0:+1G -t 1:ef00 "$DISK"
sgdisk -n 2:0:0 -t 2:8300 "$DISK"

PART_EFI="${DISK}1"
PART_ROOT="${DISK}2"
[[ "$DISK" == *"nvme"* ]] && PART_EFI="${DISK}p1" && PART_ROOT="${DISK}p2"

mkfs.vfat -F 32 "$PART_EFI"
mkfs.btrfs -f -L "ROOT" "$PART_ROOT"

mount "$PART_ROOT" /mnt
for sub in @ @home @snapshots @var_log; do
    btrfs subvolume create "/mnt/$sub"
done
umount /mnt

MOUNT_OPTS="noatime,compress=zstd:3,discard=async,space_cache=v2"
mount -o "$MOUNT_OPTS,subvol=@" "$PART_ROOT" /mnt
mkdir -p /mnt/{boot,home,.snapshots,var/log}
mount -o "$MOUNT_OPTS,subvol=@home" "$PART_ROOT" /mnt/home
mount -o "$MOUNT_OPTS,subvol=@snapshots" "$PART_ROOT" /mnt/.snapshots
mount -o "$MOUNT_OPTS,subvol=@var_log" "$PART_ROOT" /mnt/var/log
mount "$PART_EFI" /mnt/boot

# --- 5. PACSTRAP INSTALL ---
pacstrap /mnt base linux-zen linux-zen-headers linux-firmware base-devel \
btrfs-progs git sudo networkmanager "$MCODE" $GPU_PKG \
plasma-meta kde-applications-meta sddm plasma-wayland-session \
firefox terminator kate okular vlc \
pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber \
xdg-desktop-portal-kde xdg-user-dirs-gtk \
ttf-jetbrains-mono-nerd ttf-font-awesome ttf-nerd-fonts-symbols-common \
noto-fonts noto-fonts-cjk noto-fonts-emoji \
network-manager-applet bluez bluez-utils bluedevil \
duf eza bat fd ripgrep ansible wget curl htop btop ffmpegthumbs

genfstab -U /mnt >> /mnt/etc/fstab

# --- 6. CHROOT CONFIG ---
arch-chroot /mnt /bin/bash <<EOF
set -euo pipefail

# Timezone fallback
TZ=\$(curl -s https://ipapi.co/timezone || echo "UTC")
ln -sf /usr/share/zoneinfo/\$TZ /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "$HOSTNAME" > /etc/hostname

# User setup
useradd -m -G wheel $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# Bootloader: systemd-boot
bootctl install
UUID=\$(blkid -s UUID -o value $PART_ROOT)
cat <<EOT > /boot/loader/entries/arch.conf
title   Arch Linux (Zen Kernel)
linux   /vmlinuz-linux-zen
initrd  /\$MCODE.img
initrd  /initramfs-linux-zen.img
options root=UUID=\$UUID rootflags=subvol=@ rw nvidia-drm.modeset=1 zswap.enabled=1 quiet
EOT

# Snapper config
snapper -c root create-config /
chmod 750 /.snapshots
chown :wheel /.snapshots

# Enable services
systemctl enable NetworkManager bluetooth sddm
systemctl enable snapper-timeline.timer snapper-cleanup.timer

# AUR Helper: Paru
sudo -u $USERNAME bash -c "cd /tmp && git clone https://aur.archlinux.org/paru-bin.git && cd paru-bin && makepkg -si --noconfirm"

# Aliassen & dotfiles
cat <<EOT >> /home/$USERNAME/.bashrc
alias ls='eza --icons --group-directories-first'
alias ll='eza -l --icons --group-directories-first'
alias cat='bat'
alias df='duf'
alias top='btop'
EOT

mkdir -p /home/$USERNAME/.config/terminator
cat <<EOT > /home/$USERNAME/.config/terminator/config
[global_config]
[profiles]
  [[default]]
    font = JetBrainsMono Nerd Font 10
    use_system_font = False
    show_titlebar = False
EOT

chown -R $USERNAME:$USERNAME /home/$USERNAME
EOF

echo "--- INSTALL COMPLETE. REBOOTING IN 5 SECONDS ---"
sleep 5
reboot