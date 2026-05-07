#!/bin/bash

# Kleuren voor de output (want het oog wil ook wat)
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}--- Linux Café Haarlem: Logo Processor ---${NC}"

# Functie om te checken en installeren
check_and_install() {
    if ! command -v $1 &> /dev/null; then
        echo -e "Tool '$1' niet gevonden. Installeren..."
        sudo apt update && sudo apt install -y $2
    else
        echo -e "${GREEN}[OK]${NC} $1 is al geïnstalleerd."
    fi
}

# 1. Check dependencies
check_and_install magick imagemagick
check_and_install cwebp webp

# 2. Check of het bronbestand bestaat
if [ ! -f "logo.png" ]; then
    echo "Fout: logo.png niet gevonden in deze map!"
    exit 1
fi

echo -e "${BLUE}Bezig met converteren...${NC}"

# 3. De Favicon (ICO)
magick logo.png -define icon:auto-resize=64,48,32,16 favicon.ico
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ favicon.ico gegenereerd.${NC}"
fi

# 4. Het Webp logo
cwebp -q 80 -m 6 -metadata all logo.png -o logo.webp
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ logo.webp gegenereerd.${NC}"
fi

echo -e "${BLUE}Klaar! Het logo is klaar voor het web.${NC}"
