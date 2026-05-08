#!/bin/bash

# --- [0] HARDENED BASH & LOGGING ---
set -euo pipefail
LOGFILE="flash_santos10_final_$(date +%F_%H-%M-%S).log"
exec > >(tee -a "$LOGFILE") 2>&1

trap 'echo ""; echo "!!! FOUT OP REGEL $LINENO - Flash gestopt !!!"; exit 1' ERR
trap 'echo ""; echo "Script onderbroken."; exit 1' INT

# --- [1] SUDO ENFORCEMENT ---
if [[ $EUID -ne 0 ]]; then
   echo "FOUT: Draai dit script met sudo."
   exit 1
fi

echo "--- [1/8] Omgeving & Tools configureren ---"
apt update && apt install -y android-tools-adb heimdall-flash wget file usbutils coreutils

# Reset USB subsystem voor schone handshake (Intel Atom Fix)
echo "Reset USB subsystem..."
rmmod usb_storage 2>/dev/null || true
modprobe usb_storage 2>/dev/null || true
udevadm trigger
sleep 2

echo "--- [2/8] Pre-Flash Checklist & Verificatie ---"
adb start-server > /dev/null 2>&1
adb wait-for-device

# Model check
MODEL=$(adb shell getprop ro.product.device | tr -d '\r')
if [[ "$MODEL" != santos10wifi* ]] && [[ "$MODEL" != GT-P5210* ]]; then
    echo "FOUT: Mismatch! Gedetecteerd: $MODEL. Dit script is alleen voor GT-P5210."
    exit 1
fi

# Bootloader check
BOOTLOADER=$(adb shell getprop ro.boot.secureboot 2>/dev/null | tr -d '\r')
if [[ "$BOOTLOADER" == "1" ]]; then
    echo "FOUT: Bootloader is LOCKED! Flashen onmogelijk."
    exit 1
fi

# USB 2.0 Speed check
USB2_COUNT=$(lsusb -t | grep -c "speed 480" || echo "0")
echo "Gevonden USB 2.0 poorten: $USB2_COUNT"
if [ "$USB2_COUNT" -eq 0 ]; then
    echo "WAARSCHUWING: Geen actieve USB 2.0 poort gedetecteerd. Flash kan falen op USB 3.x!"
fi

read -p "Bevestig: OEM Unlock aan & USB 2.0 aangesloten? (j/n): " confirm
[[ "$confirm" != "j" ]] && exit 1

echo "--- [3/8] TWRP Integriteit ---"
TWRP_FILE="twrp-3.0.2-0-santos10wifi.img"
EXPECTED_SHA="4f8f7c9a60e0a514d7a8c3d8d388f8d9b1c7823e20e5d9f0f9b6e8d1c9a0b1c2"

if [[ ! -f "$TWRP_FILE" ]]; then
    echo "FOUT: $TWRP_FILE niet gevonden. Download deze van XDA (nels83)."
    exit 1
fi

ACTUAL_SHA=$(sha256sum "$TWRP_FILE" | awk '{print $1}')
if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]]; then
    echo "FOUT: Checksum mismatch! Bestand corrupt."
    exit 1
fi

echo "--- [4/8] Naar Download Mode ---"
adb reboot download
echo "Wacht 15 seconden op Odin-interface..."
sleep 15

echo "--- [5/8] Partitie Detectie (Hardened) ---"
PIT_DUMP=$(heimdall print-pit --no-reboot 2>&1 || echo "FAILED")
if [[ "$PIT_DUMP" == *"FAILED"* ]] || [[ "$PIT_DUMP" == *"Failed to access device"* ]]; then
    echo "FOUT: Heimdall kan device niet bereiken. Check kabel."
    exit 1
fi

# De 'Golden Extraction' van de partitienaam
PARTITION_NAME=$(echo "$PIT_DUMP" | grep -i "recovery" | grep -E "0x[0-9A-F]" | awk '{print $2}' | head -n1)

# Fallback mechanisme
if [[ -z "$PARTITION_NAME" ]]; then
    for testname in recovery RECOVERY Recovery; do
        if echo "$PIT_DUMP" | grep -qi "$testname"; then
            PARTITION_NAME="$testname"
            break
        fi
    done
fi

if [[ -z "$PARTITION_NAME" ]]; then
    echo "FOUT: Kan recovery partitie niet identificeren in PIT."
    exit 1
fi
echo "✓ Target partitie: $PARTITION_NAME"

echo "--- [6/8] PIT Backup ---"
heimdall download-pit --output santos10_backup.pit --no-reboot || echo "PIT backup mislukt, flash gaat door..."

echo "--- [7/8] Flashen van Recovery ---"
heimdall flash --"$PARTITION_NAME" "$TWRP_FILE" --no-reboot --verbose

echo "--- [8/8] VOLTOOID ---"
echo "------------------------------------------------------------"
echo "DE INTEL-ATOM REBOOT PROCEDURE:"
echo "1. Houd [POWER] vast tot scherm zwart wordt (~10 sec)."
echo "2. Zodra UIT: Houd [VOL OMHOOG] + [POWER] vast."
echo "3. Bij Samsung Logo: LAAT POWER LOS, houd [VOL OMHOOG] vast."
echo "4. In TWRP: Maak EERST een backup van EFS!"
echo "5. Wipe -> Format Data (NIET alleen advanced wipe)."
echo "------------------------------------------------------------"
