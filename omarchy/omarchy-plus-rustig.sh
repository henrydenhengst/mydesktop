#!/usr/bin/env bash
#
# Omarchy Plus Rustig
# CLI Toolkit + Docker Toolbox + thema "Rustig Signaal"
# Omarchy / Arch Linux
# Versie: 4.0.0
#
# Samengevoegd uit:
#   - Omarchy Plus 3.2.1
#   - FreeBoot Rustig Signaal v3
#
# Onderdelen (altijd in deze volgorde):
#   1. CLI Toolkit      Systeempakketten via: omarchy pkg add
#   2. Docker Toolbox   dtool CLI, aliassen, Bash-integratie,
#                       systemd drop-in voor automatische cleanup
#   3. Rustig Signaal   Rustig kleurenthema, eza, Kitty, Bash, Zsh, Fish
#
# Gebruik:
#   bash omarchy-plus-rustig.sh --help
#   bash omarchy-plus-rustig.sh --check      (alleen controleren)
#   bash omarchy-plus-rustig.sh --dry-run    (alleen tonen)
#   bash omarchy-plus-rustig.sh              (installeren)
#
# Vaste afspraken:
#   - Er wordt eerst gevraagd, daarna pas gewijzigd.
#   - Omarchy-update vooraf bij CLI Toolkit of Docker Toolbox
#     (niet bij alleen het thema; overslaan met --skip-update).
#   - Geen losse pacman -Syu. Geen AUR-installatie door dit script.
#   - Geen automatische serviceactivatie. Geen herstart door dit script.
#   - Van bestaande configuratiebestanden wordt eerst een back-up gemaakt.
#   - Systeempakketten worden nooit verwijderd.
#   - Docker-images, -volumes en -containers blijven behouden bij --uninstall.
#
# ============================================================

set -Eeuo pipefail
umask 077

readonly VERSION="4.0.0"

# ============================================================
# INSTELLINGEN
# ============================================================

# --- Algemeen ---
readonly STATE_DIR="${HOME}/.local/state/omarchy-plus"
readonly BASHRC="${HOME}/.bashrc"

# --- Docker Toolbox ---
readonly CONFIG_DIR="${HOME}/.config/docker-toolbox"
readonly DOCKER_BACKUP_DIR="${CONFIG_DIR}/backups"
readonly BIN_DIR="${HOME}/.local/bin"
readonly SCRIPT_PATH="${BIN_DIR}/dtool"
readonly ALIAS_FILE="${CONFIG_DIR}/aliases.sh"

readonly DROPIN_DIR="/etc/systemd/system/docker.service.d"
readonly DROPIN_FILE="${DROPIN_DIR}/docker-toolbox.conf"

readonly OLD_SERVICE="docker-toolbox-cleanup.service"
readonly OLD_SERVICE_FILE="/etc/systemd/system/${OLD_SERVICE}"
readonly OLD_CLEANUP="${CONFIG_DIR}/cleanup.sh"

readonly BEGIN_MARK="# >>> DOCKER_TOOLBOX >>>"
readonly END_MARK="# <<< DOCKER_TOOLBOX <<<"
readonly OLD_BEGIN="# DOCKER_TOOLBOX"
readonly OLD_END="# Einde Docker Toolbox"

# --- Thema Rustig Signaal ---
# De namen en paden zijn gelijk aan FreeBoot Rustig Signaal v3,
# zodat eerdere installaties en back-ups blijven werken.
readonly THEME_NAME="freeboot-rustig-signaal"
readonly THEME_DIR="${HOME}/.config/omarchy/themes/${THEME_NAME}"
readonly EZA_DIR="${HOME}/.config/eza"
readonly EZA_THEME="${EZA_DIR}/theme.yml"
readonly KITTY_CONFIG="${HOME}/.config/kitty/kitty.conf"
readonly THEME_BACKUP_ROOT="${HOME}/.local/share/freeboot/backups"

# Omarchy 4 bewaart de themanaam in .local/state, Omarchy 3 in .config.
readonly THEME_NAME_FILE_V4="${HOME}/.local/state/omarchy/current/theme.name"
readonly THEME_NAME_FILE_V3="${HOME}/.config/omarchy/current/theme.name"

readonly MARKER_BEGIN="# >>> FREEBOOT RUSTIG SIGNAAL >>>"
readonly MARKER_END="# <<< FREEBOOT RUSTIG SIGNAAL <<<"

MANAGED_PATHS=(
    ".config/omarchy/themes/${THEME_NAME}"
    ".config/eza/theme.yml"
    ".config/kitty/kitty.conf"
    ".config/fish/conf.d/freeboot-rustig-signaal.fish"
    ".bashrc"
    ".zshrc"
)

# ============================================================
# KLEURENPALET (thema)
# ============================================================
#
# Vaste betekenis:
#   rood   = fout          oranje = waarschuwing
#   groen  = gelukt        blauw  = informatie

readonly BG="#24262b"
readonly FG="#cfd2d6"

readonly C_RED="#e8707c"
readonly C_ORANGE="#e0a050"
readonly C_GREEN="#76c9a0"
readonly C_BLUE="#7aa2d4"
readonly C_MUTED="#8a909a"

readonly SELECTION="#3a3f4b"
readonly BRIGHT_FG="#e6e8eb"

readonly DARKER_BG="#1a1c20"
readonly DARK_BG="#1e2025"

readonly C_PURPLE="#c9a0dc"
readonly C_YELLOW="#e0c080"

# ============================================================
# PAKKETLIJSTEN
# ============================================================

# CLI Toolkit: wordt geïnstalleerd.  Opbouw: categorie|pakket|commando
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
EOF
)

# Thema: deze lijst wordt alleen GECONTROLEERD, niet geïnstalleerd.
THEME_PACKAGES=(
  bash zsh fish starship tmux screen less man-db man-pages parallel
  eza bat ripgrep fd fzf zoxide tree ncdu dust duf
  git git-delta lazygit tig github-cli
  neovim helix
  jq yq
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
  inetutils iproute2 iputils openbsd-netcat socat
  tealdeer
)

# ============================================================
# STATUS
# ============================================================

MODE="install"          # install | check | restore | uninstall
DRY_RUN=false
ASSUME_YES=false
SKIP_UPDATE=false
DO_CLI=true
DO_DOCKER=true
DO_THEME=true
SELECTION_USED=false    # true zodra een --skip-... of --only-... is gebruikt
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
# Elke melding begint met een vast woord. Kleur is alleen extra.
# NO_COLOR=1 zet alle kleur uit.

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
    local color="$1" label="$2"
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
    warning "Een deel van de stappen kan al uitgevoerd zijn. Controleer met: bash $0 --check"
    [[ -z "$THEME_BACKUP_DIR" ]] || warning "Thema-back-up: $THEME_BACKUP_DIR"
    exit 130
}

trap cleanup_on_exit EXIT
trap on_interrupt INT TERM
trap 'error "Onverwachte fout op regel ${LINENO}. Het script stopt."' ERR

start_sudo_keepalive() {
    info "Het script heeft beheerdersrechten (sudo) nodig. Mogelijk wordt nu je wachtwoord gevraagd."
    sudo -v || die "Geen sudo-rechten. Er is niets geïnstalleerd."
    (
        trap - ERR EXIT INT
        sleep_pid=""
        trap '[[ -z "$sleep_pid" ]] || kill "$sleep_pid" 2>/dev/null; exit 0' TERM
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
        command_exists "$cmd" || die "Vereist commando ontbreekt: $cmd"
    done
}

confirm() {
    local prompt="$1"
    local answer=""

    [[ "$ASSUME_YES" == true ]] && return 0

    if ! { : < /dev/tty; } 2>/dev/null; then
        die "Geen interactieve terminal beschikbaar. Gebruik --yes om zonder vragen door te gaan."
    fi

    echo
    echo "Typ j en druk op Enter om door te gaan."
    echo "Druk alleen op Enter om te stoppen."
    read -r -p "$prompt [j/N] " answer < /dev/tty || answer=""

    case "${answer,,}" in
        j|ja|y|yes) return 0 ;;
        *)          return 1 ;;
    esac
}

# ============================================================
# OMARCHY-SYSTEEMUPDATE
# ============================================================

reboot_required() {
    [[ -e /run/reboot-required || -e /var/run/reboot-required ]] && return 0
    [[ -f "${HOME}/.local/state/omarchy/reboot-required" ]] && return 0

    local modules
    modules="/usr/lib/modules/$(uname -r)"
    [[ -d "$modules" ]] || return 0

    # Na een kernelupdate hoort de actieve kernel niet meer bij een pakket.
    if [[ -f "${modules}/modules.builtin" ]]; then
        pacman -Qo "${modules}/modules.builtin" >/dev/null 2>&1 || return 0
    fi
    return 1
}

# Uitkomst: 0 = gelukt, 1 = mislukt, 2 = eerst herstarten
run_omarchy_update() {
    if [[ "$SKIP_UPDATE" == true ]]; then
        info "Omarchy-update bewust overgeslagen (--skip-update)."
        return 0
    fi

    info "Eerst wordt Omarchy bijgewerkt via de officiële updateworkflow (omarchy update)."
    info "Dit kan enkele minuten duren. Dat is normaal."
    info "Omarchy kan zelf nog vragen stellen. Kies je daarbij voor herstarten,"
    info "start dit script dan na de herstart opnieuw."

    confirm "Nu 'omarchy update' uitvoeren?" || {
        warning "Update en installatie geannuleerd. Er is niets gewijzigd."
        exit 0
    }

    # -y slaat alleen de startvraag van Omarchy over (die is hierboven al gesteld).
    # Zonder -y meldt Omarchy ook "gelukt" als de update wordt geannuleerd.
    # OMARCHY_UPDATE_UNATTENDED=0 houdt de overige vragen van Omarchy actief.
    if ! OMARCHY_UPDATE_UNATTENDED=0 omarchy update -y; then
        error "Omarchy-update is mislukt. Omarchy Plus installeert niets."
        error "Lees de melding hierboven of het bestand /tmp/omarchy-update.log."
        return 1
    fi

    success "Omarchy-update is afgerond."
    if reboot_required; then
        warning "Een herstart is nodig na de update."
        info "Herstart met: omarchy system reboot"
        info "Start daarna dit script opnieuw."
        info "Blijft deze melding na een herstart terugkomen, gebruik dan --skip-update."
        return 2
    fi
    return 0
}

# ============================================================
# BACK-UPS (Docker Toolbox)
# ============================================================

check_backup_dir() {
    [[ ! -L "$CONFIG_DIR" && ! -L "$DOCKER_BACKUP_DIR" ]] || {
        error "Back-upmap is een symbolische link; handmatige controle nodig."
        return 1
    }
    mkdir -p "$DOCKER_BACKUP_DIR"
}

# Zet een nog niet bestaande back-upnaam in BACKUP_TARGET.
backup_target() {
    local base counter=1
    base="${DOCKER_BACKUP_DIR}/$(basename "$1").$(date +%Y%m%d-%H%M%S).$$"
    BACKUP_TARGET="$base"
    while [[ -e "$BACKUP_TARGET" ]]; do
        counter=$((counter + 1))
        BACKUP_TARGET="${base}.${counter}"
    done
}

backup() {
    local file="$1"

    [[ -e "$file" || -L "$file" ]] || return 0
    [[ ! -L "$file" ]] || { error "Back-up geweigerd: symbolische link: $file"; return 1; }
    [[ -f "$file" ]] || { error "Back-up geweigerd: geen regulier bestand: $file"; return 1; }

    check_backup_dir || return 1
    backup_target "$file"

    cp -- "$file" "$BACKUP_TARGET" || return 1
    chmod 600 "$BACKUP_TARGET" || return 1

    info "Back-up gemaakt: $BACKUP_TARGET"
}

backup_system_file() {
    local file="$1"

    sudo test -e "$file" || return 0
    sudo test ! -L "$file" || { error "Systeemback-up geweigerd: symbolische link: $file"; return 1; }
    sudo test -f "$file" || { error "Systeemback-up geweigerd: geen regulier bestand: $file"; return 1; }

    check_backup_dir || return 1
    backup_target "$file"

    sudo cp -- "$file" "$BACKUP_TARGET" || return 1
    sudo chown "$(id -u):$(id -g)" "$BACKUP_TARGET" || return 1
    chmod 600 "$BACKUP_TARGET" || return 1

    info "Systeemback-up gemaakt: $BACKUP_TARGET"
}

# ============================================================
# BASH-BLOKKEN (Docker Toolbox)
# ============================================================

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

    # De lege regel direct voor het blok verdwijnt mee, zodat het bestand
    # niet bij elke uitvoering langer wordt.
    if ! awk -v b="$begin" -v e="$end" '
        $0 == b { inside=1; held=0; next }
        $0 == e && inside { inside=0; next }
        inside { next }
        held { print blank; held=0 }
        /^[[:space:]]*$/ { blank=$0; held=1; next }
        { print }
        END { if (held) print blank }
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

# ============================================================
# OUDE VERSIE 1.x OPRUIMEN
# ============================================================

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

# ============================================================
# ONDERDEEL 1: CLI TOOLKIT
# ============================================================

is_installed() {
    # Alleen de pakketdatabase is leidend; een gelijknamig commando uit
    # een ander pakket mag dit pakket niet als geïnstalleerd markeren.
    pacman -Qq "$1" >/dev/null 2>&1
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

        if is_installed "$package"; then
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
        success "Alle beschikbare CLI-gereedschappen zijn al aanwezig."
        return 0
    fi

    info "CLI-installatie: ${#INSTALL_LIST[@]} pakketten in één pakkettransactie."
    info "Dit kan enkele minuten duren. Dat is normaal."

    local entry category package cmd
    local -a packages=()
    for entry in "${INSTALL_LIST[@]}"; do
        IFS='|' read -r category package cmd <<< "$entry"
        packages+=("$package")
    done

    # Eén aanroep voorkomt tientallen afzonderlijke pakkettransacties.
    # tee: je ziet de voortgang en alles staat ook in het logbestand.
    if ! omarchy pkg add "${packages[@]}" 2>&1 | tee -a "$LOG_FILE"; then
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
}

# ============================================================
# ONDERDEEL 2: DOCKER TOOLBOX
# ============================================================

check_docker_paths() {
    validate_bashrc || {
        error "Bash-integratie kon niet worden gevalideerd."
        return 1
    }
    [[ ! -L "$SCRIPT_PATH" && ! -L "$ALIAS_FILE" ]] || {
        error "dtool of aliases.sh is een symbolische link; handmatige controle nodig."
        return 1
    }
    [[ ! -L "$CONFIG_DIR" && ! -L "$BIN_DIR" && ! -L "$DOCKER_BACKUP_DIR" ]] || {
        error "Configuratie-, back-up- of bin-map is een symbolische link; handmatige controle nodig."
        return 1
    }
}

docker_available() {
    command_exists docker &&
        [[ "$(systemctl show docker.service -p LoadState --value 2>/dev/null)" == "loaded" ]]
}

install_dtool() {
    local temp
    [[ ! -L "$SCRIPT_PATH" ]] || { error "Weiger dtool te overschrijven: symbolische link."; return 1; }
    backup "$SCRIPT_PATH" || return 1
    temp="$(mktemp "${BIN_DIR}/.dtool.XXXXXX")" || return 1
    TEMP_PATHS+=("$temp")

    cat > "$temp" <<'DTOOL' || return 1
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

    check_mount_path "$(pwd -P)"
    WORK=(-v "$(pwd -P):/werk" -w /werk)
}

# Docker gebruikt ":" als scheidingsteken bij het koppelen van mappen.
check_mount_path() {
    [[ "$1" != *:* ]] ||
        die "De mapnaam bevat een dubbele punt (:). Docker kan die niet koppelen: $1"
}

check_scan_directory() {
    if is_restricted_dir; then
        die "Scan vanuit een projectsubmap.
De volledige thuismap en / worden niet automatisch gescand."
    fi
}

check_docker() {
    local output

    # </dev/null: voorkomt dat deze controle invoer opeet die voor
    # de container bedoeld is (bijvoorbeeld bij dtool hadolint).
    if output="$(docker info 2>&1 </dev/null)"; then
        return 0
    fi

    if grep -qi "permission denied" <<<"$output"; then
        sudo -v </dev/null || die "Geen sudo-rechten."
        DOCKER=(sudo docker)

        sudo docker info >/dev/null 2>&1 </dev/null ||
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

    # Eerst Docker controleren, daarna pas het adres tonen.
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
        check_mount_path "$(pwd -P)"

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
            sudo -v </dev/null || die "Geen sudo-rechten."
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

        check_mount_path "$dir"

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
        error "Gegenereerde dtool bevat een Bash-syntaxfout; bestaande versie blijft behouden."
        return 1
    fi
    chmod 755 "$temp" || return 1
    mv -f -- "$temp" "$SCRIPT_PATH" || return 1
    success "dtool CLI geïnstalleerd: $SCRIPT_PATH"
}

install_aliases() {
    local temp
    [[ ! -L "$ALIAS_FILE" ]] || { error "Weiger aliases.sh te overschrijven: symbolische link."; return 1; }
    backup "$ALIAS_FILE" || return 1
    temp="$(mktemp "${CONFIG_DIR}/.aliases.XXXXXX")" || return 1
    TEMP_PATHS+=("$temp")

    cat > "$temp" <<'ALIASES' || return 1
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
    TEMP_PATHS+=("$temp")

    # Kopieer zonder lege regels aan het einde, zodat het bestand
    # niet bij elke uitvoering langer wordt.
    awk '
        /^[[:space:]]*$/ { blank = blank $0 ORS; next }
        { printf "%s", blank; blank = ""; print }
    ' "$BASHRC" > "$temp" || {
        error "Kon ~/.bashrc niet veilig kopiëren."
        return 1
    }

    cat >> "$temp" <<'BASHBLOCK' || return 1

# >>> DOCKER_TOOLBOX >>>
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

[[ -f "$HOME/.config/docker-toolbox/aliases.sh" ]] &&
    source "$HOME/.config/docker-toolbox/aliases.sh"
# <<< DOCKER_TOOLBOX <<<
BASHBLOCK

    chmod --reference="$BASHRC" "$temp" || return 1
    chown --reference="$BASHRC" "$temp" || return 1
    if ! mv -f -- "$temp" "$BASHRC"; then
        error "Kon ~/.bashrc niet atomair vervangen."
        return 1
    fi

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
    if ! sudo test -d "$DROPIN_DIR"; then
        sudo install -d -m 755 "$DROPIN_DIR" || return 1
    fi

    local tmp
    tmp="$(mktemp)" || return 1
    TEMP_PATHS+=("$tmp")

    cat > "$tmp" <<EOF || return 1
[Service]
ExecStartPost=-${DOCKER_BIN} container prune --force --filter label=docker-toolbox.temporary=true
EOF

    if sudo test -f "$DROPIN_FILE"; then
        if ! sudo cmp -s "$tmp" "$DROPIN_FILE"; then
            backup_system_file "$DROPIN_FILE" || return 1
            sudo install -m 644 "$tmp" "$DROPIN_FILE" || return 1
            success "Docker systemd-drop-in bijgewerkt."
        else
            info "Docker systemd-drop-in is al actueel."
        fi
    else
        sudo install -m 644 "$tmp" "$DROPIN_FILE" || return 1
        success "Docker systemd-drop-in geïnstalleerd."
    fi

    sudo systemctl daemon-reload || return 1
}

install_docker_toolbox() {
    check_docker_paths || return 1

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

uninstall_docker_toolbox() {
    info "Verwijderen van Docker Toolbox-integratie gestart."

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

    rm -f -- "$ALIAS_FILE" "$SCRIPT_PATH" || return 1

    success "Docker Toolbox verwijderd."
    echo
    info "Behouden: Docker-images, volumes, containers, systeempakketten en back-ups."
    info "Open een nieuwe terminal om de aliassen te verwijderen."
}

# ============================================================
# ONDERDEEL 3: THEMA - CONTROLES
# ============================================================

current_theme_file() {
    if [[ -f "$THEME_NAME_FILE_V4" ]]; then
        printf '%s' "$THEME_NAME_FILE_V4"
    elif [[ -f "$THEME_NAME_FILE_V3" ]]; then
        printf '%s' "$THEME_NAME_FILE_V3"
    fi
}

current_theme() {
    local file
    file="$(current_theme_file)"
    [[ -z "$file" ]] || cat -- "$file"
}

check_theme_requirements() {
    command_exists python3 || die "Python 3 ontbreekt."
    require tar find sort realpath mktemp

    python3 -I -c 'import sys
if sys.version_info < (3, 11):
    raise SystemExit("Python 3.11 of hoger is vereist.")
import tomllib' || die "Python 3.11+ met TOML-ondersteuning is vereist."

    success "Python 3.11+ en TOML-validatie beschikbaar."

    if command_exists omarchy-theme-set; then
        success "Omarchy-themafunctie beschikbaar."
    elif command_exists omarchy; then
        success "Omarchy CLI beschikbaar."
    else
        die "Omarchy-themafunctie niet gevonden."
    fi

    local active
    active="$(current_theme)"
    if [[ -n "$active" ]]; then
        info "Actief thema: $active"
    else
        warning "Actieve themanaam niet gevonden."
    fi
}

check_managed_paths() {
    local rel path

    for rel in "${MANAGED_PATHS[@]}"; do
        path="${HOME}/${rel}"

        [[ ! -L "$path" ]] ||
            die "Symbolische link aangetroffen: $path. Handmatige controle vereist."

        if [[ -e "$path" && ! -f "$path" && ! -d "$path" ]]; then
            die "Onverwacht bestandstype: $path"
        fi
    done

    success "Geen conflicterende symbolische links gevonden."
}

# Controleert vooraf of de FreeBoot-markeringen in bestaande bestanden kloppen,
# zodat de installatie niet halverwege stopt.
check_theme_blocks() {
    python3 -I - "$MARKER_BEGIN" "$MARKER_END" \
        "$BASHRC" "${HOME}/.zshrc" "$KITTY_CONFIG" <<'PY' || die "Herstel eerst de markeringen in het genoemde bestand."
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
    if len(starts) != len(ends) or len(starts) > 1 or (starts and ends[0] < starts[0]):
        raise SystemExit(f"Ongeldige of dubbele FreeBoot-markeringen in {name}")
PY
}

check_theme_directory() {
    [[ -d "$THEME_DIR" ]] || return 0

    local extra
    extra="$(find "$THEME_DIR" -mindepth 1 ! -name colors.toml -print -quit)"

    [[ -z "$extra" ]] || die "Bestaande themamap bevat extra bestanden: $extra
Maak eerst handmatig een back-up en controleer deze bestanden."
}

check_theme_preconditions() {
    check_theme_requirements
    check_managed_paths
    check_theme_blocks
    check_theme_directory
}

check_theme_packages() {
    local package
    local -a missing=()

    for package in "${THEME_PACKAGES[@]}"; do
        pacman -Q "$package" >/dev/null 2>&1 || missing+=("$package")
    done

    echo
    printf 'Pakketten in controlelijst : %s\n' "${#THEME_PACKAGES[@]}"
    printf 'Geïnstalleerd             : %s\n' "$(( ${#THEME_PACKAGES[@]} - ${#missing[@]} ))"
    printf 'Ontbrekend                : %s\n' "${#missing[@]}"

    if (( ${#missing[@]} > 0 )); then
        printf '\nOntbrekende pakketten:\n'
        printf '  - %s\n' "${missing[@]}"
    fi

    echo
    info "Deze controlelijst installeert niets. Dit is alleen een overzicht."
}

show_theme_overview() {
    echo
    printf 'Thema              : %s\n' "$THEME_NAME"
    printf 'Themamap           : %s\n' "$THEME_DIR"
    printf 'eza-configuratie   : %s\n' "$EZA_THEME"
    printf 'Kitty-configuratie : %s\n' "$KITTY_CONFIG"
    printf 'Shellbestanden     : .bashrc, .zshrc en een Fish-bestand\n'
    printf 'Back-upmap         : %s\n' "$THEME_BACKUP_ROOT"
}

# ============================================================
# THEMA - BACK-UP
# ============================================================

# $1 = voorvoegsel (leeg bij installatie, "voor-herstel-" bij herstel)
create_theme_backup() {
    local prefix="${1:-}"
    local base target counter=1

    mkdir -p "$THEME_BACKUP_ROOT" || return 1

    base="${THEME_BACKUP_ROOT}/${prefix}$(date '+%Y%m%d-%H%M%S')"
    target="$base"
    while [[ -e "$target" ]]; do
        counter=$((counter + 1))
        target="${base}-${counter}"
    done
    mkdir -- "$target" || return 1

    local -a existing=()
    local rel
    for rel in "${MANAGED_PATHS[@]}"; do
        [[ ! -e "${HOME}/${rel}" ]] || existing+=("$rel")
    done

    if (( ${#existing[@]} > 0 )); then
        tar -cpf "${target}/files.tar" -C "$HOME" -- "${existing[@]}" || return 1
        printf '%s\n' "${existing[@]}" > "${target}/existing-paths.txt" || return 1
    else
        tar -cpf "${target}/files.tar" --files-from /dev/null || return 1
        : > "${target}/existing-paths.txt" || return 1
    fi

    current_theme > "${target}/previous-theme.txt" || return 1
    printf '%s\n' "${MANAGED_PATHS[@]}" > "${target}/managed-paths.txt" || return 1

    THEME_BACKUP_DIR="$target"
    success "Back-up gemaakt: $target"
}

# ============================================================
# THEMA - BESTANDEN SCHRIJVEN
# ============================================================

# Leest de inhoud van standaardinvoer en vervangt het doelbestand in één keer.
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
    mv -f -- "$temp" "$target"
}

write_colors() {
    write_atomic "${THEME_DIR}/colors.toml" 0644 <<EOF || return 1
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
# Terminals gebruiken "yellow" voor waarschuwingen: daarom oranje.
yellow = "$C_ORANGE"
bright_yellow = "$C_YELLOW"
green = "$C_GREEN"
blue = "$C_BLUE"
purple = "$C_PURPLE"

# ANSI-kleuren

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

    python3 -I - "${THEME_DIR}/colors.toml" <<'PY' || return 1
import re
import sys
import tomllib

with open(sys.argv[1], "rb") as handle:
    data = tomllib.load(handle)

required = [
    "mode", "accent", "selection", "muted", "cursor",
    "selection_background", "selection_foreground",
    "background", "dark_background", "darker_background", "lighter_background",
    "foreground", "dark_foreground", "light_foreground", "bright_foreground",
    "red", "orange", "yellow", "green", "blue",
] + [f"color{number}" for number in range(16)]

for key in required:
    if key not in data:
        raise SystemExit(f"Ontbrekende TOML-sleutel: {key}")

for key, value in data.items():
    if key == "mode":
        continue
    if not isinstance(value, str) or not re.fullmatch(r"#[0-9a-fA-F]{6}", value):
        raise SystemExit(f"Ongeldige hexkleur: {key} = {value}")
PY

    success "colors.toml aangemaakt en gevalideerd."
}

write_eza_theme() {
    write_atomic "$EZA_THEME" 0644 <<EOF || return 1
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

    success "eza-thema aangemaakt."
}

# Vervangt alleen het eigen blok in een bestand. De rest blijft behouden.
update_managed_block() {
    local target="$1"
    local snippet="$2"

    python3 -I - "$target" "$snippet" "$MARKER_BEGIN" "$MARKER_END" <<'PY'
import os
import pathlib
import sys
import tempfile

target = pathlib.Path(sys.argv[1])
snippet = pathlib.Path(sys.argv[2])
begin = sys.argv[3].encode()
end = sys.argv[4].encode()

lines = target.read_bytes().split(b"\n") if target.exists() else []

starts = [i for i, line in enumerate(lines) if line == begin]
ends = [i for i, line in enumerate(lines) if line == end]

if len(starts) != len(ends):
    raise SystemExit(f"Ongeldige FreeBoot-markeringen in {target}")
if len(starts) > 1:
    raise SystemExit(f"Dubbele FreeBoot-blokken in {target}")
if starts:
    if ends[0] < starts[0]:
        raise SystemExit(f"Ongeldige blokvolgorde in {target}")
    first = starts[0]
    # Ook de lege regel direct voor het blok verwijderen.
    if first > 0 and not lines[first - 1].strip():
        first -= 1
    lines = lines[:first] + lines[ends[0] + 1:]

while lines and not lines[-1].strip():
    lines.pop()

if lines:
    lines.append(b"")
lines += [begin, snippet.read_bytes().rstrip(), end]
content = b"\n".join(lines) + b"\n"

target.parent.mkdir(parents=True, exist_ok=True)
mode = target.stat().st_mode & 0o777 if target.exists() else 0o644

fd, temp_name = tempfile.mkstemp(prefix=".freeboot-", dir=target.parent)
try:
    with os.fdopen(fd, "wb") as handle:
        handle.write(content)
    os.chmod(temp_name, mode)
    os.replace(temp_name, target)
except BaseException:
    try:
        os.unlink(temp_name)
    except FileNotFoundError:
        pass
    raise
PY
}

write_kitty_settings() {
    local snippet
    snippet="$(mktemp)" || return 1
    TEMP_PATHS+=("$snippet")

    cat > "$snippet" <<'EOF' || return 1
# Rustige cursor en geen geluid
cursor_blink_interval 0
cursor_trail 0
enable_audio_bell no
visual_bell_duration 0.0

# Rustige vensterweergave
window_padding_width 8
background_opacity 1.0
dim_opacity 0.7
inactive_text_alpha 1.0
EOF

    update_managed_block "$KITTY_CONFIG" "$snippet" || return 1
    success "Kitty-instellingen toegevoegd."
}

write_shell_settings() {
    local snippet
    snippet="$(mktemp)" || return 1
    TEMP_PATHS+=("$snippet")

    cat > "$snippet" <<'EOF' || return 1
# Rustige FreeBoot-instellingen

export EZA_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/eza"

# eza gebruikt theme.yml; omgevingskleuren hebben voorrang.
unset EZA_COLORS
unset LS_COLORS

# Minder visuele ruis in fzf.
export FZF_DEFAULT_OPTS='--color=bg:#24262b,fg:#cfd2d6,hl:#e0a050,fg+:#e6e8eb,bg+:#3a3f4b,hl+:#e0a050,info:#8a909a,prompt:#7aa2d4,pointer:#76c9a0,marker:#76c9a0,header:#7aa2d4'

# Kleurondersteuning voor less.
export LESS="${LESS:--R}"
EOF

    update_managed_block "$BASHRC" "$snippet" || return 1
    update_managed_block "${HOME}/.zshrc" "$snippet" || return 1
    success "Bash- en Zsh-instellingen toegevoegd."
}

write_fish_settings() {
    write_atomic "${HOME}/.config/fish/conf.d/freeboot-rustig-signaal.fish" 0644 <<'EOF' || return 1
# FreeBoot Rustig Signaal

set -gx EZA_CONFIG_DIR "$HOME/.config/eza"

set -e EZA_COLORS
set -e LS_COLORS

set -gx FZF_DEFAULT_OPTS '--color=bg:#24262b,fg:#cfd2d6,hl:#e0a050,fg+:#e6e8eb,bg+:#3a3f4b,hl+:#e0a050,info:#8a909a,prompt:#7aa2d4,pointer:#76c9a0,marker:#76c9a0,header:#7aa2d4'

set -gx LESS '-R'
EOF

    success "Fish-configuratie aangemaakt."
}

activate_theme() {
    local name="$1"

    info "Thema activeren: $name"
    info "Het scherm kan kort van kleur en achtergrond veranderen. Dat is normaal."

    if command_exists omarchy-theme-set; then
        OMARCHY_THEME_WAIT=1 omarchy-theme-set "$name"
    elif command_exists omarchy; then
        OMARCHY_THEME_WAIT=1 omarchy theme set "$name"
    else
        error "Geen ondersteunde Omarchy-themafunctie gevonden."
        return 1
    fi
}

verify_theme() {
    activate_theme "$THEME_NAME" || { error "Thema activeren is mislukt."; return 1; }

    local active
    active="$(current_theme)"

    [[ -n "$active" ]] || { error "Omarchy heeft geen actieve themanaam geschreven."; return 1; }
    [[ "$active" == "$THEME_NAME" ]] || { error "Actief thema wijkt af: $active"; return 1; }

    success "Omarchy-thema is actief."
}

install_theme() {
    create_theme_backup || { error "Back-up mislukt. Er zijn geen themabestanden gewijzigd."; return 1; }

    write_colors || return 1
    write_eza_theme || return 1
    write_kitty_settings || return 1
    write_shell_settings || return 1
    write_fish_settings || return 1
    verify_theme || return 1
}

# ============================================================
# THEMA - HERSTEL
# ============================================================

latest_theme_backup() {
    [[ -d "$THEME_BACKUP_ROOT" ]] || return 0
    find "$THEME_BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name '20*' |
        sort |
        tail -n 1
}

list_theme_backups() {
    [[ -d "$THEME_BACKUP_ROOT" ]] || return 0
    local dir theme
    echo "Beschikbare back-ups (naam = datum en tijd; voor-herstel = veiligheidskopie):"
    while IFS= read -r dir; do
        theme="$(cat -- "${dir}/previous-theme.txt" 2>/dev/null || true)"
        printf '  - %s   (thema toen: %s)\n' "$dir" "${theme:-onbekend}"
    done < <(find "$THEME_BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d | sort)
}

# Controleert dat het archief uitsluitend beheerde, gewone bestanden bevat.
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
            raise SystemExit(f"Onveilig archiefpad: {member.name}")
        if not (member.isfile() or member.isdir()):
            raise SystemExit(f"Onveilig bestandstype in archief: {member.name}")
        if not any(member.name == item or member.name.startswith(item + "/") for item in allowed):
            raise SystemExit(f"Onverwacht archiefpad: {member.name}")
PY
}

has_docker_block() {
    [[ -f "$BASHRC" ]] && grep -Fqx -- "$BEGIN_MARK" "$BASHRC"
}

restore_theme() {
    local source="$RESTORE_DIR"
    [[ -n "$source" ]] || source="$(latest_theme_backup)"

    [[ -n "$source" && -d "$source" ]] || die "Back-upmap niet gevonden."

    local required
    for required in files.tar managed-paths.txt existing-paths.txt; do
        [[ -f "${source}/${required}" ]] || die "Back-up is onvolledig. Bestand ontbreekt: ${source}/${required}"
    done

    local archive="${source}/files.tar"
    check_theme_archive "$archive" || die "Back-uparchief is afgekeurd. Er is niets gewijzigd."
    success "Back-uparchief gecontroleerd."

    local previous_theme=""
    [[ ! -f "${source}/previous-theme.txt" ]] || previous_theme="$(cat -- "${source}/previous-theme.txt")"

    echo
    list_theme_backups
    echo
    info "Gekozen back-up : $source"
    info "Thema daarin    : ${previous_theme:-onbekend}"
    info "Deze bestanden worden teruggezet (of verwijderd als ze toen niet bestonden):"
    printf '  - ~/%s\n' "${MANAGED_PATHS[@]}"

    if [[ "$DRY_RUN" == true ]]; then
        info "DRY-RUN: er is niets gewijzigd."
        return 0
    fi

    confirm "De huidige beheerde configuratie vervangen door deze back-up?" || {
        warning "Herstel geannuleerd. Er is niets gewijzigd."
        return 0
    }

    local keep_docker_block=false
    ! has_docker_block || keep_docker_block=true

    info "Eerst een veiligheidskopie van de huidige situatie."
    create_theme_backup "voor-herstel-" || die "Veiligheidskopie mislukt. Er is niets hersteld."
    local safety="$THEME_BACKUP_DIR"

    # Eerst volledig uitpakken in een tijdelijke map, pas daarna vervangen.
    local staging
    staging="$(mktemp -d "${HOME}/.freeboot-restore.XXXXXX")" || die "Tijdelijke map maken mislukt."
    TEMP_PATHS+=("$staging")
    tar -xpf "$archive" -C "$staging" || die "Uitpakken mislukt. Er is niets gewijzigd."

    local rel
    for rel in "${MANAGED_PATHS[@]}"; do
        rm -rf -- "${HOME:?}/${rel}" ||
            die "Verwijderen mislukt: ~/${rel}. Veiligheidskopie: $safety"
        if [[ -e "${staging}/${rel}" ]]; then
            mkdir -p "$(dirname "${HOME}/${rel}")" &&
                mv -- "${staging}/${rel}" "${HOME}/${rel}" ||
                die "Terugzetten mislukt: ~/${rel}. Veiligheidskopie: $safety"
        fi
    done

    success "Bestanden uit de back-up hersteld."

    # De Docker Toolbox-koppeling in .bashrc blijft zoals die vlak voor het herstel was.
    if [[ "$keep_docker_block" == true ]]; then
        has_docker_block || install_bashrc_block ||
            warning "Docker Toolbox-blok niet teruggezet. Voer uit: bash $0 --only-docker"
    elif has_docker_block; then
        remove_block "$BEGIN_MARK" "$END_MARK" ||
            warning "Controleer het Docker Toolbox-blok in ~/.bashrc."
    fi

    if [[ -n "$previous_theme" ]]; then
        activate_theme "$previous_theme" ||
            die "Bestanden zijn hersteld, maar thema '$previous_theme' kon niet worden geactiveerd."
        success "Vorige themakeuze hersteld."
    else
        warning "Er was geen vorige themanaam opgeslagen."
    fi

    echo
    success "Herstel afgerond."
    info "Situatie van vóór dit herstel: $safety"
    info "Open een nieuwe terminal."
}

# ============================================================
# HELP
# ============================================================

show_help() {
    cat <<EOF
Omarchy Plus Rustig ${VERSION}

GEBRUIK
  bash $0 [opties]

ZONDER OPTIES
  Alle drie onderdelen: CLI Toolkit, Docker Toolbox en thema.

EERST KIJKEN (wijzigt niets)
  --check             Controleren van de gekozen onderdelen
  --dry-run           Tonen wat er zou gebeuren
  --help, -h          Deze uitleg

ONDERDELEN KIEZEN
  --only-cli          Alleen CLI Toolkit
  --only-docker       Alleen Docker Toolbox
  --only-theme        Alleen thema Rustig Signaal (geen systeemupdate)
  --skip-cli          CLI Toolkit overslaan
  --skip-docker       Docker Toolbox overslaan
  --skip-theme        Thema overslaan

OVERIG
  --skip-update       Voorafgaande Omarchy-update overslaan
  --yes               Vragen van dit script overslaan
                      (Omarchy zelf kan nog om invoer vragen)

TERUGDRAAIEN
  --uninstall         Docker Toolbox verwijderen
  --restore           Themabestanden uit de nieuwste back-up herstellen
  --restore PAD       Themabestanden uit een gekozen back-up herstellen

VASTE VOLGORDE BIJ INSTALLEREN
  1. Voorcontroles (wijzigt niets)
  2. Omarchy bijwerken (niet bij alleen het thema)
  3. Overzicht tonen en bevestiging vragen
  4. CLI Toolkit
  5. Docker Toolbox
  6. Thema Rustig Signaal
  7. Eindrapport

BLIJFT BEHOUDEN
  - Systeempakketten (worden nooit verwijderd)
  - Docker-images, -volumes en -containers (bij --uninstall)
  - Back-ups:
      Docker Toolbox: ${DOCKER_BACKUP_DIR}
      Thema:          ${THEME_BACKUP_ROOT}

LOGBESTAND
  ${STATE_DIR}/install-JJJJMMDD-UUMMSS-PID.log
EOF
}

# ============================================================
# ARGUMENTEN
# ============================================================

set_mode() {
    [[ "$MODE" == "install" || "$MODE" == "$1" ]] ||
        die "Gebruik maar één van deze opties tegelijk: --check, --restore, --uninstall."
    MODE="$1"
}

set_only() {
    [[ -z "$ONLY_USED" || "$ONLY_USED" == "$1" ]] ||
        die "Gebruik maar één --only-... optie tegelijk."
    ONLY_USED="$1"
    SELECTION_USED=true
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)     DRY_RUN=true ;;
            --check)       set_mode check ;;
            --skip-update) SKIP_UPDATE=true ;;
            --yes)         ASSUME_YES=true ;;
            --uninstall)   set_mode uninstall ;;
            --restore)
                set_mode restore
                if [[ $# -gt 1 && "$2" != -* ]]; then
                    RESTORE_DIR="$2"
                    shift
                fi
                ;;
            --skip-cli)    DO_CLI=false;    SELECTION_USED=true ;;
            --skip-docker) DO_DOCKER=false; SELECTION_USED=true ;;
            --skip-theme)  DO_THEME=false;  SELECTION_USED=true ;;
            --only-cli)    set_only cli ;;
            --only-docker) set_only docker ;;
            --only-theme)  set_only theme ;;
            -h|--help)     show_help; exit 0 ;;
            *)             die "Onbekende optie: $1 (zie --help)" ;;
        esac
        shift
    done

    case "$ONLY_USED" in
        cli)    DO_DOCKER=false; DO_THEME=false ;;
        docker) DO_CLI=false;    DO_THEME=false ;;
        theme)  DO_CLI=false;    DO_DOCKER=false ;;
    esac

    if [[ ( "$MODE" == "uninstall" || "$MODE" == "restore" ) && "$SELECTION_USED" == true ]]; then
        die "Gebruik --$MODE niet samen met --skip-... of --only-..."
    fi
}

# ============================================================
# MODI
# ============================================================

run_check() {
    heading "Controle (er wordt niets gewijzigd)"
    require pacman
    local problems=0

    if [[ "$DO_CLI" == true ]]; then
        heading "CLI Toolkit"
        command_exists omarchy || { warning "Commando omarchy ontbreekt."; problems=1; }
        inventory_cli
        show_cli_overview
    fi

    if [[ "$DO_DOCKER" == true ]]; then
        heading "Docker Toolbox"
        require systemctl grep awk
        if check_docker_paths; then success "Paden en ~/.bashrc zijn in orde."; else problems=1; fi
        if docker_available; then
            success "Docker en docker.service zijn aanwezig."
        else
            warning "Docker of docker.service ontbreekt."
            problems=1
        fi
        if [[ -x "$SCRIPT_PATH" ]]; then
            info "dtool is geïnstalleerd."
        else
            info "dtool is nog niet geïnstalleerd."
        fi
    fi

    if [[ "$DO_THEME" == true ]]; then
        heading "Thema Rustig Signaal"
        check_theme_preconditions
        check_theme_packages
    fi

    echo
    if (( problems == 0 )); then
        success "Controle afgerond zonder problemen."
        return 0
    fi
    warning "Controle afgerond. Lees de meldingen met [LET OP] en [FOUT]."
    exit 1
}

run_uninstall() {
    require pacman sudo systemctl grep awk
    check_docker_paths || die "Verwijderen afgebroken. Er is niets gewijzigd."

    heading "Docker Toolbox verwijderen"
    echo "Wordt verwijderd : dtool, aliassen, blok in ~/.bashrc, systemd drop-in"
    echo "Blijft behouden  : Docker-data, systeempakketten, back-ups, thema"

    if [[ "$DRY_RUN" == true ]]; then
        info "DRY-RUN: er is niets gewijzigd."
        return 0
    fi

    confirm "Docker Toolbox verwijderen?" || {
        warning "Actie geannuleerd. Er is niets gewijzigd."
        return 0
    }

    init_log
    start_sudo_keepalive
    uninstall_docker_toolbox || exit 1
}

init_log() {
    [[ ! -L "$STATE_DIR" ]] || die "State-map is een symbolische link; handmatige controle nodig."
    mkdir -p "$STATE_DIR"
    LOG_FILE="${STATE_DIR}/install-$(date +%Y%m%d-%H%M%S)-$$.log"
    : > "$LOG_FILE"
    chmod 600 "$LOG_FILE"
    info "Omarchy Plus Rustig ${VERSION}"
    info "Logbestand: $LOG_FILE"
}

yes_no() {
    if [[ "$1" == true ]]; then echo "ja"; else echo "nee"; fi
}

run_install() {
    if [[ "$DO_CLI" != true && "$DO_DOCKER" != true && "$DO_THEME" != true ]]; then
        warning "Niets te doen: alle onderdelen worden overgeslagen."
        return 0
    fi

    local needs_system=false
    [[ "$DO_CLI" != true && "$DO_DOCKER" != true ]] || needs_system=true

    # Aantal stappen: voorcontrole, overzicht en eindrapport zijn er altijd.
    STEP_TOTAL=3
    [[ "$needs_system" != true ]] || STEP_TOTAL=$((STEP_TOTAL + 1))
    [[ "$DO_CLI" != true ]]    || STEP_TOTAL=$((STEP_TOTAL + 1))
    [[ "$DO_DOCKER" != true ]] || STEP_TOTAL=$((STEP_TOTAL + 1))
    [[ "$DO_THEME" != true ]]  || STEP_TOTAL=$((STEP_TOTAL + 1))

    heading "Omarchy Plus Rustig ${VERSION}"
    echo "CLI Toolkit            : $(yes_no "$DO_CLI")"
    echo "Docker Toolbox         : $(yes_no "$DO_DOCKER")"
    echo "Thema Rustig Signaal   : $(yes_no "$DO_THEME")"
    echo "Aantal stappen         : $STEP_TOTAL"

    # ---------- Voorcontroles ----------
    step "Voorcontroles (wijzigt niets)"
    require pacman
    if [[ "$needs_system" == true ]]; then
        require omarchy sudo
    fi
    if [[ "$DO_DOCKER" == true ]]; then
        require systemctl grep awk cmp install readlink mktemp
        check_docker_paths || die "Voorcontrole Docker Toolbox mislukt. Er is niets gewijzigd."
    fi
    if [[ "$DO_THEME" == true ]]; then
        check_theme_preconditions
    fi
    success "Voorcontroles geslaagd."

    # ---------- Dry-run: volledig alleen-lezen ----------
    if [[ "$DRY_RUN" == true ]]; then
        heading "DRY-RUN: dit zou er gebeuren"
        if [[ "$needs_system" == true ]]; then
            if [[ "$SKIP_UPDATE" == true ]]; then
                info "Omarchy-update zou worden overgeslagen."
            else
                info "Eerst zou 'omarchy update' worden uitgevoerd."
            fi
        fi
        if [[ "$DO_CLI" == true ]]; then
            inventory_cli
            show_cli_overview
            info "Zou ${#INSTALL_LIST[@]} CLI-pakketten installeren."
        fi
        if [[ "$DO_DOCKER" == true ]]; then
            if docker_available; then
                info "Docker en docker.service zijn aanwezig."
            else
                warning "Docker of docker.service ontbreekt; de echte installatie controleert dit na de update."
            fi
            info "Zou Docker Toolbox installeren of bijwerken."
        fi
        if [[ "$DO_THEME" == true ]]; then
            check_theme_packages
            show_theme_overview
            info "Zou een back-up maken, de themabestanden schrijven en het thema activeren."
        fi
        echo
        info "DRY-RUN: geen update, pakketten, bestanden of services zijn gewijzigd."
        return 0
    fi

    # ---------- Update ----------
    if [[ "$needs_system" == true ]]; then
        step "Omarchy bijwerken"
        run_omarchy_update || exit 1
    fi

    if [[ "$DO_DOCKER" == true ]]; then
        command_exists docker ||
            die "Docker ontbreekt. Installeer Docker eerst, of gebruik --skip-docker."
        DOCKER_BIN="$(readlink -f "$(command -v docker)")"
        [[ -x "$DOCKER_BIN" ]] || die "Docker-binary niet uitvoerbaar."
        docker_available || die "docker.service ontbreekt. Configureer Docker eerst, of gebruik --skip-docker."
    fi

    # ---------- Overzicht en bevestiging ----------
    step "Overzicht en bevestiging"
    if [[ "$DO_CLI" == true ]]; then
        inventory_cli
        show_cli_overview
    fi
    [[ "$DO_THEME" != true ]] || show_theme_overview

    echo
    info "Samenvatting:"
    [[ "$DO_CLI" != true ]]    || echo "  - CLI Toolkit: ${#INSTALL_LIST[@]} installeren, ${#SKIP_LIST[@]} overslaan"
    [[ "$DO_DOCKER" != true ]] || echo "  - Docker Toolbox installeren of bijwerken"
    [[ "$DO_THEME" != true ]]  || echo "  - Thema: back-up maken, bestanden aanpassen, thema activeren"

    confirm "Doorgaan?" || {
        warning "Actie geannuleerd. Er zijn geen onderdelen geïnstalleerd."
        return 0
    }

    # ---------- Uitvoeren ----------
    init_log
    [[ "$needs_system" != true ]] || start_sudo_keepalive

    local cli_result="overgeslagen"
    local docker_result="overgeslagen"
    local theme_result="overgeslagen"
    local failures=0

    if [[ "$DO_CLI" == true ]]; then
        step "CLI Toolkit"
        if install_cli_packages; then cli_result="OK"; else cli_result="MISLUKT"; failures=1; fi
    fi

    if [[ "$DO_DOCKER" == true ]]; then
        step "Docker Toolbox"
        if install_docker_toolbox; then docker_result="OK"; else docker_result="MISLUKT"; failures=1; fi
    fi

    stop_sudo_keepalive

    if [[ "$DO_THEME" == true ]]; then
        step "Thema Rustig Signaal"
        # Na de CLI Toolkit, zodat het overzicht de actuele situatie toont.
        check_theme_packages
        if install_theme; then theme_result="OK"; else theme_result="MISLUKT"; failures=1; fi
    fi

    # ---------- Eindrapport ----------
    step "Eindrapport"
    report_line "CLI Toolkit" "$cli_result"
    report_line "Docker Toolbox" "$docker_result"
    report_line "Thema Rustig Signaal" "$theme_result"

    echo
    info "Logbestand: $LOG_FILE"
    if [[ -n "$THEME_BACKUP_DIR" ]]; then
        info "Thema-back-up: $THEME_BACKUP_DIR"
        info "Thema terugdraaien:"
        printf '  bash %q --restore %q\n' "$0" "$THEME_BACKUP_DIR"
    fi
    if [[ "$docker_result" == "OK" ]]; then
        info "Docker Toolbox terugdraaien:"
        printf '  bash %q --uninstall\n' "$0"
    fi

    echo
    if (( failures == 0 )); then
        success "Alles is klaar."
        info "Volgende stap: open een nieuwe terminal."
        [[ "$docker_result" != "OK" ]] || info "Test daarna met: dtool help"
        return 0
    fi
    warning "Niet alles is gelukt. Lees de [FOUT]-meldingen hierboven."
    info "Je kunt dit script veilig opnieuw starten."
    exit 1
}

report_line() {
    case "$2" in
        OK)      success "$1: OK" ;;
        MISLUKT) error "$1: MISLUKT" ;;
        *)       info "$1: overgeslagen" ;;
    esac
}

# ============================================================
# START
# ============================================================

main() {
    parse_arguments "$@"

    [[ "$EUID" -ne 0 ]] || die "Voer dit script niet uit als root of met sudo."
    [[ -n "${HOME:-}" && -d "$HOME" ]] || die "HOME is niet beschikbaar."
    [[ "$(uname -s)" == "Linux" ]] || die "Dit script is uitsluitend bedoeld voor Linux."

    case "$MODE" in
        check)
            run_check
            ;;
        restore)
            require pacman
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
