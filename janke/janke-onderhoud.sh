#!/usr/bin/env bash
#
# Debian 12 (Bookworm) - Onderhoud voor Janke
# Uitvoeren: sudo bash janke-onderhoud.sh
#
# 1. Beheerdersaccount henry
# 2. KeePassXC beschermen EN back-up maken van kluizen in /home
# 3. Systeem bijwerken
# 4. Oude pakketten opruimen na toestemming
# 5. GRUB bijwerken
# 6. Tailscale installeren en SSH inschakelen
# 7. Automatische beveiligingsupdates
# 8. UFW-firewall, daarna optioneel openssh-server
# 9. SMART-schijfcontrole
# 10. Back-upvoorzieningen inventariseren en actieve SQL-databases detecteren
#
# Geen automatische herstart. Geen automatische back-up van systeemdata.
# KeePassXC-kluizen worden wel veilig gekopieerd naar /var/backups/keepassxc/.

set -Eeuo pipefail
umask 077

NEW_USER="henry"
LOG_FILE="/var/log/janke-onderhoud-$(date +%F_%H%M%S).log"
KPXC_BACKUP_ROOT="/var/backups/keepassxc"

APT_OPTS=(
    -o Dpkg::Options::="--force-confdef"
    -o Dpkg::Options::="--force-confold"
)

trap 'rc=$?; echo "[FOUT] Regel ${LINENO}: exitcode ${rc}. Log: ${LOG_FILE:-onbekend}." >&2; exit "$rc"' ERR

# ==================================================
# CONTROLE
# ==================================================

if [[ "$EUID" -ne 0 ]]; then
    echo "Voer uit met: sudo bash $0"
    exit 1
fi

if [[ ! -r /etc/debian_version ]] ||
   ! grep -qE '^12([.]|$)' /etc/debian_version; then
    echo "Dit script is uitsluitend bedoeld voor Debian 12."
    exit 1
fi

exec > >(tee -a "$LOG_FILE") 2>&1
export DEBIAN_FRONTEND=noninteractive

echo "[i] Logboek: $LOG_FILE"
echo "=================================================="
echo " Debian 12 - Onderhoud voor Janke"
echo "=================================================="

# ==================================================
# HULPFUNCTIES
# ==================================================

ask_yes_no() {
    local answer="nee"

    if [[ ! -r /dev/tty ]]; then
        echo "[!] Geen interactieve terminal. Actie overgeslagen."
        return 1
    fi

    read -r -p "$1 [ja/N]: " answer </dev/tty || answer="nee"

    [[ "${answer,,}" == "ja" || "${answer,,}" == "j" ]]
}

backup_keepassxc() {
    local SEARCH_ROOT="/home"
    local TIMESTAMP
    TIMESTAMP=$(date +%F_%H%M%S)
    local BACKUP_DIR="$KPXC_BACKUP_ROOT/$TIMESTAMP"

    echo "[i] Zoeken naar KeePassXC-databases in $SEARCH_ROOT..."

    local DB_FILES
    DB_FILES=$(find "$SEARCH_ROOT" -type f \
        \( -name '*.kdbx' -o -name '*.kdbx.bak' -o -name '*.kdbx.old' -o -name '*.kdb' \) \
        -not -path '*/.cache/*' \
        -not -path '*/.local/share/Trash/*' \
        -not -name '*.kdbx.lock' \
        2>/dev/null | sort || true)

    if [[ -z "$DB_FILES" ]]; then
        echo "[i] Geen KeePassXC-databases gevonden in $SEARCH_ROOT."
        return 0
    fi

    local COUNT
    COUNT=$(printf '%s\n' "$DB_FILES" | wc -l)
    echo "[i] $COUNT databasebestand(en) gevonden:"
    printf '%s\n' "$DB_FILES" | sed 's/^/    /'

    # Lock-bestanden duiden op een mogelijk geopende database.
    local LOCK_FILES
    LOCK_FILES=$(find "$SEARCH_ROOT" -type f -name '*.kdbx.lock' \
        -not -path '*/.cache/*' 2>/dev/null | sort || true)

    if [[ -n "$LOCK_FILES" ]]; then
        echo
        echo "[!] Lock-bestanden gevonden — database mogelijk OPEN:"
        printf '%s\n' "$LOCK_FILES" | sed 's/^/    /'
        echo "[!] Een kopie van een geopend bestand kan inconsistent zijn."
        echo "[i] Vraag de gebruiker KeePassXC te sluiten voor een schone kopie."
        if ! ask_yes_no "Toch doorgaan met de back-up?"; then
            echo "[i] Back-up overgeslagen vanwege lock-bestanden."
            return 0
        fi
    fi

    # Grootte bepalen
    local TOTAL_BYTES=0 SZ
    while IFS= read -r F; do
        [[ -z "$F" ]] && continue
        SZ=$(stat -c '%s' "$F" 2>/dev/null || echo 0)
        TOTAL_BYTES=$(( TOTAL_BYTES + SZ ))
    done <<< "$DB_FILES"

    echo "[i] Totale grootte: ca. $(( TOTAL_BYTES / 1024 )) KB"

    if (( TOTAL_BYTES > 524288000 )); then
        echo "[!] Meer dan 500 MB aan kluizen. Controleer of dit klopt."
    fi

    if ! mkdir -p "$BACKUP_DIR"; then
        echo "[!] Kon back-upmap niet aanmaken: $BACKUP_DIR"
        return 1
    fi
    chmod 700 "$BACKUP_DIR"
    chown root:root "$BACKUP_DIR" 2>/dev/null || true

    local MANIFEST="$BACKUP_DIR/MANIFEST.txt"
    {
        echo "# KeePassXC back-up manifest"
        echo "# Datum:    $(date -Iseconds)"
        echo "# Hostname: $(hostname)"
        echo "# Bron:     $SEARCH_ROOT"
        echo
    } > "$MANIFEST"

    local OK=0 FAIL=0
    while IFS= read -r SRC; do
        [[ -z "$SRC" ]] && continue
        local DEST_PATH="$BACKUP_DIR/files${SRC}"
        local DEST_DIR
        DEST_DIR=$(dirname "$DEST_PATH")

        mkdir -p "$DEST_DIR"
        chmod 700 "$DEST_DIR"

        if cp -a -- "$SRC" "$DEST_PATH"; then
            chown root:root "$DEST_PATH" 2>/dev/null || true
            chmod 600 "$DEST_PATH"

            local SRC_HASH DST_HASH
            SRC_HASH=$(sha256sum "$SRC" | awk '{print $1}')
            DST_HASH=$(sha256sum "$DEST_PATH" | awk '{print $1}')

            if [[ "$SRC_HASH" == "$DST_HASH" ]]; then
                printf 'OK   %s  %s\n' "$SRC_HASH" "$SRC" >> "$MANIFEST"
                OK=$(( OK + 1 ))
            else
                echo "[!] Hash-mismatch voor: $SRC"
                printf 'FAIL %s  %s\n' "$SRC_HASH" "$SRC" >> "$MANIFEST"
                FAIL=$(( FAIL + 1 ))
            fi
        else
            echo "[!] Kon niet kopiëren: $SRC"
            printf 'FAIL -      %s\n' "$SRC" >> "$MANIFEST"
            FAIL=$(( FAIL + 1 ))
        fi
    done <<< "$DB_FILES"

    chmod 600 "$MANIFEST"

    echo
    if (( FAIL == 0 )); then
        echo "[+] Back-up voltooid: $OK bestand(en), hash geverifieerd."
    else
        echo "[!] Back-up met fouten: $OK OK, $FAIL mislukt."
    fi
    echo "[i] Locatie:  $BACKUP_DIR"
    echo "[i] Manifest: $MANIFEST"
    echo "[i] Toegang:  alleen root (mode 700/600)."
    echo
    echo "[!] Deze back-up staat op DEZELFDE machine."
    echo "[!] Kopieer $BACKUP_DIR naar externe media VOORDAT je vertrekt."
    echo "[!] /var/backups kan bij handmatig onderhoud worden opgeruimd."

    return 0
}

check_sql_databases() {
    echo "--- Actieve SQL-databases ---"
    echo "[i] Alleen detectie; er wordt niets gewijzigd."

    echo
    echo "[i] Luisterende standaard SQL-poorten:"
    local PORT_LINES
    if command -v ss >/dev/null 2>&1; then
        PORT_LINES=$(ss -tlnp 2>/dev/null | \
            grep -E ':(3306|33060|5432|5433|27017|27018|1433|1521|6379|11211|9200|9300|9042|8086|8123)\s' \
            || true)
    else
        PORT_LINES=$(netstat -tlnp 2>/dev/null | \
            grep -E ':(3306|33060|5432|5433|27017|27018|1433|1521|6379|11211|9200|9300|9042|8086|8123)\s' \
            || true)
    fi
    if [[ -n "$PORT_LINES" ]]; then
        printf '%s\n' "$PORT_LINES" | sed 's/^/    /'
    else
        echo "    (geen standaard SQL-poorten in gebruik)"
    fi

    echo
    echo "[i] Draaiende database-services:"
    local SERVICE_LINES
    SERVICE_LINES=$(systemctl list-units --type=service --state=running --no-pager 2>/dev/null | \
        grep -iE 'mysql|mariadb|postgres|mongodb|redis|elasticsearch|memcached|cassandra|influxdb|clickhouse|cockroach|oracle|percona' \
        || true)
    if [[ -n "$SERVICE_LINES" ]]; then
        printf '%s\n' "$SERVICE_LINES" | sed 's/^/    /'
    else
        echo "    (geen herkenbare draaiende database-services)"
    fi

    echo
    echo "[i] Database-processen:"
    local PROC_LINES
    PROC_LINES=$(pgrep -a -f \
        '(mysqld|mariadbd|postgres|mongod|redis-server|elasticsearch|memcached|cassandra|influxd|clickhouse-server|cockroach)' \
        2>/dev/null || true)
    if [[ -n "$PROC_LINES" ]]; then
        printf '%s\n' "$PROC_LINES" | sed 's/^/    /'
    else
        echo "    (geen draaiende database-processen)"
    fi

    echo
    echo "[i] Database Unix-sockets:"
    local SOCK_FOUND=0 DIR LS_OUT
    for DIR in /var/run/mysqld /run/mysqld /var/run/postgresql /run/postgresql \
               /var/run/mongodb /run/redis /var/run/redis; do
        if [[ -d "$DIR" ]]; then
            LS_OUT=$(ls -1 "$DIR" 2>/dev/null || true)
            if [[ -n "$LS_OUT" ]]; then
                echo "    $DIR:"
                printf '%s\n' "$LS_OUT" | sed 's/^/      /'
                SOCK_FOUND=1
            fi
        fi
    done
    if (( SOCK_FOUND == 0 )); then
        echo "    (geen bekende socket-mappen met inhoud)"
    fi

    echo
    echo "[i] Geïnstalleerde database-server-pakketten:"
    local PKG_LINES
    PKG_LINES=$(dpkg-query -W -f='${Package}\t${Status}\n' 2>/dev/null | \
        awk -F'\t' '$2 == "install ok installed" { print $1 }' | \
        grep -iE '^(mysql-server|mariadb-server|postgresql-[0-9]+$|postgresql$|mongodb|mongodb-server|redis-server|elasticsearch|memcached|cassandra|influxdb|clickhouse-server|cockroach)' \
        || true)
    if [[ -n "$PKG_LINES" ]]; then
        printf '%s\n' "$PKG_LINES" | sed 's/^/    /'
    else
        echo "    (geen database-server-pakketten geïnstalleerd)"
    fi

    echo
    echo "[i] SQLite-bestanden in /home (informatief, geen actieve server):"
    local SQLITE_FILES
    SQLITE_FILES=$(find /home -type f \
        \( -name '*.sqlite' -o -name '*.sqlite3' -o -name '*.db' -o -name '*.db3' \) \
        -not -path '*/.cache/*' \
        -not -path '*/.mozilla/*' \
        -not -path '*/.config/*' \
        2>/dev/null | head -50 || true)
    if [[ -n "$SQLITE_FILES" ]]; then
        echo "    (max. 50 getoond)"
        printf '%s\n' "$SQLITE_FILES" | sed 's/^/    /'
    else
        echo "    (geen SQLite-bestanden gevonden in /home)"
    fi
}

# ==================================================
# PRE-FLIGHT
# ==================================================

echo
echo "PRE-FLIGHT: veiligheidscontroles"

if ! command -v sudo >/dev/null 2>&1; then
    echo "[!] sudo ontbreekt. Installeren..."
    apt-get update
    apt-get install -y sudo
fi

ROOT_AVAIL_MB=$(df --output=avail -m / | tail -n 1 | tr -d ' ')

if [[ ! "$ROOT_AVAIL_MB" =~ ^[0-9]+$ ]] ||
   (( ROOT_AVAIL_MB < 1024 )); then
    echo "[-] Minder dan 1 GB vrije ruimte op /."
    exit 1
fi

echo "[+] Vrije ruimte op /: ${ROOT_AVAIL_MB} MB"

if mountpoint -q /boot; then
    BOOT_AVAIL_MB=$(df --output=avail -m /boot | tail -n 1 | tr -d ' ')
    echo "[i] Vrije ruimte op /boot: ${BOOT_AVAIL_MB} MB"

    if [[ "$BOOT_AVAIL_MB" =~ ^[0-9]+$ ]] &&
       (( BOOT_AVAIL_MB < 200 )); then
        echo "[-] Minder dan 200 MB vrij op /boot."
        echo "[i] Los dit eerst op."
        exit 1
    fi
fi

echo "[i] dpkg-configuratie controleren..."
dpkg --configure -a
apt-get check

echo "[+] dpkg en APT zijn in orde."

HELD=$(apt-mark showhold 2>/dev/null || true)

if [[ -n "$HELD" ]]; then
    echo "[!] Pakketten op hold:"
    printf '%s\n' "$HELD"
fi

# ==================================================
# STAP 1: BEHEERDERSACCOUNT
# ==================================================

echo
echo "STAP 1: Beheerdersaccount"

if id "$NEW_USER" >/dev/null 2>&1; then
    echo "[i] Gebruiker $NEW_USER bestaat al."
else
    echo "[+] Gebruiker $NEW_USER aanmaken."
    useradd -m -s /bin/bash "$NEW_USER"
    passwd "$NEW_USER"
fi

if ! getent group sudo >/dev/null; then
    echo "[-] De groep sudo bestaat niet."
    exit 1
fi

usermod -aG sudo "$NEW_USER"

echo "[+] $NEW_USER is lid van de sudo-groep."
echo "[i] Opnieuw aanmelden is nodig voor bestaande sessies."

# ==================================================
# STAP 2: KEEPASSXC BESCHERMEN EN BACK-UP MAKEN
# ==================================================

echo
echo "STAP 2: KeePassXC beschermen en back-up maken"

if dpkg-query -W -f='${Status}' keepassxc 2>/dev/null |
   grep -q 'install ok installed'; then
    apt-mark manual keepassxc
    echo "[+] KeePassXC beschermd tegen autoremove."
else
    echo "[i] KeePassXC is niet geïnstalleerd op dit systeem."
fi

echo
backup_keepassxc || echo "[!] KeePassXC-back-up niet voltooid; ga verder."

# ==================================================
# STAP 3: SYSTEEM BIJWERKEN
# ==================================================

echo
echo "STAP 3: Systeem bijwerken"

apt-get update
apt-get "${APT_OPTS[@]}" upgrade -y

echo "[+] Upgrade voltooid."
echo "[i] Er is geen full-upgrade uitgevoerd."

# ==================================================
# STAP 4: AUTOREMOVE
# ==================================================

echo
echo "STAP 4: Oude pakketten opruimen"

echo "[i] Eerst de simulatie; er worden nog geen pakketten verwijderd."

if apt-get "${APT_OPTS[@]}" autoremove --purge --dry-run; then
    echo
    echo "[!] Controleer bovenstaande lijst zorgvuldig."

    if ask_yes_no "Wil je deze pakketten daadwerkelijk verwijderen?"; then
        apt-get "${APT_OPTS[@]}" autoremove --purge
        echo "[+] Autoremove voltooid."
    else
        echo "[i] Autoremove overgeslagen."
    fi
else
    echo "[!] Simulatie mislukt; autoremove overgeslagen."
    echo "[i] Controleer APT handmatig voor je opruimt."
fi

apt-get clean
echo "[+] APT-cache opgeschoond."

# ==================================================
# STAP 5: GRUB
# ==================================================

echo
echo "STAP 5: GRUB bijwerken"

if command -v update-grub >/dev/null 2>&1; then
    update-grub
    echo "[+] GRUB-configuratie bijgewerkt."
else
    echo "[i] update-grub niet gevonden."
fi

# ==================================================
# STAP 6: TAILSCALE
# ==================================================

echo
echo "STAP 6: Tailscale"

if ! command -v curl >/dev/null 2>&1; then
    apt-get install -y curl
fi

if ! command -v tailscale >/dev/null 2>&1; then
    if ask_yes_no "Tailscale installeren via tailscale.com?"; then
        curl -fsSL https://tailscale.com/install.sh \
            -o /tmp/tailscale-install.sh

        bash /tmp/tailscale-install.sh
        rm -f /tmp/tailscale-install.sh
    else
        echo "[!] Tailscale-installatie overgeslagen."
    fi
fi

if command -v tailscale >/dev/null 2>&1; then
    systemctl enable --now tailscaled

    echo "[i] Tailscale-status:"
    tailscale status || true

    TS_IP=$(tailscale ip -4 2>/dev/null || true)

    if [[ -n "$TS_IP" ]]; then
        echo "[+] Tailscale IPv4: $TS_IP"

        if ask_yes_no "Tailscale SSH inschakelen?"; then
            tailscale set --ssh=true
        fi
    else
        echo "[!] Tailscale is nog niet aangemeld."
        echo "[i] Meld de machine handmatig aan met: tailscale up"
        echo "[i] Doe dit VOORDAT je de locatie verlaat."
    fi
else
    echo "[!] Tailscale is niet beschikbaar."
fi

# ==================================================
# STAP 7: AUTOMATISCHE BEVEILIGINGSUPDATES
# ==================================================

echo
echo "STAP 7: Automatische beveiligingsupdates"

apt-get install -y unattended-upgrades smartmontools ufw

if [[ -f /etc/apt/apt.conf.d/20auto-upgrades ]]; then
    cp -a /etc/apt/apt.conf.d/20auto-upgrades \
        "/etc/apt/apt.conf.d/20auto-upgrades.bak.$(date +%F)"
    echo "[i] Oude 20auto-upgrades geback-upt."
fi

cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

chmod 644 /etc/apt/apt.conf.d/20auto-upgrades

echo "[+] Periodieke updates ingesteld."
echo "[i] Timerstatus:"
systemctl is-enabled apt-daily.timer || true
systemctl is-enabled apt-daily-upgrade.timer || true
systemctl is-active apt-daily.timer || true
systemctl is-active apt-daily-upgrade.timer || true

# ==================================================
# STAP 8: UFW EN OPTIONEEL OPENSSH-SERVER
# ==================================================

echo
echo "STAP 8: UFW-firewall"

echo "[i] Luisterende TCP-poorten:"
if command -v ss >/dev/null 2>&1; then
    ss -tlnp || true
elif command -v netstat >/dev/null 2>&1; then
    netstat -tlnp || true
else
    echo "  (ss/netstat niet beschikbaar)"
fi

echo
echo "[i] Bestaande firewallstatus:"
ufw status verbose || true

echo
echo "[!] Een standaardbeleid 'deny incoming' kan LAN-toegang blokkeren."
echo "[!] Een Tailscale-IP bewijst niet dat toegang vanaf je laptop werkt."
echo "[!] Bestaande UFW-regels worden niet automatisch verwijderd."
echo "[!] Het standaardbeleid wordt wel overschreven als je doorgaat."

UFW_ACTIVE=0

if command -v tailscale >/dev/null 2>&1 &&
   systemctl is-active --quiet tailscaled; then

    TS_IP=$(tailscale ip -4 2>/dev/null || true)

    if [[ -n "$TS_IP" ]]; then
        if ask_yes_no "UFW instellen met standaard inkomend weigeren en tailscale0 toestaan?"; then
            echo "[i] Voorgenomen wijzigingen:"
            echo "    ufw default deny incoming"
            echo "    ufw default allow outgoing"
            echo "    ufw allow in on tailscale0"

            if ask_yes_no "Bevestig dat je het risico op verlies van LAN-toegang begrijpt?"; then
                ufw default deny incoming
                ufw default allow outgoing
                ufw allow in on tailscale0
                ufw --force enable
                ufw status verbose
                UFW_ACTIVE=1

                echo "[!] Test de externe verbinding onmiddellijk."
            else
                echo "[i] Firewallwijzigingen overgeslagen."
            fi
        else
            echo "[i] UFW niet gewijzigd."
        fi
    else
        echo "[!] Geen Tailscale-IP; UFW niet gewijzigd."
    fi
else
    echo "[!] Tailscale is niet actief; UFW niet gewijzigd."
fi

echo
echo "[i] SSH-server (openssh-server):"

if dpkg-query -W -f='${Status}' openssh-server 2>/dev/null |
   grep -q 'install ok installed'; then
    echo "[i] openssh-server is al geïnstalleerd."
    systemctl is-active --quiet ssh &&
        echo "[+] Service actief." ||
        echo "[!] Service niet actief."
    systemctl is-enabled --quiet ssh &&
        echo "[+] Service ingeschakeld." ||
        echo "[!] Service niet ingeschakeld."
else
    if [[ "$UFW_ACTIVE" -eq 1 ]] ||
       ufw status 2>/dev/null | grep -q "Status: active"; then
        echo "[i] UFW is actief: openssh zou alleen via tailscale0 bereikbaar zijn."
        if ask_yes_no "openssh-server installeren en inschakelen?"; then
            apt-get install -y openssh-server
            systemctl enable --now ssh
            systemctl is-active --quiet ssh &&
                echo "[+] SSH-service actief." ||
                echo "[!] SSH-service niet actief."
            echo "[!] Wachtwoord-authenticatie staat standaard aan;"
            echo "[!] overweeg dit te beperken tot sleutels."
        fi
    else
        echo "[!] UFW is NIET actief. openssh zou op het hele LAN"
        echo "[!] bereikbaar zijn, met wachtwoord-authenticatie aan."
        if ask_yes_no "Toch openssh-server installeren? (LAN-exposure!)"; then
            apt-get install -y openssh-server
            systemctl enable --now ssh
            systemctl is-active --quiet ssh &&
                echo "[+] SSH-service actief." ||
                echo "[!] SSH-service niet actief."
        fi
    fi
fi

# ==================================================
# STAP 9: SMART
# ==================================================

echo
echo "STAP 9: SMART-schijfcontrole"

while read -r DISK TYPE; do
    if [[ "$TYPE" != "disk" ]]; then
        continue
    fi
    if [[ "$DISK" == zram* ]]; then
        continue
    fi

    DEVICE="/dev/$DISK"

    echo
    echo "[i] SMART-status: $DEVICE"

    if ! smartctl -H "$DEVICE"; then
        echo "[!] SMART-status niet beschikbaar of controle mislukt."
    fi
done < <(lsblk -dn -o NAME,TYPE)

echo
echo "[i] Dit is een korte statuscontrole, geen volledige schijftest."

# ==================================================
# STAP 10: BACK-UPS EN SQL-DATABASES INVENTARISEREN
# ==================================================

echo
echo "STAP 10: Back-upvoorzieningen en SQL-databases"

echo
echo "--- Root-crontab ---"
crontab -l 2>/dev/null || echo "Geen root-crontab gevonden."

echo
echo "--- Crontab van $NEW_USER ---"
crontab -u "$NEW_USER" -l 2>/dev/null ||
    echo "Geen gebruikerscrontab gevonden."

echo
echo "--- Mogelijke back-up-timers ---"
if ! systemctl list-timers --all --no-pager |
    grep -iE 'backup|rsync|timeshift|duplicity|borg|restic'; then
    echo "Geen herkenbare back-up-timers gevonden."
fi

echo
echo "--- Mogelijke back-updiensten ---"
if ! systemctl list-units --type=service --all --no-pager |
    grep -iE 'backup|borg|restic|duplicity|timeshift'; then
    echo "Geen herkenbare back-updiensten gevonden."
fi

echo
echo "--- Mislukte systemd-units ---"
systemctl --failed --no-pager || true

echo
check_sql_databases || true

# ==================================================
# HERSTARTCONTROLE
# ==================================================

echo
echo "HERSTARTCONTROLE"

if [[ -f /var/run/reboot-required ]]; then
    echo "[!] Een herstart kan vereist zijn."

    if [[ -f /var/run/reboot-required.pkgs ]]; then
        echo "[i] Pakketten die een herstart vereisen:"
        sed 's/^/    /' /var/run/reboot-required.pkgs
    fi

    echo "[!] Geen automatische herstart uitgevoerd."
else
    echo "[i] Geen reboot-required-bestand gevonden."
fi

# ==================================================
# AFSLUITING
# ==================================================

echo
echo "=================================================="
echo " ONDERHOUDSSCRIPT AFGEROND"
echo "=================================================="

echo
echo "CONTROLELIJST:"
echo "1. Voer 'tailscale up' uit als de machine nog niet is aangemeld."
echo "2. Test Tailscale SSH vanaf een andere computer."
echo "3. Test de gekozen SSH-methode (Tailscale SSH of openssh)."
echo "4. Kopieer de KeePassXC-back-up naar externe media."
echo "5. Open Firefox en ga naar http://fritz.box."
echo "6. Controleer KeePassXC en de locatie van de kluis."
echo "7. Controleer externe schijf- of cloudback-ups."
echo "8. Controleer SMART-status en vrije schijfruimte."
echo "9. Controleer of henry met sudo kan werken."
echo "10. Herstart pas nadat externe toegang is geverifieerd."

echo
echo "[!] Dit script maakt alleen een KeePassXC-back-up, geen systeemback-up."
echo "[!] Er wordt niet automatisch herstart."
echo "[i] Logboek: $LOG_FILE"
echo "[i] KeePassXC-back-up: $KPXC_BACKUP_ROOT/ (indien gevonden)"

# Korte pauze zodat tee de laatste regels kan wegschrijven.
sleep 0.2