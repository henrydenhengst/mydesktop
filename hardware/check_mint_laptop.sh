#!/bin/bash

# Bestand waar de output naar toe gaat
OUTPUT_FILE="hardware_rapport.txt"

echo "--- Uitgebreid Hardware Gezondheidsrapport ---" > $OUTPUT_FILE
echo "Gegenereerd op: $(date)" >> $OUTPUT_FILE
echo "----------------------------------------------" >> $OUTPUT_FILE

# 1. Benodigde tools installeren
echo "[1/5] Tools controleren en installeren..."
sudo apt update -y && sudo apt install -y smartmontools inxi upower > /dev/null 2>&1

# 2. Accu status (Grote accu)
echo "[2/5] Accu status ophalen..."
echo -e "\n### ACCU STATUS (HOOFDACCU) ###" >> $OUTPUT_FILE
BAT_PATH=$(upower -e | grep battery | head -n 1)
if [ -z "$BAT_PATH" ]; then
    echo "Geen accu gevonden." >> $OUTPUT_FILE
else
    upower -i $BAT_PATH >> $OUTPUT_FILE
fi

# 3. CMOS / RTC Check (Indirecte check voor knoopcel)
echo "[3/5] Systeemklok en RTC controleren..."
echo -e "\n### CMOS / INTERNE KLOK ANALYSE ###" >> $OUTPUT_FILE
echo "--- Actuele tijdinstellingen ---" >> $OUTPUT_FILE
timedatectl >> $OUTPUT_FILE

echo -e "\n--- Analyse van tijdsprongen bij opstarten ---" >> $OUTPUT_FILE
# Zoekt naar meldingen waarbij de klok verzet is (indicatie voor lege CMOS batterij)
journalctl -b 0 | grep -i "systemd-timesyncd" | grep "Interval" -A 2 >> $OUTPUT_FILE || echo "Geen grote tijdsprongen gedetecteerd in deze sessie." >> $OUTPUT_FILE

# 4. Opslag (SSD) gezondheid
echo "[4/5] SSD gezondheid controleren..."
echo -e "\n### SSD GEZONDHEID (SMART) ###" >> $OUTPUT_FILE
DISK=$(lsblk -dpno NAME | grep -E '/dev/sda|/dev/nvme0n1' | head -n1)
if [ -z "$DISK" ]; then
    echo "Geen ondersteunde schijf gevonden voor SMART." >> $OUTPUT_FILE
else
    sudo smartctl -H $DISK >> $OUTPUT_FILE
    echo -e "\nKritieke parameters:" >> $OUTPUT_FILE
    sudo smartctl -A $DISK | grep -iE 'reallocated|wear|pending|exhaustion' >> $OUTPUT_FILE
fi

# 5. Systeemfouten en ACPI
echo "[5/5] Systeemlogs scannen op hardwarefouten..."
echo -e "\n### HARDWARE FOUTMELDINGEN (DMESG) ###" >> $OUTPUT_FILE
sudo dmesg | grep -iE 'error|critical|fail|acpi|voltage|low battery|rtc' | tail -n 25 >> $OUTPUT_FILE

# Overzicht van hardware
echo -e "\n### SYSTEEM OVERZICHT ###" >> $OUTPUT_FILE
inxi -Fxz >> $OUTPUT_FILE

echo "----------------------------------------------" >> $OUTPUT_FILE
echo "Klaar! Het rapport staat in: $OUTPUT_FILE"
