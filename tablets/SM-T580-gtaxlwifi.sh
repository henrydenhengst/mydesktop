#!/bin/bash

# --- [0] SUDO ENFORCEMENT ---
if [[ $EUID -ne 0 ]]; then
   echo "FOUT: Dit script MOET als root worden uitgevoerd."
   echo "Gebruik: sudo ./flash_tablet.sh"
   exit 1
fi

echo "--- [1/6] Systeem-updates en Tools installeren ---"
apt update && apt install -y android-tools-adb heimdall-flash wget file

# USB Permission Setup & Race Condition fix
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="04e8", MODE="0666", GROUP="plugdev"' > /etc/udev/rules.d/51-android.rules
udevadm control --reload-rules
udevadm trigger
sleep 2

echo "--- [2/6] Belangrijke Pre-checks ---"
echo "LET OP: Nieuwere Samsung firmware kan custom binaries blokkeren."
echo "Indien TWRP niet boot, controleer op 'RMM State' of 'KG State' in Download Mode."
echo ""
echo "Controleer nu op de tablet:"
echo "1. OEM-ontgrendeling -> AAN"
echo "2. USB-foutopsporing -> AAN"
echo "3. Samsung-account -> VERWIJDERD"
echo ""
read -p "Druk op Enter als dit is gecontroleerd..."

# --- [3/6] ADB Autorisatie Check ---
adb start-server > /dev/null 2>&1
ADB_STATE=$(adb devices | awk 'NR==2 {print $2}')

if [[ "$ADB_STATE" == "unauthorized" ]]; then
    echo "FOUT: Tablet niet geautoriseerd. Accepteer de RSA-sleutel popup op de tablet!"
    exit 1
elif [[ "$ADB_STATE" != "device" ]]; then
    echo "FOUT: Geen apparaat gevonden (Status: $ADB_STATE). Check kabel/verbinding."
    exit 1
fi

echo "--- [4/6] TWRP Recovery Download & Validatie ---"
TWRP_FILE="twrp-3.7.0_9-0-gtaxlwifi.img"
TWRP_URL="https://dl.twrp.me/gtaxlwifi/$TWRP_FILE"

if [ ! -f "$TWRP_FILE" ]; then
    wget --referer="https://twrp.me/" -O "$TWRP_FILE" "$TWRP_URL"
fi

# Validatie: is het een echt data/image bestand?
if ! file "$TWRP_FILE" | grep -qi "data"; then
    echo "FOUT: TWRP download is corrupt of geen geldig image bestand."
    rm "$TWRP_FILE"
    exit 1
fi
echo "Download gevalideerd."

echo "--- [5/6] Voorbereiden op Download Mode ---"
adb reboot download
echo "Wacht 15 seconden op initialisatie..."
sleep 15

if ! heimdall detect > /dev/null 2>&1; then
    echo "FOUT: Heimdall detecteert geen apparaat. Probeer een andere poort."
    exit 1
fi

echo "--- [6/6] Flashen van TWRP ---"
# De --no-reboot vlag is essentieel voor de 'Knoppen-dans'
heimdall flash --RECOVERY "$TWRP_FILE" --no-reboot

if [ $? -eq 0 ]; then
    echo ""
    echo "------------------------------------------------------------"
    echo "SUCCESS: TWRP is geflasht!"
    echo "------------------------------------------------------------"
    echo "DE KRITIEKE TIMING (Laat Android NIET booten!):"
    echo "1. Ontkoppel de USB-kabel."
    echo "2. Houd [Vol Omlaag] + [Home] + [Power] ingedrukt om te resetten."
    echo "3. ZODRA het scherm zwart wordt: Wissel DIRECT naar [Vol Omhoog] + [Home] + [Power]."
    echo "4. Houd dit vast tot je het TWRP-menu ziet."
    echo ""
    echo "In TWRP verplicht:"
    echo "-> Wipe -> Format Data -> Type 'yes'"
    echo "-> Daarna pas je ROM (.zip) installeren."
    echo "------------------------------------------------------------"
else
    echo "FOUT: Flashen mislukt. Controleer op RMM/KG Lock op het tabletscherm."
fi
