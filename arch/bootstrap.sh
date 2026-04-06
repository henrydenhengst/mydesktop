#!/bin/bash

# --- 0. DE "BEN JE WEL ONLINE?" CHECK ---
echo "--- Checking for life signs (Internet) ---"
if ! ping -c 1 google.com &>/dev/null; then
    echo "ERROR: No internet connection. Connect via 'iwctl' or plug in a cable, then try again."
    exit 1
fi
echo "Connection confirmed. Proceeding with Robot-001 deployment..."

# --- 1. HARDWARE & DISK AUTO-SCAN ---
DISK=$(lsblk -bno NAME,SIZE,TYPE,ROTA,TRAN | awk '$3=="disk" && $4=="0" && $5!="usb" {print "/dev/"$1}' | sort -k2 -rn | head -n 1)
MCODE=$(grep -iq "Intel" /proc/cpuinfo && echo "intel-ucode" || echo "amd-ucode")
GPU_PKG=$(lspci | grep -iq "nvidia" && echo "nvidia-dkms nvidia-utils lib32-nvidia-utils opencl-nvidia libva-nvidia-driver" || echo "mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver")

HOSTNAME="arch-desktop"
USERNAME="henry"
PASSWORD="Password1!"

# --- 2. MIRROR OPTIMALISATIE ---
timedatectl set-ntp true
reflector --latest 30 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# --- 3. BTRFS LAYOUT (SNAPPER OPTIMIZED) ---
wipefs -a $DISK
sgdisk -Z $DISK
sgdisk -n 1:0:+1G -t 1:ef00 $DISK
sgdisk -n 2:0:0 -t 2:8300 $DISK
PART_EFI="${DISK}1"; PART_ROOT="${DISK}2"
[[ $DISK == *"nvme"* ]] && PART_EFI="${DISK}p1" && PART_ROOT="${DISK}p2"

mkfs.vfat -F 32 $PART_EFI
mkfs.btrfs -f -L "ROOT" $PART_ROOT
mount $PART_ROOT /mnt
for i in @ @home @snapshots @var_log; do btrfs subvolume create /mnt/$i; done
umount /mnt

MOUNT_OPTS="noatime,compress=zstd:3,discard=async,space_cache=v2"
mount -o $MOUNT_OPTS,subvol=@ $PART_ROOT /mnt
mkdir -p /mnt/{boot,home,.snapshots,var/log}
mount -o $MOUNT_OPTS,subvol=@home $PART_ROOT /mnt/home
mount -o $MOUNT_OPTS,subvol=@snapshots $PART_ROOT /mnt/.snapshots
mount -o $MOUNT_OPTS,subvol=@var_log $PART_ROOT /mnt/var/log
mount $PART_EFI /mnt/boot

# --- 4. PACSTRAP: DE VOLLEDIGE APP & DEV STACK ---
pacstrap /mnt base linux-zen linux-zen-headers linux-firmware base-devel \
btrfs-progs git sudo networkmanager $MCODE $GPU_PKG \
plasma-meta kde-applications-meta sddm plasma-wayland-session \
firefox terminator kate okular vlc \
pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber \
xdg-desktop-portal-kde xdg-user-dirs-gtk \
ttf-jetbrains-mono-nerd ttf-font-awesome ttf-nerd-fonts-symbols-common \
noto-fonts noto-fonts-cjk noto-fonts-emoji \
network-manager-applet bluez bluez-utils bluedevil \
duf eza bat fd ripgrep ansible wget curl htop btop ffmpegthumbs

# --- 5. CHROOT CONFIGURATIE ---
genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash <<EOF
# Locale & Timezone (Geo-IP scan)
ln -sf /usr/share/zoneinfo/\$(curl -s https://ipapi.co/timezone) /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname

# Gebruiker & Rechten
useradd -m -G wheel $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# Bootloader (Systemd-boot met Zen-tuning)
bootctl install
UUID=\$(blkid -s UUID -o value $PART_ROOT)
cat <<EOT > /boot/loader/entries/arch.conf
title   Arch Linux (Zen Kernel)
linux   /vmlinuz-linux-zen
initrd  /\$MCODE.img
initrd  /initramfs-linux-zen.img
options root=UUID=\$UUID rootflags=subvol=@ rw nvidia-drm.modeset=1 zswap.enabled=1 quiet
EOT

# Snapper & BTRFS Fix
umount /.snapshots && rm -rf /.snapshots
snapper -c root create-config /
rm -rf /.snapshots && mkdir /.snapshots
mount -a 
chown :wheel /.snapshots && chmod 750 /.snapshots

# Services Activeren
systemctl enable NetworkManager bluetooth sddm
systemctl enable snapper-timeline.timer snapper-cleanup.timer

# Paru (AUR Helper)
sudo -u $USERNAME bash -c "cd /tmp && git clone https://aur.archlinux.org/paru-bin.git && cd paru-bin && makepkg -si --noconfirm"

# --- DE FINISH: DOTFILES & ALIASSEN ---
# Aliassen voor Rust tools
cat <<EOT >> /home/$USERNAME/.bashrc
alias ls='eza --icons --group-directories-first'
alias ll='eza -l --icons --group-directories-first'
alias cat='bat'
alias df='duf'
alias top='btop'
EOT

# Terminator Minimalist Config
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

echo "--- INSTALLATIE VOLTOOID. ROBOT-001 HERSTART OVER 5 SECONDEN. ---"
sleep 5
reboot
