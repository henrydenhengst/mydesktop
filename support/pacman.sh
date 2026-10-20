
#!/usr/bin/env bash
set -Eeuo pipefail

RUSTDESK_URL="https://github.com/rustdesk/rustdesk/releases/download/1.5.0/rustdesk-1.5.0-0-x86_64.pkg.tar.zst"
RUSTDESK_SHA256="e920621899aeaa18c6e7e23b2b565615e7dc957dc987494795ca7a94c3108d7d"

trap 'echo; echo "[FOUT] Script gestopt op regel $LINENO."; exit 1' ERR

echo "=================================="
echo "     FreeBoot Support - Arch"
echo "=================================="
echo

if [[ $EUID -eq 0 ]]; then
    echo "Start dit script als gewone gebruiker, zonder sudo."
    exit 1
fi

if [[ ! -r /etc/os-release ]]; then
    echo "Kan distributie niet herkennen."
    exit 1
fi

. /etc/os-release

case "${ID:-}" in
    arch|manjaro)
        echo "Distributie: ${PRETTY_NAME}"
        ;;
    *)
        echo "Dit script is bedoeld voor Arch Linux en Manjaro."
        exit 1
        ;;
esac

if [[ "$(uname -m)" != "x86_64" ]]; then
    echo "Dit script vereist een x86_64-systeem."
    exit 1
fi

echo
read -r -p "Tailscale en RustDesk installeren? (j/N): " antwoord
[[ "$antwoord" =~ ^[jJ]$ ]] || exit 0

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo
echo "=== Systeem bijwerken ==="
sudo pacman -Syu --noconfirm

echo
echo "=== Tailscale installeren ==="
sudo pacman -S --needed --noconfirm tailscale

echo
echo "=== Tailscale-service starten ==="
sudo systemctl enable --now tailscaled

echo
echo "=== RustDesk downloaden ==="
curl -fL --retry 3 "$RUSTDESK_URL" \
    -o "$TMP_DIR/rustdesk.pkg.tar.zst"

echo
echo "=== SHA-256 controleren ==="
echo "$RUSTDESK_SHA256  $TMP_DIR/rustdesk.pkg.tar.zst" \
    | sha256sum -c -

echo
echo "=== RustDesk installeren ==="
sudo pacman -U --noconfirm "$TMP_DIR/rustdesk.pkg.tar.zst"

echo
echo "=== Installatie controleren ==="

if systemctl is-active --quiet tailscaled; then
    echo "[OK] Tailscale-service is actief."
else
    echo "[FOUT] Tailscale-service is niet actief."
    exit 1
fi

if pacman -Q rustdesk >/dev/null 2>&1; then
    echo "[OK] RustDesk is geïnstalleerd."
else
    echo "[FOUT] RustDesk is niet geïnstalleerd."
    exit 1
fi

echo
echo "=== Tailscale aanmelden ==="
echo "De volgende opdracht meldt deze computer aan:"
echo
echo "    sudo tailscale up"
echo
echo "Voer deze opdracht uit om de aanmeldlink te krijgen."
echo
echo "Start RustDesk via het applicatiemenu."
echo
echo "FreeBoot Support-installatie voltooid."
