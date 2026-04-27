#!/bin/bash

# Kleuren voor leesbaarheid
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}--- Void Linux Grote Schoonmaak & Check ---${NC}"

# 1. Verwijder oude kernels (vkpurge)
# De ISO kernel is na de reboot niet meer nodig.
echo -e "\n${GREEN}1. Oude kernels verwijderen...${NC}"
sudo vkpurge rm all

# 2. Verwijder wees-pakketten (orphans)
# Dit verwijdert pakketten die als afhankelijkheid zijn geïnstalleerd maar niet meer nodig zijn.
echo -e "${GREEN}2. Onnodige afhankelijkheden (orphans) verwijderen...${NC}"
sudo xbps-remove -yo

# 3. Cache opschonen
# Dit verwijdert de gedownloade .xbps bestanden van de enorme update-ronde.
echo -e "${GREEN}3. Pakket-cache opschonen...${NC}"
sudo xbps-remove -yO

# 4. Status Check: zRam
echo -e "\n${BLUE}--- Status Checks ---${NC}"
echo -e "${GREEN}zRam status:${NC}"
if zramctl > /dev/null 2>&1; then
    zramctl
else
    echo "zRam draait niet. Controleer je sv status zram."
fi

# 5. Status Check: Audio (Pipewire)
echo -e "\n${GREEN}Audio status (Pipewire):${NC}"
pactl info | grep "Server Name" || echo "Pipewire lijkt niet actief."

# 6. Status Check: Services
echo -e "\n${GREEN}Actieve Runit services:${NC}"
ls /var/service/

echo -e "\n${BLUE}--- Alles gereed! Je systeem is nu Unix-schoon. ---${NC}"
