#!/bin/bash

# Bestand waar de output naar toe gaat
OUTPUT_FILE="hardware_rapport.txt"

echo "--- Hardware Gezondheidsrapport ---" > $OUTPUT_FILE
echo "Gegenereerd op: $(date)" >> $OUTPUT_FILE
echo "-----------------------------------" >> $OUTPUT_FILE

# 1. Benodigde tools installeren
echo "[1/4] Tools controleren en installeren..."
sudo apt update -y && sudo apt install -y smartmontools inxi upower > /dev/null 2>&1

# 2. Accu status
echo "[2/4] Accu status ophalen..."
echo -e "\n### ACCU STATUS ###" >> $OUTPUT_FILE
# Zoek het batterijpad (meestal BAT0 of BAT1)
BAT_PATH=$(upower -e | grep battery)
upower -i $BAT_PATH >> $OUTPUT_FILE

# 3. Opslag (SSD) gezondheid
echo "[3/4] SSD gezondheid controleren..."
echo -e "\n### SSD GEZONDHEID (SMART) ###" >> $OUTPUT_FILE
# We pakken de eerste schijf /dev/sda of /dev/nvme0n1
DISK=$(lsblk -dpno NAME | head -n1)
sudo smartctl -H $DISK >> $OUTPUT_FILE
echo -e "\nDetails:" >> $OUTPUT_FILE
sudo smartctl -A $DISK | grep -iE 'reallocated|wear|pending' >> $OUTPUT_FILE

# 4. Systeemfouten en ACPI (stroombeheer)
echo "[4/4] Systeemlogs scannen op fouten..."
echo -e "\n### KRITIEKE SYSTEEMFOUTEN (DMESG) ###" >> $OUTPUT_FILE
sudo dmesg | grep -iE 'error|critical|fail|acpi' | tail -n 20 >> $OUTPUT_FILE

# Overzicht van hardware
echo -e "\n### HARDWARE OVERZICHT ###" >> $OUTPUT_FILE
inxi -Fxz >> $OUTPUT_FILE

echo "-----------------------------------" >> $OUTPUT_FILE
echo "Klaar! Het rapport staat in: $OUTPUT_FILE"
