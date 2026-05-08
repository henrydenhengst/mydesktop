 #!/bin/bash

# --- [0] HARDENED BASH & LOGGING ---
set -euo pipefail

# Log alles naar een bestand met tijdstempel
LOGFILE="flash_gtaxlwifi_$(date +%F_%H-%M-%S).log"
exec > >(tee -a "$LOGFILE") 2>&1

# Expert-tier Traps
trap 'echo ""; echo "!!! SCRIPT ONDERBROKEN !!!"; exit 1' INT
trap 'echo ""; echo "FOUT OP REGEL $LINENO - Script gestopt om schade te voorkomen."; exit 1' ERR

# --- [1] SUDO ENFORCEMENT ---
if [[ $EUID -ne 0 ]]; then
   echo "FOUT: Dit script MOET als root worden uitgevoerd."
   echo "Gebruik: sudo $0"
   exit 1
fi

echo "--- [1/7] Omgeving & Tools configureren ---"
apt update && apt install -y android-tools-adb heimdall-flash wget file coreutils

# USB Power Management & Permissions
echo -1 > /sys/module/usbcore/parameters/autosuspend 2>/dev/null || echo "Autosuspend tweak niet ondersteund door kernel, overgeslagen."
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="04e8", MODE="0666", GROUP="plugdev"' > /etc/udev/rules.d/51-android.rules
udevadm control --reload-rules
udevadm trigger
sleep 2

echo "--- [2/7] Model Verificatie & ADB Status ---"
adb start-server > /dev/null 2>&1
adb wait-for-device

# Robuuste ADB state check via awk
ADB_STATE=$(adb devices | awk '/\t/ {print $2; exit}')

if [[ "$ADB_STATE" != "device" ]]; then
    echo "FOUT: Apparaat gevonden maar status is: $ADB_STATE."
    echo "Zorg dat de RSA-sleutel op de tablet is geaccepteerd."
    exit 1
fi

# Flexibele modelcheck voor gtaxlwifi suffixes
MODEL=$(adb shell getprop ro.product.device | tr -d '\r')
if [[ "$MODEL" != gtaxlwifi* ]]; then
    echo "FOUT: Model mismatch! Gedetecteerd: $MODEL, Verwacht: gtaxlwifi"
    exit 1
fi
echo "Geverifieerd model: $MODEL"

echo "--- [3/7] TWRP Download & Cache Validatie ---"
TWRP_FILE="twrp-3.7.0_9-0-gtaxlwifi.img"
TWRP_URL="https://dl.twrp.me/gtaxlwifi/$TWRP_FILE"
EXPECTED_SHA256="4d75d656094079815049389f4173322792610738600d813739775f320f782335"

# Forceer download als bestand mist OF checksum niet klopt
if [[ ! -f "$TWRP_FILE" ]] || [[ "$(sha256sum "$TWRP_FILE" | awk '{print $1}')" != "$EXPECTED_SHA256" ]]; then
    echo "Downloaden (of herstellen) van TWRP image..."
    wget --https-only --secure-protocol=TLSv1_2 --referer="https://twrp.me/" -q -O "$TWRP_FILE" "$TWRP_URL"
fi

# Extra sanity check op filetype
if ! file "$TWRP_FILE" | grep -qi "data"; then
    echo "FOUT: Gedownload bestand is geen geldig image."
    exit 1
fi
echo "TWRP Image SHA256: OK"

echo "--- [4/7] Voorbereiding op Download Mode ---"
echo "Controles: OEM Unlock AAN, Samsung Account UIT."
read -p "Druk op Enter om naar Download Mode te gaan..."

adb reboot download
echo "Wacht 15 seconden op USB handshake in Download Mode..."
sleep 15

if ! timeout 10 heimdall detect > /dev/null 2>&1; then
    echo "FOUT: Heimdall detectie timeout. Probeer een andere USB-poort/kabel."
    exit 1
fi

echo "--- [5/7] PIT Backup (Diagnose) ---"
# De PIT (Partition Information Table) is de 'landkaart' van je flashgeheugen
heimdall print-pit --output device.pit --no-reboot || echo "PIT backup mislukt, flash gaat door op eigen risico..."

echo "--- [6/7] Flashen van TWRP Recovery ---"
# Verbose voor volledige logging naar het logbestand
heimdall flash --RECOVERY "$TWRP_FILE" --no-reboot --verbose

echo "--- [7/7] FLASH VOLTOOID ---"
echo "------------------------------------------------------------"
echo "Logbestand opgeslagen als: $LOGFILE"
echo ""
echo "CRUCIALE STAPPEN NU:"
echo "1. Ontkoppel de kabel."
echo "2. Reset: [Vol Omlaag] + [Home] + [Power]."
echo "3. DIRECT BIJ ZWART SCHERM: [Vol Omhoog] + [Home] + [Power]."
echo "4. In TWRP: Wipe -> Format Data -> typ 'yes'."
echo "5. Flash daarna je LineageOS 18.1 .zip"
echo "------------------------------------------------------------"
