
#!/usr/bin/env bash
set -Eeuo pipefail

# Arch Linux / CachyOS
# Installatie van systeem-, netwerk- en diagnosegereedschap.

readonly SCRIPT_NAME="arch-tools"

DRY_RUN=0
SKIP_UPGRADE=0
ASSUME_YES=0

SKIPPED=()
NOT_INSTALLED=()
INSTALLED=()

log()  { printf '\n[INFO] %s\n' "$*"; }
warn() { printf '\n[WAARSCHUWING] %s\n' "$*" >&2; }
die()  { printf '\n[FOUT] %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<EOF
Gebruik: $SCRIPT_NAME [opties]

Opties:
  --dry-run       Alleen controleren en tonen; niets installeren.
  --no-upgrade    Sla pacman -Syu over.
  -y, --yes       Bevestig automatisch alle pacman-vragen.
  -h, --help      Toon deze hulp.
EOF
}

while (($# > 0)); do
    case "$1" in
        --dry-run)    DRY_RUN=1 ;;
        --no-upgrade) SKIP_UPGRADE=1 ;;
        -y|--yes)     ASSUME_YES=1 ;;
        -h|--help)    usage; exit 0 ;;
        *)            die "Onbekende optie: $1 (gebruik --help)" ;;
    esac
    shift
done

# 1. Besturingssysteem controleren
[[ -r /etc/os-release ]] ||
    die "/etc/os-release is niet beschikbaar."

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

printf '%s\n' "========================================"
printf '%s\n' " Arch Linux / CachyOS - tools installeren"
printf '%s\n' "========================================"
printf 'Systeem: %s\n' "${PRETTY_NAME:-onbekend}"

if ((DRY_RUN)); then
    printf '%s\n' "Modus: dry-run"
fi

# 2. Rechten controleren
if ((EUID == 0)); then
    SUDO=()
elif command -v sudo >/dev/null 2>&1; then
    SUDO=(sudo)
elif command -v doas >/dev/null 2>&1; then
    SUDO=(doas)
else
    die "Geen sudo of doas gevonden."
fi

# --yes moet ook pacman-bevestigingen overslaan.
PACMAN_CONFIRM=()
if ((ASSUME_YES)); then
    PACMAN_CONFIRM+=(--noconfirm)
fi

if ((!DRY_RUN)) && ((${#SUDO[@]} > 0)); then
    "${SUDO[@]}" -v ||
        die "Authenticatie mislukt."
fi

# 3. Gewenste pakketten
readonly -a packages=(
    ufw

    htop
    btop
    glances
    nmon
    iotop
    powertop
    lsof
    strace
    lm_sensors

    ranger
    nnn
    mc
    ncdu
    tree
    fzf
    duf

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

    vim
    neovim
    bat
    jq
    ripgrep
    fd
    diffutils

    smartmontools
    inxi
    pciutils
    usbutils

    tmux
    rsync
    curl
    wget
    util-linux
    zstd
)

# 4. Systeemupdate
if ((SKIP_UPGRADE)); then
    warn "Systeemupdate overgeslagen."
    warn "Controleer dat je geen gedeeltelijke upgrade veroorzaakt."
elif ((DRY_RUN)); then
    log "Dry-run: systeemupdate zou worden uitgevoerd."
    log "Commando: pacman -Syu"
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
        warn "Systeemupdate overgeslagen."
    fi
fi

# 5. Pakketbeschikbaarheid controleren
available=()

log "Beschikbaarheid van pakketten controleren..."

for pkg in "${packages[@]}"; do
    if pacman -Si "$pkg" >/dev/null 2>&1; then
        available+=("$pkg")
    else
        SKIPPED+=("$pkg")
        warn "Niet gevonden in de huidige pakketdatabases: $pkg"
    fi
done

if ((${#available[@]} == 0)); then
    die "Geen beschikbare pakketten gevonden."
fi

# 6. Dry-run: niets installeren
if ((DRY_RUN)); then
    printf '\nPakketten die beschikbaar lijken (%d):\n' \
        "${#available[@]}"
    printf '  %s\n' "${available[@]}"

    if ((${#SKIPPED[@]} > 0)); then
        printf '\nNiet gevonden (%d):\n' "${#SKIPPED[@]}"
        printf '  %s\n' "${SKIPPED[@]}"
    fi

    log "Dry-run afgerond. Er is niets geïnstalleerd."
    exit 0
fi

# 7. Installeren
log "${#available[@]} beschikbare pakketten verwerken..."

if "${SUDO[@]}" pacman -S --needed \
    "${PACMAN_CONFIRM[@]}" "${available[@]}"; then
    log "Pacman heeft de installatieopdracht voltooid."
else
    warn "De pakketinstallatie is mislukt of onvolledig."
fi

# 8. Werkelijke pakketstatus controleren
for pkg in "${available[@]}"; do
    if pacman -Q "$pkg" >/dev/null 2>&1; then
        INSTALLED+=("$pkg")
    else
        NOT_INSTALLED+=("$pkg")
    fi
done

# 9. Resultaat
printf '\n%s\n' "========================================"
printf '%s\n' " RESULTAAT"
printf '%s\n' "========================================"

printf '\nAanwezig op systeem: %d\n' "${#INSTALLED[@]}"
printf '  %s\n' "${INSTALLED[@]}"

if ((${#SKIPPED[@]} > 0)); then
    printf '\nNiet gevonden in repositories: %d\n' "${#SKIPPED[@]}"
    printf '  %s\n' "${SKIPPED[@]}"
fi

if ((${#NOT_INSTALLED[@]} > 0)); then
    printf '\nNiet geïnstalleerd: %d\n' "${#NOT_INSTALLED[@]}"
    printf '  %s\n' "${NOT_INSTALLED[@]}"
fi

printf '\nAanvullende controles:\n'
printf '  Firewallstatus: sudo ufw status verbose\n'
printf '  Sensors:        sensors\n'
printf '  Schijven:       sudo smartctl --scan\n'
printf '  Pakketdetails:  pacman -Qi PAKKETNAAM\n'
printf '  Netwerkpoorten: ss -tulpn\n'

if ((${#NOT_INSTALLED[@]} > 0)); then
    die "Een of meer beschikbare pakketten ontbreken na afloop."
fi

if ((${#SKIPPED[@]} > 0)); then
    warn "Klaar, maar niet alle gewenste pakketten waren beschikbaar."
    exit 2
fi

log "Installatiescript afgerond."
