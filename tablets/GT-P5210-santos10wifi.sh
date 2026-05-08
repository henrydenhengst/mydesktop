#!/bin/bash

# --- [0] HARDENED BASH & LOGGING ---
set -euo pipefail
LOGFILE="flash_santos10_final_$(date +%F_%H-%M-%S).log"
exec > >(tee -a "$LOGFILE") 2>&1

trap 'echo ""; echo "!!! FOUT OP REGEL $LINENO - Flash gestopt !!!"; exit 1' ERR
trap 'echo ""; echo "Script onderbroken."; exit 1' INT

# --- [1] SUDO ENFORCEMENT ---
[[ $EUID -ne 0 ]] && { echo "FOUT: Draai dit script met sudo."; exit 1; }

echo "--- [1/8] Omgeving & Tools configureren ---"
apt update && apt install -y android-tools-adb heimdall-flash wget file usbutils coreutils

# Voorbereiding: Kill hangende processen & Reset USB
pkill -9 heimdall 2>/dev/null || true
echo "Reset USB subsystem..."
rmmod usb_storage 2>/dev/null || true
modprobe usb_storage 2>/dev/null || true
udevadm trigger
sleep 2

echo "--- [2/8] Pre-Flash Checklist & Veiligheid ---"
timeout 30 adb wait-for-device || { echo "ADB timeout: device niet gevonden of niet geautoriseerd."; exit 1; }

# Batterij status check
BATTERY=$(adb shell dumpsys battery 2>/dev/null | grep level | awk '{print $2}' | tr -d '\r')
if [[ -n "$BATTERY" ]] && [[ "$BATTERY" -lt 30 ]]; then
    echo "FOUT: Batterij ${BATTERY}% is te laag. Laad op tot minimaal 30%."
    exit 1
fi

# Model & Bootloader Verificatie
MODEL=$(adb shell getprop ro.product.device | tr -d '\r')
[[ "$MODEL" != santos10wifi* ]] && [[ "$MODEL" != GT-P5210* ]] && { echo "FOUT: Model mismatch ($MODEL)!"; exit 1; }

BOOTLOADER=$(adb shell getprop ro.boot.secureboot 2>/dev/null | tr -d '\r')
[[ "$BOOTLOADER" == "1" ]] && { echo "FOUT: Bootloader is LOCKED!"; exit 1; }

# USB 2.0 Poort verificatie
USB2_COUNT=$(lsusb -t | grep -c "speed 480" || echo "0")
[[ "$USB2_COUNT" -eq 0 ]] && echo "WAARSCHUWING: Geen USB 2.0 poort gedetecteerd (Intel Atom is kieskeurig)!"

read -p "Bevestig: TWRP image aanwezig, OEM Unlock AAN & USB 2.0 aangesloten? (j/n): " confirm
[[ "$confirm" != "j" ]] && exit 1

echo "--- [3/8] TWRP Bestand Validatie ---"
TWRP_FILE="twrp-3.0.2-0-santos10wifi.img"

if [[ ! -f "$TWRP_FILE" ]]; then
    echo "FOUT: $TWRP_FILE niet gevonden. Zorg dat het bestand in deze map staat."
    exit 1
fi

# Alleen type check (geen checksum)
if ! file "$TWRP_FILE" | grep -qi "data"; then
    echo "FOUT: $TWRP_FILE lijkt geen geldig image-bestand te zijn."
    exit 1
fi

echo "--- [4/8] Naar Download Mode ---"
adb reboot download
echo "Wacht op de tablet..."
sleep 15

echo "--- [5/8] Partitie Detectie (Heimdall PIT) ---"
PIT_DUMP=$(heimdall print-pit --no-reboot 2>&1)
PARTITION_NAME=$(echo "$PIT_DUMP" | grep -i "recovery" | grep -E "0x[0-9A-F]" | awk '{print $2}' | head -n1)

if [[ -z "$PARTITION_NAME" ]]; then
    echo "FOUT: Recovery partitie niet gevonden in de PIT."
    exit 1
fi
echo "✓ Target partitie op device: $PARTITION_NAME"

echo "--- [6/8] PIT Backup ---"
heimdall download-pit --output P5210_production.pit --no-reboot || echo "PIT backup mislukt, flash gaat door..."

echo "--- [7/8] Flashen van TWRP ---"
heimdall flash --"$PARTITION_NAME" "$TWRP_FILE" --no-reboot --verbose

echo "--- [8/8] VOLTOOID ---"
echo "------------------------------------------------------------"
echo "REBOOT PROCEDURE (NIET NORMAAL OPSTARTEN!):"
echo "1. Houd [POWER] vast tot het scherm zwart wordt."
echo "2. Zodra UIT: Houd DIRECT [VOL OMHOOG] + [POWER] vast."
echo "3. Bij Logo: LAAT POWER LOS, houd [VOL OMHOOG] vast."
echo "4. In TWRP: Maak EERST een backup van EFS en Radio!"
echo "5. Kies daarna pas voor Wipe -> Format Data."
echo "------------------------------------------------------------"
