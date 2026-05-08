#!/bin/bash

# --- SUDO ENFORCEMENT ---
if [[ $EUID -ne 0 ]]; then
   echo "FOUT: Dit script MOET als root worden uitgevoerd."
   echo "Gebruik: sudo ./flash_tablet.sh"
   exit 1
fi

echo "--- [1/5] Systeem-updates en Tools installeren ---"
# Fastboot verwijderd, alleen noodzakelijke tools
apt update && apt install -y android-tools-adb heimdall-flash wget

# Verbeterde udev configuratie
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="04e8", MODE="0666", GROUP="plugdev"' > /etc/udev/rules.d/51-android.rules
udevadm control --reload-rules
udevadm trigger

echo "--- [2/5] Belangrijke Pre-checks ---"
echo "Controleer op de tablet:"
echo "1. Instellingen -> Ontwikkelaarsopties -> OEM-ontgrendeling AAN"
echo "2. Instellingen -> Ontwikkelaarsopties -> USB-foutopsporing AAN"
echo "3. Samsung-account is VERWIJDERD (ter voorkoming van FRP/KG lock)"
echo ""
read -p "Druk op Enter als dit is gecontroleerd..."

# Betrouwbare ADB check
if ! adb get-state 1>/dev/null 2>&1; then
    echo "FOUT: Geen ADB device gevonden. Hangt de tablet aan de kabel?"
    exit 1
fi

echo "--- [3/5] TWRP Recovery Downloaden ---"
TWRP_FILE="twrp-3.7.0_9-0-gtaxlwifi.img"
TWRP_URL="https://dl.twrp.me/gtaxlwifi/$TWRP_FILE"

if [ ! -f "$TWRP_FILE" ]; then
    # Gebruik --refer om hotlink-blocking te voorkomen indien nodig
    wget --referer="https://twrp.me/" -O "$TWRP_FILE" "$TWRP_URL"
else
    echo "TWRP bestand reeds aanwezig."
fi

echo "--- [4/5] Voorbereiden op Download Mode ---"
echo "De tablet herstart nu naar Download Mode (blauw scherm)."
adb reboot download
echo "Wacht 15 seconden op initialisatie..."
sleep 15

# Heimdall detectie check
if ! heimdall detect > /dev/null 2>&1; then
    echo "FOUT: Heimdall detecteert geen apparaat. Probeer een andere USB-poort."
    exit 1
fi

echo "--- [5/5] Flashen van TWRP ---"
heimdall flash --RECOVERY "$TWRP_FILE" --no-reboot

if [ $? -eq 0 ]; then
    echo "------------------------------------------------------------"
    echo "FLASH SUCCESVOL!"
    echo "------------------------------------------------------------"
    echo "NU CRUCIAAL (De 'Knop-dans'):"
    echo "1. Houd [Vol Omlaag] + [Home] + [Power] vast."
    echo "2. Zodra scherm zwart wordt: DIRECT [Vol Omhoog] + [Home] + [Power]."
    echo "3. Houd vast tot het TWRP logo verschijnt."
    echo ""
    echo "Zodra je in TWRP bent:"
    echo "-> Ga naar 'Wipe' -> 'Format Data' (typ 'yes')."
    echo "-> Dit is verplicht om de encryptie (Verity) te breken!"
    echo "-> Flash daarna pas LineageOS.zip en GApps.zip."
    echo "------------------------------------------------------------"
else
    echo "FOUT: Flashen mislukt."
fi
