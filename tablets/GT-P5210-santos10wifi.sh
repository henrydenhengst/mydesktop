#!/bin/bash

# --- [0] HARDENED BASH & LOGGING ---
set -euo pipefail

# Log alles naar een bestand met tijdstempel
LOGFILE="flash_gt_p5210_$(date +%F_%H-%M-%S).log"
exec > >(tee -a "$LOGFILE") 2>&1

# Expert-tier Traps voor gedetailleerde foutopsporing
trap 'echo ""; echo "!!! SCRIPT ONDERBROKEN !!!"; exit 1' INT
trap 'echo ""; echo "FOUT OP REGEL $LINENO - Script gestopt om schade te voorkomen. Check $LOGFILE"; exit 1' ERR

# --- [1] SUDO ENFORCEMENT ---
if [[ $EUID -ne 0 ]]; then
   echo "FOUT: Dit script MOET als root worden uitgevoerd."
   echo "Gebruik: sudo $0"
   exit 1
fi

echo "--- [1/7] Omgeving & Tools configureren ---"
apt update && apt install -y android-tools-adb heimdall-flash wget file coreutils

# USB Power Management & Permissions (Fix voor Intel handshakes)
echo -1 > /sys/module/usbcore/parameters/autosuspend 2>/dev/null || echo "Autosuspend tweak overgeslagen."
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="04e8", MODE="0666", GROUP="plugdev"' > /etc/udev/rules.d/51-android.rules
udevadm control --reload-rules
udevadm trigger
sleep 2

echo "--- [2/7] Model Verificatie (x86 Architecture) ---"
adb start-server > /dev/null 2>&1
adb wait-for-device

# Robuuste ADB state check
ADB_STATE=$(adb devices | awk '/\t/ {print $2; exit}')

if [[ "$ADB_STATE" != "device" ]]; then
    echo "FOUT: Apparaat gevonden maar status is: $ADB_STATE. Accepteer RSA-popup!"
    exit 1
fi

# Intel Atom specifieke check
MODEL=$(adb shell getprop ro.product.device | tr -d '\r')
if [[ "$MODEL" != santos10wifi* ]] && [[ "$MODEL" != GT-P5210* ]]; then
    echo "FOUT: Model mismatch! Gedetecteerd: $MODEL, Verwacht: santos10wifi."
    exit 1
fi
echo "Geverifieerd model: $MODEL (Intel Atom Z2560)"

echo "--- [3/7] TWRP Download (Intel/x86 compatible) ---"
# Gebruik van de stabiele 3.0.2-0 build voor santos10wifi (veelal de meest betrouwbare voor P5210)
TWRP_FILE="twrp-3.0.2-0-santos10wifi.img"
# Mirror URL (Let op: mocht deze offline zijn, zoek 'nels83 twrp santos10wifi' op XDA)
TWRP_URL="https://androidfilehost.com/api/?w=download&fid=24591000460815255"
EXPECTED_SHA256="4f8f7c9a60e0a514d7a8c3d8d388f8d9b1c7823e20e5d9f0f9b6e8d1c9a0b1c2" # Voorbeeld hash

if [[ ! -f "$TWRP_FILE" ]]; then
    echo "Downloaden van TWRP voor Intel Tab..."
    # Gebruik --user-agent omdat AFH vaak wget blokkeert
    wget -U "Mozilla/5.0" --https-only -O "$TWRP_FILE" "$TWRP_URL"
fi

# Validatie
if ! file "$TWRP_FILE" | grep -qi "data"; then
    echo "FOUT: Gedownload bestand is corrupt (waarschijnlijk een HTML error page)."
    exit 1
fi
echo "TWRP Image gevalideerd."

echo "--- [4/7] Voorbereiding op Download Mode ---"
echo "Waarschuwing: De GT-P5210 is gevoelig voor USB 3.0 poorten. Gebruik liefst USB 2.0."
read -p "Druk op Enter om naar Download Mode te gaan..."

adb reboot download
echo "Wacht op USB handshake..."
sleep 15

if ! timeout 10 heimdall detect > /dev/null 2>&1; then
    echo "FOUT: Heimdall ziet de Intel chip niet. Probeer een andere poort."
    exit 1
fi

echo "--- [5/7] PIT Backup (Kritiek voor Intel Tab) ---"
heimdall download-pit --output device_P5210.pit --no-reboot || echo "PIT backup mislukt, flash op eigen risico."

echo "--- [6/7] Flashen van TWRP Recovery ---"
# Op de P5210 is de recovery partitie vaak exact gedefinieerd. 
# Bij fouten: gebruik 'heimdall print-pit' om partitienaam te checken.
heimdall flash --RECOVERY "$TWRP_FILE" --no-reboot --verbose

echo "--- [7/7] FLASH VOLTOOID ---"
echo "------------------------------------------------------------"
echo "DE KRITIEKE 'INTEL-DANS' (Knoppen-combinatie):"
echo "1. Ontkoppel de kabel."
echo "2. Houd [Power] ingedrukt tot de tablet uit gaat (forceren)."
echo "3. Houd DIRECT daarna [Vol Omhoog] + [Power] vast."
echo "4. Zodra het Samsung-logo verschijnt: LAAT POWER LOS maar houd [Vol Omhoog] vast."
echo "5. In TWRP: MOET je eerst 'Wipe' -> 'Advanced' doen voor System/Data/Cache."
echo "------------------------------------------------------------"
