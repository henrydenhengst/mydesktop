#!/bin/bash
set -e

# --- CONFIGURATIE ---
DISK="/dev/sda"  # Pas dit aan (bijv. /dev/sda of /dev/nvme0n1)
HOSTNAME="void-efi"
USERNAME="voiduser"

# Detecteer partitie-naming (nvme0n1p1 vs sda1)
if [[ $DISK == *"nvme"* ]]; then P="p"; else P=""; fi

echo "Start UEFI installatie op $DISK..."

# 1. Partitioneren (GPT: EFI + Root)
echo "Partitioneren..."
sfdisk "$DISK" <<EOF
label: gpt
device: $DISK
unit: sectors

${DISK}${P}1 : start=2048, size=1048576, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
${DISK}${P}2 : start=1050624, size=+, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
EOF

# 2. Formatteren
echo "Formatteren..."
mkfs.vfat "${DISK}${P}1"
mkfs.ext4 -F "${DISK}${P}2"

mount "${DISK}${P}2" /mnt
mkdir -p /mnt/boot/efi
mount "${DISK}${P}1" /mnt/boot/efi

# 3. Base system installeren
echo "Pakketten installeren..."
mkdir -p /mnt/var/db/xbps/keys
cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/
XBPS_ARCH=x86_64 xbps-install -S -r /mnt -R https://repo-default.voidlinux.org/current \
    base-system grub-x86_64-efi vim git ansible

# 4. Fstab genereren (Heel simpel voor ext4)
echo "${DISK}${P}2 / ext4 defaults 0 1" > /mnt/etc/fstab
echo "${DISK}${P}1 /boot/efi vfat defaults 0 2" >> /mnt/etc/fstab

# 5. Configureren (Chroot)
echo "Systeem configureren..."
chroot /mnt /bin/bash <<EOF
echo "$HOSTNAME" > /etc/hostname
echo "LANG=en_US.UTF-8" > /etc/locale.conf
useradd -m -G wheel,users -s /bin/bash $USERNAME
echo "root:voidlinux" | chpasswd
echo "$USERNAME:voidlinux" | chpasswd

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="Void"
update-grub
EOF

umount -R /mnt
echo "Klaar! Reboot nu."
