#!/bin/bash
# upgrade-debian.sh - Van Bookworm naar Trixie

set -e  # Stop bij fouten

echo "=== Debian 12 → 13 Upgrade Script ==="
echo "Backup maken eerst? (j/n)"
read -r answer
if [ "$answer" = "j" ]; then
    echo "Maak eerst een backup en druk op Enter..."
    read -r
fi

# 1. Huidig systeem bijwerken
echo "Stap 1: Huidig systeem volledig bijwerken..."
sudo apt update && sudo apt full-upgrade -y

# 2. Backup van bronnen
echo "Stap 2: Backup van apt bronnen..."
sudo cp -r /etc/apt/sources.list.d /etc/apt/sources.list.d.backup
sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup

# 3. Vervang bookworm door trixie
echo "Stap 3: Bronnen upgraden naar Trixie..."
sudo sed -i 's/bookworm/trixie/g' /etc/apt/sources.list

# 4. Third-party repos uitschakelen (tijdelijk)
echo "Stap 4: Third-party repos uitschakelen..."
find /etc/apt/sources.list.d -name "*.list" -exec sudo mv {} {}.disabled \; 2>/dev/null || true

# 5. Upgrade
echo "Stap 5: Upgrade naar Debian 13..."
sudo apt update
sudo apt full-upgrade -y

# 6. Opschonen
echo "Stap 6: Opschonen..."
sudo apt autoremove -y

# 7. Configuraties terugzetten
echo "Stap 7: Jouw persoonlijke configuraties..."
tar -xzf ~/debian-settings-backup.tar.gz -C ~/

# 8. Systeem tweaks herstellen
echo "Stap 8: Systeem tweaks (GRUB, Plymouth, etc.)..."
sudo update-grub
sudo plymouth-set-default-theme spinner
sudo update-initramfs -u

echo "=== Upgrade klaar! Herstarten? (j/n) ==="
read -r reboot
if [ "$reboot" = "j" ]; then
    sudo reboot
fi
