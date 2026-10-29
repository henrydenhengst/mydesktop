#!/usr/bin/env bash
# ============================================================
# FreeBoot - IPTV Installatie voor antiX en Debian
# Bestandsnaam: iptv.sh
# Versie: 0.3 (pre-release)
#
# STATUS:
# Statisch nagekeken; niet live getest op alle ondersteunde systemen.
#
# Functies:
# - Controleert distributie, pakketbeheer, rechten en netwerk
# - Controleert beschikbare schijfruimte per relevant filesystem
# - Installeert Kodi via apt
# - Optioneel: kodi-pvr-iptvsimple (aparte, niet-blokkerende stap)
# - Controleert de installatie achteraf
#
# Veiligheidskeuzes:
# - Geen installatie bij blokkerende precheck-fouten
# - apt-get update moet slagen
# - Geen automatische upgrade van het hele systeem
# - Geen automatische wijzigingen aan gebruikersgroepen
# - IPTV-configuratie wordt niet gewijzigd
# - Bij --with-iptv: Kodi wordt altijd geïnstalleerd; de addon
#   is een aparte stap die bij ontbreken een waarschuwing geeft
#   in plaats van de hele installatie te laten mislukken
#
# Gebruik:
#   ./iptv.sh --check-only
#   ./iptv.sh
#   ./iptv.sh --with-iptv
#   ./iptv.sh --yes --with-iptv
# ============================================================

set -u
export LC_ALL=C

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

BLOCKERS=0
WARNINGS=0

SCRIPT_NAME="iptv"
SCRIPT_VERSION="0.3"

ASSUME_YES=0
CHECK_ONLY=0
WITH_IPTV=0

IS_ROOT=0
OS_ID=""
OS_ID_LIKE=""
OS_NAME="Onbekend"

# ------------------------------------------------------------
# Hulpfuncties
# ------------------------------------------------------------

ok() {
    printf '%b\n' "${GREEN}[OK]${NC} $*"
}

warn() {
    printf '%b\n' "${YELLOW}[LET OP]${NC} $*"
    WARNINGS=$((WARNINGS + 1))
}

blocker() {
    printf '%b\n' "${RED}[BLOKKADE]${NC} $*"
    BLOCKERS=$((BLOCKERS + 1))
}

section() {
    printf '\n%b\n' "${CYAN}============================================================${NC}"
    printf '%b\n' "${CYAN}$*${NC}"
    printf '%b\n' "${CYAN}============================================================${NC}"
}

has() {
    command -v "$1" >/dev/null 2>&1
}

# Voert een commando met de juiste rechten uit.
run_privileged() {
    if (( IS_ROOT == 1 )); then
        "$@"
    else
        sudo "$@"
    fi
}

usage() {
    cat <<'EOF'
Gebruik: iptv.sh [opties]

Opties:
  -y, --yes        Geen eigen bevestigingsvraag stellen
      --check-only Alleen controles uitvoeren; niets installeren
      --with-iptv   Ook kodi-pvr-iptvsimple proberen te installeren
  -h, --help       Deze hulptekst tonen
  -V, --version    Versie tonen

Voorbeelden:
  ./iptv.sh --check-only
  ./iptv.sh
  ./iptv.sh --with-iptv

Let op:
  --yes slaat alleen de bevestigingsvraag van dit script over.
  apt-get kan nog steeds fouten melden.
EOF
}

# ------------------------------------------------------------
# Argumenten
# ------------------------------------------------------------

while (( $# > 0 )); do
    case "$1" in
        -y|--yes)
            ASSUME_YES=1
            ;;
        --check-only)
            CHECK_ONLY=1
            ;;
        --with-iptv)
            WITH_IPTV=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -V|--version)
            printf '%s %s (pre-release)\n' \
                "$SCRIPT_NAME" "$SCRIPT_VERSION"
            exit 0
            ;;
        *)
            printf 'Onbekende optie: %s\n\n' "$1" >&2
            usage
            exit 2
            ;;
    esac
    shift
done

# ------------------------------------------------------------
# 0. Voorwoord
# ------------------------------------------------------------

section "FreeBoot - IPTV Installatie v${SCRIPT_VERSION}"

echo "Doel: Kodi installeren op Debian of antiX."
echo "Pakketbeheer: apt-get."
echo

if (( CHECK_ONLY == 1 )); then
    echo "Modus: alleen controles; er wordt niets geïnstalleerd."
elif (( WITH_IPTV == 1 )); then
    echo "Modus: Kodi inclusief IPTV PVR-addon (addon is een aparte stap)."
else
    echo "Modus: alleen Kodi."
fi

# ------------------------------------------------------------
# 1. Systeemdetectie
# ------------------------------------------------------------

section "1. SYSTEEMDETECTIE"

if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release

    OS_ID="${ID:-}"
    OS_ID_LIKE="${ID_LIKE:-}"
    OS_NAME="${PRETTY_NAME:-Onbekend}"

    echo "Distributie : $OS_NAME"
    echo "ID          : ${OS_ID:-onbekend}"
    echo "ID_LIKE     : ${OS_ID_LIKE:-niet opgegeven}"
else
    blocker "/etc/os-release ontbreekt; distributie niet te identificeren."
fi

if [[ -r /etc/debian_version ]]; then
    debian_version=$(cat /etc/debian_version)
    echo "Debian-base : $debian_version"

    debian_major=${debian_version%%.*}

    if [[ "$debian_major" =~ ^[0-9]+$ ]]; then
        if (( debian_major < 10 )); then
            blocker "Debian-base is ouder dan versie 10."
        elif (( debian_major < 11 )); then
            warn "Oude Debian-base; controleer ondersteuning en pakketversies."
        else
            ok "Debian-base is versie 11 of nieuwer."
        fi
    else
        warn "Debian-versie niet numeriek herkenbaar; versiecontrole beperkt."
    fi
else
    blocker "/etc/debian_version ontbreekt; geen Debian-base aangetoond."
fi

# Alleen Debian en Debian-afgeleiden ondersteunen.
if [[ "$OS_ID" != "debian" &&
      "$OS_ID" != "antix" &&
      "$OS_ID_LIKE" != *debian* ]]; then
    blocker "Deze distributie is niet als Debian of Debian-afgeleide herkend."
fi

if has apt-get; then
    ok "apt-get is beschikbaar."
else
    blocker "apt-get ontbreekt."
fi

if has dpkg; then
    ok "dpkg is beschikbaar."
else
    blocker "dpkg ontbreekt."
fi

# ------------------------------------------------------------
# 2. Rechten
# ------------------------------------------------------------

section "2. RECHTEN"

if [[ "$(id -u)" -eq 0 ]]; then
    IS_ROOT=1
    ok "Script wordt uitgevoerd als root."
else
    IS_ROOT=0

    if has sudo; then
        ok "sudo is beschikbaar."

        if sudo -n true 2>/dev/null; then
            echo "sudo-rechten zijn zonder wachtwoord beschikbaar."
        else
            echo "sudo kan tijdens de installatie om een wachtwoord vragen."
        fi
    else
        if (( CHECK_ONLY == 1 )); then
            warn "sudo ontbreekt; alleen controles kunnen worden uitgevoerd."
        else
            blocker "Geen rootrechten en sudo ontbreekt."
        fi
    fi
fi

# ------------------------------------------------------------
# 3. Netwerk en DNS
# ------------------------------------------------------------

section "3. NETWERK EN DNS"

if has getent; then
    if getent ahosts deb.debian.org >/dev/null 2>&1; then
        ok "DNS-resolutie werkt voor deb.debian.org."
    else
        blocker "DNS-resolutie voor deb.debian.org is mislukt."
    fi
else
    warn "getent ontbreekt; DNS niet vooraf gecontroleerd."
fi

if has ping; then
    if ping -n -c 2 -W 2 1.1.1.1 >/dev/null 2>&1; then
        ok "Ping naar 1.1.1.1 geslaagd."
    else
        warn "Ping naar 1.1.1.1 mislukt; ICMP kan geblokkeerd zijn."
    fi
else
    warn "ping ontbreekt; pingcontrole overgeslagen."
fi

echo "De pakketupdate controleert straks of de pakketservers bereikbaar zijn."

# ------------------------------------------------------------
# 4. Schijfruimte
# ------------------------------------------------------------

section "4. SCHIJFRUIMTE"

if has df; then
    # Controleer de filesystems van /, /usr en /var.
    # Afzonderlijke mountpoints worden elk maar één keer beoordeeld.
    # De drempel hangt af van wat apt op dat filesystem schrijft:
    #   - / en /usr: Kodi + afhankelijkheden  -> 1,5 GiB
    #   - /var     : pakketcache en dpkg-status -> 512 MiB
    declare -A CHECKED_MOUNTS=()

    for path in / /usr /var; do
        if ! df_output=$(df -Pk "$path" 2>/dev/null); then
            blocker "Schijfruimte van $path kon niet worden gecontroleerd."
            continue
        fi

        read -r available_kb mountpoint < <(
            printf '%s\n' "$df_output" |
                awk 'NR == 2 {print $4, $6}'
        )

        if [[ ! "${available_kb:-}" =~ ^[0-9]+$ ]] ||
           [[ -z "${mountpoint:-}" ]]; then
            blocker "Schijfruimte voor $path kon niet worden uitgelezen."
            continue
        fi

        if [[ -n "${CHECKED_MOUNTS[$mountpoint]+x}" ]]; then
            continue
        fi

        CHECKED_MOUNTS["$mountpoint"]=1
        available_mb=$((available_kb / 1024))

        echo "$mountpoint: ${available_mb} MiB beschikbaar"

        case "$mountpoint" in
            /var)
                if (( available_kb < 524288 )); then
                    blocker "Minder dan 512 MiB vrij op $mountpoint."
                else
                    ok "Voldoende vrije ruimte op $mountpoint (>= 512 MiB)."
                fi
                ;;
            *)
                if (( available_kb < 1572864 )); then
                    blocker "Minder dan 1,5 GiB vrij op $mountpoint."
                else
                    ok "Voldoende vrije ruimte op $mountpoint (>= 1,5 GiB)."
                fi
                ;;
        esac
    done
else
    blocker "df ontbreekt; schijfruimte kan niet worden gecontroleerd."
fi

# ------------------------------------------------------------
# 5. Bestaande installatie
# ------------------------------------------------------------

section "5. BESTAANDE INSTALLATIE"

if has dpkg-query; then
    if dpkg-query -W -f='${Status}' kodi 2>/dev/null |
        grep -qx 'install ok installed'; then

        installed_version=$(
            dpkg-query -W -f='${Version}' kodi 2>/dev/null || echo '?'
        )

        ok "Kodi is al geïnstalleerd (versie $installed_version)."
        echo "Een eventuele beschikbare update kan worden geïnstalleerd."
    else
        ok "Kodi is nog niet geïnstalleerd."
    fi
else
    warn "dpkg-query ontbreekt; bestaande Kodi-installatie niet gecontroleerd."
fi

if (( WITH_IPTV == 1 )); then
    echo
    echo "Gevraagd: kodi-pvr-iptvsimple."

    if has dpkg-query &&
       dpkg-query -W -f='${Status}' kodi-pvr-iptvsimple 2>/dev/null |
           grep -qx 'install ok installed'; then

        addon_version=$(
            dpkg-query -W -f='${Version}' kodi-pvr-iptvsimple \
                2>/dev/null || echo '?'
        )

        ok "IPTV PVR-addon is al geïnstalleerd (versie $addon_version)."
    else
        echo "IPTV PVR-addon is nog niet als geïnstalleerd bevestigd."
    fi
fi

# ------------------------------------------------------------
# 6. Pakketten
# ------------------------------------------------------------

section "6. GESELECTEERDE PAKKETTEN"

PACKAGES=(kodi)

if (( WITH_IPTV == 1 )); then
    PACKAGES+=(kodi-pvr-iptvsimple)
fi

printf 'Te installeren/controleren:\n'

for package in "${PACKAGES[@]}"; do
    printf '  - %s\n' "$package"
done

if (( WITH_IPTV == 1 )); then
    echo
    echo "De IPTV-addon wordt als aparte installatiestap behandeld."
    echo "Als de repository dit pakket niet aanbiedt, blijft Kodi zelf"
    echo "gewoon geïnstalleerd en volgt een waarschuwing."
    echo "De addon kan dan later via Kodi's eigen addonbeheer worden"
    echo "toegevoegd."
fi

# ------------------------------------------------------------
# 7. Precheckresultaat
# ------------------------------------------------------------

section "7. SAMENVATTING PRECHECKS"

echo "Blokkades       : $BLOCKERS"
echo "Aandachtspunten : $WARNINGS"

if (( BLOCKERS > 0 )); then
    printf '\n%b\n' "${RED}STOP: er zijn blokkerende problemen.${NC}"
    echo "Los de genoemde problemen op en voer het script opnieuw uit."
    exit 1
fi

if (( CHECK_ONLY == 1 )); then
    printf '\n%b\n' "${GREEN}Prechecks afgerond.${NC}"
    echo "Er is niets geïnstalleerd of gewijzigd."
    echo
    echo "Let op: --check-only voert geen apt-get update uit."
    echo "Beschikbaarheid en actuele pakketversies zijn dus niet gegarandeerd."
    exit 0
fi

# ------------------------------------------------------------
# 8. Bevestiging
# ------------------------------------------------------------

section "8. BEVESTIGING"

# Interactieve terminal is een voorwaarde vóór we iets tonen of vragen.
if (( ASSUME_YES == 0 )) && [[ ! -t 0 ]]; then
    blocker "Geen interactieve terminal. Gebruik --yes voor automatisering."
    exit 1
fi

echo "Het script gaat:"
echo "  1. De pakketlijsten bijwerken."
echo "  2. Kodi installeren."

if (( WITH_IPTV == 1 )); then
    echo "  3. De IPTV PVR-addon proberen te installeren (aparte stap)."
    echo "  4. De installatie controleren."
else
    echo "  3. De installatie controleren."
fi

echo
echo "Er wordt geen volledige systeemupgrade uitgevoerd."
echo "Er worden geen gebruikersgroepen automatisch aangepast."
echo

if (( ASSUME_YES == 0 )); then
    printf 'Doorgaan? [j/N] '
    read -r answer

    case "$answer" in
        j|J|ja|Ja|JA|y|Y|yes|YES)
            ;;
        *)
            echo "Installatie geannuleerd."
            exit 0
            ;;
    esac
fi

# ------------------------------------------------------------
# 9. Pakketlijsten bijwerken
# ------------------------------------------------------------

section "9. PAKETLIJSTEN BIJWERKEN"

echo "Uitvoeren: apt-get update"
echo

if ! run_privileged apt-get update; then
    printf '\n%b\n' "${RED}STOP: apt-get update is mislukt.${NC}"
    echo "Er worden geen pakketten geïnstalleerd."
    echo "Controleer netwerk, DNS, repositories en systeemdatum."
    exit 1
fi

ok "Pakketlijsten zijn bijgewerkt."

# ------------------------------------------------------------
# 10. Kodi installeren
# ------------------------------------------------------------

section "10. KODI INSTALLEREN"

APT_OPTS=(
    -y
    -o
    Dpkg::Options::=--force-confdef
    -o
    Dpkg::Options::=--force-confold
)

echo "Stap 1/2: Kodi"
echo "Uitvoeren: apt-get install kodi"
echo

if ! run_privileged env DEBIAN_FRONTEND=noninteractive \
    apt-get install "${APT_OPTS[@]}" kodi; then

    blocker "Installatie van Kodi is mislukt."
    echo "Controleer de apt-uitvoer voordat je opnieuw probeert."
    exit 1
fi

ok "Kodi is geïnstalleerd."

if (( WITH_IPTV == 1 )); then
    echo
    echo "Stap 2/2: IPTV PVR-addon"
    echo "Uitvoeren: apt-get install kodi-pvr-iptvsimple"
    echo

    if ! run_privileged env DEBIAN_FRONTEND=noninteractive \
        apt-get install "${APT_OPTS[@]}" kodi-pvr-iptvsimple; then

        warn "IPTV PVR-addon kon niet worden geïnstalleerd."
        echo "  Kodi zelf is wél geïnstalleerd."
        echo "  De addon kan later via Kodi's eigen addonbeheer alsnog"
        echo "  worden toegevoegd (Instellingen > Add-ons > Zoeken)."
    else
        ok "IPTV PVR-addon is geïnstalleerd."
    fi
fi

# ------------------------------------------------------------
# 11. Verificatie
# ------------------------------------------------------------

section "11. VERIFICATIE"

if has dpkg-query &&
   dpkg-query -W -f='${Status}' kodi 2>/dev/null |
       grep -qx 'install ok installed'; then

    installed_version=$(
        dpkg-query -W -f='${Version}' kodi 2>/dev/null || echo '?'
    )

    ok "Kodi is geïnstalleerd (versie $installed_version)."
else
    blocker "Kodi is na de installatie niet als geïnstalleerd bevestigd."
fi

if (( WITH_IPTV == 1 )); then
    if has dpkg-query &&
       dpkg-query -W -f='${Status}' kodi-pvr-iptvsimple 2>/dev/null |
           grep -qx 'install ok installed'; then

        addon_version=$(
            dpkg-query -W -f='${Version}' kodi-pvr-iptvsimple \
                2>/dev/null || echo '?'
        )

        ok "IPTV PVR-addon is geïnstalleerd (versie $addon_version)."
    else
        # Geen blocker: de addon is een optionele extra.
        warn "IPTV PVR-addon is niet als geïnstalleerd bevestigd."
        echo "  Kodi zelf is correct geïnstalleerd; de addon ontbreekt."
    fi
fi

# ------------------------------------------------------------
# 12. Volgende stappen
# ------------------------------------------------------------

section "12. VOLGENDE STAPPEN"

cat <<'EOF'
1. Start Kodi vanuit het applicatiemenu of met: kodi

2. Als je --with-iptv hebt gebruikt en de addon is geïnstalleerd:
   - Open de Kodi-instellingen.
   - Ga naar Add-ons en de geïnstalleerde PVR-clients.
   - Open PVR IPTV Simple Client.
   - Configureer de M3U-afspeellijst en eventueel de EPG-URL.

   Als de addon niet kon worden geïnstalleerd:
   - Open Kodi > Instellingen > Add-ons > Zoeken.
   - Zoek "PVR IPTV Simple Client" en installeer deze daar.

3. Herstart Kodi als de PVR-client daarom vraagt.

4. Test een echte stream. Een geslaagde installatie bewijst niet
   dat de GPU, audio, netwerkverbinding of IPTV-stream goed werkt.

5. Als hardwaredecodering niet werkt, controleer dan de GPU-driver
   en de toegangsrechten van de grafische gebruikerssessie.

Let op:
- Dit script verandert de IPTV-configuratie niet.
- Dit script voegt de gebruiker niet automatisch toe aan groepen.
- Op een normale desktop regelen sessie- en apparaatregels vaak
  de benodigde toegang. Voeg niet zonder reden brede groepsrechten toe.
- De Kodi-menu's kunnen per versie en taal iets verschillen.
EOF

# ------------------------------------------------------------
# 13. Eindresultaat
# ------------------------------------------------------------

section "13. EINDRESULTAAT"

echo "Blokkades       : $BLOCKERS"
echo "Aandachtspunten : $WARNINGS"

if (( BLOCKERS > 0 )); then
    printf '%b\n' "${RED}EINDOORDEEL: controleer de blokkades hierboven.${NC}"
    exit 1
elif (( WARNINGS > 0 )); then
    printf '%b\n' "${YELLOW}EINDOORDEEL: installatie voltooid; controleer de aandachtspunten.${NC}"
else
    printf '%b\n' "${GREEN}EINDOORDEEL: installatie en pakketcontrole geslaagd.${NC}"
fi

exit 0