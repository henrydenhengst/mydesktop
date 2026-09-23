#!/usr/bin/env bash
#
# ============================================================
# FreeBoot CachyOS - Minimal User Management
# Version: 3.1
# ============================================================
#
# Doel:
#   CachyOS zo onderhoudsarm mogelijk maken voor een gewone
#   gebruiker.
#
# Regelt:
#   - pacman-offline installeren indien nodig
#   - pacman-configuratie controleren
#   - preparation timer vooraf controleren
#   - eerste offline update preparation uitvoeren
#   - offline preparation timer activeren
#   - beschikbare reboot-functionaliteit controleren
#
# Bewust NIET:
#   - Pamac installeren
#   - PackageKit gebruiken
#   - AUR automatiseren
#   - eigen reboot-service installeren
#   - willekeurige services uitschakelen
#   - desktopomgeving aanpassen
#   - gebruikersaccounts wijzigen
#
# ============================================================

set -euo pipefail

readonly SCRIPT_NAME="FreeBoot CachyOS Minimal Management"
readonly PACMAN_CONF="/etc/pacman.conf"
readonly OFFLINE_CONF="/etc/pacman.d/offline.conf"
readonly BACKUP_CONF="/etc/pacman.conf.freeboot-backup"
readonly TEMP_CONF="${PACMAN_CONF}.freeboot.tmp"

log() {
    printf '[INFO] %s\n' "$*"
}

warn() {
    printf '[WARN] %s\n' "$*" >&2
}

die() {
    printf '[ERROR] %s\n' "$*" >&2
    exit 1
}

cleanup() {
    rm -f "${TEMP_CONF}"
}

trap cleanup EXIT

# ------------------------------------------------------------
# Root
# ------------------------------------------------------------

if [[ "${EUID}" -ne 0 ]]; then
    die "Start dit script met sudo."
fi

# ------------------------------------------------------------
# CachyOS
# ------------------------------------------------------------

if [[ ! -r /etc/os-release ]]; then
    die "/etc/os-release ontbreekt."
fi

# shellcheck disable=SC1091
source /etc/os-release

if [[ "${ID:-}" != "cachyos" ]]; then
    die "Dit script is uitsluitend bedoeld voor CachyOS."
fi

log "CachyOS gedetecteerd: ${PRETTY_NAME:-onbekend}"

# ------------------------------------------------------------
# pacman
# ------------------------------------------------------------

command -v pacman >/dev/null 2>&1 ||
    die "pacman is niet gevonden."

# ------------------------------------------------------------
# pacman-offline installeren
#
# Geen -Sy:
# Een losse database-refresh kan een partial upgrade
# veroorzaken.
# ------------------------------------------------------------

if pacman -Q pacman-offline >/dev/null 2>&1; then

    log "pacman-offline is al geïnstalleerd."

else

    log "pacman-offline ontbreekt."
    log "Installatie wordt geprobeerd..."

    if pacman -S --needed --noconfirm pacman-offline; then

        log "pacman-offline is geïnstalleerd."

    else

        die "Installatie van pacman-offline mislukt.
Voer eerst een volledige systeemupdate uit met:
  pacman -Syu
en voer daarna dit script opnieuw uit."

    fi

fi

# ------------------------------------------------------------
# offline.conf
# ------------------------------------------------------------

if [[ ! -f "${OFFLINE_CONF}" ]]; then
    die "${OFFLINE_CONF} ontbreekt."
fi

log "Offline configuratie gevonden."

# ------------------------------------------------------------
# pacman.conf
# ------------------------------------------------------------

if grep -Eq \
    '^[[:space:]]*Include[[:space:]]*=[[:space:]]*/etc/pacman\.d/offline\.conf[[:space:]]*$' \
    "${PACMAN_CONF}"; then

    log "offline.conf wordt al ingelezen door pacman.conf."

else

    if [[ ! -e "${BACKUP_CONF}" ]]; then
        cp -a "${PACMAN_CONF}" "${BACKUP_CONF}"
        log "Backup gemaakt: ${BACKUP_CONF}"
    else
        log "Bestaande FreeBoot backup behouden."
    fi

    if ! awk '
        BEGIN {
            inserted=0
        }

        /^\[options\]/ {
            print
            print ""
            print "# FreeBoot: CachyOS offline package updates"
            print "Include = /etc/pacman.d/offline.conf"
            inserted=1
            next
        }

        {
            print
        }

        END {
            if (!inserted)
                exit 1
        }
    ' "${PACMAN_CONF}" > "${TEMP_CONF}"; then

        die "[options] sectie niet gevonden.
pacman.conf is niet gewijzigd."

    fi

    mv "${TEMP_CONF}" "${PACMAN_CONF}"

    log "offline.conf toegevoegd aan pacman.conf."

fi

# ------------------------------------------------------------
# pacman-configuratie testen
# ------------------------------------------------------------

log "Pacman-configuratie controleren..."

if command -v pacman-conf >/dev/null 2>&1; then

    if pacman-conf --config "${PACMAN_CONF}" >/dev/null; then
        log "Pacman-configuratie is geldig."
    else
        die "Pacman-configuratie is ongeldig."
    fi

else

    warn "pacman-conf ontbreekt."
    warn "Configuratietest wordt overgeslagen."

fi

# ------------------------------------------------------------
# pacman-offline pakketinhoud
# ------------------------------------------------------------

echo
log "Beschikbare pacman-offline units/hooks:"

if pacman -Qlq pacman-offline >/dev/null 2>&1; then

    if pacman -Qlq pacman-offline |
        grep -Eq '\.(timer|service|hook)$'; then

        pacman -Qlq pacman-offline |
            grep -E '\.(timer|service|hook)$' || true

    else

        warn "Geen timer/service/hook gevonden in pacman-offline."

    fi

else

    warn "pacman -Ql kon pacman-offline niet inspecteren."

fi

# ------------------------------------------------------------
# Preparation timer vooraf controleren
#
# Dit gebeurt vóór de mogelijk langdurige preparation.
# Zo kan het script niet eerst minutenlang werken om daarna
# te ontdekken dat de periodieke timer ontbreekt.
# ------------------------------------------------------------

echo

if ! systemctl cat pacman-offline-prepare.timer >/dev/null 2>&1; then
    die "pacman-offline-prepare.timer ontbreekt."
fi

log "pacman-offline-prepare.timer gevonden."

# ------------------------------------------------------------
# Eerste preparation
#
# Deze run wordt bewust synchroon uitgevoerd.
# Dat maakt het provisioning-resultaat voorspelbaar:
# als het script verdergaat, is de preparation klaar.
#
# De timer wordt pas daarna gestart.
# Let op: als de timer Persistent=true gebruikt en een run
# gemist is, kan systemd bij het starten alsnog een service-run
# plannen. pacman-offline-prepare is daarvoor ontworpen.
# ------------------------------------------------------------

echo
log "Eerste offline update preparation wordt gestart."
log "Dit kan afhankelijk van de hoeveelheid updates enige tijd duren."
echo

if systemctl start pacman-offline-prepare.service; then
    log "Eerste offline update preparation is voltooid."
else
    die "Offline update preparation is mislukt."
fi

# ------------------------------------------------------------
# Preparation timer activeren
# ------------------------------------------------------------

echo
log "Offline preparation timer wordt geactiveerd."

if systemctl enable pacman-offline-prepare.timer &&
   systemctl start pacman-offline-prepare.timer; then

    log "Offline preparation timer is actief."

else

    die "Kon pacman-offline-prepare.timer niet activeren."

fi

# ------------------------------------------------------------
# Reboot-functionaliteit
#
# Geen eigen reboot timer/service.
# Alleen bestaande CachyOS-functionaliteit gebruiken.
# ------------------------------------------------------------

echo

if systemctl cat pacman-offline-reboot.timer >/dev/null 2>&1; then

    log "pacman-offline-reboot.timer gevonden."

    warn "Let op: bij Persistent=true kan activering van deze"
    warn "timer een gemiste run direct laten uitvoeren."

    if systemctl enable --now pacman-offline-reboot.timer; then

        log "Automatische reboot timer is actief."

    else

        warn "pacman-offline-reboot.timer bestaat maar kon niet"
        warn "worden geactiveerd."

    fi

else

    warn "pacman-offline-reboot.timer bestaat niet."
    warn "Er wordt geen eigen reboot timer aangemaakt."

fi

# ------------------------------------------------------------
# Eindstatus
# ------------------------------------------------------------

echo
echo "============================================================"
echo " ${SCRIPT_NAME}"
echo "============================================================"
echo

printf '%-38s ' "CachyOS:"
echo "OK"

printf '%-38s ' "pacman-offline:"
if pacman -Q pacman-offline >/dev/null 2>&1; then
    pacman -Q pacman-offline
else
    echo "NIET GEVONDEN"
fi

printf '%-38s ' "prepare timer:"
if systemctl is-enabled --quiet pacman-offline-prepare.timer &&
   systemctl is-active --quiet pacman-offline-prepare.timer; then

    echo "ENABLED + ACTIVE"

else

    echo "NIET ACTIEF"

fi

printf '%-38s ' "reboot timer:"

if systemctl cat pacman-offline-reboot.timer >/dev/null 2>&1; then

    if systemctl is-enabled --quiet pacman-offline-reboot.timer &&
       systemctl is-active --quiet pacman-offline-reboot.timer; then

        echo "ENABLED + ACTIVE"

    else

        echo "GEVONDEN MAAR NIET ACTIEF"

    fi

else

    echo "NIET AANWEZIG"

fi

echo
echo "Preparation timer:"
systemctl list-timers pacman-offline-prepare.timer \
    --no-pager 2>/dev/null || true

echo
echo "Reboot timer:"
systemctl list-timers pacman-offline-reboot.timer \
    --no-pager 2>/dev/null || true

echo
echo "============================================================"
echo " FreeBoot CachyOS configuratie voltooid"
echo "============================================================"
echo
echo "De gebruiker hoeft geen handmatige pacman-updates uit te voeren."
echo