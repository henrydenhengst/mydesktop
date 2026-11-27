
#!/usr/bin/env bash
#
# Omarchy Plus Rustig
# CLI Toolkit + Docker Toolbox + Rustig Signaal
#
# Doel:
#   Een complete, rustige en CLI-gerichte inrichting voor Omarchy.
#
# Vereist:
#   Omarchy 4.5 of hoger
#   Arch Linux
#   Bash 5+
#   Python 3.11+
#
# Versie: 4.2.0
#
# Installatievolgorde:
#   1. CLI Toolkit
#   2. Docker Toolbox
#   3. Rustig Signaal
#
# Gebruik:
#   bash omarchy-plus-rustig.sh --help
#   bash omarchy-plus-rustig.sh --check
#   bash omarchy-plus-rustig.sh --dry-run
#   bash omarchy-plus-rustig.sh
#
# Veiligheidsafspraken:
#   - Nooit uitvoeren als root.
#   - Eerst inventariseren en daarna één totaalbevestiging vragen.
#   - Omarchy-update alleen na die bevestiging.
#   - Geen directe pacman -Syu.
#   - Geen automatische reboot.
#   - Geen automatische serviceactivatie.
#   - Bestaande configuratie eerst back-uppen.
#   - Geen systeempakketten verwijderen.
#   - Docker-data blijft behouden bij uninstall.
#   - Geen automatische overschrijving van bestaande PDF's.
#   - Geen onbekende configuratiebestanden verwijderen.
#
# ============================================================

set -Eeuo pipefail
umask 077

readonly VERSION="4.2.0"

# ============================================================
# INSTELLINGEN
# ============================================================

readonly STATE_DIR="${HOME}/.local/state/omarchy-plus"
readonly CONFIG_DIR="${HOME}/.config/docker-toolbox"
readonly BACKUP_DIR="${CONFIG_DIR}/backups"
readonly BIN_DIR="${HOME}/.local/bin"

readonly SCRIPT_PATH="${BIN_DIR}/dtool"
readonly ALIAS_FILE="${CONFIG_DIR}/aliases.sh"
readonly BASHRC="${HOME}/.bashrc"

readonly DROPIN_DIR="/etc/systemd/system/docker.service.d"
readonly DROPIN_FILE="${DROPIN_DIR}/docker-toolbox.conf"

readonly OLD_SERVICE="docker-toolbox-cleanup.service"
readonly OLD_SERVICE_FILE="/etc/systemd/system/${OLD_SERVICE}"
readonly OLD_CLEANUP="${CONFIG_DIR}/cleanup.sh"

readonly THEME_NAME="freeboot-rustig-signaal"
readonly THEME_DIR="${HOME}/.config/omarchy/themes/${THEME_NAME}"
readonly THEME_BACKUP_ROOT="${HOME}/.local/share/freeboot/backups"

readonly EZA_DIR="${HOME}/.config/eza"
readonly EZA_THEME="${EZA_DIR}/theme.yml"
readonly KITTY_CONFIG="${HOME}/.config/kitty/kitty.conf"
readonly FISH_FILE="${HOME}/.config/fish/conf.d/freeboot-rustig-signaal.fish"

readonly THEME_NAME_FILE="${HOME}/.local/state/omarchy/current/theme.name"
readonly THEME_BACKGROUND="${THEME_DIR}/backgrounds/rustig-effen.png"

readonly OMARCHY_DIR="${OMARCHY_PATH:-/usr/share/omarchy}"
readonly KITTY_INCLUDE="include ~/.local/state/omarchy/current/theme/kitty.conf"

readonly DOCKER_BEGIN="# >>> DOCKER_TOOLBOX >>>"
readonly DOCKER_END="# <<< DOCKER_TOOLBOX <<<"
readonly OLD_BEGIN="# DOCKER_TOOLBOX"
readonly OLD_END="# Einde Docker Toolbox"

readonly THEME_BEGIN="# >>> FREEBOOT RUSTIG SIGNAAL >>>"
readonly THEME_END="# <<< FREEBOOT RUSTIG SIGNAAL <<<"

readonly -a MANAGED_PATHS=(
    ".config/omarchy/themes/${THEME_NAME}"
    ".config/eza/theme.yml"
    ".config/kitty/kitty.conf"
    ".config/fish/conf.d/freeboot-rustig-signaal.fish"
    ".bashrc"
    ".zshrc"
)

# ============================================================
# KLEUREN
# ============================================================

readonly BG="#24262b"
readonly FG="#cfd2d6"

readonly C_RED="#f28b95"
readonly C_ORANGE="#e0a050"
readonly C_GREEN="#76c9a0"
readonly C_BLUE="#91b8e8"
readonly C_MUTED="#a6adb8"

readonly SELECTION="#353a46"
readonly BRIGHT_FG="#e6e8eb"

readonly DARKER_BG="#1a1c20"
readonly DARK_BG="#1e2025"

readonly C_PURPLE="#c9a0dc"
readonly C_YELLOW="#e0c080"

readonly FZF_COLORS="--color=bg:${BG},fg:${FG},hl:${C_ORANGE},fg+:${BRIGHT_FG},bg+:${SELECTION},hl+:${C_ORANGE},info:${C_MUTED},prompt:${C_BLUE},pointer:${C_GREEN},marker:${C_GREEN},header:${C_BLUE}"

# ============================================================
# PAKKETLIJST
# ============================================================

CLI_PACKAGES=$(cat <<'EOF'
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
Documentatie|tldr|tldr
EOF
)

# Deze pakketten worden alleen gecontroleerd.
# De themacontrole installeert zelf niets.

THEME_PACKAGES=(
    bash zsh fish starship tmux screen less man-db man-pages parallel
    eza bat ripgrep fd fzf zoxide tree ncdu dust duf
    git git-delta lazygit tig github-cli
    neovim helix jq yq
    curl wget httpie rsync openssh aria2 rclone
    btop htop procs bottom fastfetch sysstat lsof strace
    ranger nnn yazi mc
    entr watchexec hyperfine tokei
    bind whois nmap tcpdump ethtool iperf3 mtr traceroute
    smartmontools nvme-cli parted gptfdisk dosfstools
    e2fsprogs xfsprogs btrfs-progs lvm2 cryptsetup
    shellcheck shfmt ansible python python-pip go rustup
    nodejs npm cmake make gcc pkgconf
    ffmpeg imagemagick pandoc dos2unix unzip zip
    7zip zstd lz4 pigz sqlite
    inetutils iproute2 iputils openbsd-netcat socat tldr
)

declare -rA ALTERNATIVES=(
    [tldr]="tealdeer"
    [openbsd-netcat]="gnu-netcat"
    [rustup]="rust"
)

# ============================================================
# STATUS
# ============================================================

MODE="install"
DRY_RUN=false
ASSUME_YES=false
SKIP_UPDATE=false

DO_CLI=true
DO_DOCKER=true
DO_THEME=true

SELECTION_USED=false
ONLY_USED=""
RESTORE_DIR=""

LOG_FILE=""
SUDO_KEEPALIVE=""
DOCKER_BIN=""
THEME_BACKUP_DIR=""

STEP_NUMBER=0
STEP_TOTAL=0

declare -a INSTALL_LIST=()
declare -a SKIP_LIST=()
declare -a TEMP_PATHS=()

# ============================================================
# MELDINGEN
# ============================================================

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    GREEN=$'\033[0;32m'
    RED=$'\033[0;31m'
    YELLOW=$'\033[0;33m'
    BLUE=$'\033[0;34m'
    BOLD=$'\033[1m'
    RESET=$'\033[0m'
else
    GREEN='' RED='' YELLOW='' BLUE='' BOLD='' RESET=''
fi

_log_plain() {
    [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]] || return 0
    printf '%s\n' "$1" >> "$LOG_FILE"
}

_message() {
    local color="$1"
    local label="$2"
    shift 2

    printf '%s%s%s %s\n' "$color" "$label" "$RESET" "$*"
    _log_plain "$label $*"
}

info()    { _message "$BLUE"   "[INFO]"   "$@"; }
success() { _message "$GREEN"  "[OK]"     "$@"; }
warning() { _message "$YELLOW" "[LET OP]" "$@"; }
error()   { _message "$RED"    "[FOUT]"   "$@" >&2; }

die() {
    error "$@"
    exit 1
}

heading() {
    printf '\n%s%s%s\n' "$BOLD" "$1" "$RESET"
    printf '%s\n' "----------------------------------------------"
    _log_plain "== $1 =="
}

step() {
    STEP_NUMBER=$((STEP_NUMBER + 1))
    heading "Stap ${STEP_NUMBER} van ${STEP_TOTAL}: $1"
}

# ============================================================
# AFSLUITEN EN SUDO
# ============================================================

stop_sudo_keepalive() {
    if [[ -n "$SUDO_KEEPALIVE" ]]; then
        kill "$SUDO_KEEPALIVE" 2>/dev/null || true
        wait "$SUDO_KEEPALIVE" 2>/dev/null || true
        SUDO_KEEPALIVE=""
    fi
}

cleanup_on_exit() {
    stop_sudo_keepalive

    local path
    for path in "${TEMP_PATHS[@]}"; do
        [[ -z "$path" ]] || rm -rf -- "$path"
    done
}

on_interrupt() {
    echo
    warning "Gestopt door jou (Ctrl+C of stopsignaal)."
    warning "Controleer de installatie met: bash $0 --check"

    [[ -z "$THEME_BACKUP_DIR" ]] ||
        warning "Thema-back-up: $THEME_BACKUP_DIR"

    exit 130
}

trap cleanup_on_exit EXIT
trap on_interrupt INT TERM
trap 'error "Onverwachte fout op regel ${LINENO}. Het script stopt."' ERR

start_sudo_keepalive() {
    info "Beheerdersrechten worden gecontroleerd."

    sudo -v || die "Geen sudo-rechten."

    (
        trap - ERR EXIT INT

        local sleep_pid=""

        trap '
            [[ -z "$sleep_pid" ]] ||
                kill "$sleep_pid" 2>/dev/null || true
            exit 0
        ' TERM

        while kill -0 "$$" 2>/dev/null; do
            sudo -n true 2>/dev/null || true
            sleep 60 &
            sleep_pid=$!
            wait "$sleep_pid" || true
        done
    ) </dev/null >/dev/null 2>&1 &

    SUDO_KEEPALIVE=$!
}

# ============================================================
# BASISFUNCTIES
# ============================================================

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

require() {
    local cmd

    for cmd in "$@"; do
        command_exists "$cmd" ||
            die "Vereist commando ontbreekt: $cmd"
    done
}

confirm() {
    local prompt="$1"
    local answer=""

    [[ "$ASSUME_YES" == true ]] && return 0

    if ! { : < /dev/tty; } 2>/dev/null; then
        die "Geen interactieve terminal. Gebruik bewust --yes om door te gaan."
    fi

    echo
    echo "Typ j en druk op Enter om door te gaan."
    echo "Druk alleen op Enter om te stoppen."

    read -r -p "$prompt [j/N] " answer < /dev/tty || answer=""

    case "${answer,,}" in
        j|ja|y|yes) return 0 ;;
        *) return 1 ;;
    esac
}

init_log() {
    [[ ! -L "$STATE_DIR" ]] ||
        die "State-map is een symbolische link."

    mkdir -p "$STATE_DIR" ||
        die "Logmap kon niet worden aangemaakt."

    LOG_FILE="${STATE_DIR}/install-$(date +%Y%m%d-%H%M%S)-$$.log"

    : > "$LOG_FILE"
    chmod 600 "$LOG_FILE"

    info "Omarchy Plus Rustig ${VERSION}"
    info "Logbestand: $LOG_FILE"
}

yes_no() {
    [[ "$1" == true ]] && echo "ja" || echo "nee"
}

# ============================================================
# OMARCHY-VERSIE
# ============================================================

check_omarchy_version() {
    local strictness="$1"
    local output version major minor

    output="$(omarchy version 2>/dev/null)" || output=""
    version="${output#*:}"
    version="${version//[[:space:]]/}"

    if [[ ! "$version" =~ ^([0-9]+)\.([0-9]+)([.]|$) ]]; then
        if [[ "$strictness" == "streng" ]]; then
            die "Omarchy-versie niet betrouwbaar vast te stellen. Gevonden: ${output:-geen uitvoer}"
        fi

        warning "Omarchy-versie niet te bepalen."
        return 1
    fi

    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"

    if (( major > 4 || (major == 4 && minor >= 5) )); then
        success "Omarchy ${version} voldoet aan de minimumversie."
        return 0
    fi

    if [[ "$strictness" == "streng" ]]; then
        die "Omarchy 4.5 of hoger is vereist. Gevonden: $version"
    fi

    warning "Omarchy $version is ouder dan 4.5."
    return 1
}

# ============================================================
# UPDATE
# ============================================================

reboot_required() {
    [[ -e /run/reboot-required ]] && return 0
    [[ -e /var/run/reboot-required ]] && return 0
    [[ -f "${HOME}/.local/state/omarchy/reboot-required" ]] && return 0

    local modules="/usr/lib/modules/$(uname -r)"

    [[ -d "$modules" ]] || return 0

    if [[ -f "${modules}/modules.builtin" ]]; then
        pacman -Qo "${modules}/modules.builtin" >/dev/null 2>&1 ||
            return 0
    fi

    return 1
}

run_omarchy_update() {
    if [[ "$SKIP_UPDATE" == true ]]; then
        info "Omarchy-update bewust overgeslagen."
        return 0
    fi

    info "De officiële Omarchy-update wordt uitgevoerd."
    info "Deze werkt ook systeempakketten en eventueel AUR-pakketten bij."
    info "De update kan zelf om aanvullende invoer vragen."

    # De gebruiker heeft vooraf het volledige installatieplan bevestigd.
    # -y voorkomt een tweede algemene startbevestiging van Omarchy.
    if ! omarchy update -y; then
        error "Omarchy-update mislukt."
        error "Er worden geen volgende onderdelen geïnstalleerd."
        return 1
    fi

    success "Omarchy-update afgerond."

    if reboot_required; then
        warning "Een herstart lijkt nodig."
        info "Er wordt niet automatisch herstart."
        info "Herstart zelf en start daarna dit script opnieuw."
        return 2
    fi

    return 0
}

# ============================================================
# BACK-UPS
# ============================================================

check_backup_dir() {
    [[ ! -L "$CONFIG_DIR" && ! -L "$BACKUP_DIR" ]] || {
        error "Back-upmap is een symbolische link."
        return 1
    }

    mkdir -p "$BACKUP_DIR"
}

backup_target() {
    local source="$1"
    local base counter=1

    base="${BACKUP_DIR}/$(basename "$source").$(date +%Y%m%d-%H%M%S).$$"
    BACKUP_TARGET="$base"

    while [[ -e "$BACKUP_TARGET" ]]; do
        counter=$((counter + 1))
        BACKUP_TARGET="${base}.${counter}"
    done
}

backup() {
    local file="$1"

    [[ -e "$file" || -L "$file" ]] || return 0

    [[ ! -L "$file" ]] || {
        error "Back-up geweigerd: symbolische link: $file"
        return 1
    }

    [[ -f "$file" ]] || {
        error "Back-up geweigerd: geen regulier bestand: $file"
        return 1
    }

    check_backup_dir || return 1
    backup_target "$file"

    cp -p -- "$file" "$BACKUP_TARGET" || return 1
    chmod 600 "$BACKUP_TARGET" || return 1

    info "Back-up gemaakt: $BACKUP_TARGET"
}

backup_system_file() {
    local file="$1"

    sudo test -e "$file" || return 0

    sudo test ! -L "$file" || {
        error "Systeemback-up geweigerd: symbolische link: $file"
        return 1
    }

    sudo test -f "$file" || {
        error "Systeemback-up geweigerd: geen regulier bestand: $file"
        return 1
    }

    check_backup_dir || return 1
    backup_target "$file"

    sudo cp -p -- "$file" "$BACKUP_TARGET" || return 1
    sudo chown "$(id -u):$(id -g)" "$BACKUP_TARGET" || return 1
    chmod 600 "$BACKUP_TARGET" || return 1

    info "Systeemback-up gemaakt: $BACKUP_TARGET"
}

# ============================================================
# BASH-BLOKKEN
# ============================================================

validate_block() {
    local begin="$1"
    local end="$2"
    local count_begin count_end

    [[ -f "$BASHRC" ]] || return 0

    count_begin="$(grep -Fxc -- "$begin" "$BASHRC" || true)"
    count_end="$(grep -Fxc -- "$end" "$BASHRC" || true)"

    if [[ "$count_begin" -eq 0 && "$count_end" -eq 0 ]]; then
        return 0
    fi

    [[ "$count_begin" -eq 1 && "$count_end" -eq 1 ]] || {
        warning "Onvolledig of dubbel Bash-blok: $begin"
        return 1
    }

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
    [[ ! -L "$BASHRC" ]] || {
        error "~/.bashrc is een symbolische link."
        return 1
    }

    validate_block "$OLD_BEGIN" "$OLD_END" || return 1
    validate_block "$DOCKER_BEGIN" "$DOCKER_END" || return 1
    validate_block "$THEME_BEGIN" "$THEME_END" || return 1
}

remove_block() {
    local begin="$1"
    local end="$2"
    local temp

    [[ -f "$BASHRC" ]] || return 0

    validate_block "$begin" "$end" || return 1

    grep -Fqx -- "$begin" "$BASHRC" || return 0

    temp="$(mktemp "${BASHRC}.XXXXXX")" || return 1
    TEMP_PATHS+=("$temp")

    if ! awk -v b="$begin" -v e="$end" '
        $0 == b { inside=1; next }
        $0 == e && inside { inside=0; next }
        inside { next }
        { print }
    ' "$BASHRC" > "$temp"; then
        return 1
    fi

    chmod --reference="$BASHRC" "$temp" || return 1
    chown --reference="$BASHRC" "$temp" || return 1
    mv -f -- "$temp" "$BASHRC" || return 1

    success "Configuratieblok verwijderd: $begin"
}

# ============================================================
# OUDE DOCKER-SERVICE
# ============================================================

remove_old_service() {
    sudo test ! -L "$OLD_SERVICE_FILE" || {
        error "Oude cleanup-service is een symbolische link."
        return 1
    }

    if sudo test -f "$OLD_SERVICE_FILE"; then
        backup_system_file "$OLD_SERVICE_FILE" || return 1

        if sudo systemctl is-active --quiet "$OLD_SERVICE"; then
            sudo systemctl stop "$OLD_SERVICE" || return 1
        fi

        sudo systemctl disable "$OLD_SERVICE" >/dev/null 2>&1 || true

        sudo rm -f -- "$OLD_SERVICE_FILE" || return 1
        sudo systemctl daemon-reload || return 1

        success "Oude cleanup-service verwijderd."
    fi

    if [[ -e "$OLD_CLEANUP" || -L "$OLD_CLEANUP" ]]; then
        [[ ! -L "$OLD_CLEANUP" ]] || {
            error "Oude cleanup.sh is een symbolische link."
            return 1
        }

        backup "$OLD_CLEANUP" || return 1
        rm -f -- "$OLD_CLEANUP" || return 1
    fi
}

# ============================================================
# CLI TOOLKIT
# ============================================================

is_installed() {
    pacman -Qq "$1" >/dev/null 2>&1
}

installed_alternative() {
    local alternative="${ALTERNATIVES[$1]:-}"

    [[ -n "$alternative" ]] || return 1
    is_installed "$alternative" || return 1

    printf '%s' "$alternative"
}

has_conflict() {
    local package="$1"
    local metadata conflicts conflict
    local -a names=()

    metadata="$(LC_ALL=C pacman -Si "$package" 2>/dev/null)" || return 1

    conflicts="$(awk -F ': ' '/^Conflicts With/ {print $2}' <<< "$metadata")"

    [[ -z "$conflicts" || "$conflicts" == "None" ]] && return 1

    read -r -a names <<< "$conflicts"

    for conflict in "${names[@]}"; do
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

    local category package cmd alternative

    while IFS='|' read -r category package cmd; do
        [[ -z "$package" ]] && continue

        if is_installed "$package"; then
            SKIP_LIST+=("$package (reeds aanwezig)")
            continue
        fi

        if alternative="$(installed_alternative "$package")"; then
            SKIP_LIST+=("$package (alternatief aanwezig: $alternative)")
            continue
        fi

        if ! pacman -Si "$package" >/dev/null 2>&1; then
            SKIP_LIST+=("$package (niet beschikbaar)")
            continue
        fi

        if has_conflict "$package"; then
            SKIP_LIST+=("$package (pakketconflict)")
            continue
        fi

        INSTALL_LIST+=("$category|$package|$cmd")
    done <<< "$CLI_PACKAGES"
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

    if (( ${#SKIP_LIST[@]} > 0 )); then
        echo
        echo "OVERGESLAGEN"
        printf '  [-] %s\n' "${SKIP_LIST[@]}"
    fi

    echo
}

install_one_by_one() {
    local package failed_in_row=0

    for package in "$@"; do
        if omarchy pkg add "$package" 2>&1 | tee -a "$LOG_FILE"; then
            failed_in_row=0
        else
            failed_in_row=$((failed_in_row + 1))
            warning "$package is niet geïnstalleerd."
        fi

        if (( failed_in_row >= 5 )); then
            error "Vijf pakketten achter elkaar mislukt."
            return 1
        fi
    done

    return 0
}

install_cli_packages() {
    local entry category package cmd
    local -a packages=()

    if (( ${#INSTALL_LIST[@]} == 0 )); then
        success "Alle beschikbare CLI-gereedschappen zijn al aanwezig."
        return 0
    fi

    for entry in "${INSTALL_LIST[@]}"; do
        IFS='|' read -r category package cmd <<< "$entry"
        packages+=("$package")
    done

    info "CLI Toolkit: ${#packages[@]} pakketten."

    if ! omarchy pkg add "${packages[@]}" 2>&1 | tee -a "$LOG_FILE"; then
        warning "Gezamenlijke installatie mislukt."
        info "Er wordt nu per pakket geprobeerd."

        install_one_by_one "${packages[@]}" || true
    fi

    local -a failed=()

    for package in "${packages[@]}"; do
        if is_installed "$package"; then
            success "$package gecontroleerd."
        else
            failed+=("$package")
        fi
    done

    if (( ${#failed[@]} > 0 )); then
        error "Niet geïnstalleerd:"
        printf '  - %s\n' "${failed[@]}" >&2
        return 1
    fi

    success "Alle CLI-pakketten zijn geïnstalleerd."
}

# ============================================================
# DOCKER TOOLBOX - CONTROLES
# ============================================================

check_docker_paths() {
    validate_bashrc || return 1

    [[ ! -L "$SCRIPT_PATH" && ! -L "$ALIAS_FILE" ]] || {
        error "dtool of aliases.sh is een symbolische link."
        return 1
    }

    [[ ! -L "$CONFIG_DIR" && ! -L "$BACKUP_DIR" && ! -L "$BIN_DIR" ]] || {
        error "Docker-configuratie- of bin-map is een symbolische link."
        return 1
    }

    return 0
}

docker_available() {
    command_exists docker &&
        [[ "$(systemctl show docker.service -p LoadState --value 2>/dev/null)" == "loaded" ]]
}

# ============================================================
# DOCKER TOOLBOX - DTOOL
# ============================================================

install_dtool() {
    local temp

    [[ ! -L "$SCRIPT_PATH" ]] || {
        error "Weiger dtool te overschrijven: symbolische link."
        return 1
    }

    backup "$SCRIPT_PATH" || return 1

    temp="$(mktemp "${BIN_DIR}/.dtool.XXXXXX")" || return 1
    TEMP_PATHS+=("$temp")

    cat > "$temp" <<'DTOOL'
#!/usr/bin/env bash
#
# Docker Toolbox - dtool
#

set -Eeuo pipefail

LABEL="docker-toolbox.temporary=true"
TRIVY_IMAGE="aquasec/trivy:0.76.2"

DOCKER=(docker)
TTY=(-i)

if [[ -t 0 && -t 1 ]]; then
    TTY=(-it)
fi

die() {
    echo "[FOUT] $*" >&2
    exit 1
}

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
  Bestanden in /werk kunnen daardoor root-eigendom worden.

  Python en Node draaien als je eigen UID/GID.
  De volledige thuismap wordt nooit automatisch gekoppeld.

  Webtools stoppen met Ctrl+C.
  Shells stoppen met exit.
EOF
}

check_port() {
    local port="$1"

    [[ "$port" =~ ^[1-9][0-9]{0,4}$ ]] ||
        die "Ongeldig poortnummer: $port"

    (( port >= 1 && port <= 65535 )) ||
        die "Poort moet tussen 1 en 65535 liggen."
}

check_mount_path() {
    [[ "$1" != *:* ]] ||
        die "Dubbele punt in mapnaam; Docker kan deze map niet veilig koppelen."
}

is_restricted_dir() {
    local current home

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
            die "Ga naar een projectsubmap voordat je een script uitvoert."
        fi
        return 0
    fi

    if [[ -n "$first_arg" && -f "$first_arg" ]]; then
        local resolved
        resolved="$(realpath -- "$first_arg")"

        [[ "$resolved" == "$(pwd -P)"/* ]] ||
            die "Bestand valt buiten de huidige projectmap."
    fi

    check_mount_path "$(pwd -P)"
    WORK=(-v "$(pwd -P):/werk" -w /werk)
}

check_scan_directory() {
    is_restricted_dir &&
        die "Scan vanuit een projectsubmap. / en je thuismap zijn uitgesloten."
}

check_docker() {
    local output

    if output="$(docker info 2>&1 </dev/null)"; then
        return 0
    fi

    if grep -qiE 'permission denied|permission denied while trying' <<< "$output"; then
        if [[ -t 0 && -t 1 ]]; then
            sudo -v || die "Geen sudo-rechten."
        else
            die "Docker vereist sudo, maar er is geen interactieve terminal beschikbaar."
        fi

        DOCKER=(sudo docker)

        sudo docker info >/dev/null 2>&1 </dev/null ||
            die "Docker-daemon is niet bereikbaar."

        return 0
    fi

    die "Docker is niet bereikbaar. Controleer de Docker-service."
}

temporary() {
    check_docker
    "${DOCKER[@]}" run --rm --label "$LABEL" "$@"
}

web() {
    local port="${DTOOL_PORT:-$1}"
    local inner="$2"

    shift 2
    check_port "$port"
    check_docker

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
[[ $# -eq 0 ]] || shift

case "$cmd" in

    pdf)
        web 8080 8080 \
            -e SECURITY_ENABLELOGIN=false \
            -v stirling-config:/configs \
            stirlingtools/stirling-pdf
        ;;

    ittools)
        web 8081 80 corentinth/it-tools
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
        web 8083 80 excalidraw/excalidraw
        ;;

    cyberchef)
        web 8084 8080 ghcr.io/gchq/cyberchef
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
        temporary "${TTY[@]}" --init \
            "${WORK[@]}" debian:trixie-slim bash
        ;;

    alpine)
        workdir
        temporary "${TTY[@]}" --init \
            "${WORK[@]}" alpine sh
        ;;

    ubuntu)
        workdir
        temporary "${TTY[@]}" --init \
            "${WORK[@]}" ubuntu:latest bash
        ;;

    python)
        workdir "$@"
        temporary "${TTY[@]}" --init \
            "${WORK[@]}" \
            --user "$(id -u):$(id -g)" \
            -e HOME=/tmp \
            python:3-alpine python "$@"
        ;;

    node)
        workdir "$@"
        temporary "${TTY[@]}" --init \
            "${WORK[@]}" \
            --user "$(id -u):$(id -g)" \
            -e HOME=/tmp \
            node:alpine node "$@"
        ;;

    trivy)
        check_scan_directory
        check_mount_path "$(pwd -P)"

        temporary \
            --security-opt=no-new-privileges \
            -v "$(pwd -P):/work:ro" \
            -v trivy-cache:/root/.cache/trivy \
            "$TRIVY_IMAGE" fs /work
        ;;

    hadolint)
        file="${1:-Dockerfile}"

        [[ -f "$file" ]] || die "Bestand niet gevonden: $file"

        check_docker

        if [[ "${DOCKER[0]}" == "sudo" ]]; then
            [[ -t 0 && -t 1 ]] ||
                die "Sudo vereist een interactieve terminal."
            sudo -v || die "Geen sudo-rechten."
        fi

        temporary -i \
            --security-opt=no-new-privileges \
            hadolint/hadolint < "$file"
        ;;

    pandoc)
        [[ $# -eq 1 ]] ||
            die "Gebruik: dtool pandoc bestand.md"

        [[ -f "$1" ]] || die "Bestand niet gevonden: $1"

        lower="${1,,}"

        [[ "$lower" == *.md || "$lower" == *.markdown ]] ||
            die "Alleen .md- en .markdown-bestanden zijn toegestaan."

        dir="$(cd -- "$(dirname -- "$1")" && pwd -P)"
        name="$(basename -- "$1")"
        home_dir="$(cd "$HOME" && pwd -P)"

        [[ "$dir" != "/" && "$dir" != "$home_dir" ]] ||
            die "Pandoc werkt alleen vanuit een projectsubmap."

        check_mount_path "$dir"

        output="${dir}/${name%.*}.pdf"

        [[ ! -e "$output" && ! -L "$output" ]] ||
            die "Doelbestand bestaat al: $output
Verwijder of hernoem het eerst als je het bewust wilt vervangen."

        temporary \
            --security-opt=no-new-privileges \
            -e HOME=/tmp \
            --user "$(id -u):$(id -g)" \
            -v "$dir:/data" \
            -w /data \
            pandoc/typst \
            "./$name" \
            -o "./${name%.*}.pdf" \
            --pdf-engine=typst

        [[ -f "$output" ]] || die "PDF is niet aangemaakt."
        echo "PDF gemaakt: $output"
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
        die "Onbekende opdracht: $cmd"
        ;;
esac
DTOOL

    bash -n "$temp" || {
        error "dtool bevat een syntaxfout."
        return 1
    }

    chmod 755 "$temp" || return 1
    mv -f -- "$temp" "$SCRIPT_PATH" || return 1

    success "dtool geïnstalleerd."
}

# ============================================================
# DOCKER TOOLBOX - ALIASSEN
# ============================================================

install_aliases() {
    local temp

    [[ ! -L "$ALIAS_FILE" ]] || {
        error "aliases.sh is een symbolische link."
        return 1
    }

    backup "$ALIAS_FILE" || return 1

    temp="$(mktemp "${CONFIG_DIR}/.aliases.XXXXXX")" || return 1
    TEMP_PATHS+=("$temp")

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

    success "Docker-aliassen geïnstalleerd."
}

# ============================================================
# DOCKER TOOLBOX - BASH
# ============================================================

install_bashrc_block() {
    local temp

    touch "$BASHRC" || return 1
    backup "$BASHRC" || return 1

    validate_bashrc || return 1

    remove_block "$OLD_BEGIN" "$OLD_END" || return 1
    remove_block "$DOCKER_BEGIN" "$DOCKER_END" || return 1

    temp="$(mktemp "${BASHRC}.XXXXXX")" || return 1
    TEMP_PATHS+=("$temp")

    cat "$BASHRC" > "$temp" || return 1

    cat >> "$temp" <<'BASHBLOCK'

# >>> DOCKER_TOOLBOX >>>
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

if [[ -f "$HOME/.config/docker-toolbox/aliases.sh" ]]; then
    source "$HOME/.config/docker-toolbox/aliases.sh"
fi
# <<< DOCKER_TOOLBOX <<<
BASHBLOCK

    chmod --reference="$BASHRC" "$temp" || return 1
    chown --reference="$BASHRC" "$temp" || return 1
    mv -f -- "$temp" "$BASHRC" || return 1

    success "Bash-integratie bijgewerkt."
}

# ============================================================
# DOCKER TOOLBOX - SYSTEMD
# ============================================================

install_dropin() {
    local temp

    sudo test ! -L "$DROPIN_FILE" || {
        error "Docker systemd-drop-in is een symbolische link."
        return 1
    }

    sudo test -d "$DROPIN_DIR" ||
        sudo install -d -m 755 "$DROPIN_DIR" || return 1

    temp="$(mktemp)" || return 1
    TEMP_PATHS+=("$temp")

    cat > "$temp" <<EOF
[Service]
ExecStartPost=-${DOCKER_BIN} container prune --force --filter label=docker-toolbox.temporary=true
EOF

    if sudo test -f "$DROPIN_FILE"; then
        if ! sudo cmp -s "$temp" "$DROPIN_FILE"; then
            backup_system_file "$DROPIN_FILE" || return 1
            sudo install -m 644 "$temp" "$DROPIN_FILE" || return 1
            success "Docker systemd-drop-in bijgewerkt."
        else
            info "Docker systemd-drop-in is al actueel."
        fi
    else
        sudo install -m 644 "$temp" "$DROPIN_FILE" || return 1
        success "Docker systemd-drop-in geïnstalleerd."
    fi

    sudo systemctl daemon-reload || return 1
}

install_docker_toolbox() {
    check_docker_paths || return 1

    mkdir -p "$CONFIG_DIR" "$BIN_DIR" || return 1

    remove_old_service || return 1

    install_dtool || return 1
    install_aliases || return 1
    install_bashrc_block || return 1
    install_dropin || return 1

    success "Docker Toolbox geïnstalleerd."
}

# ============================================================
# DOCKER TOOLBOX - VERWIJDEREN
# ============================================================

uninstall_docker_toolbox() {
    info "Docker Toolbox wordt verwijderd."

    mkdir -p "$CONFIG_DIR" || return 1

    # Eerst alle gebruikersbestanden veiligstellen.
    backup "$BASHRC" || return 1
    backup "$SCRIPT_PATH" || return 1
    backup "$ALIAS_FILE" || return 1

    remove_block "$DOCKER_BEGIN" "$DOCKER_END" || return 1
    remove_block "$OLD_BEGIN" "$OLD_END" || return 1

    remove_old_service || return 1

    if sudo test -e "$DROPIN_FILE"; then
        sudo test ! -L "$DROPIN_FILE" || {
            error "Drop-in is een symbolische link."
            return 1
        }

        backup_system_file "$DROPIN_FILE" || return 1
        sudo rm -f -- "$DROPIN_FILE" || return 1
    fi

    sudo rmdir "$DROPIN_DIR" 2>/dev/null || true
    sudo systemctl daemon-reload || return 1

    rm -f -- "$ALIAS_FILE" "$SCRIPT_PATH" || return 1

    success "Docker Toolbox verwijderd."
    info "Docker-images, containers, volumes en systeempakketten zijn behouden."
    info "Back-ups zijn behouden."
    info "Open een nieuwe terminal."
}

# ============================================================
# THEMA - CONTROLES
# ============================================================

current_theme() {
    [[ ! -f "$THEME_NAME_FILE" ]] || cat -- "$THEME_NAME_FILE"
}

check_theme_requirements() {
    require python3 tar find sort realpath mktemp

    python3 -I -c '
import sys, tomllib
if sys.version_info < (3, 11):
    raise SystemExit("Python 3.11+ vereist")
' || die "Python 3.11+ met TOML-ondersteuning is vereist."

    if ! command_exists omarchy-theme-set && ! command_exists omarchy; then
        die "Omarchy-themafunctie niet gevonden."
    fi

    success "Thema-afhankelijkheden beschikbaar."
}

check_managed_paths() {
    local rel path

    for rel in "${MANAGED_PATHS[@]}"; do
        path="${HOME}/${rel}"

        [[ ! -L "$path" ]] ||
            die "Symbolische link aangetroffen: $path"

        if [[ -e "$path" && ! -f "$path" && ! -d "$path" ]]; then
            die "Onverwacht bestandstype: $path"
        fi
    done

    # Ook binnen de beheerde themamap geen verborgen symlinks accepteren.
    if [[ -d "$THEME_DIR" ]]; then
        local link
        link="$(find "$THEME_DIR" -type l -print -quit)"

        [[ -z "$link" ]] ||
            die "Symbolische link in themamap: $link"
    fi

    success "Beheerde paden gecontroleerd."
}

check_theme_blocks() {
    python3 -I - \
        "$THEME_BEGIN" "$THEME_END" \
        "$BASHRC" "${HOME}/.zshrc" "$KITTY_CONFIG" <<'PY'
import pathlib
import sys

begin, end = (value.encode() for value in sys.argv[1:3])

for name in sys.argv[3:]:
    path = pathlib.Path(name)
    if not path.is_file():
        continue

    lines = path.read_bytes().split(b"\n")
    starts = [i for i, line in enumerate(lines) if line == begin]
    ends = [i for i, line in enumerate(lines) if line == end]

    if len(starts) != len(ends) or len(starts) > 1:
        raise SystemExit(f"Ongeldige of dubbele markeringen: {name}")

    if starts and ends[0] < starts[0]:
        raise SystemExit(f"Verkeerde blokvolgorde: {name}")
PY
}

check_theme_preconditions() {
    check_theme_requirements
    check_managed_paths
    check_theme_blocks
}

check_theme_packages() {
    local package alternative
    local -a missing=() replaced=()

    for package in "${THEME_PACKAGES[@]}"; do
        is_installed "$package" && continue

        if alternative="$(installed_alternative "$package")"; then
            replaced+=("$package: $alternative aanwezig")
        else
            missing+=("$package")
        fi
    done

    echo
    printf 'Controlelijst : %s\n' "${#THEME_PACKAGES[@]}"
    printf 'Ontbrekend    : %s\n' "${#missing[@]}"
    printf 'Alternatief   : %s\n' "${#replaced[@]}"

    if (( ${#replaced[@]} > 0 )); then
        echo
        echo "Alternatieven:"
        printf '  - %s\n' "${replaced[@]}"
    fi

    if (( ${#missing[@]} > 0 )); then
        echo
        echo "Ontbrekende pakketten:"
        printf '  - %s\n' "${missing[@]}"
    fi

    info "Deze controle installeert niets."
}

show_theme_overview() {
    echo
    echo "Thema              : $THEME_NAME"
    echo "Themamap           : $THEME_DIR"
    echo "eza-configuratie   : $EZA_THEME"
    echo "Kitty-configuratie : $KITTY_CONFIG"
    echo "Fish-configuratie  : $FISH_FILE"
    echo "Back-upmap         : $THEME_BACKUP_ROOT"

    if ! command_exists kitty; then
        info "Kitty is niet geïnstalleerd. Het thema blijft zonder Kitty bruikbaar."
    fi
}

# ============================================================
# THEMA - BACK-UP
# ============================================================

create_theme_backup() {
    local prefix="${1:-}"
    local base target counter=1
    local rel

    [[ ! -L "$THEME_BACKUP_ROOT" ]] ||
        die "Thema-back-upmap is een symbolische link."

    mkdir -p "$THEME_BACKUP_ROOT" || return 1

    base="${THEME_BACKUP_ROOT}/${prefix}$(date '+%Y%m%d-%H%M%S')"
    target="$base"

    while [[ -e "$target" ]]; do
        counter=$((counter + 1))
        target="${base}-${counter}"
    done

    mkdir -- "$target" || return 1

    local -a existing=()

    for rel in "${MANAGED_PATHS[@]}"; do
        [[ ! -e "${HOME}/${rel}" ]] || existing+=("$rel")
    done

    if (( ${#existing[@]} > 0 )); then
        tar -cpf "${target}/files.tar" -C "$HOME" -- "${existing[@]}" ||
            return 1
    else
        tar -cpf "${target}/files.tar" --files-from /dev/null ||
            return 1
    fi

    printf '%s\n' "${existing[@]}" > "${target}/existing-paths.txt" ||
        return 1

    printf '%s\n' "${MANAGED_PATHS[@]}" > "${target}/managed-paths.txt" ||
        return 1

    current_theme > "${target}/previous-theme.txt" || return 1

    chmod 600 "${target}/files.tar" \
        "${target}/existing-paths.txt" \
        "${target}/managed-paths.txt" \
        "${target}/previous-theme.txt" || return 1

    THEME_BACKUP_DIR="$target"

    success "Thema-back-up gemaakt: $target"
}

# ============================================================
# THEMA - ATOMAIR SCHRIJVEN
# ============================================================

write_atomic() {
    local target="$1"
    local mode="${2:-0644}"
    local parent temp

    parent="$(dirname "$target")"

    mkdir -p "$parent" || return 1

    temp="$(mktemp "${parent}/.freeboot.XXXXXX")" || return 1
    TEMP_PATHS+=("$temp")

    cat > "$temp" || return 1
    chmod "$mode" "$temp" || return 1

    if [[ -e "$target" ]]; then
        chmod --reference="$target" "$temp" || return 1
        chown --reference="$target" "$temp" || return 1
    fi

    mv -f -- "$temp" "$target"
}

# ============================================================
# THEMA - KLEUREN
# ============================================================

write_colors() {
    write_atomic "${THEME_DIR}/colors.toml" 0644 <<EOF
mode = "dark"

# FreeBoot Rustig Signaal

accent = "$C_BLUE"
selection = "$SELECTION"
muted = "$C_MUTED"

cursor = "$BRIGHT_FG"
selection_background = "$SELECTION"
selection_foreground = "$BRIGHT_FG"

background = "$BG"
dark_background = "$DARK_BG"
darker_background = "$DARKER_BG"
lighter_background = "$SELECTION"

foreground = "$FG"
dark_foreground = "$C_MUTED"
light_foreground = "$BRIGHT_FG"
bright_foreground = "$BRIGHT_FG"

red = "$C_RED"
orange = "$C_ORANGE"
yellow = "$C_ORANGE"
bright_yellow = "$C_YELLOW"
green = "$C_GREEN"
blue = "$C_BLUE"
purple = "$C_PURPLE"

color0 = "$DARKER_BG"
color1 = "$C_RED"
color2 = "$C_GREEN"
color3 = "$C_ORANGE"
color4 = "$C_BLUE"
color5 = "$C_PURPLE"
color6 = "$C_BLUE"
color7 = "$FG"

color8 = "$C_MUTED"
color9 = "$C_RED"
color10 = "$C_GREEN"
color11 = "$C_YELLOW"
color12 = "$C_BLUE"
color13 = "$C_PURPLE"
color14 = "$C_BLUE"
color15 = "$BRIGHT_FG"
EOF
}

validate_colors() {
    python3 -I - "${THEME_DIR}/colors.toml" <<'PY'
import re
import sys
import tomllib

with open(sys.argv[1], "rb") as handle:
    data = tomllib.load(handle)

required = [
    "mode", "accent", "selection", "muted", "cursor",
    "selection_background", "selection_foreground",
    "background", "dark_background", "darker_background",
    "lighter_background", "foreground", "dark_foreground",
    "light_foreground", "bright_foreground", "red", "orange",
    "yellow", "green", "blue", "purple"
] + [f"color{i}" for i in range(16)]

for key in required:
    if key not in data:
        raise SystemExit(f"Ontbrekende TOML-sleutel: {key}")

for key, value in data.items():
    if key == "mode":
        if value not in ("dark", "light"):
            raise SystemExit("Ongeldige modus")
        continue

    if not isinstance(value, str):
        raise SystemExit(f"Ongeldige waarde: {key}")

    if not re.fullmatch(r"#[0-9a-fA-F]{6}", value):
        raise SystemExit(f"Ongeldige kleur: {key} = {value}")
PY
}

# ============================================================
# THEMA - ACHTERGROND
# ============================================================

write_background() {
    local parent temp

    parent="$(dirname "$THEME_BACKGROUND")"
    mkdir -p "$parent" || return 1

    # Een bestaande eigen achtergrond wordt niet overschreven.
    if [[ -e "$THEME_BACKGROUND" ]]; then
        info "Bestaande achtergrond behouden."
        return 0
    fi

    temp="$(mktemp "${parent}/.freeboot.XXXXXX")" || return 1
    TEMP_PATHS+=("$temp")

    python3 -I - "$temp" "$BG" <<'PY'
import struct
import sys
import zlib

path, color = sys.argv[1:3]
width, height = 1920, 1080

row = b"\x00" + bytes.fromhex(color.lstrip("#")) * width

def chunk(kind, data):
    body = kind + data
    return (
        struct.pack(">I", len(data))
        + body
        + struct.pack(">I", zlib.crc32(body))
    )

with open(path, "wb") as handle:
    handle.write(b"\x89PNG\r\n\x1a\n")
    handle.write(chunk(
        b"IHDR",
        struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    ))
    handle.write(chunk(b"IDAT", zlib.compress(row * height, 9)))
    handle.write(chunk(b"IEND", b""))
PY

    chmod 644 "$temp" || return 1
    mv -f -- "$temp" "$THEME_BACKGROUND" || return 1

    success "Effen achtergrond aangemaakt."
}

# ============================================================
# THEMA - EZA
# ============================================================

write_eza_theme() {
    write_atomic "$EZA_THEME" 0644 <<EOF
colourful: true

filekinds:
  directory:
    foreground: "$C_BLUE"
    is_bold: true

  symlink:
    foreground: "$C_BLUE"

git:
  new:
    foreground: "$C_GREEN"

  modified:
    foreground: "$C_ORANGE"

  deleted:
    foreground: "$C_RED"

  renamed:
    foreground: "$C_PURPLE"

  conflicted:
    foreground: "$C_RED"
    is_bold: true
EOF

    success "eza-thema bijgewerkt."
}

# ============================================================
# THEMA - BEHEERDE BLOKKEN
# ============================================================

update_managed_block() {
    local target="$1"
    local snippet="$2"

    python3 -I - "$target" "$snippet" "$THEME_BEGIN" "$THEME_END" <<'PY'
import os
import pathlib
import sys
import tempfile

target = pathlib.Path(sys.argv[1])
snippet = pathlib.Path(sys.argv[2])

begin = sys.argv[3].encode()
end = sys.argv[4].encode()

if target.is_symlink():
    raise SystemExit(f"Symbolische link geweigerd: {target}")

lines = target.read_bytes().split(b"\n") if target.exists() else []

starts = [i for i, line in enumerate(lines) if line == begin]
ends = [i for i, line in enumerate(lines) if line == end]

if len(starts) != len(ends) or len(starts) > 1:
    raise SystemExit(f"Ongeldige markeringen: {target}")

if starts:
    if ends[0] < starts[0]:
        raise SystemExit(f"Verkeerde blokvolgorde: {target}")

    first = starts[0]

    if first > 0 and not lines[first - 1].strip():
        first -= 1

    lines = lines[:first] + lines[ends[0] + 1:]

while lines and not lines[-1].strip():
    lines.pop()

if lines:
    lines.append(b"")

lines.extend([
    begin,
    snippet.read_bytes().rstrip(),
    end
])

content = b"\n".join(lines) + b"\n"

target.parent.mkdir(parents=True, exist_ok=True)

mode = target.stat().st_mode & 0o777 if target.exists() else 0o644

fd, temp_name = tempfile.mkstemp(
    prefix=".freeboot-",
    dir=target.parent
)

try:
    with os.fdopen(fd, "wb") as handle:
        handle.write(content)

    os.chmod(temp_name, mode)

    if target.exists():
        stat = target.stat()
        os.chown(temp_name, stat.st_uid, stat.st_gid)

    os.replace(temp_name, target)

except BaseException:
    try:
        os.unlink(temp_name)
    except FileNotFoundError:
        pass
    raise
PY
}

# ============================================================
# THEMA - KITTY
# ============================================================

prepare_kitty_config() {
    local default="${OMARCHY_DIR}/config/kitty/kitty.conf"

    # Alleen een ontbrekend bestand wordt aangemaakt.
    # Een bestaande configuratie wordt nooit vervangen.
    if [[ ! -e "$KITTY_CONFIG" ]]; then
        if [[ -f "$default" ]]; then
            write_atomic "$KITTY_CONFIG" 0644 < "$default" ||
                return 1
            success "Kitty-configuratie aangemaakt op basis van Omarchy."
        else
            printf '%s\n' "$KITTY_INCLUDE" |
                write_atomic "$KITTY_CONFIG" 0644 ||
                return 1
        fi
    fi

    [[ ! -L "$KITTY_CONFIG" ]] ||
        die "Kitty-configuratie is een symbolische link."
}

write_kitty_settings() {
    local snippet
    snippet="$(mktemp)" || return 1
    TEMP_PATHS+=("$snippet")

    cat > "$snippet" <<'EOF'
# Rustige cursor en geen geluid
cursor_blink_interval 0
cursor_trail 0
enable_audio_bell no
visual_bell_duration 0.0

# Rustige vensterweergave
window_padding_width 8
background_opacity 1.0
dim_opacity 0.85
inactive_text_alpha 1.0
EOF

    prepare_kitty_config || return 1

    # Geen bestaande instellingen verwijderen.
    update_managed_block "$KITTY_CONFIG" "$snippet" || return 1

    if ! grep -Eq '^[[:space:]]*include[[:space:]].*omarchy/current/theme/kitty\.conf' "$KITTY_CONFIG"; then
        local include_snippet
        include_snippet="$(mktemp)" || return 1
        TEMP_PATHS+=("$include_snippet")

        printf '%s\n' "$KITTY_INCLUDE" > "$include_snippet"

        # Voeg de themaverwijzing alleen toe als deze nog ontbreekt.
        local combined
        combined="$(mktemp)" || return 1
        TEMP_PATHS+=("$combined")

        {
            printf '%s\n' "$KITTY_INCLUDE"
            cat "$KITTY_CONFIG"
        } > "$combined" || return 1

        cat "$combined" | write_atomic "$KITTY_CONFIG" 0644 || return 1
    fi

    success "Kitty-instellingen bijgewerkt."
}

# ============================================================
# THEMA - SHELLS
# ============================================================

write_shell_settings() {
    local snippet
    snippet="$(mktemp)" || return 1
    TEMP_PATHS+=("$snippet")

    cat > "$snippet" <<'EOF'
# Rustige FreeBoot-instellingen

export EZA_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/eza"

unset EZA_COLORS
unset LS_COLORS

export LESS="${LESS:--R}"
EOF

    printf "\nexport FZF_DEFAULT_OPTS='%s'\n" "$FZF_COLORS" >> "$snippet"

    update_managed_block "$BASHRC" "$snippet" || return 1
    update_managed_block "${HOME}/.zshrc" "$snippet" || return 1

    success "Bash- en Zsh-instellingen bijgewerkt."
}

write_fish_settings() {
    local temp

    temp="$(mktemp "${HOME}/.config/fish/conf.d/.freeboot.XXXXXX")" ||
        return 1

    TEMP_PATHS+=("$temp")

    cat > "$temp" <<EOF
# FreeBoot Rustig Signaal

set -gx EZA_CONFIG_DIR "\$HOME/.config/eza"

set -e EZA_COLORS
set -e LS_COLORS

set -gx LESS '-R'
set -gx FZF_DEFAULT_OPTS '$FZF_COLORS'
EOF

    chmod 644 "$temp" || return 1

    # Alleen het eigen bestand wordt vervangen.
    mv -f -- "$temp" "$FISH_FILE" || return 1

    success "Fish-configuratie bijgewerkt."
}

# ============================================================
# THEMA - ACTIVEREN
# ============================================================

activate_theme() {
    local name="$1"

    info "Thema activeren: $name"

    if command_exists omarchy-theme-set; then
        OMARCHY_THEME_WAIT=1 omarchy-theme-set "$name"
    elif command_exists omarchy; then
        OMARCHY_THEME_WAIT=1 omarchy theme set "$name"
    else
        error "Geen ondersteunde Omarchy-themafunctie."
        return 1
    fi
}

verify_theme() {
    activate_theme "$THEME_NAME" || return 1

    local active
    active="$(current_theme)"

    [[ -n "$active" ]] || {
        error "Omarchy heeft geen actieve themanaam opgeslagen."
        return 1
    }

    [[ "$active" == "$THEME_NAME" ]] || {
        error "Actief thema wijkt af: $active"
        return 1
    }

    success "Rustig Signaal is actief."
}

# ============================================================
# THEMA - INSTALLEREN
# ============================================================

install_theme() {
    create_theme_backup || return 1

    write_colors || return 1
    validate_colors || return 1

    write_background || return 1
    write_eza_theme || return 1
    write_kitty_settings || return 1
    write_shell_settings || return 1
    write_fish_settings || return 1

    verify_theme || return 1

    success "Rustig Signaal geïnstalleerd."
}

# ============================================================
# THEMA - BACK-UPCONTROLEREN
# ============================================================

check_theme_archive() {
    python3 -I - "$1" "${MANAGED_PATHS[@]}" <<'PY'
import pathlib
import sys
import tarfile

allowed = sys.argv[2:]

with tarfile.open(sys.argv[1]) as archive:
    for member in archive.getmembers():
        path = pathlib.PurePosixPath(member.name)

        if path.is_absolute() or ".." in path.parts:
            raise SystemExit(f"Onveilig pad: {member.name}")

        if not (member.isfile() or member.isdir()):
            raise SystemExit(f"Onveilig bestandstype: {member.name}")

        if not any(
            member.name == item or member.name.startswith(item + "/")
            for item in allowed
        ):
            raise SystemExit(f"Onverwacht pad: {member.name}")
PY
}

validate_backup_manifest() {
    python3 -I - "$1" "${MANAGED_PATHS[@]}" <<'PY'
import pathlib
import sys

backup = pathlib.Path(sys.argv[1])
allowed = set(sys.argv[2:])

manifest = backup / "managed-paths.txt"
existing = backup / "existing-paths.txt"

if not manifest.is_file() or not existing.is_file():
    raise SystemExit("Back-upmanifest ontbreekt.")

managed = set(manifest.read_text().splitlines())
present = set(existing.read_text().splitlines())

if managed != allowed:
    raise SystemExit("Back-up bevat een afwijkende beheerde-padenlijst.")

if not present.issubset(allowed):
    raise SystemExit("Back-up bevat onbekende paden.")
PY
}

backup_theme_status() {
    python3 -I - "$1" "$THEME_NAME" "$THEME_BEGIN" <<'PY'
import pathlib
import sys
import tarfile

source = pathlib.Path(sys.argv[1])
theme = sys.argv[2]
marker = sys.argv[3].encode()

theme_paths = (
    f".config/omarchy/themes/{theme}",
    f".config/fish/conf.d/{theme}.fish",
)

shell_files = (
    ".bashrc",
    ".zshrc",
    ".config/kitty/kitty.conf",
)

try:
    previous = source / "previous-theme.txt"

    if previous.is_file() and previous.read_text(errors="replace").strip() == theme:
        sys.exit(0)

    with tarfile.open(source / "files.tar") as archive:
        for member in archive.getmembers():
            if member.name.startswith(theme_paths):
                sys.exit(0)

            if member.name in shell_files and member.isfile():
                handle = archive.extractfile(member)
                if handle and marker in handle.read().split(b"\n"):
                    sys.exit(0)

except (OSError, tarfile.TarError):
    sys.exit(2)

sys.exit(1)
PY
}

latest_clean_backup() {
    [[ -d "$THEME_BACKUP_ROOT" ]] || return 0

    local dir status
    local -a dirs=()

    mapfile -t dirs < <(
        find "$THEME_BACKUP_ROOT" \
            -mindepth 1 -maxdepth 1 \
            -type d -name '20*' |
        sort -V
    )

    local index

    for (( index=${#dirs[@]}-1; index>=0; index-- )); do
        dir="${dirs[index]}"
        status=0

        backup_theme_status "$dir" || status=$?

        if (( status == 1 )); then
            printf '%s' "$dir"
            return 0
        fi
    done
}

list_theme_backups() {
    [[ -d "$THEME_BACKUP_ROOT" ]] || return 0

    local dir theme status label

    echo "Beschikbare thema-back-ups:"

    while IFS= read -r dir; do
        theme="$(cat "${dir}/previous-theme.txt" 2>/dev/null || true)"

        status=0
        backup_theme_status "$dir" || status=$?

        case "$status" in
            0) label="thema al aanwezig" ;;
            1) label="van vóór het thema" ;;
            *) label="onleesbaar" ;;
        esac

        printf '  - %s\n' "$dir"
        printf '      %s; actief thema: %s\n' "$label" "${theme:-onbekend}"

    done < <(
        find "$THEME_BACKUP_ROOT" \
            -mindepth 1 -maxdepth 1 -type d |
        sort -V
    )
}

# ============================================================
# THEMA - HERSTEL
# ============================================================

restore_from_archive() {
    local archive="$1"
    local staging="$2"
    local rel

    tar -xpf "$archive" -C "$staging" || return 1

    for rel in "${MANAGED_PATHS[@]}"; do
        rm -rf -- "${HOME:?}/${rel}" || return 1

        if [[ -e "${staging}/${rel}" ]]; then
            mkdir -p "$(dirname "${HOME}/${rel}")" || return 1
            mv -- "${staging}/${rel}" "${HOME}/${rel}" || return 1
        fi
    done
}

restore_theme() {
    local source="$RESTORE_DIR"

    if [[ -z "$source" ]]; then
        source="$(latest_clean_backup)"

        [[ -n "$source" ]] || {
            list_theme_backups
            die "Geen geschikte back-up van vóór het thema gevonden."
        }
    fi

    [[ -d "$source" ]] ||
        die "Back-upmap niet gevonden: $source"

    local required

    for required in files.tar managed-paths.txt existing-paths.txt previous-theme.txt; do
        [[ -f "${source}/${required}" ]] ||
            die "Back-upbestand ontbreekt: ${required}"
    done

    validate_backup_manifest "$source" ||
        die "Back-upmanifest is ongeldig."

    check_theme_archive "${source}/files.tar" ||
        die "Back-uparchief is afgekeurd."

    local previous_theme
    previous_theme="$(cat "${source}/previous-theme.txt")"

    echo
    list_theme_backups

    echo
    info "Gekozen back-up: $source"
    info "Vorige themakeuze: ${previous_theme:-onbekend}"

    if [[ "$DRY_RUN" == true ]]; then
        info "DRY-RUN: er is niets gewijzigd."
        return 0
    fi

    confirm "De huidige beheerde configuratie vervangen?" || {
        warning "Herstel geannuleerd."
        return 0
    }

    create_theme_backup "voor-herstel-" ||
        die "Veiligheidskopie maken mislukt."

    local safety="$THEME_BACKUP_DIR"
    local staging

    staging="$(mktemp -d "${HOME}/.freeboot-restore.XXXXXX")" ||
        die "Tijdelijke herstelmap maken mislukt."

    TEMP_PATHS+=("$staging")

    if ! restore_from_archive "${source}/files.tar" "$staging"; then
        error "Herstel is gedeeltelijk mislukt."
        warning "Veiligheidskopie wordt teruggezet: $safety"

        local rollback
        rollback="$(mktemp -d "${HOME}/.freeboot-rollback.XXXXXX")" ||
            die "Automatisch terugrollen kon niet starten."

        TEMP_PATHS+=("$rollback")

        restore_from_archive "${safety}/files.tar" "$rollback" ||
            die "Ook terugrollen is mislukt. Veiligheidskopie: $safety"

        die "De vorige configuratie is teruggezet."
    fi

    if [[ -n "$previous_theme" ]]; then
        activate_theme "$previous_theme" ||
            die "Bestanden hersteld, maar thema activeren is mislukt."
    else
        warning "Geen vorige themanaam opgeslagen."
    fi

    success "Herstel afgerond."
    info "Veiligheidskopie: $safety"
    info "Open een nieuwe terminal."
}

# ============================================================
# SHELLCHECK
# ============================================================

run_shellcheck() {
    if ! command_exists shellcheck; then
        info "ShellCheck niet geïnstalleerd; controle overgeslagen."
        return 0
    fi

    local file problems=0

    for file in "${BASH_SOURCE[0]}" "$SCRIPT_PATH"; do
        [[ -f "$file" ]] || continue

        if shellcheck --shell=bash --severity=warning "$file"; then
            success "ShellCheck: geen waarschuwingen in $file"
        else
            warning "ShellCheck meldt aandachtspunten in $file."
            problems=1
        fi
    done

    return "$problems"
}

# ============================================================
# HELP
# ============================================================

show_help() {
    cat <<EOF
Omarchy Plus Rustig ${VERSION}

Voor Omarchy 4.5 of hoger.

GEBRUIK
  bash $0 [opties]

CONTROLE
  --check             Alleen controleren
  --dry-run           Tonen wat er zou gebeuren
  --help, -h          Deze uitleg

ONDERDELEN
  --only-cli          Alleen CLI Toolkit
  --only-docker       Alleen Docker Toolbox
  --only-theme        Alleen Rustig Signaal

  --skip-cli          CLI Toolkit overslaan
  --skip-docker       Docker Toolbox overslaan
  --skip-theme        Rustig Signaal overslaan

UPDATE
  --skip-update       Omarchy-update overslaan
  --yes               Bevestigingsvragen van dit script overslaan

HERSTEL
  --uninstall         Docker Toolbox-integratie verwijderen
  --restore           Nieuwste back-up van vóór het thema herstellen
  --restore PAD       Specifieke thema-back-up herstellen

INSTALLATIEVOLGORDE
  1. Voorcontroles
  2. Volledig overzicht
  3. Eén totaalbevestiging
  4. Omarchy-update indien van toepassing
  5. CLI Toolkit
  6. Docker Toolbox
  7. Rustig Signaal
  8. Eindrapport

BEHOUDEN
  - Systeempakketten
  - Docker-images, containers en volumes
  - Back-ups
  - Eigen configuratie buiten de beheerde blokken

BACK-UPS
  Docker Toolbox:
    ${BACKUP_DIR}

  Thema:
    ${THEME_BACKUP_ROOT}

LOGS
  ${STATE_DIR}

EOF
}

# ============================================================
# ARGUMENTEN
# ============================================================

set_mode() {
    [[ "$MODE" == "install" || "$MODE" == "$1" ]] ||
        die "Gebruik slechts één modus: --check, --restore of --uninstall."

    MODE="$1"
}

set_only() {
    [[ -z "$ONLY_USED" || "$ONLY_USED" == "$1" ]] ||
        die "Gebruik slechts één --only-optie."

    ONLY_USED="$1"
    SELECTION_USED=true
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                ;;

            --check)
                set_mode check
                ;;

            --skip-update)
                SKIP_UPDATE=true
                ;;

            --yes)
                ASSUME_YES=true
                ;;

            --uninstall)
                set_mode uninstall
                ;;

            --restore)
                set_mode restore

                if [[ $# -gt 1 && "$2" != -* ]]; then
                    RESTORE_DIR="$2"
                    shift
                fi
                ;;

            --skip-cli)
                DO_CLI=false
                SELECTION_USED=true
                ;;

            --skip-docker)
                DO_DOCKER=false
                SELECTION_USED=true
                ;;

            --skip-theme)
                DO_THEME=false
                SELECTION_USED=true
                ;;

            --only-cli)
                set_only cli
                ;;

            --only-docker)
                set_only docker
                ;;

            --only-theme)
                set_only theme
                ;;

            -h|--help)
                show_help
                exit 0
                ;;

            *)
                die "Onbekende optie: $1"
                ;;
        esac

        shift
    done

    case "$ONLY_USED" in
        cli)
            DO_DOCKER=false
            DO_THEME=false
            ;;
        docker)
            DO_CLI=false
            DO_THEME=false
            ;;
        theme)
            DO_CLI=false
            DO_DOCKER=false
            ;;
    esac

    if [[ "$MODE" == "uninstall" || "$MODE" == "restore" ]]; then
        [[ "$SELECTION_USED" == false ]] ||
            die "Gebruik --$MODE niet samen met --only- of --skip-opties."
    fi

    if [[ "$MODE" != "install" ]]; then
        [[ "$DRY_RUN" == false || "$MODE" == "uninstall" || "$MODE" == "restore" ]] ||
            die "Ongeldige combinatie van opties."
    fi
}

# ============================================================
# CHECK-MODUS
# ============================================================

run_check() {
    heading "Controle - er wordt niets gewijzigd"

    require pacman omarchy
    check_omarchy_version soepel || true

    local problems=0

    if [[ "$DO_CLI" == true ]]; then
        heading "CLI Toolkit"

        inventory_cli
        show_cli_overview
    fi

    if [[ "$DO_DOCKER" == true ]]; then
        heading "Docker Toolbox"

        require systemctl grep awk

        if check_docker_paths; then
            success "Docker-paden zijn in orde."
        else
            problems=1
        fi

        if docker_available; then
            success "Docker en docker.service zijn aanwezig."
        else
            warning "Docker of docker.service ontbreekt."
            problems=1
        fi

        if [[ -x "$SCRIPT_PATH" ]]; then
            success "dtool is aanwezig."
        else
            info "dtool is nog niet geïnstalleerd."
        fi
    fi

    if [[ "$DO_THEME" == true ]]; then
        heading "Rustig Signaal"

        check_theme_preconditions
        check_theme_packages
    fi

    heading "ShellCheck"
    run_shellcheck || problems=1

    if (( problems == 0 )); then
        success "Controle afgerond."
        return 0
    fi

    warning "Controle afgerond met aandachtspunten."
    return 1
}

# ============================================================
# UNINSTALL-MODUS
# ============================================================

run_uninstall() {
    require sudo systemctl grep awk

    check_docker_paths ||
        die "Voorcontrole mislukt. Er is niets gewijzigd."

    heading "Docker Toolbox verwijderen"

    echo "Wordt verwijderd:"
    echo "  - dtool"
    echo "  - Docker-aliassen"
    echo "  - Docker-blok uit ~/.bashrc"
    echo "  - systemd-drop-in"
    echo
    echo "Blijft behouden:"
    echo "  - Docker-images"
    echo "  - Docker-volumes"
    echo "  - Docker-containers"
    echo "  - Systeempakketten"
    echo "  - Alle back-ups"
    echo

    if [[ "$DRY_RUN" == true ]]; then
        info "DRY-RUN: er is niets gewijzigd."
        return 0
    fi

    confirm "Docker Toolbox verwijderen?" || {
        warning "Verwijderen geannuleerd."
        return 0
    }

    init_log
    start_sudo_keepalive

    uninstall_docker_toolbox ||
        die "Verwijderen niet volledig afgerond."
}

# ============================================================
# INSTALLATIEMODUS
# ============================================================

run_install() {
    if [[ "$DO_CLI" != true && "$DO_DOCKER" != true && "$DO_THEME" != true ]]; then
        warning "Alle onderdelen zijn overgeslagen."
        return 0
    fi

    local needs_system=false

    [[ "$DO_CLI" != true && "$DO_DOCKER" != true ]] ||
        needs_system=true

    STEP_TOTAL=3

    [[ "$needs_system" != true ]] || STEP_TOTAL=$((STEP_TOTAL + 1))
    [[ "$DO_CLI" != true ]] || STEP_TOTAL=$((STEP_TOTAL + 1))
    [[ "$DO_DOCKER" != true ]] || STEP_TOTAL=$((STEP_TOTAL + 1))
    [[ "$DO_THEME" != true ]] || STEP_TOTAL=$((STEP_TOTAL + 1))

    heading "Omarchy Plus Rustig ${VERSION}"

    echo "CLI Toolkit          : $(yes_no "$DO_CLI")"
    echo "Docker Toolbox       : $(yes_no "$DO_DOCKER")"
    echo "Rustig Signaal       : $(yes_no "$DO_THEME")"
    echo "Systeemupdate        : $(yes_no "$needs_system")"
    echo "Update overslaan    : $(yes_no "$SKIP_UPDATE")"
    echo

    # --------------------------------------------------------
    # VOORCONTROLES
    # --------------------------------------------------------

    step "Voorcontroles"

    require pacman omarchy

    if [[ "$needs_system" == true ]]; then
        require sudo
    fi

    if [[ "$needs_system" == true && "$SKIP_UPDATE" != true ]]; then
        check_omarchy_version soepel || true
    else
        check_omarchy_version streng
    fi

    if [[ "$DO_DOCKER" == true ]]; then
        require docker systemctl grep awk cmp install readlink mktemp

        check_docker_paths ||
            die "Docker-voorcontrole mislukt."

        # Docker wordt vóór de systeemupdate gecontroleerd.
        docker_available ||
            die "Docker of docker.service ontbreekt. Configureer Docker eerst of gebruik --skip-docker."

        DOCKER_BIN="$(readlink -f "$(command -v docker)")"

        [[ -x "$DOCKER_BIN" ]] ||
            die "Docker-binary is niet uitvoerbaar."
    fi

    if [[ "$DO_THEME" == true ]]; then
        check_theme_preconditions
    fi

    if [[ "$DO_CLI" == true ]]; then
        inventory_cli
    fi

    success "Voorcontroles geslaagd."

    # --------------------------------------------------------
    # DRY-RUN
    # --------------------------------------------------------

    if [[ "$DRY_RUN" == true ]]; then
        heading "DRY-RUN"

        if [[ "$needs_system" == true ]]; then
            if [[ "$SKIP_UPDATE" == true ]]; then
                info "Omarchy-update wordt overgeslagen."
            else
                info "Omarchy-update zou worden uitgevoerd."
            fi
        fi

        if [[ "$DO_CLI" == true ]]; then
            show_cli_overview
            info "CLI-pakketten te installeren: ${#INSTALL_LIST[@]}"
        fi

        if [[ "$DO_DOCKER" == true ]]; then
            info "Docker Toolbox zou worden bijgewerkt."
        fi

        if [[ "$DO_THEME" == true ]]; then
            check_theme_packages
            show_theme_overview
            info "Rustig Signaal zou worden geïnstalleerd."
        fi

        info "DRY-RUN: geen bestanden, pakketten of services gewijzigd."
        return 0
    fi

    # --------------------------------------------------------
    # OVERZICHT EN ÉÉN BEVESTIGING
    # --------------------------------------------------------

    step "Overzicht en bevestiging"

    if [[ "$DO_CLI" == true ]]; then
        show_cli_overview
    fi

    if [[ "$DO_DOCKER" == true ]]; then
        echo
        echo "Docker Toolbox:"
        echo "  - dtool"
        echo "  - Aliassen"
        echo "  - Bash-integratie"
        echo "  - systemd-drop-in"
    fi

    if [[ "$DO_THEME" == true ]]; then
        show_theme_overview
        check_theme_packages
    fi

    echo
    echo "BELANGRIJK:"
    echo "  - Omarchy-update werkt ook systeempakketten bij."
    echo "  - Eventuele AUR-pakketten kunnen eveneens worden bijgewerkt."
    echo "  - Dit script start geen herstart."
    echo "  - Bij een update die een herstart vereist, stopt de installatie."
    echo

    confirm "Het volledige installatieplan uitvoeren?" || {
        warning "Installatie geannuleerd. Er is niets gewijzigd."
        return 0
    }

    # --------------------------------------------------------
    # LOG EN SUDO
    # --------------------------------------------------------

    init_log

    if [[ "$needs_system" == true ]]; then
        start_sudo_keepalive
    fi

    # --------------------------------------------------------
    # UPDATE
    # --------------------------------------------------------

    if [[ "$needs_system" == true ]]; then
        step "Omarchy bijwerken"

        local update_result=0
        run_omarchy_update || update_result=$?

        case "$update_result" in
            0)
                check_omarchy_version streng
                ;;
            2)
                stop_sudo_keepalive
                warning "Installatie onderbroken wegens benodigde herstart."
                info "Start na de herstart opnieuw:"
                printf '  bash %q\n' "$0"
                return 2
                ;;
            *)
                stop_sudo_keepalive
                die "Omarchy-update mislukt. Volgende stappen zijn niet uitgevoerd."
                ;;
        esac
    fi

    # Na de update opnieuw de pakketinventaris bepalen.
    if [[ "$DO_CLI" == true ]]; then
        inventory_cli
    fi

    # --------------------------------------------------------
    # INSTALLATIE
    # --------------------------------------------------------

    local cli_result="overgeslagen"
    local docker_result="overgeslagen"
    local theme_result="overgeslagen"
    local failures=0

    if [[ "$DO_CLI" == true ]]; then
        step "CLI Toolkit"

        if install_cli_packages; then
            cli_result="OK"
        else
            cli_result="MISLUKT"
            failures=1
        fi
    fi

    if [[ "$DO_DOCKER" == true ]]; then
        step "Docker Toolbox"

        if install_docker_toolbox; then
            docker_result="OK"
        else
            docker_result="MISLUKT"
            failures=1
        fi
    fi

    stop_sudo_keepalive

    if [[ "$DO_THEME" == true ]]; then
        step "Rustig Signaal"

        check_theme_packages

        if install_theme; then
            theme_result="OK"
        else
            theme_result="MISLUKT"
            failures=1
        fi
    fi

    # --------------------------------------------------------
    # EINDRAPPORT
    # --------------------------------------------------------

    step "Eindrapport"

    run_shellcheck || true

    echo

    report_line() {
        case "$2" in
            OK)
                success "$1: OK"
                ;;
            MISLUKT)
                error "$1: MISLUKT"
                ;;
            *)
                info "$1: overgeslagen"
                ;;
        esac
    }

    report_line "CLI Toolkit" "$cli_result"
    report_line "Docker Toolbox" "$docker_result"
    report_line "Rustig Signaal" "$theme_result"

    echo
    info "Logbestand: $LOG_FILE"

    if [[ -n "$THEME_BACKUP_DIR" ]]; then
        info "Thema-back-up: $THEME_BACKUP_DIR"
        info "Herstelcommando:"
        printf '  bash %q --restore %q\n' "$0" "$THEME_BACKUP_DIR"
    fi

    if [[ "$docker_result" == "OK" ]]; then
        info "Docker Toolbox verwijderen:"
        printf '  bash %q --uninstall\n' "$0"
    fi

    echo

    if (( failures == 0 )); then
        success "Installatie afgerond."
        info "Open een nieuwe terminal."

        [[ "$docker_result" != "OK" ]] ||
            info "Test Docker Toolbox met: dtool help"

        return 0
    fi

    warning "Niet alle onderdelen zijn succesvol afgerond."
    info "Bekijk het logbestand en controleer met --check."

    return 1
}

# ============================================================
# START
# ============================================================

main() {
    parse_arguments "$@"

    [[ "$EUID" -ne 0 ]] ||
        die "Voer dit script niet uit als root of met sudo."

    [[ -n "${HOME:-}" && -d "$HOME" ]] ||
        die "HOME is niet beschikbaar."

    [[ "$(uname -s)" == "Linux" ]] ||
        die "Dit script is uitsluitend bedoeld voor Linux."

    case "$MODE" in
        check)
            run_check
            ;;

        restore)
            require pacman omarchy
            check_omarchy_version streng
            check_theme_requirements
            check_managed_paths
            restore_theme
            ;;

        uninstall)
            run_uninstall
            ;;

        install)
            run_install
            ;;
    esac
}

main "$@"
