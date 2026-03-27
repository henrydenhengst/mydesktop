#!/bin/bash

# --- Kleuren voor output ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}###############################################${NC}"
echo -e "${BLUE}#  Windows-to-Debian Transformation Starter  #${NC}"
echo -e "${BLUE}###############################################${NC}"

# 1. Update systeem en installeer basisbenodigdheden
echo -e "\n${GREEN}[1/3] Systeem voorbereiden en Ansible installeren...${NC}"
sudo apt update && sudo apt install -y software-properties-common ansible git curl

# 2. Controleren of alle playbooks aanwezig zijn
echo -e "\n${GREEN}[2/3] Playbooks controleren...${NC}"
if [ ! -f "site.yml" ]; then
    echo "Fout: site.yml niet gevonden in de huidige map!"
    exit 1
fi

# 3. Het Master Playbook uitvoeren
echo -e "\n${GREEN}[3/3] Starten van de volledige transformatie...${NC}"
echo "Voer je wachtwoord in voor de systeemwijzigingen:"

# Hiermee start je de hele keten van 15 playbooks
ansible-playbook site.yml -i inventory --ask-become-pass

echo -e "\n${BLUE}###############################################${NC}"
echo -e "${BLUE}#        Transformatie Voltooid!              #${NC}"
echo -e "${BLUE}#     Herstart de laptop voor resultaat.      #${NC}"
echo -e "${BLUE}###############################################${NC}"
