#!/bin/bash
#
# Script: iptv.sh
# Doel: Automatische installatie van geselecteerde IPTV-oplossingen op Linux Mint.
# Gebruik: sudo ./iptv.sh
#
# Deze tools zijn geselecteerd op basis van stabiliteit en gebruiksvriendelijkheid:
# 1. Hypnotix: De officiële, native IPTV-speler van Linux Mint.
# 2. Kodi: Uitgebreid mediacenter, ideaal met 'IPTV Simple Client'.
# 3. VLC: De alleskunner voor snelle M3U-afspeellijsten.
# 4. IPTVnator: Moderne interface, uitstekend voor app-gebruikers.
# 5. TVHplayer: Voor koppeling met TVheadend backends.
# 6. termv: Minimalistische terminal-oplossing (fzf + mpv).
#

# --- 1. Systeemanalyse ---
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" != "linuxmint" ]]; then
        echo "[FOUT] Dit script is uitsluitend bedoeld voor Linux Mint."
        exit 1
    fi
else
    echo "[FOUT] Kan het besturingssysteem niet detecteren."
    exit 1
fi

# Controleer root-rechten
if [ "$EUID" -ne 0 ]; then
  echo "[FOUT] Voer dit script uit met sudo."
  exit 1
fi

# --- 2. Menu-interface ---
echo "============================================"
echo "    Linux Café IPTV Installatie Menu"
echo "============================================"
echo "1) Hypnotix (Native, zeer gebruiksvriendelijk)"
echo "2) Kodi (Krachtig mediacenter)"
echo "3) VLC (Universele mediaspeler)"
echo "4) IPTVnator (Modern & Flatpak)"
echo "5) TVHplayer (Voor TVheadend gebruikers)"
echo "6) termv (Terminal, fzf + mpv)"
echo "7) Stoppen"
read -p "Maak je keuze [1-7]: " keuze

# --- 3. Installatielogica ---
case $keuze in
    1)
        echo "[ACTIE] Hypnotix installeren..."
        apt update && apt install -y hypnotix
        ;;
    2)
        echo "[ACTIE] Kodi installeren..."
        apt update && apt install -y kodi
        ;;
    3)
        echo "[ACTIE] VLC installeren..."
        apt update && apt install -y vlc
        ;;
    4)
        echo "[ACTIE] IPTVnator via Flatpak installeren..."
        apt install -y flatpak
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        flatpak install -y flathub io.github.emaxwell.iptvnator
        ;;
    5)
        echo "[ACTIE] TVHplayer installeren..."
        apt update && apt install -y tvhplayer
        ;;
    6)
        echo "[ACTIE] termv voorbereiden (fzf & mpv)..."
        apt update && apt install -y fzf mpv
        echo "Je kunt termv nu downloaden/klonen via GitHub."
        ;;
    7)
        echo "Geannuleerd."
        exit 0
        ;;
    *)
        echo "Ongeldige keuze."
        exit 1
        ;;
esac

echo "--------------------------------------------"
echo "Installatie succesvol afgerond."
echo "--------------------------------------------"
