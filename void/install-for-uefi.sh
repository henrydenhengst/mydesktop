#!/bin/bash
set -e

# --- AUTOMATISCHE CONFIGURATIE ---
# Zoekt de grootste schijf (disk) en negeert de live-usb/loop devices
DISK=$(lsblk -dpno NAME,TYPE,SIZE | grep 'disk' | sort -rnk3 | head -n1 | awk '{print $1}')

HOSTNAME="void-uefi"
USERNAME="voiduser"

# Check of er een schijf gevonden is
if [ -z "$DISK" ]; then
    echo "FOUT: Geen geschikte harde schijf gevonden!"
    exit 1
fi

# Bepaal de partitie-suffix (leeg voor /dev/sda, 'p' voor /dev/nvme0n1)
if [[ $DISK == *"nvme"* ]] || [[ $DISK == *"mmcblk"* ]]; then 
    P="p"
else 
    P=""
fi

echo "--- START UEFI INSTALLATIE OP $DISK ---"

# 1. Partitioneren (GPT)
echo "Partitioneren van $DISK..."
sfdisk "$DISK" <<EOF
label: gpt
device: $DISK
unit: sectors

${DISK}${P}1 : start=2048, size=2097152, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
${DISK}${P}2 : start=2099200, size=+, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
EOF

# 2. Formatteren & Mounten
echo "Formatteren van partities..."
mkfs.vfat "${DISK}${P}1"
mkfs.ext4 -F "${DISK}${P}2"

mount "${DISK}${P}2" /mnt
mkdir -p /mnt/boot/efi
mount "${DISK}${P}1" /mnt/boot/efi

# 3. Base system + ALLE verzochte tools installeren
echo "Installeren van base-system en beheer-tools..."
mkdir -p /mnt/var/db/xbps/keys
cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/

XBPS_ARCH=x86_64 xbps-install -S -r /mnt -R https://repo-default.voidlinux.org/current \
    base-system grub-x86_64-efi vim git ansible pciutils usbutils sudo xtools dbus ca-certificates

# 4. Fstab & Chroot
echo "Configureren van het systeem..."
echo "${DISK}${P}2 / ext4 defaults 0 1" > /mnt/etc/fstab
echo "${DISK}${P}1 /boot/efi vfat defaults 0 2" >> /mnt/etc/fstab

chroot /mnt /bin/bash <<EOF
echo "$HOSTNAME" > /etc/hostname
echo "LANG=en_US.UTF-8" > /etc/locale.conf
useradd -m -G wheel,users -s /bin/bash $USERNAME
echo "root:voidlinux" | chpasswd
echo "$USERNAME:voidlinux" | chpasswd

# Sudo & Dbus voorbereiding voor Ansible
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
ln -s /etc/sv/dbus /etc/runit/runsvdir/default/

# Bootloader installatie
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="Void"
update-grub
EOF

umount -R /mnt
echo "--- KLAAR! ---"
echo "Je kunt nu rebooten. Vergeet de USB-sticks te verwijderen."
