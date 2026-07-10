#!/bin/bash
#
# Script: setup_retroarch.sh
# Doel: Automatische installatie en configuratie van RetroArch op Linux Mint.
#

# 1. Controleer of het script wordt uitgevoerd op Linux Mint
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" != "linuxmint" ]]; then
        echo "[FOUT] Dit script is uitsluitend bedoeld voor Linux Mint. Huidig systeem: $NAME"
        exit 1
    fi
else
    echo "[FOUT] Kan het besturingssysteem niet detecteren."
    exit 1
fi

# 2. Controleer of de gebruiker root-rechten heeft
if [ "$EUID" -ne 0 ]; then
  echo "[FOUT] Voer dit script uit met sudo."
  exit 1
fi

# 3. Bepaal de juiste gebruiker (vanwege sudo gebruik)
TARGET_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo "~$TARGET_USER")
BASE_DIR="$USER_HOME/Games"
FLATPAK_CONFIG_DIR="$USER_HOME/.var/app/org.libretro.RetroArch/config/retroarch"

echo "--- Start installatie en configuratie RetroArch voor $TARGET_USER ---"

# 4. Installeer Flatpak (indien nodig)
if ! command -v flatpak &> /dev/null; then
    echo "[ACTIE] Flatpak installeren..."
    apt update && apt install -y flatpak
fi

# 5. Voeg Flathub toe
echo "[ACTIE] Flathub repository toevoegen..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# 6. Installeer RetroArch
echo "[ACTIE] RetroArch installeren..."
flatpak install -y flathub org.libretro.RetroArch

# 7. Mappenstructuur aanmaken
echo "[ACTIE] Mappenstructuur aanmaken in $BASE_DIR..."
SYSTEMS=("NES" "SNES" "N64" "GameBoy" "GameBoyColor" "GameBoyAdvance" "DS" "PSP" "PS1" "PS2" "SegaGenesis" "Arcade" "saves" "states")
for sys in "${SYSTEMS[@]}"; do
    mkdir -p "$BASE_DIR/$sys"
done

# 8. Configuratie voorbereiden
echo "[ACTIE] Configuratiebestanden instellen..."
mkdir -p "$FLATPAK_CONFIG_DIR"

cat <<EOF > "$FLATPAK_CONFIG_DIR/retroarch.cfg"
rgui_browser_directory = "$BASE_DIR"
content_directory = "$BASE_DIR"
savefile_directory = "$BASE_DIR/saves"
savestate_directory = "$BASE_DIR/states"
EOF

# 9. Rechten herstellen naar de gebruiker
echo "[ACTIE] Rechten toewijzen aan gebruiker..."
chown -R "$TARGET_USER:$TARGET_USER" "$BASE_DIR"
chown -R "$TARGET_USER:$TARGET_USER" "$USER_HOME/.var/app/org.libretro.RetroArch"

echo "--------------------------------------------------------"
echo "Klaar! RetroArch is geïnstalleerd en geconfigureerd."
echo "Locatie ROMs: $BASE_DIR"
echo "Bij de eerste start zal RetroArch verwijzen naar deze mappen."
echo "--------------------------------------------------------"
