#!/bin/bash

# SM-T580 (gtaxlwifi) Flash Prep Script voor Linux Mint
# Let op: Voer dit uit met sudo

echo "--- Voorbereiden van de omgeving ---"
apt update
apt install -y android-tools-adb android-tools-fastboot heimdall-flash

echo "--- Controleren van verbinding ---"
adb devices
echo "Bevestig de USB-foutopsporing melding op je tablet indien nodig."

# Download TWRP (Pas de link aan naar de laatste versie indien nodig)
# Voorbeeld voor SM-T580:
TWRP_URL="https://eu.dl.twrp.me/gtaxlwifi/twrp-3.7.0_9-0-gtaxlwifi.img"
echo "--- Downloaden van TWRP Recovery ---"
wget -O recovery.img $TWRP_URL

echo "--- Herstarten naar Download Mode ---"
echo "Zorg dat de tablet is aangesloten!"
adb reboot download

echo "Wacht 10 seconden tot de tablet in Download Mode staat..."
sleep 10

echo "--- Flashen van TWRP met Heimdall ---"
# De SM-T580 gebruikt de RECOVERY partitie
heimdall flash --RECOVERY recovery.img --no-reboot

echo ""
echo "--- KLAAR MET FLASHEN ---"
echo "1. Ontkoppel de tablet."
echo "2. Houd Vol Omlaag + Home + Power ingedrukt om te resetten."
echo "3. ZODRA het scherm zwart wordt, wissel DIRECT naar Vol Omhoog + Home + Power."
echo "4. Je bent nu in TWRP. Volg de handmatige stappen voor de ROM."
