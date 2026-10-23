#!/usr/bin/env bash
# firmware-update.sh
# FreeBoot - firmware bijwerken via fwupd en LVFS
#
# Ondersteunt:
# Debian, Ubuntu, Linux Mint, Pop!_OS, elementary, Zorin,
# Fedora, AlmaLinux, Rocky Linux, RHEL, Oracle Linux,
# openSUSE Leap, openSUSE Tumbleweed,
# Arch Linux, Manjaro, EndeavourOS, Garuda, CachyOS, Artix.
#
# Firmware wordt alleen bijgewerkt na toestemming.
# Het script start de computer nooit automatisch opnieuw op.
#
# USB-C-docks, hubs, Power Delivery-controllers en
# Thunderbolt/USB4-apparaten worden meegenomen als fwupd
# hiervoor ondersteuning en firmware beschikbaar heeft.
# Sluit zulke apparaten aan VOORDAT je dit script start,
# anders detecteert fwupd ze niet.
#
# Opties:
#   --dry-run    controleer en toon updates zonder te installeren
#   --list-usbc  toon alleen USB-C/Thunderbolt/USB4-apparaten
#   --help, -h   toon een korte uitleg

set -Eeuo pipefail
export LC_ALL=C

# Kleuren
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
RESET='\033[0m'

SUMMARY_SHOWN=false
SUMMARY_WHAT="Het script is gestart."
SUMMARY_NEXT="Controleer de onderstaande meldingen."

info() { printf '%b[INFO]%b %s\n' "$BLUE" "$RESET" "$*"; }
ok()   { printf '%b[OK]%b %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%b[LET OP]%b %s\n' "$YELLOW" "$RESET" "$*"; }
err()  { printf '%b[FOUT]%b %s\n' "$RED" "$RESET" "$*" >&2; }

show_summary() {
    printf '\n'
    printf '%b%b=== Samenvatting firmware-update ===%b\n\n' "$BOLD" "$BLUE" "$RESET"
    printf 'Wat is er gebeurd?\n%s\n\n' "$SUMMARY_WHAT"
    printf 'Wat moet je zelf nog doen?\n%s\n\n' "$SUMMARY_NEXT"
    SUMMARY_SHOWN=true
}

# Toon de samenvatting en stop met de opgegeven exitcode.
finish() {
    SUMMARY_WHAT="$1"
    SUMMARY_NEXT="$2"
    local code="${3:-0}"
    show_summary
    exit "$code"
}

on_error() {
    local code=$?
    trap - ERR
    err "Het script is onverwacht gestopt (exitcode: $code)."
    if [[ "$SUMMARY_SHOWN" != true ]]; then
        SUMMARY_WHAT="Het script is onverwacht gestopt."
        SUMMARY_NEXT="Lees de foutmelding. Controleer de firmwarestatus voordat je het script opnieuw uitvoert."
        show_summary
    fi
    exit "$code"
}
trap on_error ERR

ask_yes_no() {
    local answer=""
    if [[ ! -r /dev/tty ]]; then
        warn "Geen interactieve terminal beschikbaar; er wordt niets bijgewerkt."
        return 1
    fi
    printf '%s' "$1" > /dev/tty
    if ! IFS= read -r answer < /dev/tty; then
        return 1
    fi
    case "${answer,,}" in
        j|ja|y|yes) return 0 ;;
        *) return 1 ;;
    esac
}

print_help() {
    cat <<'EOF'
Gebruik: sudo bash firmware-update.sh [opties]

Opties:
  --dry-run      Controleer en toon welke firmware-updates beschikbaar zijn,
                 maar installeer niets.
  --list-usbc    Toon alleen USB-C-, Thunderbolt- en USB4-apparaten die
                 fwupd kent, inclusief eventuele beschikbare updates.
  --help, -h     Toon deze help en stop.

Zonder opties: volledige controle en (na toestemming) installatie.
Het script start de computer nooit automatisch opnieuw op.
EOF
}

# --- 0. Argumenten ----------------------------------------------------------
DRY_RUN=false
LIST_USBC=false

while (( $# > 0 )); do
    case "$1" in
        --dry-run)   DRY_RUN=true ;;
        --list-usbc) LIST_USBC=true ;;
        --help|-h)   print_help; exit 0 ;;
        *)
            err "Onbekende optie: $1"
            echo "Gebruik --help voor een overzicht." >&2
            exit 2
            ;;
    esac
    shift
done

# --- 1. Beheerrechten -------------------------------------------------------
if [[ "$EUID" -ne 0 ]]; then
    err "Start dit script met sudo, bijvoorbeeld: sudo bash firmware-update.sh"
    finish "Er is niets bijgewerkt: beheerdersrechten ontbreken." \
           "Voer het script opnieuw uit met sudo." 1
fi

# --- 2. Distributie herkennen ----------------------------------------------
if [[ ! -r /etc/os-release ]]; then
    err "/etc/os-release ontbreekt; de distributie kan niet worden herkend."
    finish "Er is niets bijgewerkt." \
           "Controleer of dit een ondersteunde Linux-distributie is." 1
fi

# shellcheck disable=SC1091
source /etc/os-release

# Let op: zowel ID als ID_LIKE kunnen ontbreken (Fedora/RHEL zetten
# ID_LIKE niet). Met set -u crasht ${X,,} op een niet-bestaande variabele.
DISTRO_ID="${ID:-unknown}"
DISTRO_ID="${DISTRO_ID,,}"
DISTRO_LIKE="${ID_LIKE:-}"
DISTRO_LIKE="${DISTRO_LIKE,,}"

PKG_MANAGER=""

case "$DISTRO_ID" in
    debian|ubuntu|linuxmint|pop|elementary|zorin)
        PKG_MANAGER="apt"
        ;;
    fedora|almalinux|rocky|rhel|ol)
        PKG_MANAGER="dnf"
        ;;
    opensuse*|sles|sled)
        PKG_MANAGER="zypper"
        ;;
    arch|manjaro|endeavouros|garuda|cachyos|artix)
        PKG_MANAGER="pacman"
        ;;
esac

if [[ -z "$PKG_MANAGER" && -n "$DISTRO_LIKE" ]]; then
    case " $DISTRO_LIKE " in
        *" debian "*|*" ubuntu "*)           PKG_MANAGER="apt" ;;
        *" fedora "*|*" rhel "*|*" centos "*) PKG_MANAGER="dnf" ;;
        *" suse "*)                          PKG_MANAGER="zypper" ;;
        *" arch "*)                          PKG_MANAGER="pacman" ;;
    esac
fi

if [[ -z "$PKG_MANAGER" ]]; then
    err "Niet-ondersteunde of niet-herkende distributie: ${PRETTY_NAME:-$DISTRO_ID}"
    finish "Er is niets bijgewerkt: de distributie wordt niet ondersteund." \
           "Installeer firmware handmatig met een passende methode voor deze distributie." 1
fi

info "Distributie: ${PRETTY_NAME:-$DISTRO_ID}"
info "Pakketbeheer: $PKG_MANAGER"

# --- 3. fwupd installeren indien nodig -------------------------------------
if ! command -v fwupdmgr >/dev/null 2>&1; then
    warn "fwupd ontbreekt. Het wordt nu geïnstalleerd."

    case "$PKG_MANAGER" in
        apt)
            if ! command -v apt-get >/dev/null 2>&1; then
                err "apt-get is niet beschikbaar."
                finish "fwupd kon niet worden geïnstalleerd." \
                       "Installeer fwupd handmatig en voer het script opnieuw uit." 1
            fi
            if ! apt-get update; then
                err "apt-get update is mislukt."
                finish "De pakketlijsten konden niet worden bijgewerkt." \
                       "Controleer internetverbinding en pakketbronnen." 1
            fi
            if ! DEBIAN_FRONTEND=noninteractive \
                 apt-get install -y --no-install-recommends fwupd; then
                err "Installatie van fwupd is mislukt."
                finish "fwupd kon niet worden geïnstalleerd." \
                       "Controleer de foutmelding, internetverbinding en pakketbronnen." 1
            fi
            ;;
        dnf)
            if ! command -v dnf >/dev/null 2>&1; then
                err "dnf is niet beschikbaar."
                finish "fwupd kon niet worden geïnstalleerd." \
                       "Installeer fwupd handmatig en voer het script opnieuw uit." 1
            fi
            if ! dnf install -y --setopt=install_weak_deps=False fwupd; then
                err "Installatie van fwupd is mislukt."
                finish "fwupd kon niet worden geïnstalleerd." \
                       "Controleer de foutmelding, internetverbinding en pakketbronnen." 1
            fi
            ;;
        zypper)
            if ! command -v zypper >/dev/null 2>&1; then
                err "zypper is niet beschikbaar."
                finish "fwupd kon niet worden geïnstalleerd." \
                       "Installeer fwupd handmatig en voer het script opnieuw uit." 1
            fi
            if ! zypper --non-interactive install --no-recommends fwupd; then
                err "Installatie van fwupd is mislukt."
                finish "fwupd kon niet worden geïnstalleerd." \
                       "Controleer de foutmelding, internetverbinding en pakketbronnen." 1
            fi
            ;;
        pacman)
            if ! command -v pacman >/dev/null 2>&1; then
                err "pacman is niet beschikbaar."
                finish "fwupd kon niet worden geïnstalleerd." \
                       "Installeer fwupd handmatig met: sudo pacman -S fwupd" 1
            fi
            # Bewust GEEN 'pacman -Sy' zonder '-u': dat veroorzaakt op Arch
            # een partial-upgrade-situatie. We gebruiken alleen '-S' met
            # '--needed'. De repo-database wordt NIET ververst; dat is aan
            # de gebruiker via 'pacman -Syu' op een geschikt moment.
            if ! pacman -S --noconfirm --needed fwupd; then
                err "Installatie van fwupd is mislukt."
                finish "fwupd kon niet worden geïnstalleerd." \
                       "Controleer de foutmelding en pakketbronnen. Werk eventueel eerst bij met: sudo pacman -Syu" 1
            fi
            ;;
    esac

    if ! command -v fwupdmgr >/dev/null 2>&1; then
        err "fwupdmgr is na de installatie niet beschikbaar."
        finish "De installatie van fwupd is niet geslaagd." \
               "Controleer de pakketbeheerder en de foutmeldingen." 1
    fi

    ok "fwupd is geïnstalleerd."
else
    ok "fwupd is al geïnstalleerd."
fi

if version_line=$(fwupdmgr --version 2>/dev/null | head -n1); then
    [[ -n "$version_line" ]] && info "fwupd-versie: $version_line"
fi

# --- 4. fwupd-service controleren ------------------------------------------
if command -v systemctl >/dev/null 2>&1; then
    if ! systemctl is-active --quiet fwupd 2>/dev/null; then
        info "fwupd-service starten..."
        if ! systemctl start fwupd 2>/dev/null; then
            warn "Kon de fwupd-service niet starten; fwupd kan alsnog via D-Bus geactiveerd worden."
        fi
    fi
fi

# --- 5. Accu-waarschuwing voor laptops -------------------------------------
shopt -s nullglob
BATTERIES=(/sys/class/power_supply/BAT*)
shopt -u nullglob

BATTERY_ON_BATTERY=false
if (( ${#BATTERIES[@]} > 0 )); then
    for battery in "${BATTERIES[@]}"; do
        [[ -r "$battery/status" ]] || continue
        battery_status="$(<"$battery/status")"
        if [[ "$battery_status" == "Discharging" ]]; then
            BATTERY_ON_BATTERY=true
            break
        fi
    done
fi

if [[ "$BATTERY_ON_BATTERY" == true ]]; then
    warn "Het systeem werkt op de accu."
    warn "Sluit de netvoeding aan en houd die aangesloten tijdens het bijwerken."

    if ! ask_yes_no "Toch doorgaan met de controle? [j/N] "; then
        finish "De firmwarecontrole is afgebroken omdat het systeem op de accu werkt." \
               "Sluit de netvoeding aan en voer het script opnieuw uit." 0
    fi
fi

# --- 6. Metadata vernieuwen ------------------------------------------------
info "Firmwaremetadata ophalen bij de ingestelde fwupd-bronnen..."
set +e
REFRESH_OUTPUT="$(fwupdmgr refresh 2>&1)"
REFRESH_RC=$?
set -e

if [[ -n "$REFRESH_OUTPUT" ]]; then
    printf '%s\n' "$REFRESH_OUTPUT"
fi

case "$REFRESH_RC" in
    0|2)
        ok "De metadata-opdracht is afgerond."
        ;;
    *)
        err "De firmwaremetadata kon niet betrouwbaar worden bijgewerkt (exitcode: $REFRESH_RC)."
        finish "De controle is gestopt omdat het ophalen van firmwaremetadata niet betrouwbaar is afgerond." \
               "Controleer internetverbinding, fwupd-service en foutmelding. Probeer daarna opnieuw." 1
        ;;
esac

# --- 7. Modus: alleen USB-C / Thunderbolt / USB4 ----------------------------
# Filtert device-blokken uit `fwupdmgr get-devices` die een USB-C-,
# Thunderbolt- of USB4-trefwoord bevatten. Gebruikt POSIX-awk
# (paragraph mode via RS="") zodat dit op gawk, mawk en busybox werkt.
if [[ "$LIST_USBC" == true ]]; then
    info "USB-C-, Thunderbolt- en USB4-apparaten die fwupd kent:"
    echo

    set +e
    DEVICES_OUTPUT="$(fwupdmgr get-devices 2>&1)"
    DEVICES_RC=$?
    set -e

    if (( DEVICES_RC != 0 && DEVICES_RC != 2 )); then
        err "Kon de apparatenlijst niet ophalen (exitcode: $DEVICES_RC)."
        echo "$DEVICES_OUTPUT"
        finish "De apparatenlijst kon niet worden opgehaald." \
               "Controleer de foutmelding en probeer opnieuw." 1
    fi

    USB_C_DEVICES="$(printf '%s\n' "$DEVICES_OUTPUT" | awk '
        BEGIN { RS = ""; ORS = "\n\n" }
        tolower($0) ~ /usb|thunderbolt|usb4|dock|hub|power delivery|type-c|typec/ { print }
    ')"

    if [[ -z "${USB_C_DEVICES//[[:space:]]/}" ]]; then
        warn "Geen USB-C-gerelateerde apparaten gevonden."
        echo "Tip: sluit USB-C-docks, hubs, Thunderbolt- of USB4-apparaten aan en probeer opnieuw."
        finish "Er zijn geen USB-C-gerelateerde apparaten gedetecteerd." \
               "Sluit het apparaat aan en voer het script opnieuw uit met --list-usbc." 0
    fi

    printf '%s\n' "$USB_C_DEVICES"

    echo
    info "Controleren of voor deze apparaten updates beschikbaar zijn..."
    set +e
    USB_C_UPDATES="$(fwupdmgr get-updates 2>&1)"
    UPDATES_RC=$?
    set -e

    if [[ -n "$USB_C_UPDATES" ]]; then
        printf '\n%s\n' "$USB_C_UPDATES"
    fi

    if grep -Eiq 'No updates available|No updatable devices|No devices with available firmware updates' \
        <<< "$USB_C_UPDATES"; then
        finish "De USB-C-apparaten zijn geïnventariseerd. Er zijn geen firmware-updates beschikbaar." \
               "Je hoeft niets te doen. Controleer eventueel de firmware bij de fabrikant." 0
    fi

    if (( UPDATES_RC == 2 )); then
        finish "De USB-C-apparaten zijn geïnventariseerd. fwupd meldt geen uitvoerbare updateactie." \
               "Controleer bij twijfel de firmware bij de fabrikant of op LVFS." 0
    fi

    if (( UPDATES_RC != 0 )); then
        err "De updatecontrole voor USB-C-apparaten is mislukt (exitcode: $UPDATES_RC)."
        finish "De USB-C-apparaten zijn wel getoond, maar de updatecontrole is mislukt." \
               "Controleer de foutmelding en probeer later opnieuw." 1
    fi

    finish "De USB-C-apparaten en beschikbare updates zijn hierboven weergegeven." \
           "Voer het script zonder --list-usbc uit om updates daadwerkelijk te installeren." 0
fi

# --- 8. Beschikbare updates controleren ------------------------------------
info "Beschikbare firmware-updates controleren..."
set +e
UPDATES_OUTPUT="$(fwupdmgr get-updates 2>&1)"
UPDATES_RC=$?
set -e

if [[ -n "$UPDATES_OUTPUT" ]]; then
    printf '\n%s\n' "$UPDATES_OUTPUT"
fi

# Sommige fwupd-versies geven RC 0 maar melden alsnog "no updates".
if grep -Eiq \
    'No updates available|No updatable devices|No devices with available firmware updates' \
    <<< "$UPDATES_OUTPUT"; then
    ok "fwupd meldt dat er geen firmware-updates beschikbaar zijn."
    finish "De firmwarecontrole is uitgevoerd. Er zijn geen updates gemeld." \
           "Je hoeft niets te doen. Niet alle apparaten (inclusief USB-C) ondersteunen LVFS." 0
fi

case "$UPDATES_RC" in
    0)
        ok "fwupd meldt mogelijke updates. Zie de lijst hierboven."
        ;;
    2)
        ok "fwupd meldt dat er geen updateactie nodig is."
        finish "fwupd meldt dat er geen updateactie nodig is. Dit betekent niet dat elk apparaat wereldwijd of door de fabrikant bijgewerkt is." \
               "Er is niets geïnstalleerd. Controleer bij twijfel de firmware bij de fabrikant of op LVFS." 0
        ;;
    *)
        err "De updatecontrole is mislukt (exitcode: $UPDATES_RC)."
        finish "Er is geen firmware-installatie gestart omdat de updatecontrole mislukte." \
               "Controleer de bovenstaande foutmelding en voer het script later opnieuw uit." 1
        ;;
esac

# --- 9. Modus: dry-run ------------------------------------------------------
# Toon wat er zou gebeuren, maar installeer niets.
if [[ "$DRY_RUN" == true ]]; then
    warn "Dry-run actief: er wordt niets geïnstalleerd."
    finish "De controle is uitgevoerd in dry-run-modus. Er zijn firmware-updates beschikbaar, maar er is niets geïnstalleerd." \
           "Voer het script opnieuw uit zonder --dry-run om de updates daadwerkelijk te installeren." 0
fi

# --- 10. Waarschuwing en toestemming ---------------------------------------
printf '\n'
warn "Firmware bijwerken kan apparaten tijdelijk onbruikbaar maken."
warn "Onderbreek de stroom niet en koppel een USB-C-dock of ander apparaat niet los tijdens het flashen."
warn "Niet ieder USB-C-apparaat heeft firmware die via fwupd/LVFS kan worden bijgewerkt."
warn "Zorg dat USB-C-apparaten die je wilt bijwerken al zijn aangesloten."
printf '\n'

if ! ask_yes_no "Wil je de aangeboden firmware-updates installeren? [j/N] "; then
    finish "Er zijn updates gemeld, maar de installatie is niet bevestigd." \
           "Er is niets geïnstalleerd. Voer het script opnieuw uit als je later wilt bijwerken." 0
fi

# --- 11. Firmware-update uitvoeren -----------------------------------------
#
# We gebruiken --assume-yes omdat de gebruiker hierboven al expliciet
# toestemming heeft gegeven. Zonder deze vlag vraagt fwupd per apparaat
# nóg een keer om bevestiging, wat in een script verwarrend en
# onbruikbaar is. Het script start zelf NOOIT een herstart.
info "Firmware-update starten..."
set +e
fwupdmgr update --assume-yes
UPDATE_RC=$?
set -e

case "$UPDATE_RC" in
    0)
        ok "fwupdmgr heeft de updateopdracht succesvol afgerond."
        ;;
    2)
        ok "fwupd meldt dat er uiteindelijk geen updateactie is uitgevoerd."
        finish "fwupd heeft geen updateactie uitgevoerd. Dit kan betekenen dat er op het laatste moment geen geschikte update meer was." \
               "Controleer de uitvoer hierboven. Voer bij twijfel later opnieuw uit: sudo fwupdmgr get-updates" 0
        ;;
    *)
        err "fwupdmgr meldde een fout tijdens het bijwerken (exitcode: $UPDATE_RC)."
        finish "De firmware-update is niet als succesvol bevestigd." \
               "Schakel de computer niet uit als fwupd nog bezig is. Lees de foutmelding en controleer daarna sudo fwupdmgr get-history en sudo fwupdmgr get-results." 1
        ;;
esac

# --- 12. Herstartstatus controleren ----------------------------------------
info "Controleren of een herstart nodig is..."
set +e
DEVICES_OUTPUT="$(fwupdmgr get-devices 2>&1)"
set -e

if grep -Eiq \
    'needs reboot|reboot required|update pending|reboot loop' \
    <<< "$DEVICES_OUTPUT"; then
    warn "Een herstart is nodig om de firmware-updates te activeren."
    finish "De firmware-updates zijn uitgevoerd. Minimaal één update wacht op een herstart." \
           "Sla je werk op en start de computer zelf opnieuw op. Controleer daarna met: sudo fwupdmgr get-devices" 0
fi

ok "fwupd meldt geen openstaande herstartactie."
finish "De firmware-updates zijn uitgevoerd. fwupd meldt geen openstaande herstartactie." \
       "Controleer eventuele meldingen van fwupd. Je kunt de status controleren met: sudo fwupdmgr get-devices" 0