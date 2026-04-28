#!/bin/bash
# start-install.sh - De automatische schakelaar tussen BIOS en UEFI

# 1. Bepaal waar de scripts staan (de map waarin dit script zelf staat)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "--- Repair Café Boot Mode Detector ---"

# 2. De Check
if [ -d /sys/firmware/efi ]; then
    MODE="UEFI"
    SCRIPT="install-uefi.sh"
else
    MODE="BIOS"
    SCRIPT="install-bios.sh"
fi

echo "Gedetecteerde modus: $MODE"
echo "Gepland script: $SCRIPT"
echo "---------------------------------------"

# 3. Controleer of het script daadwerkelijk bestaat op de stick
if [ ! -f "$SCRIPT_DIR/$SCRIPT" ]; then
    echo "FOUT: $SCRIPT niet gevonden in $SCRIPT_DIR!"
    exit 1
fi

# 4. Bevestiging van de gebruiker (Veiligheid voor alles)
read -p "Wil je de $MODE installatie nu starten op de ingestelde schijf? (y/n) " resp
if [[ ! $resp =~ ^[Yy]$ ]]; then
    echo "Installatie geannuleerd."
    exit 0
fi

# 5. Uitvoeren
echo "Starten van $SCRIPT..."
sudo bash "$SCRIPT_DIR/$SCRIPT"
