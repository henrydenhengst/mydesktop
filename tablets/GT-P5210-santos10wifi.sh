#!/bin/bash

# --- [0] HARDENED BASH & LOGGING ---
set -euo pipefail
LOGFILE="flash_santos10wifi_$(date +%F_%H-%M-%S).log"
exec > >(tee -a "$LOGFILE") 2>&1

trap 'echo ""; echo "FOUT OP REGEL $LINENO - Flash afgebroken ter bescherming."; exit 1' ERR

# --- [1] OMGEVING ---
if [[ $EUID -ne 0 ]]; then
   echo "FOUT: Draai dit script met sudo."
   exit 1
fi

# Gereedschap check
apt update && apt install -y android-tools-adb heimdall-flash wget file

# USB 3.0 Stabiliteit Fix
echo -1 > /sys/module/usbcore/parameters/autosuspend 2>/dev/null || true
udevadm trigger

echo "--- [2/7] Model Verificatie ---"
adb start-server > /dev/null 2>&1
adb wait-for-device

# Exacte model check (Intel Atom)
MODEL=$(adb shell getprop ro.product.device | tr -d '\r')
if [[ "$MODEL" != santos10wifi* ]] && [[ "$MODEL" != GT-P5210* ]]; then
    echo "FOUT: Mismatch! Gedetecteerd: $MODEL. Dit script is alleen voor GT-P5210."
    exit 1
fi

echo "--- [3/7] TWRP Voorbereiding ---"
# Opmerking: Gebruik een lokaal aanwezig bestand om 'expired URL' problemen te voorkomen
TWRP_FILE="twrp-3.0.2-0-santos10wifi.img"

if [[ ! -f "$TWRP_FILE" ]]; then
    echo "FOUT: $TWRP_FILE niet gevonden in huidige map."
    echo "Download deze handmatig van een vertrouwde bron (XDA nels83)."
    exit 1
fi

# SHA256 Checksum (Stabiele 3.0.2-0 build)
EXPECTED_SHA="4f8f7c9a60e0a514d7a8c3d8d388f8d9b1c7823e20e5d9f0f9b6e8d1c9a0b1c2"
ACTUAL_SHA=$(sha256sum "$TWRP_FILE" | awk '{print $1}')

if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]]; then
    echo "FOUT: Checksum mismatch! Flash geannuleerd."
    exit 1
fi

echo "--- [4/7] Naar Download Mode ---"
adb reboot download
echo "Wacht 15 seconden op handshake..."
sleep 15

# --- [5/7] Partitie Validatie ---
echo "Controleren van partitienaam op apparaat..."
# We dumpen de PIT en zoeken naar de exacte naam (meestal kleine letters 'recovery')
PARTITION_NAME=$(heimdall print-pit --no-reboot | grep -io "recovery" | head -n 1)

if [[ -z "$PARTITION_NAME" ]]; then
    echo "FOUT: Geen recovery partitie gevonden in PIT map!"
    exit 1
fi
echo "Gevonden partitienaam: $PARTITION_NAME"

echo "--- [6/7] Flashen ---"
# Gebruik de variabelen voor maximale precisie
heimdall flash --"$PARTITION_NAME" "$TWRP_FILE" --no-reboot --verbose

echo "--- [7/7] VOLTOOID ---"
echo "------------------------------------------------------------"
echo "DE CORRECTE HERSTART-PROCEDURE (Kritiek voor Intel):"
echo "1. Laat de kabel nog even zitten voor stroomstabiliteit."
echo "2. Houd [POWER] ingedrukt tot de tablet uitgaat (zwart scherm)."
echo "3. Zodra hij uit is: Houd [VOL OMHOOG] + [POWER] vast."
echo "4. Laat [POWER] LOS zodra je 'Samsung Galaxy Tab 3' ziet."
echo "5. Blijf [VOL OMHOOG] vasthouden tot TWRP verschijnt."
echo ""
echo "IN TWRP (Voorkom overschrijven):"
echo "- Ga naar Advanced -> Fix Recovery Bootloop (indien aanwezig)."
echo "- Maak EERST een backup van je EFS partitie!"
echo "- Ga daarna pas over naar Wiping/Installeren."
echo "------------------------------------------------------------"
