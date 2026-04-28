#!/bin/bash
set -e

# --- CONFIGURATIE ---
DISK="/dev/sda"  # Pas dit aan naar jouw schijf (bijv. /dev/nvme0n1)
HOSTNAME="void-bios"
USERNAME="voiduser"

echo "Start BIOS installatie op $DISK..."

# 1. Partitioneren (1 partitie voor het hele systeem)
echo "Partitioneren..."
sfdisk "$DISK" <<EOF
label: dos
device: $DISK
unit: sectors

$DISK : start=2048, type=83, bootable
EOF

# 2. Formatteren
echo "Formatteren..."
mkfs.ext4 -F "${DISK}1"
mount "${DISK}1" /mnt

# 3. Base system installeren
echo "Pakketten installeren..."
mkdir -p /mnt/var/db/xbps/keys
cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/
XBPS_ARCH=x86_64 xbps-install -S -r /mnt -R https://repo-default.voidlinux.org/current \
    base-system grub vim git ansible

# 4. Configureren (Chroot)
echo "Systeem configureren..."
chroot /mnt /bin/bash <<EOF
echo "$HOSTNAME" > /etc/hostname
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/rc.conf
useradd -m -G wheel,users -s /bin/bash $USERNAME
echo "root:voidlinux" | chpasswd
echo "$USERNAME:voidlinux" | chpasswd

grub-install "$DISK"
update-grub
EOF

umount -R /mnt
echo "Klaar! Reboot nu."
