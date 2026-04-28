#!/bin/bash
set -e

# --- AUTOMATISCHE CONFIGURATIE ---
# Pakt de grootste schijf die geen USB of loop is
DISK=$(lsblk -dpno NAME,TYPE,SIZE | grep 'disk' | sort -rnk3 | head -n1 | awk '{print $1}')
HOSTNAME="void-bios"
USERNAME="voiduser"

echo "--- START BIOS INSTALLATIE OP $DISK ---"

# Check of DISK gevonden is
if [ -z "$DISK" ]; then echo "Geen schijf gevonden!"; exit 1; fi

# 1. Partitioneren
echo "Partitioneren..."
sfdisk "$DISK" <<EOF
label: dos
device: $DISK
unit: sectors

${DISK}1 : start=2048, type=83, bootable
EOF

# 2. Formatteren & Mounten
mkfs.ext4 -F "${DISK}1"
mount "${DISK}1" /mnt

# 3. Base system + ALLE tools
echo "Installeren van base-system en beheer-tools..."
mkdir -p /mnt/var/db/xbps/keys
cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/

XBPS_ARCH=x86_64 xbps-install -S -r /mnt -R https://repo-default.voidlinux.org/current \
    base-system grub vim git ansible pciutils usbutils sudo xtools dbus ca-certificates

# 4. Configureren (Chroot)
chroot /mnt /bin/bash <<EOF
echo "$HOSTNAME" > /etc/hostname
echo "LANG=en_US.UTF-8" > /etc/locale.conf
useradd -m -G wheel,users -s /bin/bash $USERNAME
echo "root:voidlinux" | chpasswd
echo "$USERNAME:voidlinux" | chpasswd

echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
ln -s /etc/sv/dbus /etc/runit/runsvdir/default/

grub-install "$DISK"
update-grub
EOF

umount -R /mnt
echo "KLAAR! Reboot en start je Ansible playbook."
