
#!/usr/bin/env bash
set -Eeuo pipefail

# FreeBoot Support Installer
# Linux Mint, Zorin, Debian, Ubuntu, Pop!_OS,
# Fedora, openSUSE Leap/Tumbleweed, Arch en Manjaro.

RUSTDESK_VERSION="1.5.0"
BASE_URL="https://github.com/rustdesk/rustdesk/releases/download/${RUSTDESK_VERSION}"

fail() {
    echo
    echo "[STOP] $*"
    exit 1
}

trap 'rc=$?; echo; echo "[FOUT] Opdracht mislukt (regel $LINENO, code $rc)."; exit "$rc"' ERR

echo "======================================"
echo "       FreeBoot Support Installer"
echo "======================================"
echo

# 1. Niet als root starten
[[ "$EUID" -ne 0 ]] ||
    fail "Start als gewone gebruiker, zonder sudo."

# 2. Linux-distributie herkennen
[[ -r /etc/os-release ]] ||
    fail "Kan Linux-distributie niet herkennen."

. /etc/os-release

DISTRO="${ID:-unknown}"
ARCH="$(uname -m)"

echo "Systeem: ${PRETTY_NAME:-$DISTRO}"
echo "Architectuur: $ARCH"

[[ "$ARCH" == "x86_64" ]] ||
    fail "Alleen x86_64 wordt ondersteund."

# 3. Pakketbeheerder bepalen
case "$DISTRO" in
    linuxmint|zorin|ubuntu|debian|pop)
        PACKAGE_TYPE="deb"
        ;;
    fedora|rhel|centos|rocky|almalinux)
        PACKAGE_TYPE="rpm"
        ;;
    opensuse-leap|opensuse-tumbleweed|opensuse)
        PACKAGE_TYPE="suse"
        ;;
    arch|manjaro)
        PACKAGE_TYPE="arch"
        ;;
    *)
        case "${ID_LIKE:-}" in
            *debian*|*ubuntu*) PACKAGE_TYPE="deb" ;;
            *suse*)            PACKAGE_TYPE="suse" ;;
            *fedora*|*rhel*)   PACKAGE_TYPE="rpm" ;;
            *arch*)            PACKAGE_TYPE="arch" ;;
            *) fail "Distributie niet ondersteund: $DISTRO" ;;
        esac
        ;;
esac

# 4. RustDesk-pakket kiezen
case "$PACKAGE_TYPE" in
    deb)
        RUSTDESK_FILE="rustdesk-${RUSTDESK_VERSION}-x86_64.deb"
        ;;
    rpm)
        RUSTDESK_FILE="rustdesk-${RUSTDESK_VERSION}-0.x86_64.rpm"
        ;;
    suse)
        RUSTDESK_FILE="rustdesk-${RUSTDESK_VERSION}-0.x86_64-suse.rpm"
        ;;
    arch)
        RUSTDESK_FILE="rustdesk-${RUSTDESK_VERSION}-0-x86_64.pkg.tar.zst"
        ;;
esac

RUSTDESK_URL="${BASE_URL}/${RUSTDESK_FILE}"

echo "Pakketbeheer: $PACKAGE_TYPE"
echo "RustDesk: $RUSTDESK_FILE"
echo

# 5. Systeem controleren
RAM_MB="$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)"
ROOT_MB="$(df -Pm / | awk 'NR==2 {print $4}')"
TMP_MB="$(df -Pm /tmp | awk 'NR==2 {print $4}')"

echo "=== Systeemcontrole ==="
echo "RAM:                  ${RAM_MB} MB (minimum 2048)"
echo "Vrij op systeemschijf: ${ROOT_MB} MB (minimum 2048)"
echo "Vrij in /tmp:          ${TMP_MB} MB (minimum 512)"
echo

(( RAM_MB >= 2048 )) ||
    fail "Minimaal 2 GB RAM vereist."

(( ROOT_MB >= 2048 )) ||
    fail "Minimaal 2 GB vrije ruimte op / vereist."

(( TMP_MB >= 512 )) ||
    fail "Minimaal 512 MB vrije ruimte in /tmp vereist."

command -v systemctl >/dev/null 2>&1 ||
    fail "systemd/systemctl ontbreekt."

command -v sudo >/dev/null 2>&1 ||
    fail "sudo ontbreekt."

# Dit script heeft curl nodig voor de downloads.
# Bij starten via curl | bash is curl al aanwezig.
command -v curl >/dev/null 2>&1 ||
    fail "curl ontbreekt. Installeer curl eerst."

# 6. Internet controleren voordat iets wordt gewijzigd
echo "=== Internet controleren ==="

curl -fsSI --max-time 15 \
    https://github.com/rustdesk/rustdesk/releases/ >/dev/null ||
    fail "GitHub is niet bereikbaar."

curl -fsSI --max-time 15 \
    https://tailscale.com/install.sh >/dev/null ||
    fail "Tailscale-downloadserver is niet bereikbaar."

echo "[OK] Internetverbinding werkt."
echo

read -r -p "Doorgaan met installatie? (j/N): " ANSWER
[[ "$ANSWER" =~ ^[jJ]$ ]] || exit 0

TMP_DIR="$(mktemp -d)"
trap 'rc=$?; rm -rf "$TMP_DIR"; if (( rc != 0 )); then echo "[FOUT] Installatie afgebroken (code $rc)."; fi; exit "$rc"' EXIT

# 7. Benodigdheden installeren
echo
echo "=== Benodigdheden installeren ==="

case "$PACKAGE_TYPE" in
    deb)
        sudo apt-get update
        sudo apt-get install -y curl ca-certificates
        ;;
    rpm)
        if command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y curl ca-certificates
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y curl ca-certificates
        else
            fail "Geen dnf of yum gevonden."
        fi
        ;;
    suse)
        sudo zypper --non-interactive install curl ca-certificates
        ;;
    arch)
        sudo pacman -Syu --needed --noconfirm curl ca-certificates
        ;;
esac

# 8. Tailscale installeren
echo
echo "=== Tailscale installeren ==="

if [[ "$PACKAGE_TYPE" == "arch" ]]; then
    sudo pacman -S --needed --noconfirm tailscale
else
    curl -fsSL https://tailscale.com/install.sh \
        -o "$TMP_DIR/tailscale-install.sh"

    sudo sh "$TMP_DIR/tailscale-install.sh"
fi

sudo systemctl enable --now tailscaled

# 9. RustDesk downloaden
echo
echo "=== RustDesk downloaden ==="

curl -fL --retry 3 --connect-timeout 20 \
    "$RUSTDESK_URL" \
    -o "$TMP_DIR/$RUSTDESK_FILE"

[[ -s "$TMP_DIR/$RUSTDESK_FILE" ]] ||
    fail "RustDesk-download is leeg."

# 10. RustDesk installeren
echo
echo "=== RustDesk installeren ==="

case "$PACKAGE_TYPE" in
    deb)
        sudo apt-get install -y "$TMP_DIR/$RUSTDESK_FILE"
        ;;
    rpm)
        if command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y "$TMP_DIR/$RUSTDESK_FILE"
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y "$TMP_DIR/$RUSTDESK_FILE"
        else
            fail "Geen dnf of yum gevonden."
        fi
        ;;
    suse)
        sudo zypper --non-interactive --no-gpg-checks \
            install "$TMP_DIR/$RUSTDESK_FILE"
        ;;
    arch)
        sudo pacman -U --noconfirm "$TMP_DIR/$RUSTDESK_FILE"
        ;;
esac

# 11. Eindcontrole
echo
echo "=== Eindcontrole ==="

systemctl is-active --quiet tailscaled ||
    fail "Tailscale-service is niet actief."

command -v tailscale >/dev/null 2>&1 ||
    fail "Tailscale-commando ontbreekt."

command -v rustdesk >/dev/null 2>&1 ||
    fail "RustDesk-commando ontbreekt."

echo "[OK] Tailscale is geïnstalleerd en actief."
echo "[OK] RustDesk is geïnstalleerd."
echo
echo "=== Volgende stap ==="
echo "Meld de computer aan bij Tailscale met:"
echo
echo "    sudo tailscale up"
echo
echo "Start RustDesk vanuit het applicatiemenu."
echo "Controleer samen met de gebruiker de verbinding."
echo
echo "FreeBoot Support-installatie voltooid."
