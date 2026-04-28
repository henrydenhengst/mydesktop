#!/bin/bash
set -e

# --- CONFIGURATIE ---
# Tip: Gebruik $(lsblk -dpno NAME | grep -vE 'loop|boot' | head -n1) voor automatische detectie
DISK="/dev/sda"  
HOSTNAME="void-bios"
USERNAME="voiduser"

echo "Start BIOS installatie op $DISK..."

# 1. Partitioneren
echo "Partitioneren..."
sfdisk "$DISK" <<EOF
label: dos
device: $DISK
unit: sectors

${DISK}1 : start=2048, type=83, bootable
EOF

# 2. Formatteren
echo "Formatteren..."
mkfs.ext4 -F "${DISK}1"
mount "${DISK}1" /mnt

# 3. Base system installeren
# BELANGRIJK: Hier voegen we de extra tools toe voor jouw Ansible playbook
echo "Pakketten installeren (inclusief Ansible benodigdheden)..."
mkdir -p /mnt/var/db/xbps/keys
cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/

XBPS_ARCH=x86_64 xbps-install -S -r /mnt -R https://repo-default.voidlinux.org/current \
    base-system grub vim git ansible pciutils usbutils sudo xtools

# 4. Configureren (Chroot)
echo "Systeem configureren..."
chroot /mnt /bin/bash <<EOF
echo "$HOSTNAME" > /etc/hostname
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/rc.conf

# Gebruiker aanmaken en wachtwoorden instellen
useradd -m -G wheel,users -s /bin/bash $USERNAME
echo "root:voidlinux" | chpasswd
echo "$USERNAME:voidlinux" | chpasswd

# Sudo rechten alvast aanzetten zodat Ansible direct aan de slag kan
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# Bootloader
grub-install "$DISK"
update-grub
EOF

umount -R /mnt
echo "--- Basisinstallatie voltooid! ---"
echo "1. Reboot"
echo "2. Log in als $USERNAME"
echo "3. Run je post-install.sh"
