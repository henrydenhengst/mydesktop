
#!/usr/bin/env bash
#
# Omarchy Plus Rustig
# CLI Toolkit + Docker Toolbox + Rustig Signaal
#
# Versie: 4.3.0
#
# Vereist:
#   Omarchy 4.5+
#   Arch Linux
#   Bash 5+
#   Python 3.11+
#   sudo
#
# Gebruik:
#   bash omarchy-plus-rustig.sh --help
#   bash omarchy-plus-rustig.sh --check
#   bash omarchy-plus-rustig.sh --dry-run
#   bash omarchy-plus-rustig.sh
#
# Veiligheidsprincipes:
#   - Nooit uitvoeren als root.
#   - Eerst controleren, dan inventariseren.
#   - Eén totaalbevestiging voor de installatie.
#   - Geen directe pacman -Syu.
#   - Geen automatische reboot.
#   - Geen automatische serviceactivatie.
#   - Geen Docker-systemd-drop-in.
#   - Geen systeempakketten verwijderen.
#   - Geen bestaande PDF's overschrijven.
#   - Configuratie eerst back-uppen.
#   - Docker-data blijft behouden.
#
# ============================================================

set -Eeuo pipefail
umask 077

readonly VERSION="4.3.0"
readonly MIN_OMARCHY_MAJOR=4
readonly MIN_OMARCHY_MINOR=5

readonly STATE_DIR="${HOME}/.local/state/omarchy-plus"
readonly CONFIG_DIR="${HOME}/.config/docker-toolbox"
readonly BACKUP_DIR="${CONFIG_DIR}/backups"
readonly BIN_DIR="${HOME}/.local/bin"

readonly DTOOL="${BIN_DIR}/dtool"
readonly ALIAS_FILE="${CONFIG_DIR}/aliases.sh"
readonly BASHRC="${HOME}/.bashrc"

readonly THEME_NAME="freeboot-rustig-signaal"
readonly THEME_DIR="${HOME}/.config/omarchy/themes/${THEME_NAME}"
readonly THEME_BACKUP_ROOT="${HOME}/.local/share/freeboot/backups"

readonly EZA_DIR="${HOME}/.config/eza"
readonly EZA_THEME="${EZA_DIR}/theme.yml"
readonly KITTY_CONFIG="${HOME}/.config/kitty/kitty.conf"
readonly FISH_FILE="${HOME}/.config/fish/conf.d/freeboot-rustig-signaal.fish"

readonly THEME_NAME_FILE="${HOME}/.local/state/omarchy/current/theme.name"

readonly DOCKER_BEGIN="# >>> DOCKER_TOOLBOX >>>"
readonly DOCKER_END="# <<< DOCKER_TOOLBOX <<<"
readonly THEME_BEGIN="# >>> FREEBOOT RUSTIG SIGNAAL >>>"
readonly THEME_END="# <<< FREEBOOT RUSTIG SIGNAAL <<<"

readonly BG="#24262b"
readonly FG="#cfd2d6"
readonly BLUE="#91b8e8"
readonly GREEN="#76c9a0"
readonly ORANGE="#e0a050"
readonly RED="#f28b95"
readonly MUTED="#a6adb8"
readonly SELECTION="#353a46"
readonly BRIGHT_FG="#e6e8eb"

readonly FZF_COLORS="--color=bg:${BG},fg:${FG},hl:${ORANGE},fg+:${BRIGHT_FG},bg+:${SELECTION},hl+:${ORANGE},info:${MUTED},prompt:${BLUE},pointer:${GREEN},marker:${GREEN},header:${BLUE}"

MODE="install"
DRY_RUN=false
ASSUME_YES=false
SKIP_UPDATE=false

DO_CLI=true
DO_DOCKER=true
DO_THEME=true

ONLY_USED=""
RESTORE_DIR=""
LOG_FILE=""
SUDO_KEEPALIVE=""

THEME_BACKUP_DIR=""
DOCKER_BACKUP_DIR=""

declare -a INSTALL_LIST=()
declare -a SKIP_LIST=()
declare -a TEMP_PATHS=()

# ============================================================
# MELDINGEN
# ============================================================

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_GREEN=$'\033[0;32m'
    C_RED=$'\033[0;31m'
    C_YELLOW=$'\033[0;33m'
    C_BLUE=$'\033[0;34m'
    C_BOLD=$'\033[1m'
    C_RESET=$'\033[0m'
else
    C_GREEN='' C_RED='' C_YELLOW='' C_BLUE='' C_BOLD='' C_RESET=''
fi

log() {
    [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]] || return 0
    printf '%s\n' "$*" >> "$LOG_FILE"
}

info() {
    printf '%s[INFO]%s %s\n' "$C_BLUE" "$C_RESET" "$*"
    log "[INFO] $*"
}

success() {
    printf '%s[OK]%s %s\n' "$C_GREEN" "$C_RESET" "$*"
    log "[OK] $*"
}

warning() {
    printf '%s[LET OP]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"
    log "[LET OP] $*"
}

error() {
    printf '%s[FOUT]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2
    log "[FOUT] $*"
}

die() {
    error "$*"
    exit 1
}

heading() {
    printf '\n%s%s%s\n' "$C_BOLD" "$1" "$C_RESET"
    printf '%s\n' '----------------------------------------------'
    log "== $1 =="
}

require() {
    local cmd
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 ||
            die "Vereist commando ontbreekt: $cmd"
    done
}

# ============================================================
# AFSLUITEN
# ============================================================

stop_sudo_keepalive() {
    [[ -z "$SUDO_KEEPALIVE" ]] && return 0

    kill "$SUDO_KEEPALIVE" 2>/dev/null || true
    wait "$SUDO_KEEPALIVE" 2>/dev/null || true
    SUDO_KEEPALIVE=""
}

cleanup() {
    stop_sudo_keepalive

    local path
    for path in "${TEMP_PATHS[@]}"; do
        [[ -z "$path" ]] || rm -rf -- "$path"
    done
}

on_signal() {
    echo
    warning "Uitvoering onderbroken."
    warning "Controleer de configuratie voordat je opnieuw start."

    [[ -z "$THEME_BACKUP_DIR" ]] ||
        warning "Thema-back-up: $THEME_BACKUP_DIR"

    exit 130
}

trap cleanup EXIT
trap on_signal INT TERM

trap 'error "Onverwachte fout op regel ${LINENO}."; exit 1' ERR

start_sudo_keepalive() {
    sudo -v || die "Geen sudo-rechten."

    (
        trap 'exit 0' TERM INT
        trap - EXIT ERR

        while kill -0 "$$" 2>/dev/null; do
            sudo -n true 2>/dev/null || true
            sleep 60 &
            wait $! || true
        done
    ) </dev/null >/dev/null 2>&1 &

    SUDO_KEEPALIVE=$!
}

# ============================================================
# ALGEMENE VEILIGHEID
# ============================================================

confirm() {
    local prompt="$1"
    local answer=""

    [[ "$ASSUME_YES" == true ]] && return 0

    [[ -r /dev/tty ]] ||
        die "Geen interactieve terminal. Gebruik bewust --yes."

    echo
    read -r -p "$prompt [j/N] " answer </dev/tty || answer=""

    case "${answer,,}" in
        j|ja|y|yes) return 0 ;;
        *) return 1 ;;
    esac
}

init_log() {
    [[ ! -L "$STATE_DIR" ]] ||
        die "State-map is een symbolische link."

    mkdir -p "$STATE_DIR"

    LOG_FILE="${STATE_DIR}/install-$(date +%Y%m%d-%H%M%S)-$$.log"

    : > "$LOG_FILE"
    chmod 600 "$LOG_FILE"

    info "Logbestand: $LOG_FILE"
}

check_home() {
    [[ -n "${HOME:-}" && -d "$HOME" ]] ||
        die "HOME is niet beschikbaar."

    [[ "$EUID" -ne 0 ]] ||
        die "Voer dit script niet uit als root of met sudo."

    [[ "$(uname -s)" == Linux ]] ||
        die "Dit script is uitsluitend bedoeld voor Linux."

    [[ ! -L "$HOME" ]] ||
        die "HOME is een symbolische link."
}

check_managed_path() {
    local path="$1"

    [[ ! -L "$path" ]] ||
        die "Symbolische link geweigerd: $path"

    if [[ -e "$path" && ! -f "$path" && ! -d "$path" ]]; then
        die "Onverwacht bestandstype: $path"
    fi
}

# ============================================================
# OMARCHY-VERSIE
# ============================================================

get_omarchy_version() {
    local output

    command -v omarchy-version >/dev/null 2>&1 ||
        die "omarchy-version ontbreekt."

    output="$(omarchy-version 2>/dev/null)" ||
        die "Omarchy-versie kon niet worden vastgesteld."

    printf '%s\n' "$output"
}

check_omarchy_version() {
    local output version major minor

    output="$(get_omarchy_version)"

    # De uitvoer kan bijvoorbeeld zijn:
    # 4.5.0
    # Omarchy 4.5.0
    version="$(grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' <<< "$output" | head -n1)"

    [[ -n "$version" ]] ||
        die "Onbekende Omarchy-versie: $output"

    IFS=. read -r major minor _ <<< "$version"

    if (( major < MIN_OMARCHY_MAJOR ||
          (major == MIN_OMARCHY_MAJOR && minor < MIN_OMARCHY_MINOR) )); then
        die "Omarchy 4.5 of hoger vereist. Gevonden: $version"
    fi

    success "Omarchy-versie: $version"
}

# ============================================================
# OMARCHY UPDATE
# ============================================================

run_omarchy_update() {
    [[ "$SKIP_UPDATE" == true ]] && {
        info "Omarchy-update overgeslagen."
        return 0
    }

    info "Officiële Omarchy-update wordt gestart."
    info "Dit kan Omarchy, systeem- en AUR-pakketten bijwerken."
    info "Er wordt geen directe pacman -Syu uitgevoerd."

    if ! omarchy update -y; then
        error "Omarchy-update mislukt."
        return 1
    fi

    success "Omarchy-update afgerond."
    return 0
}

# ============================================================
# BACK-UPS
# ============================================================

create_backup_dir() {
    [[ ! -L "$CONFIG_DIR" && ! -L "$BACKUP_DIR" ]] ||
        die "Back-upmap is een symbolische link."

    mkdir -p "$BACKUP_DIR"
}

backup_file() {
    local source="$1"
    local target

    [[ -e "$source" || -L "$source" ]] || return 0

    [[ ! -L "$source" ]] ||
        die "Back-up geweigerd: symbolische link: $source"

    [[ -f "$source" ]] ||
        die "Back-up geweigerd: geen regulier bestand: $source"

    create_backup_dir

    target="${BACKUP_DIR}/$(basename "$source").$(date +%Y%m%d-%H%M%S)-$$"

    cp -p -- "$source" "$target"
    chmod 600 "$target"

    success "Back-up: $target"
}

create_theme_backup() {
    local prefix="${1:-}"
    local target
    local -a paths=()

    [[ ! -L "$THEME_BACKUP_ROOT" ]] ||
        die "Thema-back-upmap is een symbolische link."

    mkdir -p "$THEME_BACKUP_ROOT"

    target="${THEME_BACKUP_ROOT}/${prefix}$(date +%Y%m%d-%H%M%S)-$$"

    mkdir "$target"

    local rel
    local -a managed=(
        ".config/omarchy/themes/${THEME_NAME}"
        ".config/eza/theme.yml"
        ".config/kitty/kitty.conf"
        ".config/fish/conf.d/freeboot-rustig-signaal.fish"
        ".bashrc"
        ".zshrc"
    )

    for rel in "${managed[@]}"; do
        if [[ -e "${HOME}/${rel}" ]]; then
            paths+=("$rel")
        fi
    done

    if (( ${#paths[@]} > 0 )); then
        tar -cpf "${target}/files.tar" -C "$HOME" -- "${paths[@]}"
    else
        tar -cpf "${target}/files.tar" --files-from /dev/null
    fi

    printf '%s\n' "${managed[@]}" > "${target}/managed-paths.txt"
    printf '%s\n' "${paths[@]}" > "${target}/existing-paths.txt"

    if [[ -f "${HOME}/.local/state/omarchy/current/theme.name" ]]; then
        cat "${HOME}/.local/state/omarchy/current/theme.name" \
            > "${target}/previous-theme.txt"
    else
        : > "${target}/previous-theme.txt"
    fi

    chmod 600 "${target}/"*

    THEME_BACKUP_DIR="$target"
    success "Thema-back-up gemaakt: $target"
}

# ============================================================
# CLI TOOLKIT
# ============================================================

CLI_PACKAGES=(
    atuin
    direnv
    htop
    lsof
    strace
    sysstat
    ncdu
    dust
    duf
    smartmontools
    lm_sensors
    pciutils
    usbutils
    ethtool
    bind
    traceroute
    mtr
    nmap
    tcpdump
    wireshark-cli
    iperf3
    httpie
    openssl
    shellcheck
    shfmt
    git-delta
    make
    ansible
    ansible-lint
    terraform
    trivy
    hadolint
    restic
    rclone
    rsync
    lynis
    chkrootkit
    rkhunter
    gnupg
    age
    fail2ban
    audit
    clamav
    pandoc
    glow
    graphviz
    lynx
    w3m
    translate-shell
    tldr
)

inventory_cli() {
    INSTALL_LIST=()
    SKIP_LIST=()

    local package

    for package in "${CLI_PACKAGES[@]}"; do
        if pacman -Qq "$package" >/dev/null 2>&1; then
            SKIP_LIST+=("$package (aanwezig)")
        elif pacman -Si "$package" >/dev/null 2>&1; then
            INSTALL_LIST+=("$package")
        else
            SKIP_LIST+=("$package (niet beschikbaar)")
        fi
    done
}

show_cli_inventory() {
    echo
    echo "CLI Toolkit"
    echo "Te installeren: ${#INSTALL_LIST[@]}"
    echo "Overgeslagen:   ${#SKIP_LIST[@]}"

    if (( ${#INSTALL_LIST[@]} > 0 )); then
        printf '  [+] %s\n' "${INSTALL_LIST[@]}"
    fi

    if (( ${#SKIP_LIST[@]} > 0 )); then
        echo
        echo "Overgeslagen:"
        printf '  [-] %s\n' "${SKIP_LIST[@]}"
    fi
}

install_cli() {
    local package
    local failures=0

    for package in "${INSTALL_LIST[@]}"; do
        info "Installeren: $package"

        if omarchy pkg add "$package"; then
            if pacman -Qq "$package" >/dev/null 2>&1; then
                success "$package geïnstalleerd."
            else
                warning "$package is niet teruggevonden na installatie."
                failures=$((failures + 1))
            fi
        else
            warning "Installatie mislukt: $package"
            failures=$((failures + 1))
        fi
    done

    (( failures == 0 )) ||
        return 1
}

# ============================================================
# DTOOL
# ============================================================

install_dtool() {
    local temp

    mkdir -p "$BIN_DIR"

    check_managed_path "$DTOOL"
    backup_file "$DTOOL"

    temp="$(mktemp "${BIN_DIR}/.dtool.XXXXXX")"
    TEMP_PATHS+=("$temp")

    cat > "$temp" <<'DTOOL'
#!/usr/bin/env bash

set -Eeuo pipefail

LABEL="docker-toolbox.temporary=true"

die() {
    echo "[FOUT] $*" >&2
    exit 1
}

check_docker() {
    command -v docker >/dev/null 2>&1 ||
        die "Docker CLI ontbreekt."

    docker info >/dev/null 2>&1 ||
        die "Docker-daemon niet bereikbaar. Controleer Docker en je rechten."
}

usage() {
    cat <<'EOF'
Docker Toolbox

WEBTOOLS
  dtool pdf
  dtool ittools
  dtool metube
  dtool draw
  dtool cyberchef
  dtool convert
  dtool translate

SHELLS
  dtool debian
  dtool alpine
  dtool ubuntu
  dtool python [script.py]
  dtool node [script.js]
  dtool network

ONTWIKKELING
  dtool trivy
  dtool hadolint
  dtool pandoc document.md
  dtool postgres
  dtool redis

BEHEER
  dtool images
  dtool containers
  dtool cleanup
  dtool help

Voorbeelden:
  dtool python script.py
  dtool node script.js
  dtool pandoc document.md
  DTOOL_PORT=9000 dtool pdf

Tijdelijke containers worden bij afsluiten verwijderd.
Docker-images en benoemde volumes blijven behouden.
EOF
}

check_port() {
    [[ "$1" =~ ^[0-9]{1,5}$ ]] ||
        die "Ongeldige poort."

    (( 10#$1 >= 1 && 10#$1 <= 65535 )) ||
        die "Poort buiten bereik."
}

temporary() {
    check_docker
    docker run --rm --label "$LABEL" "$@"
}

web() {
    local default_port="$1"
    local container_port="$2"
    shift 2

    local port="${DTOOL_PORT:-$default_port}"

    check_port "$port"
    check_docker

    echo
    echo "Open: http://localhost:${port}"
    echo "Stoppen: Ctrl+C"
    echo

    temporary \
        --init \
        -p "127.0.0.1:${port}:${container_port}" \
        --security-opt=no-new-privileges \
        "$@"
}

workdir() {
    local current home

    current="$(pwd -P)"
    home="$(cd "$HOME" && pwd -P)"

    [[ "$current" != "/" && "$current" != "$home" ]] ||
        die "Ga eerst naar een projectsubmap."

    [[ "$current" != *:* ]] ||
        die "Dubbele punt in projectpad wordt niet ondersteund."

    WORK=(-v "${current}:/werk" -w /werk)
}

WORK=()
cmd="${1:-help}"
[[ $# -eq 0 ]] || shift

case "$cmd" in
    pdf)
        web 8080 8080 stirlingtools/stirling-pdf
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
        web 8085 3000 ghcr.io/c4illin/convertx
        ;;

    translate)
        web 8086 5000 libretranslate/libretranslate
        ;;

    debian)
        workdir
        temporary -it --init "${WORK[@]}" debian:trixie-slim bash
        ;;

    alpine)
        workdir
        temporary -it --init "${WORK[@]}" alpine:3.22 sh
        ;;

    ubuntu)
        workdir
        temporary -it --init "${WORK[@]}" ubuntu:24.04 bash
        ;;

    python)
        workdir
        temporary -it --init "${WORK[@]}" \
            --user "$(id -u):$(id -g)" \
            -e HOME=/tmp \
            python:3.13-alpine python "$@"
        ;;

    node)
        workdir
        temporary -it --init "${WORK[@]}" \
            --user "$(id -u):$(id -g)" \
            -e HOME=/tmp \
            node:22-alpine node "$@"
        ;;

    network)
        temporary -it --init --network host nicolaka/netshoot
        ;;

    trivy)
        workdir
        temporary \
            --security-opt=no-new-privileges \
            -v "$(pwd -P):/work:ro" \
            -v trivy-cache:/root/.cache/trivy \
            aquasec/trivy:0.76.2 fs /work
        ;;

    hadolint)
        file="${1:-Dockerfile}"
        [[ -f "$file" ]] || die "Dockerfile niet gevonden."

        check_docker

        docker run --rm -i \
            --security-opt=no-new-privileges \
            hadolint/hadolint < "$file"
        ;;

    pandoc)
        [[ $# -eq 1 ]] || die "Gebruik: dtool pandoc document.md"
        [[ -f "$1" ]] || die "Bronbestand ontbreekt."

        lower="${1,,}"
        [[ "$lower" == *.md || "$lower" == *.markdown ]] ||
            die "Alleen Markdown wordt ondersteund."

        dir="$(cd -- "$(dirname -- "$1")" && pwd -P)"
        name="$(basename -- "$1")"
        home_dir="$(cd "$HOME" && pwd -P)"

        [[ "$dir" != "/" && "$dir" != "$home_dir" ]] ||
            die "Gebruik een projectsubmap."

        output="${dir}/${name%.*}.pdf"

        [[ ! -e "$output" && ! -L "$output" ]] ||
            die "PDF bestaat al: $output"

        temporary \
            --security-opt=no-new-privileges \
            --user "$(id -u):$(id -g)" \
            -e HOME=/tmp \
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

        echo "Tijdelijke PostgreSQL."
        echo "Gebruiker: postgres"
        echo "Wachtwoord: test-only-change-me"
        echo "Niet gebruiken voor productie."

        temporary -it --init \
            -e POSTGRES_PASSWORD=test-only-change-me \
            -p "127.0.0.1:${port}:5432" \
            postgres:18-alpine
        ;;

    redis)
        port="${DTOOL_PORT:-6379}"
        check_port "$port"

        temporary -it --init \
            -p "127.0.0.1:${port}:6379" \
            redis:7-alpine
        ;;

    images)
        check_docker
        docker image ls
        ;;

    containers)
        check_docker
        docker ps -a --filter "label=$LABEL"
        ;;

    cleanup)
        check_docker
        docker container prune --force --filter "label=$LABEL"
        ;;

    help|--help|-h)
        usage
        ;;

    *)
        die "Onbekende opdracht: $cmd"
        ;;
esac
DTOOL

    bash -n "$temp" ||
        die "Syntaxfout in dtool."

    chmod 755 "$temp"
    mv -f -- "$temp" "$DTOOL"

    success "dtool geïnstalleerd."
}

# ============================================================
# DOCKER ALIASSEN
# ============================================================

install_aliases() {
    local temp

    mkdir -p "$CONFIG_DIR"
    check_managed_path "$ALIAS_FILE"
    backup_file "$ALIAS_FILE"

    temp="$(mktemp "${CONFIG_DIR}/.aliases.XXXXXX")"
    TEMP_PATHS+=("$temp")

    cat > "$temp" <<'EOF'
# Docker Toolbox

alias dpdf='dtool pdf'
alias dittools='dtool ittools'
alias dmetube='dtool metube'
alias ddraw='dtool draw'
alias dcyberchef='dtool cyberchef'
alias dconvert='dtool convert'
alias dvertaal='dtool translate'

alias dnet='dtool network'
alias ddebian='dtool debian'
alias dalpine='dtool alpine'
alias dubuntu='dtool ubuntu'
alias dpython='dtool python'
alias dnode='dtool node'

alias dtrivy='dtool trivy'
alias dhadolint='dtool hadolint'
alias dpandoc='dtool pandoc'
alias dpostgres='dtool postgres'
alias dredis='dtool redis'

alias dimages='dtool images'
alias dcontainers='dtool containers'
alias dcleanup='dtool cleanup'
EOF

    chmod 600 "$temp"
    mv -f -- "$temp" "$ALIAS_FILE"

    success "Docker-aliassen geïnstalleerd."
}

# ============================================================
# BASH-INTEGRATIE
# ============================================================

validate_block() {
    local file="$1"
    local begin="$2"
    local end="$3"

    [[ -f "$file" ]] || return 0

    python3 -I - "$file" "$begin" "$end" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
begin = sys.argv[2]
end = sys.argv[3]

lines = path.read_text(errors="replace").splitlines()

starts = [i for i, line in enumerate(lines) if line == begin]
ends = [i for i, line in enumerate(lines) if line == end]

if len(starts) != len(ends) or len(starts) > 1:
    raise SystemExit(f"Ongeldig configuratieblok: {path}")

if starts and ends[0] < starts[0]:
    raise SystemExit(f"Verkeerde blokvolgorde: {path}")
PY
}

remove_block() {
    local file="$1"
    local begin="$2"
    local end="$3"
    local temp

    [[ -f "$file" ]] || return 0

    validate_block "$file" "$begin" "$end"

    grep -Fqx -- "$begin" "$file" || return 0

    temp="$(mktemp "${file}.XXXXXX")"
    TEMP_PATHS+=("$temp")

    awk -v b="$begin" -v e="$end" '
        $0 == b { inside=1; next }
        $0 == e && inside { inside=0; next }
        inside { next }
        { print }
    ' "$file" > "$temp"

    chmod --reference="$file" "$temp"
    chown --reference="$file" "$temp"

    mv -f -- "$temp" "$file"
}

install_bash_block() {
    local temp

    touch "$BASHRC"
    check_managed_path "$BASHRC"
    backup_file "$BASHRC"

    validate_block "$BASHRC" "$DOCKER_BEGIN" "$DOCKER_END"

    remove_block "$BASHRC" "$DOCKER_BEGIN" "$DOCKER_END"

    temp="$(mktemp "${BASHRC}.XXXXXX")"
    TEMP_PATHS+=("$temp")

    cat "$BASHRC" > "$temp"

    cat >> "$temp" <<'EOF'

# >>> DOCKER_TOOLBOX >>>
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

if [[ -f "$HOME/.config/docker-toolbox/aliases.sh" ]]; then
    source "$HOME/.config/docker-toolbox/aliases.sh"
fi
# <<< DOCKER_TOOLBOX <<<
EOF

    chmod --reference="$BASHRC" "$temp"
    chown --reference="$BASHRC" "$temp"
    mv -f -- "$temp" "$BASHRC"

    success "Bash-integratie bijgewerkt."
}

# ============================================================
# DOCKER INSTALLATIE
# ============================================================

install_docker() {
    command -v docker >/dev/null 2>&1 ||
        die "Docker CLI ontbreekt."

    systemctl show docker.service -p LoadState --value |
        grep -qx loaded ||
        die "docker.service ontbreekt."

    docker info >/dev/null 2>&1 ||
        die "Docker-daemon is niet bereikbaar."

    check_managed_path "$DTOOL"
    check_managed_path "$ALIAS_FILE"
    check_managed_path "$CONFIG_DIR"
    check_managed_path "$BIN_DIR"

    mkdir -p "$CONFIG_DIR" "$BIN_DIR"

    install_dtool
    install_aliases
    install_bash_block

    success "Docker Toolbox geïnstalleerd."
    info "Er is geen systemd-drop-in geplaatst."
    info "Docker wordt niet automatisch gestart of herstart."
}

# ============================================================
# DOCKER VERWIJDEREN
# ============================================================

uninstall_docker() {
    local safety

    mkdir -p "$CONFIG_DIR"

    backup_file "$BASHRC"
    backup_file "$DTOOL"
    backup_file "$ALIAS_FILE"

    remove_block "$BASHRC" "$DOCKER_BEGIN" "$DOCKER_END"

    rm -f -- "$ALIAS_FILE" "$DTOOL"

    success "Docker Toolbox-integratie verwijderd."
    info "Docker-images, containers en volumes zijn behouden."
    info "Systeempakketten zijn behouden."
    info "Back-ups zijn behouden."
    info "Open een nieuwe terminal."
}

# ============================================================
# THEMA: ATOMAIR SCHRIJVEN
# ============================================================

write_atomic() {
    local target="$1"
    local mode="${2:-0644}"
    local parent temp

    parent="$(dirname "$target")"
    mkdir -p "$parent"

    temp="$(mktemp "${parent}/.freeboot.XXXXXX")"
    TEMP_PATHS+=("$temp")

    cat > "$temp"

    chmod "$mode" "$temp"

    if [[ -e "$target" ]]; then
        chmod --reference="$target" "$temp"
        chown --reference="$target" "$temp"
    fi

    mv -f -- "$temp" "$target"
}

# ============================================================
# THEMA: KLEUREN
# ============================================================

write_colors() {
    write_atomic "${THEME_DIR}/colors.toml" 0644 <<EOF
mode = "dark"

accent = "${BLUE}"
selection = "${SELECTION}"
muted = "${MUTED}"

cursor = "${BRIGHT_FG}"
selection_background = "${SELECTION}"
selection_foreground = "${BRIGHT_FG}"

background = "${BG}"
foreground = "${FG}"

red = "${RED}"
orange = "${ORANGE}"
yellow = "${ORANGE}"
green = "${GREEN}"
blue = "${BLUE}"

color0 = "#1a1c20"
color1 = "${RED}"
color2 = "${GREEN}"
color3 = "${ORANGE}"
color4 = "${BLUE}"
color5 = "#c9a0dc"
color6 = "${BLUE}"
color7 = "${FG}"

color8 = "${MUTED}"
color9 = "${RED}"
color10 = "${GREEN}"
color11 = "${ORANGE}"
color12 = "${BLUE}"
color13 = "#c9a0dc"
color14 = "${BLUE}"
color15 = "${BRIGHT_FG}"
EOF

    python3 -I - "${THEME_DIR}/colors.toml" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as f:
    data = tomllib.load(f)

if data.get("mode") != "dark":
    raise SystemExit("Ongeldige themamodus")

for key, value in data.items():
    if key == "mode":
        continue
    if not isinstance(value, str):
        raise SystemExit(f"Ongeldige waarde: {key}")
    if len(value) != 7 or not value.startswith("#"):
        raise SystemExit(f"Ongeldige kleur: {key}")
PY

    success "Themakleuren geschreven en gecontroleerd."
}

# ============================================================
# THEMA: ACHTERGROND
# ============================================================

write_background() {
    local target="${THEME_DIR}/backgrounds/rustig-effen.png"
    local temp

    if [[ -e "$target" ]]; then
        info "Bestaande achtergrond behouden."
        return 0
    fi

    mkdir -p "$(dirname "$target")"

    temp="$(mktemp "$(dirname "$target")/.background.XXXXXX")"
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

with open(path, "wb") as f:
    f.write(b"\x89PNG\r\n\x1a\n")
    f.write(chunk(
        b"IHDR",
        struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    ))
    f.write(chunk(b"IDAT", zlib.compress(row, 9)))
    f.write(chunk(b"IEND", b""))
PY

    chmod 644 "$temp"
    mv -f -- "$temp" "$target"

    success "Effen achtergrond aangemaakt."
}

# ============================================================
# THEMA: EZA
# ============================================================

write_eza() {
    write_atomic "$EZA_THEME" 0644 <<EOF
colourful: true

filekinds:
  directory:
    foreground: "${BLUE}"
    is_bold: true

  symlink:
    foreground: "${BLUE}"

git:
  new:
    foreground: "${GREEN}"

  modified:
    foreground: "${ORANGE}"

  deleted:
    foreground: "${RED}"

  renamed:
    foreground: "#c9a0dc"

  conflicted:
    foreground: "${RED}"
    is_bold: true
EOF

    success "eza-thema geschreven."
}

# ============================================================
# THEMA: KITTY
# ============================================================

write_kitty() {
    local default="${OMARCHY_PATH:-/usr/share/omarchy}/config/kitty/kitty.conf"

    check_managed_path "$KITTY_CONFIG"

    if [[ ! -e "$KITTY_CONFIG" ]]; then
        if [[ -f "$default" ]]; then
            write_atomic "$KITTY_CONFIG" 0644 < "$default"
        else
            write_atomic "$KITTY_CONFIG" 0644 <<'EOF'
# Eigen Kitty-configuratie
EOF
        fi
    fi

    backup_file "$KITTY_CONFIG"

    local snippet
    snippet="$(mktemp)"
    TEMP_PATHS+=("$snippet")

    cat > "$snippet" <<'EOF'
# Rustig Signaal

cursor_blink_interval 0
cursor_trail 0
enable_audio_bell no
visual_bell_duration 0.0

window_padding_width 8
background_opacity 1.0
dim_opacity 0.85
inactive_text_alpha 1.0
EOF

    update_theme_block "$KITTY_CONFIG" "$snippet"

    if ! grep -Eq '^[[:space:]]*include[[:space:]].*omarchy/current/theme/kitty\.conf' "$KITTY_CONFIG"; then
        local combined
        combined="$(mktemp)"
        TEMP_PATHS+=("$combined")

        {
            printf '%s\n' 'include ~/.local/state/omarchy/current/theme/kitty.conf'
            cat "$KITTY_CONFIG"
        } > "$combined"

        write_atomic "$KITTY_CONFIG" 0644 < "$combined"
    fi

    success "Kitty-configuratie bijgewerkt."
}

# ============================================================
# THEMA: BEHEERDE BLOKKEN
# ============================================================

update_theme_block() {
    local target="$1"
    local snippet="$2"

    python3 -I - "$target" "$snippet" "$THEME_BEGIN" "$THEME_END" <<'PY'
import os
import pathlib
import sys
import tempfile

target = pathlib.Path(sys.argv[1])
snippet = pathlib.Path(sys.argv[2])
begin = sys.argv[3]
end = sys.argv[4]

if target.is_symlink():
    raise SystemExit(f"Symbolische link geweigerd: {target}")

lines = target.read_text().splitlines() if target.exists() else []

starts = [i for i, line in enumerate(lines) if line == begin]
ends = [i for i, line in enumerate(lines) if line == end]

if len(starts) != len(ends) or len(starts) > 1:
    raise SystemExit(f"Ongeldige markeringen: {target}")

if starts:
    if ends[0] < starts[0]:
        raise SystemExit(f"Verkeerde blokvolgorde: {target}")
    lines = lines[:starts[0]] + lines[ends[0] + 1:]

while lines and not lines[-1].strip():
    lines.pop()

if lines:
    lines.append("")

lines.extend([
    begin,
    snippet.read_text().rstrip(),
    end
])

content = "\n".join(lines) + "\n"
mode = target.stat().st_mode & 0o777 if target.exists() else 0o644

fd, name = tempfile.mkstemp(prefix=".freeboot-", dir=target.parent)

try:
    with os.fdopen(fd, "w") as f:
        f.write(content)

    os.chmod(name, mode)

    if target.exists():
        st = target.stat()
        os.chown(name, st.st_uid, st.st_gid)

    os.replace(name, target)

except BaseException:
    try:
        os.unlink(name)
    except FileNotFoundError:
        pass
    raise
PY
}

# ============================================================
# THEMA: SHELLS
# ============================================================

write_shells() {
    local snippet

    snippet="$(mktemp)"
    TEMP_PATHS+=("$snippet")

    cat > "$snippet" <<EOF
# Rustig Signaal

export EZA_CONFIG_DIR="\${XDG_CONFIG_HOME:-\$HOME/.config}/eza"

unset EZA_COLORS
unset LS_COLORS

export LESS="\${LESS:--R}"
export FZF_DEFAULT_OPTS='${FZF_COLORS}'
EOF

    check_managed_path "$BASHRC"
    check_managed_path "${HOME}/.zshrc"

    backup_file "$BASHRC"
    backup_file "${HOME}/.zshrc"

    update_theme_block "$BASHRC" "$snippet"
    update_theme_block "${HOME}/.zshrc" "$snippet"

    success "Bash- en Zsh-instellingen bijgewerkt."
}

write_fish() {
    local temp

    check_managed_path "$FISH_FILE"

    mkdir -p "$(dirname "$FISH_FILE")"
    backup_file "$FISH_FILE"

    temp="$(mktemp "$(dirname "$FISH_FILE")/.freeboot.XXXXXX")"
    TEMP_PATHS+=("$temp")

    cat > "$temp" <<EOF
# FreeBoot Rustig Signaal

set -gx EZA_CONFIG_DIR "\$HOME/.config/eza"
set -e EZA_COLORS
set -e LS_COLORS
set -gx LESS '-R'
set -gx FZF_DEFAULT_OPTS '${FZF_COLORS}'
EOF

    chmod 644 "$temp"
    mv -f -- "$temp" "$FISH_FILE"

    success "Fish-configuratie bijgewerkt."
}

# ============================================================
# THEMA: ACTIVEREN
# ============================================================

activate_theme() {
    omarchy theme set "$1"
}

verify_theme() {
    activate_theme "$THEME_NAME"

    [[ -f "$THEME_NAME_FILE" ]] ||
        die "Omarchy heeft geen actieve themanaam opgeslagen."

    [[ "$(cat "$THEME_NAME_FILE")" == "$THEME_NAME" ]] ||
        die "Thema kon niet worden geactiveerd."

    success "Rustig Signaal is actief."
}

# ============================================================
# THEMA: INSTALLEREN
# ============================================================

install_theme() {
    create_theme_backup

    write_colors
    write_background
    write_eza
    write_kitty
    write_shells
    write_fish

    verify_theme

    success "Rustig Signaal geïnstalleerd."
}

# ============================================================
# THEMA: BACK-UPVALIDATIE
# ============================================================

validate_theme_backup() {
    local source="$1"

    [[ -d "$source" ]] ||
        die "Back-upmap ontbreekt."

    [[ -f "${source}/files.tar" ]] ||
        die "Back-uparchief ontbreekt."

    [[ -f "${source}/managed-paths.txt" ]] ||
        die "Back-upmanifest ontbreekt."

    [[ -f "${source}/existing-paths.txt" ]] ||
        die "Bestaande-padenlijst ontbreekt."

    python3 -I - "$source" <<'PY'
import pathlib
import sys
import tarfile

root = pathlib.Path(sys.argv[1])
allowed = set((root / "managed-paths.txt").read_text().splitlines())
existing = set((root / "existing-paths.txt").read_text().splitlines())

if not existing.issubset(allowed):
    raise SystemExit("Ongeldige bestaande-padenlijst")

with tarfile.open(root / "files.tar") as archive:
    names = set()

    for member in archive.getmembers():
        path = pathlib.PurePosixPath(member.name)

        if path.is_absolute() or ".." in path.parts:
            raise SystemExit(f"Onveilig archiefpad: {member.name}")

        if not (member.isfile() or member.isdir()):
            raise SystemExit(f"Onveilig bestandstype: {member.name}")

        if not any(
            member.name == item or member.name.startswith(item + "/")
            for item in allowed
        ):
            raise SystemExit(f"Onverwacht bestand: {member.name}")

        if member.issym() or member.islnk():
            raise SystemExit(f"Link geweigerd: {member.name}")

        names.add(member.name)

    for item in existing:
        if item not in names:
            raise SystemExit(f"Manifestbestand ontbreekt in archief: {item}")
PY
}

# ============================================================
# THEMA: HERSTEL
# ============================================================

restore_archive() {
    local source="$1"
    local staging="$2"
    local rel

    tar -xpf "${source}/files.tar" -C "$staging"

    local -a managed=(
        ".config/omarchy/themes/${THEME_NAME}"
        ".config/eza/theme.yml"
        ".config/kitty/kitty.conf"
        ".config/fish/conf.d/freeboot-rustig-signaal.fish"
        ".bashrc"
        ".zshrc"
    )

    for rel in "${managed[@]}"; do
        rm -rf -- "${HOME:?}/${rel}"

        if [[ -e "${staging}/${rel}" ]]; then
            mkdir -p "$(dirname "${HOME}/${rel}")"
            mv -- "${staging}/${rel}" "${HOME}/${rel}"
        fi
    done
}

restore_theme() {
    local source="$RESTORE_DIR"
    local staging safety rollback previous_theme

    if [[ -z "$source" ]]; then
        [[ -d "$THEME_BACKUP_ROOT" ]] ||
            die "Geen thema-back-ups gevonden."

        source="$(
            find "$THEME_BACKUP_ROOT" \
                -mindepth 1 -maxdepth 1 \
                -type d -name '20*' |
            sort -rV |
            head -n1
        )"
    fi

    [[ -n "$source" ]] ||
        die "Geen geschikte back-up gevonden."

    validate_theme_backup "$source"

    previous_theme="$(cat "${source}/previous-theme.txt" 2>/dev/null || true)"

    info "Herstelbron: $source"
    info "Vorige themakeuze: ${previous_theme:-onbekend}"

    if [[ "$DRY_RUN" == true ]]; then
        info "DRY-RUN: geen bestanden gewijzigd."
        return 0
    fi

    confirm "De beheerde configuratie herstellen?" || return 0

    create_theme_backup "voor-herstel-"
    safety="$THEME_BACKUP_DIR"

    staging="$(mktemp -d "${HOME}/.freeboot-restore.XXXXXX")"
    TEMP_PATHS+=("$staging")

    if ! restore_archive "$source" "$staging"; then
        error "Herstel mislukt. Veiligheidskopie wordt teruggezet."

        rollback="$(mktemp -d "${HOME}/.freeboot-rollback.XXXXXX")"
        TEMP_PATHS+=("$rollback")

        restore_archive "$safety" "$rollback" ||
            die "Automatisch terugrollen mislukt. Veiligheidskopie: $safety"

        die "Vorige configuratie teruggezet."
    fi

    if [[ -n "$previous_theme" ]]; then
        if ! activate_theme "$previous_theme"; then
            warning "Bestanden zijn hersteld, maar thema-activering mislukte."
            warning "Veiligheidskopie: $safety"
            die "Controleer de actieve themakeuze handmatig."
        fi
    fi

    success "Herstel afgerond."
    info "Veiligheidskopie: $safety"
}

# ============================================================
# CONTROLES
# ============================================================

check_theme_requirements() {
    require python3 tar find sort realpath mktemp

    python3 -I -c '
import sys, tomllib
if sys.version_info < (3, 11):
    raise SystemExit("Python 3.11+ vereist")
'

    command -v omarchy >/dev/null 2>&1 ||
        die "Omarchy CLI ontbreekt."
}

check_docker() {
    command -v docker >/dev/null 2>&1 ||
        die "Docker CLI ontbreekt."

    systemctl show docker.service -p LoadState --value |
        grep -qx loaded ||
        die "Docker-service ontbreekt."

    docker info >/dev/null 2>&1 ||
        die "Docker-daemon is niet bereikbaar."
}

run_check() {
    heading "Controle - er wordt niets gewijzigd"

    require pacman omarchy omarchy-version

    check_omarchy_version

    if [[ "$DO_CLI" == true ]]; then
        heading "CLI Toolkit"
        inventory_cli
        show_cli_inventory
    fi

    if [[ "$DO_DOCKER" == true ]]; then
        heading "Docker Toolbox"
        check_docker
        success "Docker is bereikbaar."
    fi

    if [[ "$DO_THEME" == true ]]; then
        heading "Rustig Signaal"
        check_theme_requirements

        check_managed_path "$THEME_DIR"
        check_managed_path "$EZA_THEME"
        check_managed_path "$KITTY_CONFIG"
        check_managed_path "$FISH_FILE"
        check_managed_path "$BASHRC"

        success "Themapaden gecontroleerd."
    fi

    success "Controle afgerond."
}

# ============================================================
# OPTIES
# ============================================================

show_help() {
    cat <<EOF
Omarchy Plus Rustig ${VERSION}

GEBRUIK
  bash $0 [opties]

CONTROLE
  --check
  --dry-run
  --help

ONDERDELEN
  --only-cli
  --only-docker
  --only-theme

  --skip-cli
  --skip-docker
  --skip-theme

UPDATE
  --skip-update
  --yes

BEHEER
  --uninstall
  --restore
  --restore PAD

INSTALLATIEVOLGORDE
  1. Voorcontroles
  2. Inventarisatie
  3. Totaalbevestiging
  4. Omarchy-update
  5. CLI Toolkit
  6. Docker Toolbox
  7. Rustig Signaal
  8. Eindcontrole

EOF
}

set_mode() {
    [[ "$MODE" == install || "$MODE" == "$1" ]] ||
        die "Gebruik slechts één hoofdmodus."

    MODE="$1"
}

parse_arguments() {
    local only_count=0
    local -a skip_options=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_help
                exit 0
                ;;

            --check)
                set_mode check
                ;;

            --dry-run)
                DRY_RUN=true
                ;;

            --yes)
                ASSUME_YES=true
                ;;

            --skip-update)
                SKIP_UPDATE=true
                ;;

            --only-cli)
                only_count=$((only_count + 1))
                DO_DOCKER=false
                DO_THEME=false
                ONLY_USED=cli
                ;;

            --only-docker)
                only_count=$((only_count + 1))
                DO_CLI=false
                DO_THEME=false
                ONLY_USED=docker
                ;;

            --only-theme)
                only_count=$((only_count + 1))
                DO_CLI=false
                DO_DOCKER=false
                ONLY_USED=theme
                ;;

            --skip-cli)
                DO_CLI=false
                skip_options+=(cli)
                ;;

            --skip-docker)
                DO_DOCKER=false
                skip_options+=(docker)
                ;;

            --skip-theme)
                DO_THEME=false
                skip_options+=(theme)
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

            *)
                die "Onbekende optie: $1"
                ;;
        esac

        shift
    done

    (( only_count <= 1 )) ||
        die "Gebruik maximaal één --only-optie."

    if [[ -n "$ONLY_USED" && ${#skip_options[@]} -gt 0 ]]; then
        die "Combineer --only niet met --skip."
    fi

    if [[ "$MODE" != install ]]; then
        [[ "$DRY_RUN" == false || "$MODE" == check ]] ||
            die "Deze combinatie is niet toegestaan."

        [[ "$ONLY_USED" == "" && ${#skip_options[@]} -eq 0 ]] ||
            die "Gebruik geen onderdeelkeuze bij deze modus."
    fi
}

# ============================================================
# INSTALLATIE
# ============================================================

run_install() {
    local needs_update=false
    local failures=0

    [[ "$DO_CLI" == true || "$DO_DOCKER" == true ]] &&
        needs_update=true

    heading "Omarchy Plus Rustig ${VERSION}"

    echo "CLI Toolkit     : $DO_CLI"
    echo "Docker Toolbox  : $DO_DOCKER"
    echo "Rustig Signaal  : $DO_THEME"
    echo "Systeemupdate   : $needs_update"
    echo "Update overslaan: $SKIP_UPDATE"

    heading "Voorcontroles"

    require pacman omarchy omarchy-version

    check_omarchy_version

    if [[ "$DO_DOCKER" == true ]]; then
        require docker systemctl
        check_docker
    fi

    if [[ "$DO_THEME" == true ]]; then
        check_theme_requirements
    fi

    if [[ "$DO_CLI" == true ]]; then
        inventory_cli
    fi

    if [[ "$DRY_RUN" == true ]]; then
        heading "DRY-RUN"

        [[ "$needs_update" != true || "$SKIP_UPDATE" == true ]] ||
            info "Omarchy-update zou worden uitgevoerd."

        [[ "$DO_CLI" != true ]] || show_cli_inventory
        [[ "$DO_DOCKER" != true ]] || info "Docker Toolbox zou worden bijgewerkt."
        [[ "$DO_THEME" != true ]] || info "Rustig Signaal zou worden geïnstalleerd."

        success "DRY-RUN afgerond. Er is niets gewijzigd."
        return 0
    fi

    heading "Installatieoverzicht"

    [[ "$DO_CLI" != true ]] || show_cli_inventory

    [[ "$DO_DOCKER" != true ]] ||
        info "Docker Toolbox: dtool, aliassen en Bash-integratie."

    [[ "$DO_THEME" != true ]] ||
        info "Rustig Signaal: thema, eza, Kitty, Bash, Zsh en Fish."

    echo
    warning "Omarchy-update werkt ook systeem- en eventueel AUR-pakketten bij."
    warning "Er wordt geen automatische herstart uitgevoerd."
    warning "De update kan zelf aanvullende invoer vragen."

    confirm "Het volledige installatieplan uitvoeren?" || {
        warning "Installatie geannuleerd."
        return 0
    }

    init_log

    if [[ "$needs_update" == true ]]; then
        start_sudo_keepalive

        if [[ "$SKIP_UPDATE" != true ]]; then
            heading "Omarchy bijwerken"

            run_omarchy_update ||
                die "Omarchy-update mislukt. Installatie gestopt."

            check_omarchy_version
        fi
    fi

    if [[ "$DO_CLI" == true ]]; then
        heading "CLI Toolkit"

        inventory_cli

        if ! install_cli; then
            warning "Niet alle CLI-pakketten zijn geïnstalleerd."
            failures=1
        fi
    fi

    if [[ "$DO_DOCKER" == true ]]; then
        heading "Docker Toolbox"

        if ! install_docker; then
            warning "Docker Toolbox-installatie mislukt."
            failures=1
        fi
    fi

    stop_sudo_keepalive

    if [[ "$DO_THEME" == true ]]; then
        heading "Rustig Signaal"

        if ! install_theme; then
            warning "Thema-installatie mislukt."
            failures=1
        fi
    fi

    heading "Eindrapport"

    [[ "$DO_CLI" != true ]] ||
        info "CLI Toolkit: uitgevoerd."

    [[ "$DO_DOCKER" != true ]] ||
        info "Docker Toolbox: uitgevoerd."

    [[ "$DO_THEME" != true ]] ||
        info "Rustig Signaal: uitgevoerd."

    info "Logbestand: $LOG_FILE"

    [[ -z "$THEME_BACKUP_DIR" ]] ||
        info "Thema-back-up: $THEME_BACKUP_DIR"

    if (( failures == 0 )); then
        success "Installatie afgerond."
        info "Open een nieuwe terminal."
        info "Test Docker Toolbox met: dtool help"
        return 0
    fi

    warning "Installatie afgerond met fouten."
    info "Bekijk het logbestand en voer --check uit."
    return 1
}

# ============================================================
# VERWIJDEREN
# ============================================================

run_uninstall() {
    heading "Docker Toolbox verwijderen"

    require docker systemctl

    check_managed_path "$DTOOL"
    check_managed_path "$ALIAS_FILE"
    check_managed_path "$BASHRC"

    echo "Wordt verwijderd:"
    echo "  - dtool"
    echo "  - Docker-aliassen"
    echo "  - Eigen Docker-blok uit .bashrc"

    echo
    echo "Blijft behouden:"
    echo "  - Docker-images"
    echo "  - Containers"
    echo "  - Volumes"
    echo "  - Systeempakketten"
    echo "  - Back-ups"

    if [[ "$DRY_RUN" == true ]]; then
        info "DRY-RUN: niets gewijzigd."
        return 0
    fi

    confirm "Docker Toolbox verwijderen?" || return 0

    init_log

    uninstall_docker
}

# ============================================================
# START
# ============================================================

main() {
    parse_arguments "$@"
    check_home

    case "$MODE" in
        check)
            run_check
            ;;

        restore)
            require omarchy omarchy-version python3 tar
            check_omarchy_version
            check_theme_requirements
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
