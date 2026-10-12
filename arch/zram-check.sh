
#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# zram-check.sh
# Diagnose en veilige configuratie van zram op Arch/CachyOS.
#
# Standaard: alleen onderzoeken en advies geven.
# --apply:   zram-generator installeren/configureren.
# --dry-run: tonen wat --apply zou doen.
# --help:    helptekst tonen.
#
# Het script:
# - controleert distributie, RAM en CPU
# - detecteert bestaande swap en zram
# - herkent bestaande zram-configuratie
# - geeft advies op basis van RAM
# - maakt een back-up van een bestaande configuratie
# - overschrijft geen bestaande zram-configuratie
# - schakelt bestaande swap niet uit
# ============================================================

readonly SCRIPT_NAME="zram-check"
readonly CONFIG="/etc/systemd/zram-generator.conf"
readonly BACKUP_DIR="/etc/systemd/zram-generator.conf.backups"

APPLY=0
DRY_RUN=0

log()  { printf '\n[INFO] %s\n' "$*"; }
warn() { printf '\n[WAARSCHUWING] %s\n' "$*" >&2; }
die()  { printf '\n[FOUT] %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<EOF
Gebruik: $SCRIPT_NAME [opties]

Opties:
  --apply     Voer aanbevolen wijzigingen uit.
  --dry-run   Toon acties zonder iets te wijzigen.
  -h, --help  Toon deze hulp.

Zonder opties wordt alleen een diagnose uitgevoerd.

Voorbeelden:
  ./$SCRIPT_NAME
  ./$SCRIPT_NAME --dry-run
  ./$SCRIPT_NAME --apply
EOF
}

while (($# > 0)); do
    case "$1" in
        --apply)   APPLY=1 ;;
        --dry-run) DRY_RUN=1 ;;
        -h|--help) usage; exit 0 ;;
        *) die "Onbekende optie: $1" ;;
    esac
    shift
done

if ((DRY_RUN)); then
    APPLY=1
fi

# ------------------------------------------------------------
# 1. Besturingssysteem
# ------------------------------------------------------------

[[ -r /etc/os-release ]] ||
    die "Kan /etc/os-release niet lezen."

# shellcheck disable=SC1091
source /etc/os-release

if [[ "${ID:-}" != "arch" &&
      "${ID:-}" != "cachyos" &&
      " ${ID_LIKE:-} " != *" arch "* ]]; then
    die "Dit script ondersteunt alleen Arch Linux en CachyOS."
fi

command -v pacman >/dev/null 2>&1 ||
    die "Pacman is niet beschikbaar."

printf '%s\n' "=========================================="
printf '%s\n' " zram-diagnose voor Arch Linux / CachyOS"
printf '%s\n' "=========================================="
printf 'Systeem: %s\n' "${PRETTY_NAME:-onbekend}"

# ------------------------------------------------------------
# 2. RAM bepalen
# ------------------------------------------------------------

[[ -r /proc/meminfo ]] ||
    die "Kan /proc/meminfo niet lezen."

RAM_KIB=$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo)

[[ "$RAM_KIB" =~ ^[0-9]+$ ]] ||
    die "Totale hoeveelheid RAM kon niet worden bepaald."

RAM_MIB=$((RAM_KIB / 1024))
RAM_GIB=$((RAM_MIB / 1024))

printf '\nRAM: %s MiB (ongeveer %s GiB)\n' \
    "$RAM_MIB" "$RAM_GIB"

# ------------------------------------------------------------
# 3. MacBook en CPU onderzoeken
# ------------------------------------------------------------

MODEL="onbekend"

for f in /sys/class/dmi/id/product_name \
         /sys/class/dmi/id/board_name; do
    if [[ -r "$f" ]]; then
        value=$(<"$f")
        if [[ "$value" == *MacBook* ]]; then
            MODEL="$value"
            break
        fi
    fi
done

printf 'Computermodel: %s\n' "$MODEL"

if command -v lscpu >/dev/null 2>&1; then
    CPU=$(lscpu | awk -F: '/^Model name:/ {
        sub(/^[[:space:]]+/, "", $2); print $2; exit
    }')
    printf 'Processor: %s\n' "${CPU:-onbekend}"
fi

# ------------------------------------------------------------
# 4. Huidige swap en zram onderzoeken
# ------------------------------------------------------------

printf '\n--- Huidige geheugensituatie ---\n'

if command -v free >/dev/null 2>&1; then
    free -h
fi

printf '\n--- Actieve swap ---\n'

if command -v swapon >/dev/null 2>&1; then
    swapon --show || true
else
    warn "swapon is niet beschikbaar."
fi

printf '\n--- Zram-apparaten ---\n'

ZRAM_FOUND=0

for dev in /sys/block/zram*; do
    [[ -e "$dev" ]] || continue
    ZRAM_FOUND=1

    printf 'Apparaat: %s\n' "${dev##*/}"

    if [[ -r "$dev/disksize" ]]; then
        size=$(<"$dev/disksize")
        printf 'Capaciteit: %s bytes\n' "$size"
    fi

    if [[ -r "$dev/comp_algorithm" ]]; then
        printf 'Compressie: '
        cat "$dev/comp_algorithm"
    fi
done

if ((ZRAM_FOUND == 0)); then
    printf '%s\n' "Geen actief zram-apparaat aangetroffen."
fi

# ------------------------------------------------------------
# 5. Bestaande zram-configuratie detecteren
# ------------------------------------------------------------

printf '\n--- Bestaande configuratie ---\n'

CONFIG_EXISTS=0

if [[ -e "$CONFIG" ]]; then
    CONFIG_EXISTS=1
    printf 'Configuratie gevonden: %s\n' "$CONFIG"
    cat "$CONFIG"
else
    printf '%s\n' "Geen hoofdbestand zram-generator.conf."
fi

for f in /etc/systemd/zram-generator.conf.d/*.conf; do
    [[ -e "$f" ]] || continue
    printf '\nAanvullend configuratiebestand: %s\n' "$f"
    cat "$f"
    CONFIG_EXISTS=1
done

for pkg in zram-generator zram-tools zramswap; do
    if pacman -Q "$pkg" >/dev/null 2>&1; then
        printf 'Geïnstalleerd pakket: %s\n' "$pkg"
    fi
done

# ------------------------------------------------------------
# 6. Advies op basis van RAM
# ------------------------------------------------------------

printf '\n==========================================\n'
printf '%s\n' " ADVIES"
printf '%s\n' "=========================================="

TARGET_MIB=0

if ((RAM_MIB < 2048)); then
    warn "Minder dan 2 GiB RAM."
    printf '%s\n' \
        "Zram kan helpen, maar lost ernstige geheugentekorten niet op."
    TARGET_MIB=$((RAM_MIB / 2))

elif ((RAM_MIB < 8192)); then
    printf '%s\n' \
        "Zram aanbevolen: het systeem heeft relatief weinig RAM."
    TARGET_MIB=$((RAM_MIB / 2))

elif ((RAM_MIB < 16384)); then
    printf '%s\n' \
        "Zram waarschijnlijk nuttig bij veel gelijktijdige programma's."
    TARGET_MIB=$((RAM_MIB / 4))

else
    printf '%s\n' \
        "Zram optioneel: het systeem heeft relatief veel RAM."
    TARGET_MIB=$((RAM_MIB / 4))
fi

# Houd de standaardconfiguratie bescheiden.
if ((TARGET_MIB > 8192)); then
    TARGET_MIB=8192
fi

# Rond naar beneden af op veelvouden van 256 MiB.
TARGET_MIB=$((TARGET_MIB / 256 * 256))

if ((TARGET_MIB < 256)); then
    TARGET_MIB=256
fi

printf 'Voorgestelde zram-capaciteit: %s MiB\n' "$TARGET_MIB"
printf '%s\n' \
    "Dit is de maximale logische swapruimte, geen gegarandeerde geheugentoename."

# ------------------------------------------------------------
# 7. Bestaande zram niet overschrijven
# ------------------------------------------------------------

if ((ZRAM_FOUND)) || ((CONFIG_EXISTS)); then
    warn "Er is al een zram-apparaat of configuratie gevonden."
    printf '%s\n' \
        "Automatische herconfiguratie wordt overgeslagen."
    printf '%s\n' \
        "Controleer de huidige instellingen voordat je iets wijzigt."

    if ((APPLY)); then
        die "Geen wijzigingen uitgevoerd vanwege bestaande zram-configuratie."
    fi

    exit 0
fi

if ((ZRAM_FOUND == 0)); then
    printf '%s\n' \
        "Er is geen actief zram-apparaat gevonden."
fi

# ------------------------------------------------------------
# 8. Alleen diagnose wanneer --apply ontbreekt
# ------------------------------------------------------------

if ((!APPLY)); then
    printf '\n%s\n' \
        "Diagnose afgerond. Er zijn geen wijzigingen uitgevoerd."
    printf '%s\n' \
        "Gebruik --dry-run om de voorgestelde acties te bekijken."
    printf '%s\n' \
        "Gebruik --apply om de configuratie toe te passen."
    exit 0
fi

# ------------------------------------------------------------
# 9. Rechten en pakketcontrole
# ------------------------------------------------------------

if ((EUID == 0)); then
    SUDO=()
elif command -v sudo >/dev/null 2>&1; then
    SUDO=(sudo)
elif command -v doas >/dev/null 2>&1; then
    SUDO=(doas)
else
    die "Geen sudo of doas beschikbaar."
fi

if ((!DRY_RUN)); then
    if ((${#SUDO[@]} > 0)); then
        "${SUDO[@]}" -v ||
            die "Authenticatie mislukt."
    fi
fi

if pacman -Q zram-generator >/dev/null 2>&1; then
    log "zram-generator is al geïnstalleerd."
else
    if ((DRY_RUN)); then
        log "DRY-RUN: zou zram-generator installeren."
    else
        log "zram-generator installeren..."

        "${SUDO[@]}" pacman -S --needed zram-generator ||
            die "Installatie van zram-generator mislukt."
    fi
fi

# ------------------------------------------------------------
# 10. Configuratie aanmaken
# ------------------------------------------------------------

if ((DRY_RUN)); then
    printf '\n%s\n' "DRY-RUN: voorgestelde configuratie:"
    printf '[zram0]\n'
    printf 'zram-size = %sM\n' "$TARGET_MIB"
    printf 'compression-algorithm = zstd\n'
    printf 'swap-priority = 100\n'

    printf '\n%s\n' \
        "Er zijn geen configuratiebestanden gewijzigd."
    exit 0
fi

# Controleer opnieuw om overschrijven te voorkomen.
if [[ -e "$CONFIG" ]]; then
    die "Configuratie bestaat inmiddels; bestand niet overschreven."
fi

# Maak de back-upmap aan voor eventuele latere wijzigingen.
"${SUDO[@]}" install -d -m 0755 "$BACKUP_DIR"

# Maak een tijdelijk bestand en installeer het atomair.
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

cat > "$tmp" <<EOF
# Automatisch aangemaakt door $SCRIPT_NAME
# RAM: ${RAM_MIB} MiB
# Voorgestelde zram-capaciteit: ${TARGET_MIB} MiB

[zram0]
zram-size = ${TARGET_MIB}M
compression-algorithm = zstd
swap-priority = 100
EOF

"${SUDO[@]}" install -m 0644 "$tmp" "$CONFIG" ||
    die "Configuratie kon niet worden geschreven."

log "Configuratie opgeslagen in $CONFIG"

# ------------------------------------------------------------
# 11. systemd opnieuw laten inlezen
# ------------------------------------------------------------

if "${SUDO[@]}" systemctl daemon-reload; then
    log "systemd-configuratie opnieuw ingelezen."
else
    warn "systemctl daemon-reload is mislukt."
fi

printf '\n%s\n' "=========================================="
printf '%s\n' " CONFIGURATIE AANGEMAAKT"
printf '%s\n' "=========================================="
printf 'RAM: %s MiB\n' "$RAM_MIB"
printf 'Zram-doelgrootte: %s MiB\n' "$TARGET_MIB"
printf '%s\n' "Compressie: zstd"
printf '%s\n' "Prioriteit: 100"

printf '\n%s\n' \
    "Start de computer opnieuw op om zram te activeren."
printf '%s\n' \
    "Herstart niet automatisch; sla eerst je werk op."

printf '\nControleer na de herstart met:\n'
printf '%s\n' "  zramctl"
printf '%s\n' "  swapon --show"
printf '%s\n' "  free -h"

log "Klaar."
