#!/usr/bin/env bash
#
# Omarchy Plus
# CLI Toolkit + Docker Toolbox
# Omarchy / Arch Linux
# Versie: 3.2.1
#
# Installeert:
#   1. CLI Toolkit          ~50 systeempakketten via omarchy pkg add
#   2. Docker Toolbox        dtool CLI, aliassen, bash-integratie,
#                            systemd drop-in voor automatische cleanup
#
# Gebruik:
#   chmod +x omarchy-plus.sh
#   ./omarchy-plus.sh
#
# Opties:
#   --dry-run       Alleen tonen wat er zou gebeuren; voert geen update uit.
#   --skip-update   Sla de voorafgaande Omarchy-update bewust over.
#   --yes           Sla bevestiging van Omarchy Plus over (Omarchy-update
#                   kan zelf nog om invoer/bevestiging vragen).
#   --skip-cli      Alleen Docker Toolbox.
#   --skip-docker   Alleen CLI Toolkit.
#   --uninstall     Docker Toolbox verwijderen (systeempakketten blijven).
#   --help          Deze hulp.
#
# Veiligheid:
#   - Eerst standaard Omarchy-update (tenzij --skip-update).
#   - Geen losse pacman -Syu; gebruik Omarchy-updateworkflow.
#   - Geen dubbele installatie.
#   - Geen AUR-installatie door dit script.
#   - Geen automatische serviceactivatie.
#   - Geen wijzigingen aan Omarchy-configuraties.
#   - Systeempakketten worden nooit verwijderd.
#   - Docker-images, -volumes en -containers blijven behouden.
#
# ============================================================

set -Eeuo pipefail

VERSION="3.2.1"

# ------------------------------------------------------------
# Configuratie
# ------------------------------------------------------------

STATE_DIR="${HOME}/.local/state/omarchy-plus"

CONFIG_DIR="${HOME}/.config/docker-toolbox"
BACKUP_DIR="${CONFIG_DIR}/backups"
BIN_DIR="${HOME}/.local/bin"
BASHRC="${HOME}/.bashrc"

SCRIPT_PATH="${BIN_DIR}/dtool"
ALIAS_FILE="${CONFIG_DIR}/aliases.sh"

DROPIN_DIR="/etc/systemd/system/docker.service.d"
DROPIN_FILE="${DROPIN_DIR}/docker-toolbox.conf"

OLD_SERVICE="docker-toolbox-cleanup.service"
OLD_SERVICE_FILE="/etc/systemd/system/${OLD_SERVICE}"
OLD_CLEANUP="${CONFIG_DIR}/cleanup.sh"

BEGIN_MARK="# >>> DOCKER_TOOLBOX >>>"
END_MARK="# <<< DOCKER_TOOLBOX <<<"
OLD_BEGIN="# DOCKER_TOOLBOX"
OLD_END="# Einde Docker Toolbox"

LOG_FILE=""
SUDO_KEEPALIVE=""
DOCKER_BIN=""

DRY_RUN=false
ASSUME_YES=false
DO_CLI=true
DO_DOCKER=true
DO_UNINSTALL=false
SKIP_UPDATE=false

umask 077

# ------------------------------------------------------------
# Kleuren (alleen op TTY)
# ------------------------------------------------------------

if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    RESET='\033[0m'
else
    GREEN='' RED='' YELLOW='' BLUE='' RESET=''
fi

# ------------------------------------------------------------
# Logging
# ------------------------------------------------------------

_log_plain() {
    [[ -n "$LOG_FILE" && -d "$(dirname "$LOG_FILE")" ]] || return 0
    printf '%s\n' "$1" >> "$LOG_FILE"
}

info() {
    if [[ -t 1 ]]; then
        echo -e "${BLUE}[INFO]${RESET} $*"
    else
        echo "[INFO] $*"
    fi
    _log_plain "[INFO] $*"
}

success() {
    if [[ -t 1 ]]; then
        echo -e "${GREEN}[OK]${RESET} $*"
    else
        echo "[OK] $*"
    fi
    _log_plain "[OK] $*"
}

warning() {
    if [[ -t 1 ]]; then
        echo -e "${YELLOW}[LET OP]${RESET} $*"
    else
        echo "[LET OP] $*"
    fi
    _log_plain "[LET OP] $*"
}

error() {
    if [[ -t 1 ]]; then
        echo -e "${RED}[FOUT]${RESET} $*" >&2
    else
        echo "[FOUT] $*" >&2
    fi
    _log_plain "[FOUT] $*"
}

# ------------------------------------------------------------
# sudo-keepalive
# ------------------------------------------------------------

stop_sudo_keepalive() {
    if [[ -n "$SUDO_KEEPALIVE" ]]; then
        kill "$SUDO_KEEPALIVE" 2>/dev/null || true
        wait "$SUDO_KEEPALIVE" 2>/dev/null || true
        SUDO_KEEPALIVE=""
    fi
}

start_sudo_keepalive() {
    sudo -v || { error "Geen sudo-rechten."; exit 1; }
    ( while true; do
        sudo -n true 2>/dev/null
        sleep 60
        kill -0 "$$" 2>/dev/null || exit
      done ) &
    SUDO_KEEPALIVE=$!
}

trap stop_sudo_keepalive EXIT
trap 'error "Afgebroken op regel ${LINENO}."' ERR

# ------------------------------------------------------------
# Basis-functies
# ------------------------------------------------------------

require() {
    local cmd
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            error "Vereist commando ontbreekt: $cmd"
            exit 1
        fi
    done
}

confirm() {
    local prompt="$1"

    [[ "$ASSUME_YES" == true ]] && return 0

    if [[ ! -r /dev/tty ]]; then
        error "Geen interactieve terminal beschikbaar. Gebruik --yes om expliciet door te gaan."
        exit 1
    fi

    local answer
    read -r -p "$prompt [j/N] " answer < /dev/tty

    case "$answer" in
        j|J|ja|JA) return 0 ;;
        *)         return 1 ;;
    esac
}

# ------------------------------------------------------------
# Omarchy systeemupdate
# ------------------------------------------------------------

reboot_required() {
    # Distributie-onafhankelijke signalen plus controle van de actieve kernel.
    [[ -e /run/reboot-required || -e /var/run/reboot-required ]] && return 0

    local running_kernel
    running_kernel="$(uname -r)"
    [[ -d "/usr/lib/modules/${running_kernel}" ]] || return 0
    return 1
}

run_omarchy_update() {
    [[ "$DO_UNINSTALL" != true ]] || return 0
    [[ "$SKIP_UPDATE" != true ]] || {
        info "Voorafgaande Omarchy-update bewust overgeslagen (--skip-update)."
        return 0
    }

    if [[ "$DRY_RUN" == true ]]; then
        info "DRY-RUN: zou eerst 'omarchy update' uitvoeren."
        return 0
    fi

    echo
    warning "Eerst wordt Omarchy bijgewerkt via de officiële updateworkflow."
    info "De update kan systeem- en Omarchy-componenten bijwerken."
    info "Er wordt geen losse pacman -Syu uitgevoerd."
    echo

    confirm "Nu 'omarchy update' uitvoeren?" || {
        warning "Update en installatie geannuleerd."
        exit 0
    }

    info "Omarchy-update gestart..."
    if ! omarchy update; then
        error "Omarchy-update is mislukt. Omarchy Plus wordt niet geïnstalleerd."
        return 1
    fi

    success "Omarchy-update is succesvol afgerond."
    if reboot_required; then
        warning "Een herstart lijkt noodzakelijk na de update."
        error "Herstart Omarchy en voer daarna Omarchy Plus opnieuw uit."
        return 2
    fi
    return 0
}

backup() {
    local file="$1"
    local name
    local destination

    [[ -e "$file" || -L "$file" ]] || return 0
    [[ ! -L "$file" ]] || { error "Back-up geweigerd: symbolische link: $file"; return 1; }
    [[ -f "$file" ]] || { error "Back-up geweigerd: geen regulier bestand: $file"; return 1; }

    [[ ! -L "$CONFIG_DIR" && ! -L "$BACKUP_DIR" ]] || {
        error "Back-upmap is een symbolische link; handmatige controle nodig."
        return 1
    }
    mkdir -p "$BACKUP_DIR" || return 1
    name="$(basename "$file")"
    destination="${BACKUP_DIR}/${name}.$(date +%Y%m%d-%H%M%S).$$"

    cp -- "$file" "$destination" || return 1
    chmod 600 "$destination" || return 1

    info "Back-up gemaakt: $destination"
}

backup_system_file() {
    local file="$1"
    local name
    local destination

    sudo test -e "$file" || return 0
    sudo test ! -L "$file" || { error "Systeemback-up geweigerd: symbolische link: $file"; return 1; }
    sudo test -f "$file" || { error "Systeemback-up geweigerd: geen regulier bestand: $file"; return 1; }

    [[ ! -L "$CONFIG_DIR" && ! -L "$BACKUP_DIR" ]] || {
        error "Back-upmap is een symbolische link; handmatige controle nodig."
        return 1
    }
    mkdir -p "$BACKUP_DIR" || return 1
    name="$(basename "$file")"
    destination="${BACKUP_DIR}/${name}.$(date +%Y%m%d-%H%M%S).$$"

    sudo cp -- "$file" "$destination" || return 1
    sudo chown "$(id -u):$(id -g)" "$destination" || return 1
    chmod 600 "$destination" || return 1

    info "Systeemback-up gemaakt: $destination"
}

# ------------------------------------------------------------
# Bash-blokken
# ------------------------------------------------------------

validate_block() {
    local begin="$1"
    local end="$2"
    local count_begin
    local count_end

    [[ -f "$BASHRC" ]] || return 0

    count_begin="$(grep -Fxc -- "$begin" "$BASHRC" || true)"
    count_end="$(grep -Fxc -- "$end" "$BASHRC" || true)"

    if [[ "$count_begin" -eq 0 && "$count_end" -eq 0 ]]; then
        return 0
    fi

    if [[ "$count_begin" -ne 1 || "$count_end" -ne 1 ]]; then
        warning "Onvolledig of dubbel Bash-blok: $begin"
        return 1
    fi

    awk -v b="$begin" -v e="$end" '
        $0 == b {
            if (state != 0) bad=1
            state=1
            next
        }
        $0 == e {
            if (state != 1) bad=1
            state=2
            next
        }
        END {
            if (bad || state == 1) exit 1
            if (state == 0 || state == 2) exit 0
        }
    ' "$BASHRC"
}

validate_bashrc() {
    if [[ -L "$BASHRC" ]]; then
        error "~/.bashrc is een symbolische link."
        error "Pas deze eerst handmatig aan of gebruik een normaal bestand."
        return 1
    fi

    validate_block "$OLD_BEGIN" "$OLD_END" || return 1
    validate_block "$BEGIN_MARK" "$END_MARK" || return 1

    return 0
}

remove_block() {
    local begin="$1"
    local end="$2"
    local temp

    [[ -f "$BASHRC" ]] || return 0

    validate_block "$begin" "$end" || {
        warning "Bash-blok niet gewijzigd: $begin"
        return 1
    }

    if ! grep -Fqx -- "$begin" "$BASHRC"; then
        return 0
    fi

    temp="$(mktemp "${BASHRC}.XXXXXX")"

    if ! awk -v b="$begin" -v e="$end" '
        $0 == b { inside=1; next }
        $0 == e && inside { inside=0; next }
        !inside { print }
    ' "$BASHRC" > "$temp"; then
        rm -f "$temp"
        warning "Bash-blok kon niet worden verwerkt."
        return 1
    fi

    chmod --reference="$BASHRC" "$temp" || { rm -f "$temp"; return 1; }
    chown --reference="$BASHRC" "$temp" || { rm -f "$temp"; return 1; }

    if ! mv -f -- "$temp" "$BASHRC"; then
        rm -f "$temp"
        warning "Bashrc kon niet veilig worden vervangen."
        return 1
    fi

    success "Bash-blok verwijderd: $begin"
}

# ------------------------------------------------------------
# Oude versie 1.x opruimen
# ------------------------------------------------------------

remove_old_service() {
    sudo test ! -L "$OLD_SERVICE_FILE" || {
        error "Oude cleanup-service is een symbolische link; handmatige controle nodig."
        return 1
    }
    if sudo test -f "$OLD_SERVICE_FILE"; then
        if sudo systemctl is-active --quiet "$OLD_SERVICE"; then
            sudo systemctl stop "$OLD_SERVICE" || {
                error "Oude cleanup-service kon niet worden gestopt."
                return 1
            }
        fi
        sudo systemctl disable "$OLD_SERVICE" >/dev/null 2>&1 || {
            warning "Oude service was mogelijk niet ingeschakeld; ga door met verwijderen."
        }
        sudo rm -f "$OLD_SERVICE_FILE" || return 1
        sudo systemctl daemon-reload || return 1
        success "Oude cleanup-service verwijderd."
    fi

    if [[ -e "$OLD_CLEANUP" || -L "$OLD_CLEANUP" ]]; then
        [[ ! -L "$OLD_CLEANUP" ]] || { error "Oude cleanup.sh is een symbolische link; handmatige controle nodig."; return 1; }
        backup "$OLD_CLEANUP" || return 1
        rm -f -- "$OLD_CLEANUP" || return 1
    fi
}

# ------------------------------------------------------------
# CLI Toolkit — inventarisatie
# ------------------------------------------------------------

PACKAGES=$(cat <<'EOF'
Shell|atuin|atuin
Shell|direnv|direnv

Systeembeheer|htop|htop
Systeembeheer|lsof|lsof
Systeembeheer|strace|strace
Systeembeheer|sysstat|iostat
Systeembeheer|ncdu|ncdu
Systeembeheer|dust|dust
Systeembeheer|duf|duf
Systeembeheer|smartmontools|smartctl
Systeembeheer|lm_sensors|sensors
Systeembeheer|pciutils|lspci
Systeembeheer|usbutils|lsusb
Systeembeheer|ethtool|ethtool

Netwerk|bind|dig
Netwerk|traceroute|traceroute
Netwerk|mtr|mtr
Netwerk|nmap|nmap
Netwerk|tcpdump|tcpdump
Netwerk|wireshark-cli|tshark
Netwerk|iperf3|iperf3
Netwerk|httpie|http
Netwerk|openssl|openssl

Ontwikkeling|shellcheck|shellcheck
Ontwikkeling|shfmt|shfmt
Ontwikkeling|git-delta|delta
Ontwikkeling|make|make

Automatisering|ansible|ansible
Automatisering|ansible-lint|ansible-lint
Automatisering|terraform|terraform
Automatisering|trivy|trivy
Automatisering|hadolint|hadolint
Automatisering|restic|restic
Automatisering|rclone|rclone
Automatisering|rsync|rsync

Beveiliging|lynis|lynis
Beveiliging|chkrootkit|chkrootkit
Beveiliging|rkhunter|rkhunter
Beveiliging|gnupg|gpg
Beveiliging|age|age
Beveiliging|fail2ban|fail2ban-client
Beveiliging|audit|auditctl
Beveiliging|clamav|clamscan

Documentatie|pandoc|pandoc
Documentatie|glow|glow
Documentatie|graphviz|dot
Documentatie|lynx|lynx
Documentatie|w3m|w3m
Documentatie|translate-shell|trans
EOF
)

declare -a INSTALL_LIST=()
declare -a SKIP_LIST=()

is_installed() {
    local package="$1"
    local cmd="$2"

    # Alleen de pakketdatabase is leidend; een gelijknamig commando uit
    # een ander pakket mag dit pakket niet als geinstalleerd markeren.
    pacman -Qq "$package" >/dev/null 2>&1
}

has_conflict() {
    local package="$1"
    local metadata
    local conflicts
    local conflict

    metadata=$(LC_ALL=C pacman -Si "$package" 2>/dev/null) || return 1
    conflicts=$(awk -F ': ' '/^Conflicts With/ {print $2}' <<< "$metadata")

    [[ -z "$conflicts" || "$conflicts" == "None" ]] && return 1

    for conflict in $conflicts; do
        conflict="${conflict%%[<>=]*}"
        if pacman -Qq "$conflict" >/dev/null 2>&1; then
            warning "$package conflicteert met geïnstalleerd pakket $conflict"
            return 0
        fi
    done

    return 1
}

inventory_cli() {
    INSTALL_LIST=()
    SKIP_LIST=()

    info "CLI Toolkit: inventarisatie..."

    local category package cmd
    while IFS='|' read -r category package cmd; do
        [[ -z "$package" ]] && continue

        if is_installed "$package" "$cmd"; then
            SKIP_LIST+=("$package (reeds aanwezig)")
            continue
        fi

        if ! pacman -Si "$package" >/dev/null 2>&1; then
            SKIP_LIST+=("$package (niet beschikbaar in repositories)")
            continue
        fi

        if has_conflict "$package"; then
            SKIP_LIST+=("$package (pakketconflict)")
            continue
        fi

        INSTALL_LIST+=("$category|$package|$cmd")
    done <<< "$PACKAGES"
}

show_cli_overview() {
    echo
    echo "=============================================="
    echo " OMARCHY CLI TOOLKIT"
    echo "=============================================="
    echo "Te installeren: ${#INSTALL_LIST[@]}"
    echo "Overgeslagen:   ${#SKIP_LIST[@]}"
    echo

    local entry category package cmd
    for entry in "${INSTALL_LIST[@]}"; do
        IFS='|' read -r category package cmd <<< "$entry"
        printf "  [+] %-18s %s\n" "$category" "$package"
    done

    if [[ ${#SKIP_LIST[@]} -gt 0 ]]; then
        echo
        echo " OVERGESLAGEN"
        echo "=============================================="
        for entry in "${SKIP_LIST[@]}"; do
            printf "  [-] %s\n" "$entry"
        done
    fi

    echo
    echo "=============================================="
}

install_cli_packages() {
    if [[ ${#INSTALL_LIST[@]} -eq 0 ]]; then
        success "Alle CLI-gereedschappen zijn al aanwezig."
        return 0
    fi

    info "CLI-installatie gestart als één pakkettransactie..."

    local entry category package cmd
    local -a packages=()
    for entry in "${INSTALL_LIST[@]}"; do
        IFS='|' read -r category package cmd <<< "$entry"
        packages+=("$package")
    done

    # omarchy pkg add geeft de pakketnamen door aan de Omarchy-pakketworkflow.
    # Eén aanroep voorkomt tientallen afzonderlijke pakkettransacties.
    if ! omarchy pkg add "${packages[@]}" >> "$LOG_FILE" 2>&1; then
        error "De gezamenlijke CLI-pakketinstallatie is mislukt. Zie het logbestand."
        return 1
    fi

    local -a failed=()
    for package in "${packages[@]}"; do
        if pacman -Qq "$package" >/dev/null 2>&1; then
            success "$package gecontroleerd."
        else
            failed+=("$package")
        fi
    done

    if [[ ${#failed[@]} -gt 0 ]]; then
        warning "Niet teruggevonden na installatie:"
        printf '  - %s\n' "${failed[@]}"
        return 1
    fi

    success "Alle CLI-pakketten zijn geïnstalleerd en gecontroleerd."
    return 0
}

# ------------------------------------------------------------
# Docker Toolbox — dtool CLI
# ------------------------------------------------------------

install_dtool() {
    local temp
    [[ ! -L "$SCRIPT_PATH" ]] || { error "Weiger dtool te overschrijven: symbolische link."; return 1; }
    backup "$SCRIPT_PATH" || return 1
    temp="$(mktemp "${BIN_DIR}/.dtool.XXXXXX")" || return 1
    trap 'rm -f -- "$temp"' RETURN

    cat > "$temp" <<'DTOOL'
#!/usr/bin/env bash

set -Eeuo pipefail

LABEL="docker-toolbox.temporary=true"
TRIVY_IMAGE="aquasec/trivy:0.76.2"

DOCKER=(docker)

TTY=(-i)

if [[ -t 0 && -t 1 ]]; then
    TTY=(-it)
fi

usage() {
    cat <<'EOF'
Docker Toolbox

WEBTOOLS
  dtool pdf           Stirling PDF       localhost:8080
  dtool ittools       IT-Tools           localhost:8081
  dtool metube        MeTube             localhost:8082
  dtool draw          Excalidraw         localhost:8083
  dtool cyberchef     CyberChef          localhost:8084
  dtool convert       ConvertX           localhost:8085
  dtool translate     LibreTranslate     localhost:8086

SHELLS
  dtool debian        Debian Trixie
  dtool alpine        Alpine
  dtool ubuntu        Ubuntu
  dtool python        Python
  dtool node          Node.js
  dtool network       Netwerkdiagnose

ONTWIKKELING
  dtool trivy         Scan huidige map
  dtool hadolint      Controleer Dockerfile
  dtool pandoc        Markdown naar PDF
  dtool postgres      Tijdelijke PostgreSQL
  dtool redis         Tijdelijke Redis

BEHEER
  dtool images        Docker-images
  dtool containers    Toolbox-containers
  dtool cleanup       Gestopte Toolbox-containers opruimen
  dtool help          Deze hulp

VOORBEELDEN
  dtool python script.py
  dtool node script.js
  dtool pandoc document.md
  DTOOL_PORT=9000 dtool pdf

LET OP
  Debian, Alpine en Ubuntu draaien als root.
  Bestanden die je daar in /werk schrijft, worden op de
  host eigendom van root.

  Python en Node draaien als je eigen UID/GID.
  De volledige thuismap wordt nooit automatisch gekoppeld.

  Stirling PDF-configuratie, ConvertX- en LibreTranslate-gegevens
  blijven behouden. Verwerkte PDF-bestanden zijn tijdelijk.
  MeTube-downloads worden bewaard in ~/Downloads.
  Trivy bewaart zijn cache in een Docker-volume.

  Webtools stoppen met Ctrl+C.
  Shells stoppen met exit.
EOF
}

die() {
    echo "[FOUT] $*" >&2
    exit 1
}

check_port() {
    local port="$1"

    [[ "$port" =~ ^[1-9][0-9]{0,4}$ ]] ||
        die "Ongeldig poortnummer: $port"

    (( port >= 1 && port <= 65535 )) ||
        die "Poort moet tussen 1 en 65535 liggen: $port"
}

is_restricted_dir() {
    local current
    local home

    current="$(pwd -P)"
    home="$(cd "$HOME" && pwd -P)"

    [[ "$current" == "/" || "$current" == "$home" ]]
}

WORK=()

workdir() {
    local first_arg="${1:-}"

    WORK=()

    if is_restricted_dir; then
        if [[ -n "$first_arg" && -f "$first_arg" ]]; then
            die "Je staat in / of je thuismap.
Ga naar een projectsubmap voordat je een script uitvoert.
De volledige thuismap wordt niet gekoppeld."
        fi
        return 0
    fi

    if [[ -n "$first_arg" && -f "$first_arg" ]]; then
        local resolved
        resolved="$(realpath -- "$first_arg")"
        if [[ "$resolved" != "$(pwd -P)"/* ]]; then
            die "Bestand valt buiten de huidige map: $first_arg
Start dtool vanuit de map die het bestand bevat."
        fi
    fi

    WORK=(-v "$(pwd -P):/werk" -w /werk)
}

check_scan_directory() {
    if is_restricted_dir; then
        die "Scan vanuit een projectsubmap.
De volledige thuismap en / worden niet automatisch gescand."
    fi
}

check_docker() {
    local output

    if output="$(docker info 2>&1)"; then
        return 0
    fi

    if grep -qi "permission denied" <<<"$output"; then
        sudo -v || die "Geen sudo-rechten."
        DOCKER=(sudo docker)

        sudo docker info >/dev/null 2>&1 ||
            die "Docker-daemon is niet bereikbaar."

        return 0
    fi

    die "Docker is niet bereikbaar.
Probeer: sudo systemctl start docker"
}

temporary() {
    check_docker

    "${DOCKER[@]}" run \
        --rm \
        --label "$LABEL" \
        "$@"
}

web() {
    local port="${DTOOL_PORT:-$1}"
    local inner="$2"

    check_port "$port"

    shift 2

    echo
    echo "Open: http://localhost:${port}"
    echo "Stoppen: Ctrl+C"
    echo

    temporary \
        "${TTY[@]}" \
        -p "127.0.0.1:${port}:${inner}" \
        --security-opt=no-new-privileges \
        "$@"
}

cmd="${1:-help}"

if [[ $# -gt 0 ]]; then
    shift
fi

case "$cmd" in

    pdf)
        web 8080 8080 \
            -e SECURITY_ENABLELOGIN=false \
            -v stirling-config:/configs \
            stirlingtools/stirling-pdf
        ;;

    ittools)
        web 8081 80 \
            corentinth/it-tools
        ;;

    metube)
        mkdir -p "$HOME/Downloads"

        web 8082 8081 \
            -e "PUID=$(id -u)" \
            -e "PGID=$(id -g)" \
            -e CHOWN_DIRS=false \
            -v "$HOME/Downloads:/downloads" \
            ghcr.io/alexta69/metube
        ;;

    draw)
        web 8083 80 \
            excalidraw/excalidraw
        ;;

    cyberchef)
        web 8084 8080 \
            ghcr.io/gchq/cyberchef
        ;;

    convert)
        web 8085 3000 \
            -e ALLOW_UNAUTHENTICATED=true \
            -e HTTP_ALLOWED=true \
            -v convertx-data:/app/data \
            ghcr.io/c4illin/convertx
        ;;

    translate)
        web 8086 5000 \
            -v libretranslate-data:/home/libretranslate/.local \
            libretranslate/libretranslate
        ;;

    network)
        temporary "${TTY[@]}" \
            --init \
            --network host \
            nicolaka/netshoot
        ;;

    debian)
        workdir
        temporary "${TTY[@]}" \
            --init \
            "${WORK[@]}" \
            debian:trixie-slim bash
        ;;

    alpine)
        workdir
        temporary "${TTY[@]}" \
            --init \
            "${WORK[@]}" \
            alpine sh
        ;;

    ubuntu)
        workdir
        temporary "${TTY[@]}" \
            --init \
            "${WORK[@]}" \
            ubuntu:latest bash
        ;;

    python)
        workdir "$@"
        temporary "${TTY[@]}" \
            --init \
            "${WORK[@]}" \
            --user "$(id -u):$(id -g)" \
            -e HOME=/tmp \
            python:3-alpine python "$@"
        ;;

    node)
        workdir "$@"
        temporary "${TTY[@]}" \
            --init \
            "${WORK[@]}" \
            --user "$(id -u):$(id -g)" \
            -e HOME=/tmp \
            node:alpine node "$@"
        ;;

    trivy)
        check_scan_directory

        temporary \
            --security-opt=no-new-privileges \
            -v "$(pwd -P):/work:ro" \
            -v trivy-cache:/root/.cache/trivy \
            "$TRIVY_IMAGE" fs /work
        ;;

    hadolint)
        file="${1:-Dockerfile}"

        [[ -f "$file" ]] ||
            die "Bestand niet gevonden: $file"

        check_docker

        if [[ "${DOCKER[0]}" == "sudo" ]]; then
            sudo -v || die "Geen sudo-rechten."
        fi

        temporary -i \
            --security-opt=no-new-privileges \
            hadolint/hadolint < "$file"
        ;;

    pandoc)
        [[ $# -eq 1 ]] ||
            die "Gebruik: dtool pandoc bestand.md"

        [[ -f "$1" ]] ||
            die "Bestand niet gevonden: $1"

        lower="${1,,}"

        [[ "$lower" == *.md || "$lower" == *.markdown ]] ||
            die "Alleen .md of .markdown."

        dir="$(cd -- "$(dirname -- "$1")" && pwd -P)"
        name="$(basename -- "$1")"
        home_dir="$(cd "$HOME" && pwd -P)"

        if [[ "$dir" == "/" || "$dir" == "$home_dir" ]]; then
            die "Pandoc koppelt niet automatisch / of je volledige thuismap.
Verplaats het document naar een projectsubmap."
        fi

        temporary \
            --security-opt=no-new-privileges \
            --user "$(id -u):$(id -g)" \
            -v "$dir:/data" \
            -w /data \
            pandoc/typst \
            "$name" \
            -o "${name%.*}.pdf" \
            --pdf-engine=typst

        echo "PDF gemaakt: ${dir}/${name%.*}.pdf"
        ;;

    postgres)
        port="${DTOOL_PORT:-5432}"
        check_port "$port"

        echo
        echo "Tijdelijke PostgreSQL"
        echo "Adres: 127.0.0.1:${port}"
        echo "Gebruiker: postgres"
        echo "Wachtwoord: test-only-change-me"
        echo "Gegevens verdwijnen na afsluiten."
        echo

        temporary "${TTY[@]}" \
            --init \
            -e POSTGRES_PASSWORD=test-only-change-me \
            -p "127.0.0.1:${port}:5432" \
            postgres:18-alpine
        ;;

    redis)
        port="${DTOOL_PORT:-6379}"
        check_port "$port"

        echo
        echo "Tijdelijke Redis"
        echo "Adres: 127.0.0.1:${port}"
        echo

        temporary "${TTY[@]}" \
            --init \
            -p "127.0.0.1:${port}:6379" \
            redis:alpine
        ;;

    images)
        check_docker
        "${DOCKER[@]}" image ls
        ;;

    containers)
        check_docker
        "${DOCKER[@]}" ps -a --filter "label=$LABEL"
        ;;

    cleanup)
        check_docker
        "${DOCKER[@]}" container prune --force --filter "label=$LABEL"
        ;;

    help|--help|-h)
        usage
        ;;

    *)
        echo "Onbekende opdracht: $cmd" >&2
        usage >&2
        exit 1
        ;;
esac
DTOOL

    if ! bash -n "$temp"; then
        rm -f -- "$temp"
        error "Gegenereerde dtool bevat een Bash-syntaxfout; bestaande versie blijft behouden."
        return 1
    fi
    chmod 755 "$temp" || return 1
    mv -f -- "$temp" "$SCRIPT_PATH" || return 1
    temp=""
    trap - RETURN
    success "dtool CLI geïnstalleerd: $SCRIPT_PATH"
}

install_aliases() {
    local temp
    [[ ! -L "$ALIAS_FILE" ]] || { error "Weiger aliases.sh te overschrijven: symbolische link."; return 1; }
    backup "$ALIAS_FILE" || return 1
    temp="$(mktemp "${CONFIG_DIR}/.aliases.XXXXXX")" || return 1
    trap 'rm -f -- "$temp"' RETURN

    cat > "$temp" <<'ALIASES'
# Docker Toolbox

# Webtools
alias dpdf='dtool pdf'
alias dittools='dtool ittools'
alias dmetube='dtool metube'
alias ddraw='dtool draw'
alias dcyberchef='dtool cyberchef'
alias dconvert='dtool convert'
alias dvertaal='dtool translate'

# Shells
alias dnet='dtool network'
alias ddebian='dtool debian'
alias dalpine='dtool alpine'
alias dubuntu='dtool ubuntu'
alias dpython='dtool python'
alias dnode='dtool node'

# Ontwikkeling
alias dtrivy='dtool trivy'
alias dhadolint='dtool hadolint'
alias dpandoc='dtool pandoc'
alias dpostgres='dtool postgres'
alias dredis='dtool redis'

# Beheer
alias dimages='dtool images'
alias dcontainers='dtool containers'
alias dcleanup='dtool cleanup'
ALIASES

    chmod 600 "$temp" || return 1
    mv -f -- "$temp" "$ALIAS_FILE" || return 1
    temp=""
    trap - RETURN
    success "Aliassen geïnstalleerd: $ALIAS_FILE"
}

install_bashrc_block() {
    touch "$BASHRC" || return 1
    backup "$BASHRC" || return 1

    remove_block "$OLD_BEGIN" "$OLD_END" || {
        error "Oud Bash-blok kon niet worden verwijderd."
        return 1
    }

    remove_block "$BEGIN_MARK" "$END_MARK" || {
        error "Bestaand Toolbox Bash-blok kon niet worden verwijderd."
        return 1
    }

    local temp
    temp="$(mktemp "${BASHRC}.XXXXXX")" || return 1
    trap 'rm -f -- "$temp"' RETURN
    if ! cat "$BASHRC" > "$temp"; then
        rm -f "$temp"
        error "Kon ~/.bashrc niet veilig kopieren."
        return 1
    fi
    cat >> "$temp" <<'BASHBLOCK'

# >>> DOCKER_TOOLBOX >>>
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

[[ -f "$HOME/.config/docker-toolbox/aliases.sh" ]] &&
    source "$HOME/.config/docker-toolbox/aliases.sh"
# <<< DOCKER_TOOLBOX <<<
BASHBLOCK
    chmod --reference="$BASHRC" "$temp" || { rm -f "$temp"; return 1; }
    chown --reference="$BASHRC" "$temp" || { rm -f "$temp"; return 1; }
    if ! mv -f -- "$temp" "$BASHRC"; then
        rm -f "$temp"
        error "Kon ~/.bashrc niet atomair vervangen."
        return 1
    fi

    temp=""
    trap - RETURN
    success "Bash-integratie bijgewerkt."

    if grep -Eq "^alias [a-z]+='docker run " "$BASHRC"; then
        warning "Er staan mogelijk oude losse Docker-aliassen in ~/.bashrc."
        warning "Deze worden niet automatisch verwijderd."
    fi
}

install_dropin() {
    sudo test ! -L "$DROPIN_FILE" || {
        error "Docker systemd-drop-in is een symbolische link; handmatige controle nodig."
        return 1
    }
    sudo mkdir -p "$DROPIN_DIR" || return 1

    (
        local tmp
        tmp="$(mktemp)" || exit 1
        trap 'rm -f "$tmp"' EXIT

        cat > "$tmp" <<EOF
[Service]
ExecStartPost=-${DOCKER_BIN} container prune --force --filter label=docker-toolbox.temporary=true
EOF

        if sudo test -f "$DROPIN_FILE"; then
            if ! sudo cmp -s "$tmp" "$DROPIN_FILE"; then
                backup_system_file "$DROPIN_FILE" || exit 1
                sudo install -m 644 "$tmp" "$DROPIN_FILE" || exit 1
                success "Docker systemd-drop-in bijgewerkt."
            else
                info "Docker systemd-drop-in is al actueel."
            fi
        else
            sudo install -m 644 "$tmp" "$DROPIN_FILE" || exit 1
            success "Docker systemd-drop-in geïnstalleerd."
        fi
    ) || return 1

    sudo systemctl daemon-reload || return 1
}

install_docker_toolbox() {
    info "Docker Toolbox: installatie gestart..."

    validate_bashrc || {
        error "Bash-integratie kon niet worden gevalideerd."
        return 1
    }
    [[ ! -L "$SCRIPT_PATH" && ! -L "$ALIAS_FILE" ]] || {
        error "dtool of aliases.sh is een symbolische link; handmatige controle nodig."
        return 1
    }

    [[ ! -L "$CONFIG_DIR" && ! -L "$BIN_DIR" ]] || {
        error "Configuratie- of bin-map is een symbolische link; handmatige controle nodig."
        return 1
    }

    # Verwijder de oude 1.x-cleanup-service voordat de nieuwe installatie
    # begint. Zo kan de oude service niet actief blijven bij een latere fout.
    remove_old_service || return 1

    mkdir -p "$CONFIG_DIR" "$BIN_DIR" || return 1

    install_dtool || return 1
    install_aliases || return 1
    install_bashrc_block || return 1
    install_dropin || return 1

    success "Docker Toolbox geïnstalleerd."
}

# ------------------------------------------------------------
# Docker Toolbox — uninstall
# ------------------------------------------------------------

uninstall_docker_toolbox() {
    require sudo systemctl grep awk

    validate_bashrc || {
        error "Verwijderen afgebroken; controleer eerst ~/.bashrc."
        return 1
    }

    [[ ! -L "$CONFIG_DIR" && ! -L "$BACKUP_DIR" && ! -L "$ALIAS_FILE" && ! -L "$SCRIPT_PATH" ]] || {
        error "Verwijderen afgebroken: aliases.sh of dtool is een symbolische link."
        return 1
    }

    info "Verwijderen van Docker Toolbox-integratie gestart."

    sudo -v || { error "Geen sudo-rechten."; return 1; }
    mkdir -p "$CONFIG_DIR" || return 1
    backup "$BASHRC" || return 1

    remove_block "$BEGIN_MARK" "$END_MARK" || return 1
    remove_block "$OLD_BEGIN" "$OLD_END" || return 1

    remove_old_service || return 1

    if sudo test -e "$DROPIN_FILE"; then
        sudo test ! -L "$DROPIN_FILE" || {
            error "Drop-in is een symbolische link; handmatige controle nodig."
            return 1
        }
        backup_system_file "$DROPIN_FILE" || return 1
        sudo rm -f -- "$DROPIN_FILE" || return 1
    fi

    sudo rmdir "$DROPIN_DIR" 2>/dev/null || true
    sudo systemctl daemon-reload || return 1

    [[ ! -e "$ALIAS_FILE" ]] || rm -f -- "$ALIAS_FILE" || return 1
    [[ ! -e "$SCRIPT_PATH" ]] || rm -f -- "$SCRIPT_PATH" || return 1

    success "Docker Toolbox verwijderd."
    echo
    info "Behouden: Docker-images, volumes, containers, systeempakketten en back-ups."
    info "Open een nieuwe terminal om de aliassen te verwijderen."
}

# ------------------------------------------------------------
# Usage
# ------------------------------------------------------------

usage() {
    cat <<EOF
Omarchy Plus ${VERSION}

Gebruik:
  $0                      CLI Toolkit + Docker Toolbox installeren
  $0 --dry-run            Alleen tonen; voert geen systeemupdate uit
  $0 --skip-update        Voorafgaande Omarchy-update overslaan
  $0 --yes                Omarchy Plus zonder bevestiging installeren
  $0 --skip-cli           Alleen Docker Toolbox
  $0 --skip-docker        Alleen CLI Toolkit
  $0 --uninstall          Docker Toolbox verwijderen
  $0 --dry-run --uninstall  Tonen wat verwijderd zou worden
  $0 --help               Deze hulp

Volgorde:
  1. Read-only voorcontroles
  2. Omarchy bijwerken via: omarchy update
  3. Herstartindicatie controleren
  4. Pakketten inventariseren en installeren
  5. Docker Toolbox installeren en controleren

Wat wordt geïnstalleerd:
  1. CLI Toolkit          ~50 systeempakketten via omarchy pkg add
  2. Docker Toolbox        dtool CLI, aliassen, bash-integratie,
                           systemd drop-in voor automatische cleanup

Wat blijft behouden bij --uninstall:
  - Systeempakketten (via omarchy pkg add geïnstalleerd)
  - Docker-images, -volumes en overige containers
  - Back-ups in ${BACKUP_DIR}

Logbestand: ${STATE_DIR}/install-YYYYMMDD-HHMMSS-PID.log
EOF
}

# ------------------------------------------------------------
# Argumenten
# ------------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)     DRY_RUN=true ;;
        --skip-update) SKIP_UPDATE=true ;;
        --yes)         ASSUME_YES=true ;;
        --uninstall)   DO_UNINSTALL=true ;;
        --skip-cli)    DO_CLI=false ;;
        --skip-docker) DO_DOCKER=false ;;
        -h|--help)     usage; exit 0 ;;
        *)             error "Onbekende optie: $1"; exit 1 ;;
    esac
    shift
done

if [[ "$DO_UNINSTALL" == true && ( "$DO_CLI" == false || "$DO_DOCKER" == false ) ]]; then
    error "Gebruik --uninstall niet samen met --skip-cli of --skip-docker."
    exit 1
fi

if [[ "$DO_UNINSTALL" == true ]]; then
    DO_CLI=false
    DO_DOCKER=true
fi

# ------------------------------------------------------------
# Voorcontroles (read-only, vóór systeemupdate)
# ------------------------------------------------------------

require pacman

if [[ "$DO_CLI" != true && "$DO_DOCKER" != true ]]; then
    warning "Niets te doen: zowel --skip-cli als --skip-docker opgegeven."
    exit 0
fi

if [[ "$DO_UNINSTALL" != true ]]; then
    require omarchy sudo
else
    require sudo
fi

if [[ "$DO_DOCKER" == true ]]; then
    require systemctl grep awk cmp install readlink mktemp
    validate_bashrc || {
        error "Bash-integratie kon niet worden gevalideerd."
        exit 1
    }
fi

# Dry-run blijft volledig read-only: geen update, sudo-ticket of logbestand.
if [[ "$DRY_RUN" == true ]]; then
    if [[ "$DO_CLI" == true ]]; then
        inventory_cli
        show_cli_overview
    fi
    echo
    info "DRY-RUN: geen update, pakketten, bestanden of services worden gewijzigd."
    [[ "$DO_UNINSTALL" == true ]] && info "Zou Docker Toolbox-integratie verwijderen; Docker-data blijft behouden."
    [[ "$DO_UNINSTALL" == true || "$DO_CLI" != true ]] || info "Zou eerst 'omarchy update' uitvoeren, daarna ${#INSTALL_LIST[@]} CLI-pakketten installeren."
    if [[ "$DO_DOCKER" == true && "$DO_UNINSTALL" != true ]]; then
        if command -v docker >/dev/null 2>&1 && systemctl show docker.service -p LoadState --value 2>/dev/null | grep -qx loaded; then
            info "Docker-binary en docker.service zijn aanwezig."
        else
            warning "Docker of docker.service ontbreekt; echte installatie wordt na de update hierop gecontroleerd."
        fi
        info "Zou Docker Toolbox installeren/bijwerken."
    fi
    exit 0
fi

# Voor de echte installatie eerst de systeemupdate uitvoeren.
if ! run_omarchy_update; then
    exit 1
fi

# ------------------------------------------------------------
# Controles na update (read-only)
# ------------------------------------------------------------

if [[ "$DO_CLI" == true ]]; then
    command -v omarchy >/dev/null 2>&1 || {
        error "Omarchy CLI ontbreekt na de update."
        exit 1
    }
fi

if [[ "$DO_DOCKER" == true && "$DO_UNINSTALL" != true ]]; then
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker CLI ontbreekt. Installeer/configureer Docker eerst; er wordt niets automatisch toegevoegd."
        exit 1
    fi
    DOCKER_BIN="$(readlink -f "$(command -v docker)")"
    [[ -x "$DOCKER_BIN" ]] || { error "Docker-binary niet uitvoerbaar."; exit 1; }
    if [[ "$(systemctl show docker.service -p LoadState --value)" != "loaded" ]]; then
        error "docker.service ontbreekt. Configureer Docker eerst."
        exit 1
    fi
fi

if [[ "$DO_CLI" == true ]]; then
    inventory_cli
    show_cli_overview
fi

# ------------------------------------------------------------
# Optiecombinaties en bevestiging
# ------------------------------------------------------------

if [[ "$DO_UNINSTALL" == true && ( "$DO_CLI" == true || "$DO_DOCKER" != true ) ]]; then
    error "Interne optiecombinatie ongeldig voor --uninstall."
    exit 1
fi

if [[ "$ASSUME_YES" != true ]]; then
    echo
    info "Samenvatting:"
    if [[ "$DO_UNINSTALL" == true ]]; then
        echo "  - Docker Toolbox verwijderen"
    else
        [[ "$DO_CLI" != true ]] || echo "  - CLI Toolkit: ${#INSTALL_LIST[@]} installeren, ${#SKIP_LIST[@]} overslaan"
        [[ "$DO_DOCKER" != true ]] || echo "  - Docker Toolbox installeren/bijwerken"
    fi
    echo
    confirm "Doorgaan?" || {
        warning "Actie geannuleerd."
        exit 0
    }
fi

# ------------------------------------------------------------
# Log initialiseren (pas na dry-run en bevestiging)
# ------------------------------------------------------------

[[ ! -L "$STATE_DIR" ]] || {
    error "State-map is een symbolische link; handmatige controle nodig."
    exit 1
}
mkdir -p "$STATE_DIR" || exit 1
LOG_FILE="${STATE_DIR}/install-$(date +%Y%m%d-%H%M%S)-$$.log"
: > "$LOG_FILE"
chmod 600 "$LOG_FILE"
info "Omarchy Plus ${VERSION}"
info "Logbestand: $LOG_FILE"

# ------------------------------------------------------------
# Uninstall-pad
# ------------------------------------------------------------

if [[ "$DO_UNINSTALL" == true ]]; then
    start_sudo_keepalive
    if uninstall_docker_toolbox; then
        exit 0
    else
        exit 1
    fi
fi

# ------------------------------------------------------------
# Installatie
# ------------------------------------------------------------

start_sudo_keepalive

CLI_FAILED=0
DOCKER_FAILED=0

if [[ "$DO_CLI" == true ]]; then
    install_cli_packages || CLI_FAILED=1
fi

if [[ "$DO_DOCKER" == true ]]; then
    install_docker_toolbox || DOCKER_FAILED=1
fi

stop_sudo_keepalive

# ------------------------------------------------------------
# Eindrapport
# ------------------------------------------------------------

echo
echo "=============================================="
echo " OMARCHY PLUS — EINDRAPPORT"
echo "=============================================="

if [[ "$DO_CLI" == true ]]; then
    if [[ "$CLI_FAILED" -eq 0 ]]; then
        success "CLI Toolkit: OK"
    else
        warning "CLI Toolkit: met fouten afgerond."
    fi
fi

if [[ "$DO_DOCKER" == true ]]; then
    if [[ "$DOCKER_FAILED" -eq 0 ]]; then
        success "Docker Toolbox: OK"
    else
        warning "Docker Toolbox: met fouten afgerond."
    fi
fi

echo
echo "Logbestand: $LOG_FILE"

if [[ "$DO_DOCKER" == true && "$DOCKER_FAILED" -eq 0 ]]; then
    echo
    info "Activeer Docker Toolbox in deze terminal:"
    echo "  source ~/.bashrc"
fi

if [[ "$CLI_FAILED" -eq 1 || "$DOCKER_FAILED" -eq 1 ]]; then
    exit 1
fi

exit 0
