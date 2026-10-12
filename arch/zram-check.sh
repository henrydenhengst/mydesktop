
#!/usr/bin/env bash
#
# zram-check.sh
# Controle en optionele configuratie van zram voor Arch Linux en CachyOS.
#
# Gebruik:
#   bash zram-check.sh
#   sudo bash zram-check.sh --dry-run
#   sudo bash zram-check.sh --apply
#   bash zram-check.sh --help
#
# Gebruikt uitsluitend pacman en officiële geconfigureerde pakketbronnen.
# Geen AUR, yay of paru.
#
# Veiligheid:
# - Bestaande zram-configuratie wordt niet overschreven.
# - Actieve zram wordt niet gewijzigd.
# - --dry-run voert geen wijzigingen uit.
# - Na configuratie is een herstart nodig.

set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly CONFIG="/etc/systemd/zram-generator.conf"
readonly CONFIG_DIR="/etc/systemd/zram-generator.conf.d"

MODE="check"

usage() {
    cat <<EOF
Gebruik: $SCRIPT_NAME [OPTIE]

Opties:
  --check      Alleen controleren (standaard)
  --dry-run    Tonen wat --apply zou doen, zonder wijzigingen
  --apply      zram-generator installeren en configuratie aanmaken
  --help       Deze hulp tonen

Pakketbeheer:
  Alleen pacman en officiële geconfigureerde repositories.
  Geen AUR en geen AUR-helper.
EOF
}

log() {
    printf '[INFO] %s\n' "$*"
}

warn() {
    printf '[WAARSCHUWING] %s\n' "$*" >&2
}

error() {
    printf '[FOUT] %s\n' "$*" >&2
}

die() {
    error "$*"
    exit 1
}

for arg in "$@"; do
    case "$arg" in
        --check)  MODE="check" ;;
        --dry-run) MODE="dry-run" ;;
        --apply)  MODE="apply" ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            die "Onbekende optie: $arg"
            ;;
    esac
done

# Controleer of dit Arch Linux of een daarop gebaseerde distributie is.
[[ -r /etc/os-release ]] || die "/etc/os-release niet gevonden."
# shellcheck source=/dev/null
source /etc/os-release

OS_IDS=" ${ID:-} ${ID_LIKE:-} "

case "$OS_IDS" in
    *" arch "*|*" cachyos "*)
        log "Distributie: ${PRETTY_NAME:-Arch Linux-compatibel}"
        ;;
    *)
        die "Deze distributie lijkt geen Arch Linux of CachyOS te zijn."
        ;;
esac

# Controleer beschikbare RAM.
RAM_KIB="$(awk '/^MemTotal:/ { print $2; exit }' /proc/meminfo)"
[[ "$RAM_KIB" =~ ^[0-9]+$ ]] || die "RAM kon niet worden bepaald."

RAM_MIB=$((RAM_KIB / 1024))
log "Totaal RAM: ${RAM_MIB} MiB"

# Toon de huidige swapconfiguratie.
printf '\n--- Huidige swap ---\n'

if command -v swapon >/dev/null 2>&1; then
    if ! swapon --show; then
        warn "De swapstatus kon niet worden uitgelezen."
    fi
else
    warn "Het commando swapon is niet beschikbaar."
fi

# Controleer actieve zram-apparaten.
printf '\n--- Zram-apparaten ---\n'

shopt -s nullglob
ZRAM_DEVICES=(/sys/block/zram*)

ACTIVE_ZRAM=0

if ((${#ZRAM_DEVICES[@]} == 0)); then
    log "Geen zram-apparaten gevonden."
else
    ACTIVE_ZRAM=1

    for device in "${ZRAM_DEVICES[@]}"; do
        [[ -e "$device" ]] || continue

        DEVICE_NAME="${device##*/}"
        printf 'Apparaat: %s\n' "$DEVICE_NAME"

        if [[ -r "$device/disksize" ]]; then
            SIZE_BYTES="$(<"$device/disksize")"
            SIZE_MIB=$((SIZE_BYTES / 1024 / 1024))
            printf '  Grootte: %s MiB\n' "$SIZE_MIB"
        fi

        if [[ -r "$device/comp_algorithm" ]]; then
            printf '  Compressie: '
            cat "$device/comp_algorithm"
        fi

        if [[ -r "$device/mm_stat" ]]; then
            printf '  Geheugenstatistieken: '
            cat "$device/mm_stat"
        fi
    done
fi

# Controleer de geïnstalleerde pakketstatus.
printf '\n--- Pakketstatus ---\n'

if pacman -Q zram-generator >/dev/null 2>&1; then
    log "zram-generator is geïnstalleerd."
    PACKAGE_INSTALLED=1
else
    log "zram-generator is niet geïnstalleerd."
    PACKAGE_INSTALLED=0
fi

# Toon bestaande configuratiebestanden.
printf '\n--- Bestaande configuratie ---\n'

EXISTING_CONFIGS=()

if [[ -e "$CONFIG" ]]; then
    EXISTING_CONFIGS+=("$CONFIG")
fi

if [[ -d "$CONFIG_DIR" ]]; then
    for file in "$CONFIG_DIR"/*.conf; do
        [[ -e "$file" ]] && EXISTING_CONFIGS+=("$file")
    done
fi

if ((${#EXISTING_CONFIGS[@]} == 0)); then
    log "Geen bestaande zram-generator-configuratie gevonden."
else
    for file in "${EXISTING_CONFIGS[@]}"; do
        printf 'Gevonden: %s\n' "$file"
    done
    warn "Bestaande configuratie wordt niet automatisch gewijzigd."
fi

# Bepaal een conservatieve zram-grootte: maximaal de helft van het RAM,
# met een maximum van 8 GiB.
TARGET_MIB=$((RAM_MIB / 2))

if ((TARGET_MIB > 8192)); then
    TARGET_MIB=8192
fi

if ((TARGET_MIB < 256)); then
    TARGET_MIB=256
fi

printf '\n--- Voorgestelde instelling ---\n'
printf 'Zram-grootte: %s MiB\n' "$TARGET_MIB"
printf 'Swap-prioriteit: 100\n'

if [[ "$MODE" == "check" ]]; then
    printf '\nControle voltooid. Er zijn geen wijzigingen aangebracht.\n'
    exit 0
fi

# Controleer of de wijziging veilig kan worden uitgevoerd.
if ((ACTIVE_ZRAM == 1)); then
    die "Er bestaat al een zram-apparaat. Er worden geen wijzigingen aangebracht."
fi

if ((${#EXISTING_CONFIGS[@]} > 0)); then
    die "Er bestaat al configuratie. Controleer die eerst handmatig."
fi

if [[ "$MODE" == "dry-run" ]]; then
    printf '\n--- Dry-run: geplande acties ---\n'

    if ((PACKAGE_INSTALLED == 0)); then
        printf '1. Installeren met: pacman -S --needed zram-generator\n'
    else
        printf '1. zram-generator is al geïnstalleerd; installatie overslaan.\n'
    fi

    printf '2. Configuratie aanmaken: %s\n' "$CONFIG"
    printf '3. systemd opnieuw laten inlezen.\n'
    printf '4. Herstarten om zram te activeren.\n'
    printf '\nDry-run voltooid. Er zijn geen wijzigingen aangebracht.\n'
    exit 0
fi

# Vanaf hier is --apply actief.
if [[ "$EUID" -ne 0 ]]; then
    die "Gebruik voor --apply: sudo bash $SCRIPT_NAME --apply"
fi

# Installeer uitsluitend vanuit de geconfigureerde pacman-repositories.
if ((PACKAGE_INSTALLED == 0)); then
    if ! pacman -Si zram-generator >/dev/null 2>&1; then
        die "zram-generator niet gevonden in de geconfigureerde pacman-repositories. Er wordt geen AUR gebruikt."
    fi

    log "zram-generator installeren via pacman..."
    pacman -S --needed zram-generator
fi

# Controleer opnieuw of de configuratie nog steeds ontbreekt.
if [[ -e "$CONFIG" ]]; then
    die "Configuratiebestand bestaat inmiddels. Er wordt niets overschreven."
fi

if [[ -d "$CONFIG_DIR" ]]; then
    for file in "$CONFIG_DIR"/*.conf; do
        if [[ -e "$file" ]]; then
            die "Configuratiefragment gevonden: $file. Er wordt niets overschreven."
        fi
    done
fi

# Maak de configuratie aan.
mkdir -p /etc/systemd

cat > "$CONFIG" <<EOF
# Beheerd door $SCRIPT_NAME
# Aangemaakt: $(date '+%Y-%m-%d %H:%M:%S')
[zram0]
zram-size = ${TARGET_MIB}M
swap-priority = 100
EOF

chmod 0644 "$CONFIG"

log "Configuratie aangemaakt: $CONFIG"

systemctl daemon-reload

printf '\n--- Volgende stap ---\n'
printf 'Herstart de computer om zram te activeren:\n'
printf '  sudo reboot\n'
printf '\nControleer na de herstart met:\n'
printf '  swapon --show\n'
printf '  zramctl\n'

printf '\nKlaar. Er is geen AUR gebruikt.\n'
