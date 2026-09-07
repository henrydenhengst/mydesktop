#!/usr/bin/env bash
#
# wget -O zram-setup.sh https://pastebin.com/raw/Qdf3gxFV
#
# ZRAM + Swap configuratie voor antiX / SysVinit
#
# Functie:
# - ZRAM automatisch configureren
# - ZRAM automatisch starten via SysVinit
# - Dynamische ZRAM-grootte op basis van RAM
# - Swapfile als vangnet
# - ZRAM hogere prioriteit dan disk-swap
# - vm.swappiness instellen
# - Logging en statusrapportage
# - Idempotent: veilig meerdere keren uitvoeren
# - Dry-run ondersteuning
#
# Geschikt voor:
# - antiX Linux
# - SysVinit
# - Debian-gebaseerde systemen

set -Eeuo pipefail

# =============================================================================
# Configuratie
# =============================================================================
ZRAM_MIN_MB=512
ZRAM_MAX_MB=2048
ZRAM_RATIO="0.5"
ZRAM_DEVICES=1
ZRAM_PRIORITY=100
SWAPFILE="/swapfile"
SWAPSIZE_MB=2048
SWAPFILE_PRIORITY=10
SWAPPINESS=20
INIT_SCRIPT="/etc/init.d/zramswap"
LOG_FILE="/var/log/zram-setup.log"
DRY_RUN=false
VERBOSE=false
COLOR_OUTPUT=true

# =============================================================================
# Kleuren (voor betere leesbaarheid)
# =============================================================================
if [[ -t 1 ]] && [[ "$COLOR_OUTPUT" == true ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m' # No Color
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; NC=''
fi

# =============================================================================
# Command-line opties
# =============================================================================
usage() {
    cat << EOF
${BOLD}ZRAM + Swap configuratie voor antiX / SysVinit${NC}

${BOLD}Gebruik:${NC}
  sudo $0 [OPTIES]

${BOLD}Opties:${NC}
  ${CYAN}--dry-run${NC}      Toon wat er zou gebeuren zonder wijzigingen uit te voeren.
  ${CYAN}--verbose${NC}      Toon uitgebreide uitvoer.
  ${CYAN}--ratio <getal>${NC} ZRAM-grootte als percentage van RAM (0.1-1.0). Standaard: 0.5
  ${CYAN}--devices <aantal>${NC} Aantal ZRAM-devices. Standaard: 1
  ${CYAN}--swappiness <getal>${NC} vm.swappiness waarde (0-100). Standaard: 20
  ${CYAN}--no-color${NC}     Schakel kleuren uit.
  ${CYAN}--help${NC}         Toon deze hulp.

${BOLD}Voorbeelden:${NC}
  sudo $0
  sudo $0 --verbose
  sudo $0 --ratio 0.75
  sudo $0 --dry-run --verbose
  sudo $0 --swappiness 10

${BOLD}Info:${NC}
  - ZRAM wordt geconfigureerd met hogere prioriteit dan de swapfile
  - De swapfile dient als vangnet wanneer ZRAM vol raakt
  - Na herstart wordt ZRAM automatisch gestart via SysVinit
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --ratio)
            if [[ -z "${2:-}" ]]; then
                echo "${RED}Fout: --ratio vereist een waarde.${NC}"
                exit 1
            fi
            if ! [[ "$2" =~ ^([0-9]+([.][0-9]+)?|[.][0-9]+)$ ]]; then
                echo "${RED}Fout: --ratio moet een getal zijn.${NC}"
                exit 1
            fi
            ZRAM_RATIO="$2"
            shift 2
            ;;
        --devices)
            if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
                echo "${RED}Fout: --devices vereist een positief geheel getal.${NC}"
                exit 1
            fi
            if (( $2 < 1 )); then
                echo "${RED}Fout: minimaal één ZRAM-device vereist.${NC}"
                exit 1
            fi
            ZRAM_DEVICES="$2"
            shift 2
            ;;
        --swappiness)
            if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
                echo "${RED}Fout: --swappiness vereist een getal tussen 0 en 100.${NC}"
                exit 1
            fi
            if (( $2 < 0 || $2 > 100 )); then
                echo "${RED}Fout: --swappiness moet tussen 0 en 100 liggen.${NC}"
                exit 1
            fi
            SWAPPINESS="$2"
            shift 2
            ;;
        --no-color)
            COLOR_OUTPUT=false
            RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; NC=''
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "${RED}Fout: onbekende optie: $1${NC}"
            echo
            usage
            exit 1
            ;;
    esac
done

# =============================================================================
# Validatie configuratie
# =============================================================================
if ! awk -v r="$ZRAM_RATIO" \
    'BEGIN { exit !(r >= 0.1 && r <= 1.0) }' 2>/dev/null; then
    echo "${RED}Fout: --ratio moet tussen 0.1 en 1.0 liggen.${NC}"
    exit 1
fi

# =============================================================================
# Root controle
# =============================================================================
if [[ "$EUID" -ne 0 ]]; then
    echo "${RED}Fout: Dit script moet als root worden uitgevoerd.${NC}"
    echo
    echo "${BOLD}Gebruik:${NC}"
    echo "  sudo $0"
    exit 1
fi

# =============================================================================
# Logging
# =============================================================================
setup_logging() {
    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi
    
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    chmod 640 "$LOG_FILE"
    
    # Log naar bestand, maar behoud terminal output
    exec > >(tee -a "$LOG_FILE") 2>&1
    
    echo
    echo "${CYAN}============================================================${NC}"
    echo "${CYAN} ZRAM Setup Log${NC}"
    echo " $(date '+%Y-%m-%d %H:%M:%S')"
    echo "${CYAN}============================================================${NC}"
    echo
}

log() {
    local level="$1"
    local message="$2"
    local color=""
    local prefix=""
    
    case "$level" in
        ERROR)   color="$RED"; prefix="✗";;
        WARN)    color="$YELLOW"; prefix="⚠";;
        INFO)    color="$GREEN"; prefix="✓";;
        DEBUG)   color="$CYAN"; prefix="▶";;
        *)       color="$NC"; prefix="•";;
    esac
    
    if [[ "$VERBOSE" == true || "$level" == "ERROR" || "$level" == "WARN" ]]; then
        echo "${color}[${level}] ${prefix} ${message}${NC}"
    else
        echo "${color}[${level}] ${prefix} ${message}${NC}"
    fi
}

setup_logging

# =============================================================================
# Banner
# =============================================================================
echo "${BOLD}${CYAN}============================================================${NC}"
echo "${BOLD}${CYAN} ZRAM + Swap configuratie voor antiX / SysVinit${NC}"
echo "${BOLD}${CYAN}============================================================${NC}"
echo

if [[ "$DRY_RUN" == true ]]; then
    echo "${YELLOW}*** DRY RUN MODE ***${NC}"
    echo "${YELLOW}Er worden geen wijzigingen uitgevoerd.${NC}"
    echo
fi

# =============================================================================
# Systeeminformatie
# =============================================================================
get_ram_mb() {
    awk '/MemTotal:/ { print int($2 / 1024); exit }' /proc/meminfo
}

get_swap_total() {
    swapon --show=SIZE --noheadings 2>/dev/null | \
        awk '{sum += $1} END {print sum}' || echo 0
}

get_os_version() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "${NAME:-Linux} ${VERSION_ID:-}"
    elif [[ -f /etc/debian_version ]]; then
        echo "Debian $(cat /etc/debian_version)"
    else
        echo "Onbekend"
    fi
}

RAM_MB="$(get_ram_mb)"
SWAP_TOTAL_MB="$(get_swap_total)"
OS_VERSION="$(get_os_version)"

if [[ -z "$RAM_MB" || "$RAM_MB" -le 0 ]]; then
    log "ERROR" "Kan hoeveelheid RAM niet bepalen."
    exit 1
fi

# =============================================================================
# ZRAM-grootte berekenen
# =============================================================================
calculate_zram_size() {
    local ram_mb="$1"
    local zram_mb
    
    zram_mb="$(awk -v ram="$ram_mb" -v ratio="$ZRAM_RATIO" \
        'BEGIN { printf "%.0f", ram * ratio }')"
    
    if (( zram_mb < ZRAM_MIN_MB )); then
        zram_mb="$ZRAM_MIN_MB"
    fi
    if (( zram_mb > ZRAM_MAX_MB )); then
        zram_mb="$ZRAM_MAX_MB"
    fi
    
    echo "$zram_mb"
}

ZRAM_SIZE_MB="$(calculate_zram_size "$RAM_MB")"

# =============================================================================
# Configuratie-overzicht
# =============================================================================
log "INFO" "Systeem: ${OS_VERSION}"
log "INFO" "Geïnstalleerd RAM : ${RAM_MB} MB"
log "INFO" "Bestaande swap : ${SWAP_TOTAL_MB} MB"
log "INFO" "ZRAM ratio : ${ZRAM_RATIO}"
log "INFO" "ZRAM per device : ${ZRAM_SIZE_MB} MB"
log "INFO" "Aantal ZRAM-devices : ${ZRAM_DEVICES}"
log "INFO" "Totale ZRAM-capaciteit : $((ZRAM_SIZE_MB * ZRAM_DEVICES)) MB"
log "INFO" "ZRAM prioriteit : ${ZRAM_PRIORITY}"
log "INFO" "Swapfile : ${SWAPSIZE_MB} MB"
log "INFO" "Swapfile prioriteit : ${SWAPFILE_PRIORITY}"
log "INFO" "Swappiness : ${SWAPPINESS}"
echo

# =============================================================================
# Compressor bepalen (zonder lz4hc - niet ideaal voor swap)
# =============================================================================
get_compressor() {
    local sys="$1"
    local available
    
    if [[ ! -f "${sys}/comp_algorithm" ]]; then
        return 1
    fi
    
    available="$(cat "${sys}/comp_algorithm")"
    
    # Voorkeursvolgorde: zstd -> lz4 -> lzo
    # lz4hc is niet opgenomen omdat het voor swap meestal niet de beste keuze is
    if echo "$available" | grep -qw "zstd"; then
        echo "zstd"
        return 0
    fi
    if echo "$available" | grep -qw "lz4"; then
        echo "lz4"
        return 0
    fi
    if echo "$available" | grep -qw "lzo"; then
        echo "lzo"
        return 0
    fi
    
    return 1
}

# =============================================================================
# Check of ZRAM ondersteund wordt
# =============================================================================
check_zram_support() {
    if ! lsmod | grep -q "^zram"; then
        if ! modprobe zram 2>/dev/null; then
            log "ERROR" "ZRAM wordt niet ondersteund door deze kernel."
            return 1
        fi
    fi
    return 0
}

# =============================================================================
# Check of ZRAM al correct actief is
# =============================================================================
is_zram_active() {
    local device="$1"
    local expected_size="$2"
    
    # Check of device als swap actief is
    if ! swapon --show=NAME --noheadings 2>/dev/null | grep -Fxq "$device"; then
        return 1
    fi
    
    # Check of de grootte overeenkomt (indien mogelijk)
    local sys="/sys/block/$(basename "$device")"
    if [[ -f "${sys}/disksize" ]]; then
        local current_size=$(cat "${sys}/disksize" | sed 's/M$//')
        if [[ "$current_size" -eq "$expected_size" ]]; then
            return 0
        fi
    fi
    
    return 1
}

# =============================================================================
# ZRAM configureren (alleen als nodig)
# =============================================================================
configure_zram() {
    local zram_mb="$1"
    
    log "INFO" "ZRAM configureren..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log "INFO" "DRY RUN: ZRAM zou worden geconfigureerd."
        return 0
    fi
    
    # Controleer ZRAM ondersteuning
    if ! check_zram_support; then
        return 1
    fi
    
    # -------------------------------------------------------------------------
    # Devices
    # -------------------------------------------------------------------------
    local i device sys compressor priority
    
    for ((i=0; i<ZRAM_DEVICES; i++)); do
        device="/dev/zram${i}"
        sys="/sys/block/zram${i}"
        
        log "DEBUG" "Controleren: ${device}"
        
        if [[ ! -b "$device" ]]; then
            log "WARN" "${device} bestaat niet."
            continue
        fi
        
        # Check of ZRAM al correct actief is
        if is_zram_active "$device" "$zram_mb"; then
            log "INFO" "${device} is al correct geconfigureerd (${zram_mb} MB). Overslaan."
            continue
        fi
        
        # ---------------------------------------------------------------------
        # Bestaande swap uitschakelen
        # ---------------------------------------------------------------------
        if swapon --show=NAME --noheadings 2>/dev/null | grep -Fxq "$device"; then
            log "INFO" "${device} is actief met andere configuratie; herconfigureren..."
            swapoff "$device" || true
        fi
        
        # ---------------------------------------------------------------------
        # ZRAM resetten
        # ---------------------------------------------------------------------
        if [[ -f "${sys}/reset" ]]; then
            echo 1 > "${sys}/reset"
        fi
        
        # ---------------------------------------------------------------------
        # Compressor (zonder lz4hc)
        # ---------------------------------------------------------------------
        compressor="$(get_compressor "$sys" || true)"
        if [[ -n "$compressor" ]]; then
            if echo "$compressor" > "${sys}/comp_algorithm" 2>/dev/null; then
                log "DEBUG" "${device}: compressor = ${compressor}"
            else
                log "WARN" "${device}: compressor kon niet worden ingesteld."
            fi
        else
            log "WARN" "${device}: geen geschikt compressie-algoritme gevonden."
        fi
        
        # ---------------------------------------------------------------------
        # Grootte
        # ---------------------------------------------------------------------
        echo "${zram_mb}M" > "${sys}/disksize"
        
        # ---------------------------------------------------------------------
        # Maximalisatie instellingen (alleen als beschikbaar)
        # ---------------------------------------------------------------------
        if [[ -f "${sys}/max_comp_streams" ]]; then
            local ncpu
            ncpu="$(nproc 2>/dev/null || echo 1)"
            echo "$ncpu" > "${sys}/max_comp_streams" 2>/dev/null || true
        fi
        
        # ---------------------------------------------------------------------
        # Swap initialiseren
        # ---------------------------------------------------------------------
        mkswap -f "$device" >/dev/null
        
        # ---------------------------------------------------------------------
        # Prioriteit
        # ---------------------------------------------------------------------
        priority=$((ZRAM_PRIORITY - i))
        swapon -p "$priority" "$device"
        
        log "INFO" \
            "${device} actief: ${zram_mb} MB, prioriteit ${priority}"
    done
    
    return 0
}

# =============================================================================
# Backupfunctie
# =============================================================================
backup_config() {
    local file="$1"
    local backup="${file}.zram-bak.$(date +%Y%m%d-%H%M%S)"
    
    if [[ "$DRY_RUN" == true ]]; then
        log "DEBUG" "DRY RUN: backup van ${file} zou worden gemaakt."
        return 0
    fi
    
    if [[ -f "$file" ]]; then
        cp -a "$file" "$backup"
        log "DEBUG" "Backup gemaakt: ${backup}"
    fi
}

# =============================================================================
# Verwijder oude ZRAM configuraties
# =============================================================================
clean_old_zram_config() {
    # Verwijder oude init scripts als ze bestaan
    local old_scripts=(
        "/etc/init.d/zram"
        "/etc/init.d/zram-config"
        "/usr/local/bin/zram-setup"
    )
    
    for script in "${old_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            log "INFO" "Oud script gevonden: ${script}"
            if [[ "$DRY_RUN" == true ]]; then
                log "INFO" "DRY RUN: zou ${script} verwijderen"
            else
                rm -f "$script"
                log "INFO" "Verwijderd: ${script}"
            fi
        fi
    done
    
    # Verwijder oude registraties uit rc.d
    if [[ "$DRY_RUN" != true ]]; then
        for level in 0 1 2 3 4 5 6; do
            local link="/etc/rc${level}.d/S*zram*"
            if ls $link 2>/dev/null | grep -q .; then
                rm -f $link 2>/dev/null || true
            fi
        done
    fi
}

# =============================================================================
# ZRAM activeren voor huidige sessie
# =============================================================================
# Verwijder oude configuraties eerst
clean_old_zram_config

if ! configure_zram "$ZRAM_SIZE_MB"; then
    echo
    log "WARN" "ZRAM kon niet worden geconfigureerd."
    log "WARN" "Het swapfile blijft als vangnet beschikbaar."
fi
echo

# =============================================================================
# SysVinit script genereren (consistent met hoofdconfiguratie)
# =============================================================================
log "INFO" "SysVinit-script configureren: ${INIT_SCRIPT}"

if [[ "$DRY_RUN" == true ]]; then
    log "INFO" "DRY RUN: ${INIT_SCRIPT} zou worden aangemaakt."
else
    backup_config "$INIT_SCRIPT"
    
    cat > "$INIT_SCRIPT" << 'EOF'
#!/bin/sh
#
# ZRAM swap voor antiX / SysVinit
#
### BEGIN INIT INFO
# Provides: zramswap
# Required-Start: $local_fs
# Required-Stop: $local_fs
# Should-Start: $syslog
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Configure ZRAM swap
# Description: Start ZRAM swap devices at boot time
### END INIT INFO

# Configuratie - consistent met hoofdscript
ZRAM_DEVICES="'"${ZRAM_DEVICES}"'"
ZRAM_MIN_MB="'"${ZRAM_MIN_MB}"'"
ZRAM_MAX_MB="'"${ZRAM_MAX_MB}"'"
ZRAM_RATIO="'"${ZRAM_RATIO}"'"
ZRAM_PRIORITY="'"${ZRAM_PRIORITY}"'"
LOG_FILE="'"${LOG_FILE}"'"

# Kleuren (indien beschikbaar)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; NC=''
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null || true
}

log_info() {
    echo "${GREEN}✓${NC} $1"
    log "INFO: $1"
}

log_warn() {
    echo "${YELLOW}⚠${NC} $1"
    log "WARN: $1"
}

log_error() {
    echo "${RED}✗${NC} $1"
    log "ERROR: $1"
}

calculate_zram_size() {
    RAM_MB=$(awk '/MemTotal:/ { print int($2 / 1024); exit }' /proc/meminfo)
    ZRAM_MB=$(awk -v ram="$RAM_MB" -v ratio="$ZRAM_RATIO" \
        'BEGIN { printf "%.0f", ram * ratio }')
    [ "$ZRAM_MB" -lt "$ZRAM_MIN_MB" ] && ZRAM_MB="$ZRAM_MIN_MB"
    [ "$ZRAM_MB" -gt "$ZRAM_MAX_MB" ] && ZRAM_MB="$ZRAM_MAX_MB"
    echo "$ZRAM_MB"
}

get_compressor() {
    SYS="$1"
    [ -f "${SYS}/comp_algorithm" ] || return 1
    AVAILABLE=$(cat "${SYS}/comp_algorithm")
    
    # Voorkeursvolgorde: zstd -> lz4 -> lzo (zonder lz4hc)
    if echo "$AVAILABLE" | grep -qw "zstd"; then
        echo "zstd"
    elif echo "$AVAILABLE" | grep -qw "lz4"; then
        echo "lz4"
    elif echo "$AVAILABLE" | grep -qw "lzo"; then
        echo "lzo"
    else
        return 1
    fi
}

check_zram_support() {
    if ! lsmod | grep -q "^zram"; then
        if ! modprobe zram 2>/dev/null; then
            return 1
        fi
    fi
    return 0
}

is_zram_active() {
    DEVICE="$1"
    EXPECTED_SIZE="$2"
    
    # Check of device als swap actief is
    if ! swapon --show=NAME --noheadings 2>/dev/null | grep -Fxq "$DEVICE"; then
        return 1
    fi
    
    # Check of de grootte overeenkomt
    SYS="/sys/block/$(basename "$DEVICE")"
    if [ -f "${SYS}/disksize" ]; then
        CURRENT_SIZE=$(cat "${SYS}/disksize" | sed 's/M$//')
        if [ "$CURRENT_SIZE" -eq "$EXPECTED_SIZE" ] 2>/dev/null; then
            return 0
        fi
    fi
    
    return 1
}

start_zram() {
    echo "ZRAM swap activeren..."
    log "ZRAM starten."
    
    if ! check_zram_support; then
        log_warn "ZRAM kernelmodule niet beschikbaar."
        return 0
    fi
    
    ZRAM_MB=$(calculate_zram_size)
    
    for i in $(seq 0 $((ZRAM_DEVICES - 1))); do
        DEVICE="/dev/zram$i"
        SYS="/sys/block/zram$i"
        
        if [ ! -b "$DEVICE" ]; then
            log_warn "$DEVICE bestaat niet."
            continue
        fi
        
        # Check of ZRAM al correct actief is
        if is_zram_active "$DEVICE" "$ZRAM_MB"; then
            log_info "$DEVICE is al correct geconfigureerd. Overslaan."
            continue
        fi
        
        # Bestaande swap uitschakelen indien nodig
        if swapon --show=NAME --noheadings 2>/dev/null | grep -Fxq "$DEVICE"; then
            log_info "$DEVICE was actief met andere configuratie; herconfigureren..."
            swapoff "$DEVICE" 2>/dev/null || true
        fi
        
        # Reset ZRAM device
        if [ -f "${SYS}/reset" ]; then
            echo 1 > "${SYS}/reset"
        fi
        
        # Compressor instellen (zonder lz4hc)
        COMPRESSOR=$(get_compressor "$SYS" 2>/dev/null || true)
        if [ -n "$COMPRESSOR" ]; then
            echo "$COMPRESSOR" > "${SYS}/comp_algorithm" 2>/dev/null || true
        fi
        
        # Max compressie streams (alleen als beschikbaar)
        if [ -f "${SYS}/max_comp_streams" ]; then
            NCPU=$(nproc 2>/dev/null || echo 1)
            echo "$NCPU" > "${SYS}/max_comp_streams" 2>/dev/null || true
        fi
        
        # ZRAM-grootte instellen
        echo "${ZRAM_MB}M" > "${SYS}/disksize"
        
        # Swap initialiseren
        mkswap -f "$DEVICE" >/dev/null
        
        # Prioriteit
        PRIORITY=$((ZRAM_PRIORITY - i))
        swapon -p "$PRIORITY" "$DEVICE"
        
        log_info "$DEVICE actief: ${ZRAM_MB} MB (prioriteit $PRIORITY)"
    done
}

stop_zram() {
    echo "ZRAM swap deactiveren..."
    log "ZRAM stoppen."
    
    for i in $(seq 0 $((ZRAM_DEVICES - 1))); do
        DEVICE="/dev/zram$i"
        SYS="/sys/block/zram$i"
        
        if [ -b "$DEVICE" ]; then
            if swapon --show=NAME --noheadings 2>/dev/null | grep -Fxq "$DEVICE"; then
                swapoff "$DEVICE" 2>/dev/null || true
            fi
            if [ -f "${SYS}/reset" ]; then
                echo 1 > "${SYS}/reset"
                log "$DEVICE gereset"
            fi
        fi
    done
}

status_zram() {
    echo
    echo "ZRAM status:"
    echo "-------------"
    
    ACTIVE=0
    for i in $(seq 0 $((ZRAM_DEVICES - 1))); do
        DEVICE="/dev/zram$i"
        SYS="/sys/block/zram$i"
        
        if [ -b "$DEVICE" ]; then
            if swapon --show=NAME --noheadings 2>/dev/null | grep -Fxq "$DEVICE"; then
                ACTIVE=1
                echo "  ${GREEN}✓${NC} $DEVICE: ACTIEF"
                
                if [ -f "${SYS}/disksize" ]; then
                    echo "    Grootte: $(cat "${SYS}/disksize")"
                fi
                
                if [ -f "${SYS}/mem_used_total" ]; then
                    USED=$(cat "${SYS}/mem_used_total" 2>/dev/null || echo 0)
                    if [ "$USED" -gt 0 ] 2>/dev/null; then
                        echo "    RAM gebruik: $((USED / 1024 / 1024)) MB"
                    else
                        echo "    RAM gebruik: 0 MB"
                    fi
                fi
                
                if [ -f "${SYS}/comp_algorithm" ]; then
                    echo "    Compressor: $(cat "${SYS}/comp_algorithm" | sed 's/\[//g; s/\]//g')"
                fi
                
                if [ -f "${SYS}/compr_data_size" ] && [ -f "${SYS}/orig_data_size" ]; then
                    COMPR_RATIO=$(awk "BEGIN {printf \"%.2f\", $(cat ${SYS}/compr_data_size 2>/dev/null || echo 1) / $(cat ${SYS}/orig_data_size 2>/dev/null || echo 1)}")
                    echo "    Compressie ratio: ${COMPR_RATIO}x"
                fi
            else
                echo "  ${YELLOW}○${NC} $DEVICE: INACTIEF"
            fi
        else
            echo "  ${YELLOW}○${NC} $DEVICE: NIET BESCHIKBAAR"
        fi
    done
    
    echo
    if [ "$ACTIVE" -eq 0 ]; then
        echo "  ${YELLOW}⚠ Geen actieve ZRAM swap.${NC}"
    fi
    
    echo
    echo "Alle swap:"
    echo "----------"
    swapon --show
}

case "${1:-}" in
    start)
        start_zram
        ;;
    stop)
        stop_zram
        ;;
    restart|force-reload)
        stop_zram
        sleep 1
        start_zram
        ;;
    status)
        status_zram
        ;;
    *)
        echo "Gebruik: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac

exit 0
EOF

    chmod 755 "$INIT_SCRIPT"
    log "INFO" "SysVinit-script geïnstalleerd."
fi
echo

# =============================================================================
# SysVinit registratie
# =============================================================================
if [[ "$DRY_RUN" == true ]]; then
    log "INFO" "DRY RUN: SysVinit registratie zou worden uitgevoerd."
else
    # Eerst verwijderen indien aanwezig
    if command -v update-rc.d >/dev/null 2>&1; then
        update-rc.d -f zramswap remove >/dev/null 2>&1 || true
        update-rc.d zramswap defaults >/dev/null 2>&1
        log "INFO" "ZRAM geregistreerd via update-rc.d."
    elif command -v insserv >/dev/null 2>&1; then
        insserv -r zramswap >/dev/null 2>&1 || true
        insserv zramswap >/dev/null 2>&1
        log "INFO" "ZRAM geregistreerd via insserv."
    else
        log "WARN" "Geen update-rc.d of insserv gevonden."
        log "WARN" "Voeg handmatig toe aan /etc/rc.local:"
        log "WARN" "  ${INIT_SCRIPT} start"
    fi
fi
echo

# =============================================================================
# Swapfile (zonder file commando als verplichte check)
# =============================================================================
log "INFO" "Swapfile controleren: ${SWAPFILE}"

if [[ "$DRY_RUN" == true ]]; then
    log "INFO" "DRY RUN: ${SWAPFILE} (${SWAPSIZE_MB} MB) zou worden gecontroleerd."
else
    backup_config "/etc/fstab"
    
    # -------------------------------------------------------------------------
    # Swapfile maken
    # -------------------------------------------------------------------------
    if [[ ! -e "$SWAPFILE" ]]; then
        log "INFO" "Swapfile van ${SWAPSIZE_MB} MB aanmaken..."
        
        if command -v fallocate >/dev/null 2>&1; then
            fallocate -l "${SWAPSIZE_MB}M" "$SWAPFILE"
        else
            dd if=/dev/zero \
               of="$SWAPFILE" \
               bs=1M \
               count="$SWAPSIZE_MB" \
               status=progress
        fi
        
        chmod 600 "$SWAPFILE"
        mkswap "$SWAPFILE" >/dev/null
        log "INFO" "Swapfile aangemaakt."
    else
        chmod 600 "$SWAPFILE"
        
        # Simpele check of het bestand een swap is
        # (zonder file commando als verplichting)
        if ! mkswap -q "$SWAPFILE" 2>/dev/null; then
            log "WARN" "Bestaand bestand is geen geldige swapfile."
            
            if swapon --show=NAME --noheadings 2>/dev/null | grep -Fxq "$SWAPFILE"; then
                swapoff "$SWAPFILE" || true
            fi
            
            mkswap "$SWAPFILE" >/dev/null
            log "INFO" "Swapfile opnieuw geïnitialiseerd."
        else
            log "INFO" "Geldige swapfile bestaat al."
        fi
    fi
    
    # -------------------------------------------------------------------------
    # Swapfile activeren
    # -------------------------------------------------------------------------
    if ! swapon --show=NAME --noheadings 2>/dev/null | grep -Fxq "$SWAPFILE"; then
        swapon -p "$SWAPFILE_PRIORITY" "$SWAPFILE"
        log "INFO" "Swapfile geactiveerd (prioriteit ${SWAPFILE_PRIORITY})."
    else
        log "INFO" "Swapfile is al actief."
    fi
    
    # -------------------------------------------------------------------------
    # fstab
    # -------------------------------------------------------------------------
    sed -i "\|^[[:space:]]*${SWAPFILE}[[:space:]]|d" /etc/fstab
    
    cat >> /etc/fstab << EOF
${SWAPFILE} none swap sw,pri=${SWAPFILE_PRIORITY} 0 0
EOF
    
    log "INFO" "Swapfile geregistreerd in /etc/fstab."
fi
echo

# =============================================================================
# Swappiness
# =============================================================================
if [[ "$DRY_RUN" == true ]]; then
    log "INFO" "DRY RUN: vm.swappiness zou ${SWAPPINESS} worden."
else
    SYSCTL_CONF="/etc/sysctl.conf"
    backup_config "$SYSCTL_CONF"
    
    log "INFO" "vm.swappiness instellen op ${SWAPPINESS}."
    
    sed -i '/^[[:space:]]*vm\.swappiness[[:space:]]*=/d' "$SYSCTL_CONF"
    
    cat >> "$SYSCTL_CONF" << EOF

# ZRAM + swap optimalisatie
vm.swappiness=${SWAPPINESS}
EOF
    
    sysctl -p >/dev/null
    log "INFO" "vm.swappiness=${SWAPPINESS} ingesteld."
fi
echo

# =============================================================================
# Eindcontrole
# =============================================================================
echo "${BOLD}${CYAN}============================================================${NC}"
echo "${BOLD}${CYAN} Configuratiecontrole${NC}"
echo "${BOLD}${CYAN}============================================================${NC}"
echo

if [[ "$DRY_RUN" == true ]]; then
    echo "${YELLOW}DRY RUN voltooid.${NC}"
    echo
    echo "${YELLOW}Er zijn GEEN wijzigingen uitgevoerd.${NC}"
    echo
    echo "${BOLD}Geplande configuratie:${NC}"
    echo "  ${CYAN}RAM${NC}            : ${RAM_MB} MB"
    echo "  ${CYAN}ZRAM ratio${NC}     : ${ZRAM_RATIO}"
    echo "  ${CYAN}ZRAM per device${NC}: ${ZRAM_SIZE_MB} MB"
    echo "  ${CYAN}ZRAM devices${NC}   : ${ZRAM_DEVICES}"
    echo "  ${CYAN}Totale ZRAM${NC}    : $((ZRAM_SIZE_MB * ZRAM_DEVICES)) MB"
    echo "  ${CYAN}ZRAM prioriteit${NC}: ${ZRAM_PRIORITY}"
    echo "  ${CYAN}Swapfile${NC}       : ${SWAPSIZE_MB} MB"
    echo "  ${CYAN}Swapfile prio${NC}  : ${SWAPFILE_PRIORITY}"
    echo "  ${CYAN}Swappiness${NC}     : ${SWAPPINESS}"
    echo "  ${CYAN}SysVinit script${NC}: ${INIT_SCRIPT}"
    echo
    echo "${BOLD}Om de configuratie uit te voeren:${NC}"
    echo "  sudo $0 (zonder --dry-run)"
    echo
    
    exit 0
fi

echo "${BOLD}RAM:${NC}"
free -h
echo

echo "${BOLD}Actieve swap:${NC}"
swapon --show
echo

echo "${BOLD}ZRAM devices:${NC}"
for ((i=0; i<ZRAM_DEVICES; i++)); do
    DEVICE="/dev/zram${i}"
    SYS="/sys/block/zram${i}"
    
    if [[ ! -b "$DEVICE" ]]; then
        echo "  ${YELLOW}○${NC} ${DEVICE}: NIET BESCHIKBAAR"
        continue
    fi
    
    echo
    echo "  ${BOLD}${DEVICE}:${NC}"
    
    if swapon --show=NAME --noheadings 2>/dev/null | grep -Fxq "$DEVICE"; then
        echo "    ${GREEN}Status${NC}     : ACTIEF"
    else
        echo "    ${YELLOW}Status${NC}     : INACTIEF"
    fi
    
    if [[ -f "${SYS}/disksize" ]]; then
        echo "    Grootte    : $(cat "${SYS}/disksize")"
    fi
    
    if [[ -f "${SYS}/mem_used_total" ]]; then
        USED="$(cat "${SYS}/mem_used_total" 2>/dev/null || echo 0)"
        if [[ "$USED" =~ ^[0-9]+$ ]]; then
            echo "    RAM gebruik: $((USED / 1024 / 1024)) MB"
        fi
    fi
    
    if [[ -f "${SYS}/comp_algorithm" ]]; then
        echo "    Compressor : $(cat "${SYS}/comp_algorithm" | sed 's/\[//g; s/\]//g')"
    fi
    
    if [[ -f "${SYS}/compr_data_size" ]] && [[ -f "${SYS}/orig_data_size" ]]; then
        COMPR_RATIO=$(awk "BEGIN {printf \"%.2f\", $(cat ${SYS}/compr_data_size 2>/dev/null || echo 1) / $(cat ${SYS}/orig_data_size 2>/dev/null || echo 1)}")
        echo "    Compressie ratio: ${COMPR_RATIO}x"
    fi
done
echo

echo "${BOLD}Swappiness:${NC}"
sysctl vm.swappiness
echo

echo "${BOLD}Swapprioriteiten:${NC}"
swapon --show=NAME,TYPE,SIZE,USED,PRIO
echo

echo "${BOLD}SysVinit:${NC}"
if [[ -x "$INIT_SCRIPT" ]]; then
    echo "  ${GREEN}✓${NC} Script : ${INIT_SCRIPT}"
    echo "    Status : geïnstalleerd"
else
    echo "  ${RED}✗${NC} Status : FOUT - script ontbreekt"
fi
echo

echo "${BOLD}Logbestand:${NC}"
echo "  ${LOG_FILE}"
echo

echo "${BOLD}${GREEN}============================================================${NC}"
echo "${BOLD}${GREEN} ZRAM + Swap configuratie voltooid${NC}"
echo "${BOLD}${GREEN}============================================================${NC}"
echo
echo "${BOLD}ZRAM blijft actief na het beëindigen van dit script.${NC}"
echo "${BOLD}Bij de volgende boot wordt ZRAM via SysVinit opnieuw geactiveerd.${NC}"
echo
echo "${BOLD}Beheer:${NC}"
echo "  Status   : ${INIT_SCRIPT} status"
echo "  Starten  : ${INIT_SCRIPT} start"
echo "  Stoppen  : ${INIT_SCRIPT} stop"
echo "  Herstart : ${INIT_SCRIPT} restart"
echo