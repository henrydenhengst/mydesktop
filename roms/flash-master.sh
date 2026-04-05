#!/bin/bash

# Configuratie
BASE_DIR="$HOME/android"
PLATFORM_TOOLS="$HOME/platform-tools"
export PATH=$PATH:$PLATFORM_TOOLS

# Kleuren voor output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

clear
echo -e "${BLUE}==============================================${NC}"
echo -e "${BLUE}   ANDROID FLASHING DASHBOARD - DEBIAN 2026  ${NC}"
echo -e "${BLUE}==============================================${NC}"

# Stap 1: Kies Leverancier
echo -e "\n${GREEN}Selecteer Leverancier:${NC}"
select VENDOR in google motorola samsung xiaomi fairphone sony nothing asus; do
    if [ -n "$VENDOR" ]; then break; fi
done

# Stap 2: Kies ROM
echo -e "\n${GREEN}Selecteer de ROM die je wilt installeren:${NC}"
select ROM in grapheneos lineageos eos calyxos evolutionx; do
    if [ -n "$ROM" ]; then break; fi
done

WORKING_DIR="$BASE_DIR/$VENDOR/$ROM"
echo -e "\n${BLUE}Werkmap ingesteld op: $WORKING_DIR${NC}"

# Stap 3: Actie Menu
echo -e "\n${GREEN}Wat wil je doen?${NC}"
options=("Check Verbinding" "Backup Toestel (ADB)" "Unlock Bootloader" "Flash Images (Auto)" "Installeer App-pakket" "Lock Bootloader" "Exit")
select opt in "${options[@]}"; do
    case $opt in
        "Check Verbinding")
            echo -e "${BLUE}Zoeken naar apparaten...${NC}"
            adb devices
            fastboot devices
            ;;
        "Backup Toestel (ADB)")
            BACKUP_FILE="$WORKING_DIR/backups/backup_$(date +%F_%T).ab"
            echo -e "${BLUE}Backup wordt gestart naar: $BACKUP_FILE${NC}"
            adb backup -apk -shared -all -f "$BACKUP_FILE"
            ;;
        "Unlock Bootloader")
            echo -e "${RED}WAARSCHUWING: Dit wist alle data!${NC}"
            if [ "$VENDOR" == "google" ] || [ "$VENDOR" == "nothing" ]; then
                fastboot flashing unlock
            else
                echo -e "Voor $VENDOR: volg de instructies in $WORKING_DIR/docs/"
            fi
            ;;
        "Flash Images (Auto)")
            cd "$WORKING_DIR/images" || exit
            if [ "$ROM" == "grapheneos" ] || [ "$ROM" == "calyxos" ]; then
                echo -e "${BLUE}Starten van de vendor-specifieke flasher...${NC}"
                ./flash-all.sh
            else
                echo -e "${BLUE}Flash handmatig met de bestanden in: $(pwd)${NC}"
                ls -lh
            fi
            ;;
        "Installeer App-pakket")
            echo -e "${BLUE}Installeren van APK's uit $BASE_DIR/global/apps/...${NC}"
            for apk in "$BASE_DIR/global/apps"/*.apk; do
                adb install "$apk" && echo "Geïnstalleerd: $apk"
            done
            ;;
        "Lock Bootloader")
            if [ "$ROM" == "grapheneos" ] || [ "$ROM" == "calyxos" ]; then
                fastboot flashing lock
            else
                echo -e "${RED}Let op: Alleen vergrendelen bij ondersteunde ROMs!${NC}"
            fi
            ;;
        "Exit")
            break
            ;;
        *) echo "Ongeldige optie $REPLY";;
    esac
done