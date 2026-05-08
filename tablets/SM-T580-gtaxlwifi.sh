#!/bin/bash

# --- SUDO ENFORCEMENT ---
if [[ $EUID -ne 0 ]]; then
   echo "FOUT: Dit script MOET als root worden uitgevoerd via sudo."
   echo "Gebruik: sudo ./SM-T580-gtaxlwifi.sh"
   exit 1
fi

echo "--- [1/5] Systeem-updates en Tools installeren ---"
apt update && apt install -y android-tools-adb android-tools-fastboot heimdall-flash wget

# Installeer Samsung udev regels voor betere herkenning
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="04e8", MODE="0666", GROUP="plugdev"' > /etc/udev/rules.d/51-android.rules
udevadm control --reload-rules

echo "--- [2/5] Verbinding controleren ---"
echo "Zorg dat de tablet aan staat, verbonden is en USB-foutopsporing aan staat."
adb devices | grep -w "device" > /dev/null
if [ $? -ne 0 ]; then
    echo "FOUT: Geen tablet gevonden via ADB. Controleer de kabel en de melding op het scherm."
    exit 1
fi

echo "--- [3/5] TWRP Recovery Downloaden ---"
# De officiële gtaxlwifi TWRP image
TWRP_FILE="twrp-3.7.0_9-0-gtaxlwifi.img"
if [ ! -f "$TWRP_FILE" ]; then
    wget -O "$TWRP_FILE" "https://eu.dl.twrp.me/gtaxlwifi/twrp-3.7.0_9-0-gtaxlwifi.img"
else
    echo "TWRP bestand reeds aanwezig, download overgeslagen."
fi

echo "--- [4/5] Reboot naar Download Mode (Odin Mode) ---"
echo "De tablet herstart nu naar het blauwe Samsung-scherm..."
adb reboot download
echo "Wacht 15 seconden tot de drivers geladen zijn..."
sleep 15

echo "--- [5/5] Flashen van TWRP met Heimdall ---"
# --no-reboot is essentieel omdat Samsung de recovery overschrijft bij een normale reboot
heimdall flash --RECOVERY "$TWRP_FILE" --no-reboot

if [ $? -eq 0 ]; then
    echo "------------------------------------------------------------"
    echo "FLASH SUCCESVOL!"
    echo "------------------------------------------------------------"
    echo "BELANGRIJK: De tablet staat nu nog in Download Mode."
    echo "1. Trek de kabel eruit."
    echo "2. Houd [Vol Omlaag] + [Home] + [Power] ingedrukt."
    echo "3. ZODRA het scherm zwart wordt (na ~7 sec), laat direct [Vol Omlaag] los"
    echo "   en houd direct [Vol Omhoog] + [Home] + [Power] vast."
    echo "4. Laat de knoppen pas los als je het TWRP logo ziet."
    echo ""
    echo "Als de tablet normaal opstart naar Android, ben je te laat en"
    echo "moet je het script opnieuw draaien (Samsung wist TWRP bij boot)."
    echo "------------------------------------------------------------"
else
    echo "FOUT: Flashen mislukt. Controleer of de tablet in Download Mode staat."
fi
