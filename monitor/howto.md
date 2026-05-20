---
HOW-TO: EEN STILLE BEST-PRACTICE THRESHOLD MONITOR OPZETTEN
---

Deze handleiding beschrijft hoe je een vederlichte, stille systeem-wachthond (syscheck-thresholds.sh) inricht op een Linux-systeem. Het script is gebaseerd op de 10 essentiële categorieën van de HexSec Linux Quick-Fix cheatsheets. 

In tegenstelling tot traditionele monitoring-tools verbruikt dit script geen resources op de achtergrond. Het blijft volledig stil (silent exit) zolang het systeem binnen de gestelde drempelwaarden (thresholds) draait. Pas wanneer een best practice wordt overschreden, genereert het script output en waarschuwt het de beheerder, inclusief de bijbehorende herstelcommando's.

---
1. HET SCRIPT AANMAKEN

Sla de onderstaande Bash-code op in een centrale, uitvoerbare locatie op het systeem, bijvoorbeeld in `/usr/local/bin/syscheck.sh`.

```bash
#!/usr/bin/env bash
#
# syscheck-thresholds.sh - Stille threshold-monitor gebaseerd op 10 Linux Cheatsheets
# Focust uitsluitend op afwijkingen van best practices.
#

# --- CONFIGURATIE THRESHOLDS ---
MAX_LOAD_FACTOR=0.85   # Max load per CPU core (bv. 0.85 = 85% belasting)
MAX_RAM_USAGE=90       # Maximaal RAM-gebruik in procenten
MAX_DISK_USAGE=85      # Maximaal schijfgebruik in procenten (Root FS)
MAX_LOG_SIZE_MB=1024   # Maximaal 1GB aan logs in /var/log
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)

# Buffer om waarschuwingen te verzamelen
WARNINGS=""
add_warning() {
    WARNINGS="$WARNINGS\n[!] $1\n    👉 FIX/CHECK: $2\n"
}

# Controleer op tools
has_cmd() { command -v "$1" >/dev/null 2>&1; }

# ==============================================================================
# CONTROLES OP BASIS VAN DE 10 CATEGORIEËN
# ==============================================================================

# --- 1. SYSTEM HEALTH & PERFORMANCE ---
if [ -f /proc/loadavg ] && [ -f /proc/cpuinfo ]; then
    CORES=$(grep -c ^processor /proc/cpuinfo)
    LOAD_1MIN=$(awk '{print $1}' /proc/loadavg)
    # Bereken load per core (schaal naar 100 voor bash integer vergelijking)
    LOAD_PER_CORE_INT=$(awk -v l="$LOAD_1MIN" -v c="$CORES" 'BEGIN {print int((l/c)*100)}')
    MAX_LOAD_INT=$(awk -v m="$MAX_LOAD_FACTOR" 'BEGIN {print int(m*100)}')
    
    if [ "$LOAD_PER_CORE_INT" -gt "$MAX_LOAD_INT" ]; then
        add_warning "Systeemload is te hoog: $LOAD_1MIN ($CORES cores)." "Gebruik 'htop' of 'ps aux' om malafide processen te vinden en eventueel te stoppen met 'kill PID'."
    fi
fi

RAM_PCT=$(free | awk '/Mem:/ {print int(($3/$2)*100)}')
if [ "$RAM_PCT" -gt "$MAX_RAM_USAGE" ]; then
    add_warning "RAM-gebruik overschrijdt drempelwaarde: ${RAM_PCT}% gebruikt." "Controleer geheugenvreters met 'free -h' en 'top'."
fi

# --- 2. CONFIG, TEXT & SCRIPT FIXES ---
# Gereserveerd voor specifieke omgevingscontroles (bv. syntax-audits via shellcheck)

# --- 3. SSH, FIREWALL & REMOTE ACCESS ---
if has_cmd ufw; then
    UFW_STATUS=$(sudo ufw status | head -n 1 | awk '{print $2}')
    if [ "$UFW_STATUS" != "active" ]; then
        add_warning "De UFW Firewall staat UIT." "Zet the firewall aan met 'sudo ufw enable' en controleer regels via 'sudo ufw status verbose'."
    fi
fi

# Waarschuwing als SSH luistert zonder dat Fail2Ban aanwezig is
if ss -tlpn | grep -q ":22 " && ! has_cmd fail2ban-client; then
    add_warning "SSH poort 22 luistert, maar Fail2Ban is niet geïnstalleerd." "Beveilig SSH tegen brute-force aanvallen via 'sudo apt install fail2ban'."
fi

# --- 4. PACKAGES, USERS & PERMISSIONS ---
# Waarschuwing als er cruciale beveiligingsupdates klaarstaan (Debian/Ubuntu systemen)
if [ -x /usr/lib/update-notifier/apt-check ]; then
    UPDATES=$(/usr/lib/update-notifier/apt-check 2>&1)
    SEC_UPDATES=$(echo "$UPDATES" | cut -d';' -f2)
    if [ "$SEC_UPDATES" -gt 0 ]; then
        add_warning "Er staan $SEC_UPDATES beveiligingsupdates open!" "Voer direct een update uit via 'sudo apt update && sudo apt upgrade'."
    fi
fi

# --- 5. LOGS & ERROR HUNTING ---
# Check op recente kritieke meldingen in dmesg
if has_cmd dmesg; then
    RECENT_ERRORS=$(sudo dmesg -T 2>/dev/null | grep -i -E 'error|fail|critical' | tail -n 3)
    if [ -n "$RECENT_ERRORS" ]; then
        add_warning "Er zijn recente kritieke meldingen in de kernel gedetecteerd." "Inspecteer de logs live met 'sudo dmesg -T | grep -i error' of 'journalctl -kx'."
    fi
fi

# --- 6. HARDWARE, DRIVERS & DEVICES ---
if has_cmd sensors; then
    HIGH_TEMP=$(sensors 2>/dev/null | grep -E '(Core 0|temp1)' | awk '{print $2}' | tr -d '+°C' | awk '{if($1 > 80) print $1}')
    if [ -n "$HIGH_TEMP" ]; then
        add_warning "CPU Temperatuur is kritiek hoog (>80°C): ${HIGH_TEMP}°C." "Controleer de hardware-status en fans via 'sensors' of 'upower'."
    fi
fi

# --- 7. DISK, FILESYSTEM & STORAGE ---
DISK_PCT=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$DISK_PCT" -gt "$MAX_DISK_USAGE" ]; then
    add_warning "Schijfruimte op / is bijna vol: ${DISK_PCT}% gebruikt." "Zoek grote bestanden via 'du -ah . | sort -h' en schoon de cache op met 'sudo apt clean'."
fi

LOG_SIZE_KB=$(sudo du -s /var/log 2>/dev/null | awk '{print $1}')
LOG_SIZE_MB=$((LOG_SIZE_KB / 1024))
if [ "$LOG_SIZE_MB" -gt "$MAX_LOG_SIZE_MB" ]; then
    add_warning "/var/log is groter dan de limiet: ${LOG_SIZE_MB}MB." "Forceer een log-rotatie om ruimte te maken: 'sudo logrotate -f /etc/logrotate.conf'."
fi

# --- 8. SERVICES, BOOT & STARTUP ---
FAILED_SVCS=$(systemctl list-units --failed --quiet | wc -l)
if [ "$FAILED_SVCS" -gt 0 ]; then
    add_warning "Er zijn $FAILED_SVCS systemd services gecrasht of gefaald." "Vind de boosdoener met 'systemctl list-units --failed' en bekijk de fout met 'journalctl -xe'."
fi

# --- 9. NETWORK & DNS FIXES ---
if [ -n "$INTERFACE" ]; then
    LINK_STATUS=$(cat /sys/class/net/"$INTERFACE"/operstate 2>/dev/null)
    if [ "$LINK_STATUS" != "up" ]; then
        add_warning "Netwerkinterface $INTERFACE is down of heeft geen link." "Probeer de interface te herstarten via 'sudo ip link set $INTERFACE up' of 'sudo systemctl restart NetworkManager'."
    fi
fi

# --- 10. BACKUP, SYNC & RECOVERY ---
# Waarschuwing als er in de afgelopen 7 dagen geen backup- of archiefbestand (.tar.gz/.zip/.bak) is aangemaakt/gewijzigd
if [ -z "$(find /home -maxdepth 3 -mtime -7 \( -name "*.tar.gz" -o -name "*.zip" -o -name "*.bak" \) 2>/dev/null)" ]; then
    add_warning "Geen recente backups of archieven (.tar.gz/.zip) gevonden uit de afgelopen 7 dagen." "Maak een handmatige backup met 'tar -czf backup.tar.gz folder/' of verifieer je rsync-taken."
fi

# ==============================================================================
# RAPPORTAGE (OUTPUT ALLEEN BIJ AFWIJKINGEN)
# ==============================================================================

if [ -n "$WARNINGS" ]; then
    echo -e "⚠️  LINUX BEST PRACTICE ALERTS — AANDACHT VEREIST"
    echo -e "Geregistreerd op: $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "----------------------------------------------------------------------"
    echo -e "$WARNINGS"
    echo -e "----------------------------------------------------------------------"
    exit 1
else
    # Systeem is gezond, wees volledig stil
    exit 0
fi

```

---
2. INSTALLATIE & RECHTEN

Om ervoor te zorgen dat het script betrouwbaar de systeembestanden, firewall-statistieken en kernel-logs kan inzien, dient het met root-rechten te worden uitgevoerd.

1. Sla de bovenstaande code op in `/usr/local/bin/syscheck.sh`.
2. Maak het bestand uitsluitend lees- en uitvoerbaar voor de root-gebruiker om misbruik te voorkomen:
```bash
   sudo chmod 700 /usr/local/bin/syscheck.sh
   sudo chown root:root /usr/local/bin/syscheck.sh
```
---
3. HANDMATIGE TEST
--------------------------------------------------------------------------------

Je kunt de werking van het script direct handmatig controleren via de terminal:

sudo /usr/local/bin/syscheck.sh

* Indien alles in orde is: Het script geeft geen enkele output en keert direct terug naar de prompt (exit 0).
* Indien een threshold is overschreden: Het script toont een overzichtelijke waarschuwing met directe quick-fixes (exit 1).

--------------------------------------------------------------------------------
4. AUTOMATISERING VIA CRON
--------------------------------------------------------------------------------

De kracht van dit 'stille' script komt pas echt tot zijn recht wanneer je het periodiek laat draaien via de systeem-cron. Omdat Cron de output van scripts opvangt, kun je er eenvoudig voor zorgen dat je alleen bij calamiteiten wordt genotificeerd.

1. Open de crontab van de root-gebruiker:
   sudo crontab -e

2. Voeg een regel toe onderaan het bestand om de controle bijvoorbeeld elke ochtend om 08:00 uur uit te voeren:

   Optie A: Meldingen wegschrijven naar een lokaal logbestand
   0 8 * * * /usr/local/bin/syscheck.sh >> /var/log/syscheck_alerts.log 2>&1

   Optie B: Direct e-mailen (indien een lokale mail-agent zoals postfix of ssmtp actief is op de host)
   0 8 * * * /usr/local/bin/syscheck.sh

   (Cron verstuurt automatisch een e-mail naar root zodra een script tekstuele output genereert. Blijft het script stil? Dan wordt er geen mail verstuurd).
================================================================================
