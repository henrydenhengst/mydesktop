#!/bin/bash

# Zorg ervoor dat het script als root (sudo) wordt uitgevoerd
if [ "$EUID" -ne 0 ]; then
  echo "Voer dit script uit met sudo: sudo ./installeer-ssh.sh"
  exit 1
fi

echo "==> Bezig met bijwerken van pakketlijst..."
apt update

echo "==> Bezig met installeren van OpenSSH server..."
apt install -y openssh-server

echo "==> SSH-service permanent inschakelen en starten..."
systemctl enable --now ssh

echo "==> Klaar! SSH draait en is permanent ingeschakeld."
systemctl status ssh --no-pager
