#!/bin/bash

# =====================================================
# DeepSeek Chat Script voor Debian (lokaal met Ollama)
# =====================================================

# Configuratie
MODEL="deepseek-r1:7b"  # Wijzig naar 1.5b, 14b indien gewenst
OLLAMA_HOST="localhost:11434"

# Kleuren voor output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Controleer of Ollama geïnstalleerd is
if ! command -v ollama &> /dev/null; then
    echo -e "${RED}Ollama is niet geïnstalleerd.${NC}"
    echo "Installeer met: curl -fsSL https://ollama.com/install.sh | sh"
    exit 1
fi

# Controleer of Ollama draait
if ! pgrep -x "ollama" > /dev/null; then
    echo -e "${BLUE}Ollama starten...${NC}"
    ollama serve &> /dev/null &
    sleep 3
fi

# Controleer of model beschikbaar is, zo niet downloaden
if ! ollama list | grep -q "$MODEL"; then
    echo -e "${BLUE}Model $MODEL wordt gedownload (eenmalig)...${NC}"
    ollama pull "$MODEL"
fi

# Start de chat
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}DeepSeek Chat (${MODEL})${NC}"
echo -e "${GREEN}Typ 'exit' of 'quit' om te stoppen${NC}"
echo -e "${GREEN}Typ 'clear' om het scherm te wissen${NC}"
echo -e "${GREEN}========================================${NC}"

while true; do
    echo -ne "${BLUE}Jij: ${NC}"
    read -r user_input
    
    case "$user_input" in
        exit|quit)
            echo -e "${GREEN}Tot ziens!${NC}"
            break
            ;;
        clear)
            clear
            continue
            ;;
        "")
            continue
            ;;
    esac
    
    echo -ne "${GREEN}DeepSeek: ${NC}"
    
    # Roep Ollama aan met het model
    ollama run "$MODEL" "$user_input"
    
    echo ""  # Extra nieuwe regel voor leesbaarheid
done