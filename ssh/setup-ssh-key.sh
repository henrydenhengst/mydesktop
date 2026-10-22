#!/bin/bash

# ==========================================
# CONFIGURATIE VOOR DIE ÉNE COMPUTER
# ==========================================
USER_NAME="henry"
USER_EMAIL="henrydenhengst@gmail.com"
KEY_PATH="$HOME/.ssh/id_ed25519"

# Vul hier direct het IP-adres van die andere computer in:
TARGET_IP="192.168.192.X"  # <-- Vervang dit door het echte IP-adres!
# ==========================================

echo "==> 1. Controleren of SSH-sleutel bestaat..."
if [ ! -f "$KEY_PATH" ]; then
    echo "Sleutel wordt aangemaakt..."
    ssh-keygen -t ed25519 -C "$USER_EMAIL" -f "$KEY_PATH" -N ""
else
    echo "Sleutel bestaat al."
fi

echo ""
echo "==> 2. Sleutel kopiëren naar $USER_NAME@$TARGET_IP..."
echo "(Voer hierna eenmalig het wachtwoord in van de andere computer)"
echo ""

ssh-copy-id -i "${KEY_PATH}.pub" "$USER_NAME@$TARGET_IP"

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================================"
    echo " Klaar! Je kunt nu zonder wachtwoord inloggen via:"
    echo " ssh $USER_NAME@$TARGET_IP"
    echo "========================================================"
else
    echo ""
    echo "Oeps, er ging iets mis. Controleer het IP-adres of de verbinding."
fi
