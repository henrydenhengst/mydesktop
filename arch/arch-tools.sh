
#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Arch Linux / CachyOS - systeem- en diagnosegereedschap
#
# Inclusief:
# - Systeem- en procesdiagnose
# - Netwerk- en netwerkdiagnose
# - Terminalgereedschap en tekstbewerking
# - Hardware- en schijfdiagnose
# - Webcam en video4linux
# - NTFS- en exFAT-ondersteuning
# - Smartcard- en kaartlezerondersteuning
#
# Gebruik:
#   ./arch-tools.sh
#   ./arch-tools.sh --dry-run
#   ./arch-tools.sh --no-upgrade
#   ./arch-tools.sh --yes
# ============================================================

readonly SCRIPT_NAME="arch-tools"

DRY_RUN=0
SKIP_UPGRADE=0
ASSUME_YES=0

SKIPPED=()
NOT_INSTALLED=()
INSTALLED=()

log() {
    printf '\n[INFO] %s\n' "$*"
}

warn() {
    printf '\n[WAARSCHUWING] %s\n' "$*" >&2
}

die() {
    printf '\n[FOUT] %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<EOF
Gebruik: $SCRIPT_NAME [opties]

Opties:
  --dry-run       Controleer pakketten zonder iets te wijzigen.
  --no-upgrade    Sla de systeemupdate over.
  -y, --yes       Sla bevestigingsvragen over.
  -h, --help      Toon deze hulp.

Voorbeelden:
  ./$SCRIPT_NAME --dry-run
  ./$SCRIPT_NAME
  ./$SCRIPT_NAME --yes

Let op:
  Arch Linux en CachyOS vereisen zorgvuldig pakketbeheer.
  Vermijd gedeeltelijke systeemupgrades.
EOF
}

# ------------------------------------------------------------
# 1. Argumenten verwerken
# ------------------------------------------------------------

while (($# > 0)); do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            ;;
        --no-upgrade)
            SKIP_UPGRADE=1
            ;;
        -y|--yes)
            ASSUME_YES=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "Onbekende optie: $1 (gebruik --help)"
            ;;
    esac
    shift
done

# ------------------------------------------------------------
# 2. Besturingssysteem controleren
# ------------------------------------------------------------

[[ -r /etc/os-release ]] ||
    die "Kan /etc/os-release niet lezen."

# shellcheck disable=SC1091
source /etc/os-release

id_like=" ${ID_LIKE:-} "

if [[ "${ID:-}" != "arch" &&
      "${ID:-}" != "cachyos" &&
      "$id_like" != *" arch "* &&
      "$id_like" != *" archlinux "* ]]; then
    die "Dit script is bedoeld voor Arch Linux en CachyOS."
fi

command -v pacman >/dev/null 2>&1 ||
    die "Pacman is niet beschikbaar."

printf '%s\n' "================================================"
printf '%s\n' " Arch Linux / CachyOS - tools installeren"
printf '%s\n' "================================================"
printf 'Besturingssysteem: %s\n' "${PRETTY_NAME:-onbekend}"

if ((DRY_RUN)); then
    printf '%s\n' "Modus: DRY-RUN (geen wijzigingen)"
fi

# ------------------------------------------------------------
# 3. Rootrechten of sudo/doas bepalen
# ------------------------------------------------------------

if ((EUID == 0)); then
    SUDO=()
elif command -v sudo >/dev/null 2>&1; then
    SUDO=(sudo)
elif command -v doas >/dev/null 2>&1; then
    SUDO=(doas)
else
    die "Geen sudo of doas gevonden."
fi

PACMAN_CONFIRM=()

if ((ASSUME_YES)); then
    PACMAN_CONFIRM+=(--noconfirm)
fi

if ((!DRY_RUN)) && ((${#SUDO[@]} > 0)); then
    "${SUDO[@]}" -v ||
        die "Authenticatie mislukt."
fi

# ------------------------------------------------------------
# 4. Gewenste pakketten
# ------------------------------------------------------------

readonly -a packages=(
    # Firewall
    ufw

    # Systeem- en procesdiagnose
    htop
    btop
    glances
    nmon
    iotop
    powertop
    lsof
    strace
    lm_sensors

    # Terminalbestandsbeheer
    ranger
    nnn
    mc
    ncdu
    tree
    fzf
    duf

    # Netwerkdiagnose
    nmap
    iperf3
    mtr
    tcpdump
    wireshark-cli
    bmon
    speedtest-cli
    bind-tools
    openbsd-netcat
    socat
    ethtool
    ipcalc

    # Tekstbewerking en zoeken
    vim
    neovim
    bat
    jq
    ripgrep
    fd
    diffutils

    # Hardware en opslag
    smartmontools
    inxi
    pciutils
    usbutils

    # Terminal, bestandsoverdracht en archivering
    tmux
    rsync
    curl
    wget
    util-linux
    zstd

    # Webcam en videoapparatuur
    cheese
    v4l-utils

    # Bestandssystemen
    ntfs-3g
    exfatprogs

    # Smartcard en kaartlezers
    pcsclite
    ccid
    pcsc-tools
    opensc
)

# ------------------------------------------------------------
# 5. Systeem bijwerken
# ------------------------------------------------------------

if ((SKIP_UPGRADE)); then
    warn "Systeemupdate overgeslagen (--no-upgrade)."
    warn "Controleer zelf of het systeem up-to-date is."

elif ((DRY_RUN)); then
    log "DRY-RUN: pacman -Syu zou worden uitgevoerd."

else
    do_upgrade=1

    if ((!ASSUME_YES)); then
        answer=""

        if ! read -r -p \
            "Volledige systeemupdate uitvoeren (pacman -Syu)? [J/n] " answer; then
            die "Geen invoer ontvangen."
        fi

        case "$answer" in
            ""|j|J|ja|Ja|JA|y|Y|yes|Yes|YES)
                do_upgrade=1
                ;;
            n|N|nee|Nee|NEE|no|No|NO)
                do_upgrade=0
                ;;
            *)
                die "Ongeldige keuze: $answer"
                ;;
        esac
    fi

    if ((do_upgrade)); then
        log "Volledige systeemupdate uitvoeren..."

        if ! "${SUDO[@]}" pacman -Syu "${PACMAN_CONFIRM[@]}"; then
            die "Systeemupdate mislukt. Los dit eerst op."
        fi
    else
        die "Systeemupdate geweigerd. Installatie afgebroken om een gedeeltelijke upgrade te vermijden. Gebruik --no-upgrade alleen als je bewust zonder systeemupdate wilt doorgaan."
    fi
fi

# ------------------------------------------------------------
# 6. Pakketbeschikbaarheid controleren
# ------------------------------------------------------------

available=()

log "Beschikbaarheid van pakketten controleren..."

for pkg in "${packages[@]}"; do
    if pacman -Si "$pkg" >/dev/null 2>&1; then
        available+=("$pkg")
    else
        SKIPPED+=("$pkg")
        warn "Niet gevonden in de ingeschakelde repositories: $pkg"
    fi
done

if ((${#available[@]} == 0)); then
    die "Geen beschikbare pakketten gevonden."
fi

# ------------------------------------------------------------
# 7. DRY-RUN: niets installeren
# ------------------------------------------------------------

if ((DRY_RUN)); then
    printf '\nBeschikbare pakketten (%d):\n' "${#available[@]}"
    printf '  %s\n' "${available[@]}"

    if ((${#SKIPPED[@]} > 0)); then
        printf '\nNiet gevonden (%d):\n' "${#SKIPPED[@]}"
        printf '  %s\n' "${SKIPPED[@]}"
    fi

    log "DRY-RUN afgerond. Er zijn geen wijzigingen uitgevoerd."
    exit 0
fi

# ------------------------------------------------------------
# 8. Pakketten installeren
# ------------------------------------------------------------

log "${#available[@]} beschikbare pakketten installeren..."

if "${SUDO[@]}" pacman -S --needed \
    "${PACMAN_CONFIRM[@]}" "${available[@]}"; then
    log "Pacman-installatieopdracht voltooid."
else
    warn "De installatie is mislukt of niet volledig uitgevoerd."
fi

# ------------------------------------------------------------
# 9. Controleren welke pakketten aanwezig zijn
# ------------------------------------------------------------

for pkg in "${available[@]}"; do
    if pacman -Q "$pkg" >/dev/null 2>&1; then
        INSTALLED+=("$pkg")
    else
        NOT_INSTALLED+=("$pkg")
    fi
done

# ------------------------------------------------------------
# 10. Smartcardondersteuning activeren
# ------------------------------------------------------------

if pacman -Q pcsclite >/dev/null 2>&1; then
    log "Smartcardondersteuning configureren..."

    # Arch gebruikt socketactivatie voor pcscd.
    if systemctl list-unit-files pcscd.socket \
        --no-legend 2>/dev/null |
        grep -q 'pcscd\.socket'; then

        if "${SUDO[@]}" systemctl enable --now pcscd.socket; then
            log "pcscd.socket is ingeschakeld en gestart."
        else
            warn "pcscd.socket kon niet worden geactiveerd."
        fi

    # Terugvaloptie voor systemen die een service aanbieden.
    elif systemctl list-unit-files pcscd.service \
        --no-legend 2>/dev/null |
        grep -q 'pcscd\.service'; then

        if "${SUDO[@]}" systemctl enable --now pcscd.service; then
            log "pcscd.service is ingeschakeld en gestart."
        else
            warn "pcscd.service kon niet worden geactiveerd."
        fi
    else
        warn "Geen pcscd.socket of pcscd.service gevonden."
    fi
else
    warn "pcsclite is niet geïnstalleerd; smartcardservice overgeslagen."
fi

# ------------------------------------------------------------
# 11. Resultaat
# ------------------------------------------------------------

printf '\n%s\n' "================================================"
printf '%s\n' " RESULTAAT"
printf '%s\n' "================================================"

printf '\nAanwezige pakketten: %d\n' "${#INSTALLED[@]}"

if ((${#INSTALLED[@]} > 0)); then
    printf '  %s\n' "${INSTALLED[@]}"
fi

if ((${#SKIPPED[@]} > 0)); then
    printf '\nNiet beschikbaar: %d\n' "${#SKIPPED[@]}"
    printf '  %s\n' "${SKIPPED[@]}"
fi

if ((${#NOT_INSTALLED[@]} > 0)); then
    printf '\nNiet geïnstalleerd: %d\n' "${#NOT_INSTALLED[@]}"
    printf '  %s\n' "${NOT_INSTALLED[@]}"
fi

# ------------------------------------------------------------
# 12. Controlecommando's
# ------------------------------------------------------------

printf '\n%s\n' "CONTROLECOMMANDO'S"
printf '%s\n' "------------------------------------------------"
printf '%s\n' "Firewall:"
printf '%s\n' "  sudo ufw status verbose"
printf '%s\n' "Sensoren:"
printf '%s\n' "  sensors"
printf '%s\n' "Schijven:"
printf '%s\n' "  sudo smartctl --scan"
printf '%s\n' "Netwerk:"
printf '%s\n' "  ip -brief address"
printf '%s\n' "  ss -tulpn"
printf '%s\n' "Webcam:"
printf '%s\n' "  v4l2-ctl --list-devices"
printf '%s\n' "Smartcardlezers:"
printf '%s\n' "  opensc-tool --list-readers"
printf '%s\n' "  pcsc_scan"
printf '%s\n' "Bestandssystemen:"
printf '%s\n' "  ntfs-3g --version"
printf '%s\n' "  mkfs.exfat --help"
printf '%s\n' "Pakketdetails:"
printf '%s\n' "  pacman -Qi PAKKETNAAM"

printf '\nUFW is geïnstalleerd, maar niet automatisch ingeschakeld.\n'
printf 'Controleer firewallregels voordat je UFW activeert.\n'

# ------------------------------------------------------------
# 13. Eindstatus
# ------------------------------------------------------------

if ((${#NOT_INSTALLED[@]} > 0)); then
    die "Een of meer pakketten ontbreken na de installatie."
fi

if ((${#SKIPPED[@]} > 0)); then
    warn "Script voltooid, maar niet alle gewenste pakketten waren beschikbaar."
    exit 2
fi

log "Alle beschikbare pakketten zijn gecontroleerd."
log "Installatiescript afgerond."
