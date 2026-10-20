
#!/usr/bin/env bash
set -Eeuo pipefail

RUSTDESK_URL="https://github.com/rustdesk/rustdesk/releases/download/1.5.0/rustdesk-1.5.0-x86_64.deb"

trap 'echo; echo "[FOUT] Script afgebroken op regel $LINENO."; exit 1' ERR

echo "=================================="
echo "     FreeBoot Support Installer"
echo "=================================="
echo

# Controleer gebruiker
if [[ $EUID -eq 0 ]]; then
    echo "Voer dit script uit als gewone gebruiker."
    echo "Gebruik dus niet sudo bij het starten."
    exit 1
fi

# Controleer distributie
if [[ ! -r /etc/os-release ]]; then
    echo "Kan Linux-distributie niet herkennen."
    exit 1
fi

. /etc/os-release

case "${ID:-}" in
    linuxmint)
        echo "Linux Mint herkend."
        ;;
    zorin)
        echo "Zorin OS herkend."
        ;;
    *)
        echo "Niet ondersteund: ${PRETTY_NAME:-onbekend}"
        echo "Ondersteund: Linux Mint en Zorin OS."
        exit 1
        ;;
esac

# Controleer architectuur
if [[ "$(dpkg --print-architecture)" != "amd64" ]]; then
    echo "Dit RustDesk-pakket vereist amd64."
    exit 1
fi

echo "Systeem: ${PRETTY_NAME}"
echo "Architectuur: amd64"
echo

read -r -p "Tailscale en RustDesk installeren? (j/N): " antwoord
[[ "$antwoord" =~ ^[jJ]$ ]] || exit 0

# Tijdelijke werkmap
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Basisbenodigdheden
echo
echo "=== Basisbenodigdheden installeren ==="
sudo apt-get update
sudo apt-get install -y curl ca-certificates

# Tailscale
echo
echo "=== Tailscale installeren ==="
curl -fsSL https://tailscale.com/install.sh \
    -o "$TMP_DIR/tailscale-install.sh"

sudo sh "$TMP_DIR/tailscale-install.sh"

sudo systemctl enable --now tailscaled

# RustDesk
echo
echo "=== RustDesk downloaden ==="
curl -fL --retry 3 "$RUSTDESK_URL" \
    -o "$TMP_DIR/rustdesk.deb"

echo
echo "=== RustDesk installeren ==="
sudo apt-get install -y "$TMP_DIR/rustdesk.deb"

# Resultaat
echo
echo "=================================="
echo "       Installatie voltooid"
echo "=================================="
echo

if systemctl is-active --quiet tailscaled; then
    echo "[OK] Tailscale-service is actief."
else
    echo "[FOUT] Tailscale-service is niet actief."
    exit 1
fi

if dpkg-query -W -f='${Status}' rustdesk 2>/dev/null \
    | grep -q "install ok installed"; then
    echo "[OK] RustDesk is geïnstalleerd."
else
    echo "[FOUT] RustDesk is niet geïnstalleerd."
    exit 1
fi

echo
echo "=== Tailscale aanmelden ==="
echo "Er verschijnt nu een aanmeldlink."
echo "Open deze in een browser en autoriseer de client."
echo

sudo tailscale up

echo
echo "=== Tailscale-status ==="
tailscale status
echo
echo "Tailscale-IP:"
tailscale ip -4

echo
echo "Start RustDesk via het applicatiemenu."
echo "Controleer samen met de gebruiker de verbindingsgegevens."
echo
echo "FreeBoot Support is klaar."
