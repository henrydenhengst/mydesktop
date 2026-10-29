#!/usr/bin/env bash
# ============================================================
# FreeBoot - IPTV Hardware- en Systeemdiagnose
# Geschikt voor antiX en Debian
# Versie: 0.9 (pre-release)
#
# STATUS: pre-release
# Dit script is statisch nagekeken, nog niet grootschalig
# live getest. Gebruik ter diagnose, niet als enige bron
# voor een IPTV-aankoop- of inrichtingsbeslissing.
#
# Alleen-lezen diagnose:
# - Geen pakketten installeren
# - Geen systeeminstellingen wijzigen
# - Geen netwerkbuffers aanpassen
# ============================================================

set -u
export LC_ALL=C

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

WARNINGS=0

ok() {
    printf '%b\n' "${GREEN}[OK]${NC} $*"
}

warn() {
    printf '%b\n' "${YELLOW}[LET OP]${NC} $*"
    WARNINGS=$((WARNINGS + 1))
}

section() {
    printf '\n%b\n' "${CYAN}============================================================${NC}"
    printf '%b\n' "${CYAN}$*${NC}"
    printf '%b\n' "${CYAN}============================================================${NC}"
}

has() {
    command -v "$1" >/dev/null 2>&1
}

# ------------------------------------------------------------
# 1. Systeem en processor
# ------------------------------------------------------------

section "1. SYSTEEM EN PROCESSOR"

if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    echo "Distributie : ${PRETTY_NAME:-Onbekend}"
else
    echo "Distributie : Onbekend"
fi

echo "Kernel      : $(uname -r)"
echo "Architectuur: $(uname -m)"

cpu_model=$(awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo)

if [[ -z "$cpu_model" ]]; then
    cpu_model=$(awk -F': ' '/Hardware/ {print $2; exit}' /proc/cpuinfo)
fi

echo "CPU         : ${cpu_model:-Onbekend}"

if has nproc; then
    echo "Logische CPU's: $(nproc)"
else
    echo "Logische CPU's: $(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo '?')"
fi

if has free; then
    free -h
else
    warn "Commando free ontbreekt."
fi

# ------------------------------------------------------------
# 2. GPU en hardwarematige videodecodering
# ------------------------------------------------------------

section "2. GPU EN VIDEODECODERING"

if has lspci; then
    gpu_info=$(lspci 2>/dev/null |
        grep -Ei 'VGA compatible controller|3D controller|Display controller' || true)

    if [[ -n "$gpu_info" ]]; then
        printf '%s\n' "$gpu_info"
    else
        warn "Geen GPU-informatie gevonden via lspci."
    fi
else
    warn "lspci ontbreekt; GPU-model niet gecontroleerd."
fi

if has vainfo; then
    vainfo_output=$(vainfo 2>&1)
    vainfo_status=$?

    if (( vainfo_status == 0 )) &&
       printf '%s\n' "$vainfo_output" |
           grep -Eq 'VAProfile[A-Za-z0-9_]+'; then

        ok "VA-API rapporteert ondersteunde profielen."

        printf '%s\n' "$vainfo_output" |
            grep -E 'Driver version|VAProfile' |
            sort -u |
            head -n 15

        if printf '%s\n' "$vainfo_output" |
            grep -q 'VAProfileH264'; then
            ok "H.264-profiel aangetroffen."
        else
            warn "Geen H.264-profiel aangetroffen."
        fi

        if printf '%s\n' "$vainfo_output" |
            grep -q 'VAProfileHEVC'; then
            ok "HEVC-profiel aangetroffen."
        else
            warn "Geen HEVC-profiel aangetroffen."
        fi
    else
        warn "VA-API kon niet worden bevestigd."
        printf '%s\n' "$vainfo_output" | head -n 6
        echo "Mogelijke oorzaken: driver, rechten of grafische sessie."
    fi
else
    warn "vainfo ontbreekt; hardwaredecodering niet getest."
    echo "Installeer zo nodig vainfo en de passende GPU-driver."
fi

echo "Let op: beschikbare profielen bewijzen niet dat een speler"
echo "de hardwaredecodering daadwerkelijk gebruikt."

# ------------------------------------------------------------
# 3. Netwerkinterfaces
# ------------------------------------------------------------

section "3. NETWERKINTERFACES"

if ! has ip; then
    warn "Het commando ip ontbreekt; interfaces niet gecontroleerd."
else
    interfaces=$(ip -o link show up 2>/dev/null |
        awk -F': ' '{print $2}' |
        sed 's/@.*//' |
        grep -v '^lo$' || true)

    if [[ -z "$interfaces" ]]; then
        warn "Geen actieve netwerkinterface gevonden."
    else
        while IFS= read -r iface; do
            [[ -n "$iface" ]] || continue

            echo
            echo "Interface: $iface"

            if [[ -d "/sys/class/net/$iface/wireless" ]]; then
                echo "Type     : WiFi"

                if has iw; then
                    wifi_info=$(iw dev "$iface" link 2>/dev/null || true)

                    if printf '%s\n' "$wifi_info" |
                        grep -q 'Connected to'; then
                        printf '%s\n' "$wifi_info" |
                            grep -E 'Connected to|SSID:|signal:|tx bitrate:' || true
                    else
                        warn "Geen actieve wifi-associatie aangetoond voor $iface."
                    fi
                else
                    warn "iw ontbreekt; wifi-signaal niet gecontroleerd."
                fi
            else
                iface_type=$(cat "/sys/class/net/$iface/type" 2>/dev/null || echo '?')

                case "$iface_type" in
                    1)
                        echo "Type     : Ethernet-achtig of virtueel"
                        ;;
                    *)
                        echo "Type     : onbekend of virtueel"
                        ;;
                esac
            fi

            if [[ -r "/sys/class/net/$iface/operstate" ]]; then
                echo "Status   : $(cat "/sys/class/net/$iface/operstate")"
            fi

            ip -brief address show dev "$iface" 2>/dev/null || true
        done <<< "$interfaces"
    fi
fi

echo
echo "Opmerking: UP betekent niet automatisch dat internet werkt."

# ------------------------------------------------------------
# 4. Ping, pakketverlies en DNS
# ------------------------------------------------------------

section "4. INTERNETVERBINDING EN LATENCY"

if has ping; then
    ping_output=$(ping -n -c 10 -W 2 1.1.1.1 2>&1)
    ping_status=$?

    printf '%s\n' "$ping_output" |
        grep -E 'packets transmitted|packet loss|round-trip|rtt min/avg|max/mdev|unknown host|Network is unreachable' ||
        true

    # Expliciete routefout heeft voorrang.
    if printf '%s\n' "$ping_output" |
        grep -q 'Network is unreachable'; then

        warn "Netwerk onbereikbaar; controleer interface en route."

    else
        packet_loss=$(printf '%s\n' "$ping_output" |
            sed -nE 's/.* ([0-9]+([.][0-9]+)?)% packet loss.*/\1/p' |
            tail -n 1)

        loss_valid=0

        if [[ "${packet_loss:-}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
            loss_valid=1
        fi

        # Iedere uitkomst krijgt één beoordeling.
        if (( loss_valid == 0 )); then
            warn "Pakketverlies kon niet betrouwbaar worden uitgelezen."
        elif awk -v p="$packet_loss" 'BEGIN {exit !(p == 0)}'; then
            if (( ping_status == 0 )); then
                ok "Geen pakketverlies gemeten tijdens deze pingtest."
            else
                warn "Ping eindigde met een foutcode; controleer de uitvoer."
            fi
        elif awk -v p="$packet_loss" 'BEGIN {exit !(p < 2)}'; then
            warn "Beperkt pakketverlies gemeten: ${packet_loss}%."
        elif awk -v p="$packet_loss" 'BEGIN {exit !(p < 100)}'; then
            warn "Aanzienlijk pakketverlies gemeten: ${packet_loss}%. Herhaal de test."
        else
            warn "Geen pingantwoorden ontvangen; ICMP kan geblokkeerd zijn."
        fi
    fi
else
    warn "ping ontbreekt; latency niet getest."
fi

echo
echo "DNS-resolutie:"

if has getent; then
    if getent ahosts deb.debian.org >/dev/null 2>&1; then
        ok "DNS-resolutie werkt voor deb.debian.org."
    else
        warn "DNS-resolutie mislukt voor deb.debian.org."
    fi
else
    warn "getent ontbreekt; DNS niet gecontroleerd."
fi

if has dig; then
    dig +time=3 +tries=1 +stats deb.debian.org 2>/dev/null |
        awk '/Query time:/ {
                 print "DNS-resolutietijd: " $4 " ms"
                 found=1
             }
             END {
                 if (!found)
                     print "DNS-resolutietijd niet beschikbaar."
             }'
fi

# ------------------------------------------------------------
# 5. UDP-buffers en multicast
# ------------------------------------------------------------

section "5. UDP-BUFFERS EN MULTICAST"

if has sysctl; then
    rmem_max=$(sysctl -n net.core.rmem_max 2>/dev/null || true)
    rmem_default=$(sysctl -n net.core.rmem_default 2>/dev/null || true)

    echo "net.core.rmem_max     : ${rmem_max:-niet beschikbaar}"
    echo "net.core.rmem_default : ${rmem_default:-niet beschikbaar}"

    if [[ "$rmem_max" =~ ^[0-9]+$ ]]; then
        if (( rmem_max < 262144 )); then
            warn "Maximale receive-buffer kleiner dan 256 KiB."
        else
            ok "Maximale receive-buffer minimaal 256 KiB."
        fi
    else
        warn "Maximale receive-buffer niet beschikbaar."
    fi

    if [[ "$rmem_default" =~ ^[0-9]+$ ]]; then
        ok "Standaard receive-buffer numeriek beschikbaar (${rmem_default})."
    else
        warn "Standaard receive-buffer niet beschikbaar."
    fi
else
    warn "sysctl ontbreekt; UDP-buffers niet gecontroleerd."
fi

if has ip; then
    multicast_info=$(ip -o link show 2>/dev/null |
        grep -v '<[^>]*LOOPBACK' |
        grep -E '<[^>]*MULTICAST[^>]*>' || true)

    if [[ -n "$multicast_info" ]]; then
        ok "Multicast-vlag gevonden op minimaal één interface."
        printf '%s\n' "$multicast_info" |
            sed -E 's/^[0-9]+: /  /'
    else
        warn "Geen multicast-vlag aangetroffen."
    fi
fi

echo "Multicast-vlaggen bewijzen niet dat IGMP of de IPTV-stream werkt."

# ------------------------------------------------------------
# 6. Internet-downloadtest
# ------------------------------------------------------------

section "6. INTERNET-DOWNLOADTEST"

if ! has curl; then
    warn "curl ontbreekt; snelheidstest overgeslagen."
else
    echo "Doel: maximaal 25 MB; maximale testduur: 30 seconden."

    speed_file=$(mktemp 2>/dev/null) || speed_file=""
    curl_err=$(mktemp 2>/dev/null) || curl_err=""

    if [[ -z "$speed_file" || -z "$curl_err" ]]; then
        warn "Tijdelijke bestanden konden niet worden aangemaakt."
        [[ -z "$speed_file" ]] || rm -f "$speed_file"
        [[ -z "$curl_err" ]] || rm -f "$curl_err"
    else
        curl_output=$(curl -L -sS \
            --connect-timeout 10 \
            --max-time 30 \
            --max-filesize 30000000 \
            -o "$speed_file" \
            -w '%{http_code} %{speed_download} %{size_download}' \
            'https://speed.cloudflare.com/__down?bytes=25000000' \
            2>"$curl_err")
        curl_status=$?

        http_code=""
        speed_bytes=""
        downloaded=""
        read -r http_code speed_bytes downloaded <<< "${curl_output:-}"

        have_data=0

        if [[ "${downloaded:-}" =~ ^[0-9]+([.][0-9]+)?$ ]] &&
            awk -v n="$downloaded" 'BEGIN {exit !(n >= 1000000)}'; then
            have_data=1
        fi

        valid_status=0

        case "$curl_status" in
            0)
                valid_status=1
                ;;
            28|63)
                if (( have_data == 1 )); then
                    valid_status=1
                fi
                ;;
        esac

        if (( valid_status == 0 )) ||
            [[ ! "${http_code:-}" =~ ^2[0-9][0-9]$ ]] ||
            [[ ! "${speed_bytes:-}" =~ ^[0-9]+([.][0-9]+)?$ ]] ||
            (( have_data == 0 )); then

            warn "Snelheidstest mislukt of onvoldoende data ontvangen."
            echo "curl-status : $curl_status"
            echo "HTTP-status : ${http_code:-onbekend}"
            echo "Data        : ${downloaded:-0} bytes"

            if [[ -s "$curl_err" ]]; then
                echo "curl-melding:"
                sed 's/^/  /' "$curl_err"
            fi
        else
            speed_mbps=$(awk -v s="$speed_bytes" \
                'BEGIN {printf "%.2f", s*8/1000000}')

            echo "HTTP-status         : $http_code"
            echo "Ontvangen data      : $downloaded bytes"
            echo "Gemiddelde snelheid : $speed_mbps Mbps"

            case "$curl_status" in
                28)
                    echo "Opmerking: test afgebroken door tijdslimiet; deelmeting."
                    ;;
                63)
                    echo "Opmerking: test afgebroken door bestandslimiet; deelmeting."
                    ;;
            esac

            if awk -v s="$speed_mbps" 'BEGIN {exit !(s < 10)}'; then
                warn "Minder dan 10 Mbps gemeten."
            elif awk -v s="$speed_mbps" 'BEGIN {exit !(s < 25)}'; then
                warn "10 tot 25 Mbps gemeten; benodigde marge hangt af van de stream."
            else
                ok "Meer dan 25 Mbps gemeten tijdens deze test."
            fi

            echo "Een downloadtest garandeert geen stabiele IPTV."
        fi

        rm -f "$speed_file" "$curl_err"
    fi
fi

# ------------------------------------------------------------
# 7. Schijfruimte
# ------------------------------------------------------------

section "7. SCHIJFRUIMTE"

if has df; then
    df -h /

    available_kb=$(df -Pk / | awk 'NR==2 {print $4}')

    if [[ "$available_kb" =~ ^[0-9]+$ ]]; then
        if (( available_kb < 1048576 )); then
            warn "Minder dan 1 GiB vrije ruimte op de rootpartitie."
        else
            ok "Minimaal 1 GiB vrije ruimte op de rootpartitie."
        fi
    else
        warn "Vrije schijfruimte kon niet worden uitgelezen."
    fi
else
    warn "df ontbreekt; schijfruimte niet gecontroleerd."
fi

# ------------------------------------------------------------
# 8. Samenvatting
# ------------------------------------------------------------

section "8. SAMENVATTING"

echo "Aandachtspunten: $WARNINGS"

if (( WARNINGS > 0 )); then
    printf '%b\n' "${YELLOW}EINDOORDEEL: aanvullende controle aanbevolen.${NC}"
else
    printf '%b\n' "${GREEN}EINDOORDEEL: alle uitgevoerde controles zijn geslaagd.${NC}"
fi

echo
echo "BELANGRIJK:"
echo "- Dit script stelt geen definitieve IPTV-geschiktheid vast."
echo "- Test de daadwerkelijke stream, codec, audio en beeldkwaliteit."
echo "- Controleer bij multicast ook router, IGMP en provider."
echo "- De resultaten zijn afhankelijk van beschikbare hulpmiddelen."
echo "- Versie 0.9 is pre-release: resultaten kunnen per systeem afwijken."

exit 0