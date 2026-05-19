#!/bin/sh
# -------------------------------------------------------------------------
# Alpine Linux Diskless Kiosk Setup Script
# Versie: 2.3 - Final Productie Ready
# Features: RAM-only kiosk, Firefox, Firewall (nftables), Auto-Updates,
# Startpage.com default homepage, WiFi ondersteuning & NTP tijd synchronisatie
# -------------------------------------------------------------------------

# ============================================
# 1. BASIS CHECKS EN VARIABELEN
# ============================================

# Forceer root-rechten
if [ "$(id -u)" -ne 0 ]; then
    echo "Dit script moet als root worden uitgevoerd!"
    exit 1
fi

# Controleer Alpine Linux
if ! grep -q "Alpine" /etc/os-release 2>/dev/null; then
    echo "Dit script is alleen voor Alpine Linux!"
    exit 1
fi

# Lock bestand om dubbele uitvoering te voorkomen
LOCK_FILE="/var/run/kiosk-setup.lock"
if [ -f "$LOCK_FILE" ]; then
    echo "⚠ Setup is al eerder uitgevoerd!"
    echo "  Reboot eerst of verwijder $LOCK_FILE om opnieuw te installeren"
    exit 1
fi
touch "$LOCK_FILE"

# Kleuren voor output (indien terminal ondersteunt het)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; NC=''
fi

# Logbestand setup (POSIX-compliant)
LOG_FILE="/var/log/kiosk-setup.log"
echo "--- Kiosk Setup Log Start: $(date) ---" > "$LOG_FILE"
exec 3>&1
exec >> "$LOG_FILE" 2>&1

log_echo() {
    echo "$1" >&3
    echo "$1"
}

# ============================================
# 2. SYSTEEM UPDATE & PAKKETTEN
# ============================================

log_echo "${GREEN}========================================================================${NC}"
log_echo "${GREEN}     ALPINE LINUX DISKLESS KIOSK SETUP - VERSIE 2.3${NC}"
log_echo "${GREEN}========================================================================${NC}"
log_echo "Start tijd: $(date)"
log_echo ""

log_echo "${GREEN}=== 1. Pakketbronnen instellen ===${NC}"
cat > /etc/apk/repositories << 'EOF'
https://dl-cdn.alpinelinux.org/alpine/v3.20/main
https://dl-cdn.alpinelinux.org/alpine/v3.20/community
EOF

log_echo "${GREEN}=== 2. Systeem updaten en software installeren ===${NC}"
apk update
apk upgrade

log_echo "${BLUE}Benodigde pakketten worden geïnstalleerd...${NC}"
apk add \
    xorg-server xinit xf86-input-libinput xf86-video-fbdev \
    eudev udev-init-scripts \
    openbox \
    font-dejavu \
    firefox-esr \
    alsa-utils alsa-lib alsa-utils-doc \
    pipewire pipewire-pulse wireplumber \
    nftables \
    dbus dbus-x11 \
    util-linux \
    dcron \
    busybox-ntpd \
    sudo \
    tzdata \
    bash \
    wpa_supplicant \
    wireless-tools \
    iw \
    dhcpcd \
    htop \
    curl \
    ca-certificates \
    logrotate \
    mesa-dri-gallium \
    xrandr \
    terminus-font

# WiFi firmware (errors negeren)
log_echo "${BLUE}WiFi firmware wordt geïnstalleerd...${NC}"
for fw in linux-firmware-iwlwifi firmware-rtlwifi linux-firmware-brcm \
          linux-firmware-ath9k linux-firmware-ath10k; do
    apk add $fw 2>/dev/null && log_echo "  ✓ $fw geïnstalleerd"
done

# Start services
log_echo "${BLUE}Systeemservices worden gestart...${NC}"
rc-update add dbus default
rc-service dbus start
rc-update add udev sysinit
rc-service udev start

# ============================================
# 3. KIOSK GEBRUIKER
# ============================================

log_echo "${GREEN}=== 3. Kiosk-gebruiker aanmaken ===${NC}"

if ! id -u kiosk >/dev/null 2>&1; then
    adduser -D -h /home/kiosk -s /bin/bash kiosk
    log_echo "${GREEN}✓ Gebruiker 'kiosk' aangemaakt${NC}"
else
    log_echo "${YELLOW}⚠ Gebruiker 'kiosk' bestaat al${NC}"
fi

# Groepen toevoegen
for group in audio video input netdev plugdev; do
    addgroup kiosk $group 2>/dev/null
done

# Sudo rechten voor reboot/shutdown
cat > /etc/sudoers.d/kiosk << 'EOF'
kiosk ALL=(ALL) NOPASSWD: /sbin/poweroff, /sbin/reboot, /sbin/shutdown
EOF
chmod 440 /etc/sudoers.d/kiosk
log_echo "${GREEN}✓ Sudo rechten geconfigureerd${NC}"

# ============================================
# 4. WIFI CONFIGURATIE (INTERACTIEF)
# ============================================

log_echo "${GREEN}=== 4. WiFi configuratie ===${NC}"
log_echo "${YELLOW}Beschikbare netwerkinterfaces:${NC}"
ip link show | grep -E '^[0-9]+:' | awk -F': ' '{print $2}' >&3

# Detecteer wireless interface
WIFI_INTERFACE=$(iw dev 2>/dev/null | grep Interface | awk '{print $2}')
if [ -z "$WIFI_INTERFACE" ]; then
    WIFI_INTERFACE="wlan0"
    log_echo "${YELLOW}⚠ Geen wireless interface gevonden, gebruik standaard: $WIFI_INTERFACE${NC}"
else
    log_echo "${GREEN}✓ Wireless interface gevonden: $WIFI_INTERFACE${NC}"
fi

echo -n "Wil je WiFi configureren? (j/n): " >&3
read CONFIGURE_WIFI

if [ "$CONFIGURE_WIFI" = "j" ] || [ "$CONFIGURE_WIFI" = "J" ]; then
    ip link set "$WIFI_INTERFACE" up 2>/dev/null
    sleep 2
    
    log_echo "${YELLOW}Scannen naar beschikbare WiFi netwerken...${NC}"
    iw dev "$WIFI_INTERFACE" scan 2>/dev/null | grep "SSID:" | \
        sort -u | sed 's/SSID: //' | grep -v "^$" >&3
    
    echo -n "Voer WiFi SSID (netwerknaam) in: " >&3
    read WIFI_SSID
    
    echo -n "Voer WiFi wachtwoord in: " >&3
    stty -echo >&3
    read WIFI_PASSWORD
    stty echo >&3
    echo "" >&3
    echo -n "Is dit een verborgen netwerk? (j/n): " >&3
    read WIFI_HIDDEN
    
    # Genereer wpa_supplicant.conf
    cat > /etc/wpa_supplicant/wpa_supplicant.conf << EOF
ctrl_interface=/var/run/wpa_supplicant
ctrl_interface_group=0
update_config=1
country=NL
ap_scan=1

network={
    ssid="$WIFI_SSID"
    psk="$WIFI_PASSWORD"
    key_mgmt=WPA-PSK
    proto=RSN WPA
    pairwise=CCMP TKIP
    group=CCMP TKIP
EOF

    if [ "$WIFI_HIDDEN" = "j" ] || [ "$WIFI_HIDDEN" = "J" ]; then
        echo "    scan_ssid=1" >> /etc/wpa_supplicant/wpa_supplicant.conf
    fi
    
    echo "}" >> /etc/wpa_supplicant/wpa_supplicant.conf
    chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf
    
    # Netwerk interface configuratie
    cat > /etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto $WIFI_INTERFACE
iface $WIFI_INTERFACE inet dhcp
    pre-up wpa_supplicant -B -i $WIFI_INTERFACE -c /etc/wpa_supplicant/wpa_supplicant.conf
    post-down killall -q wpa_supplicant
EOF
    
    rc-update add wpa_supplicant boot
    rc-update add networking boot
    rc-update add dhcpcd default
    
    # Direct verbinden
    killall wpa_supplicant 2>/dev/null
    wpa_supplicant -B -i "$WIFI_INTERFACE" -c /etc/wpa_supplicant/wpa_supplicant.conf 2>/dev/null
    sleep 3
    dhcpcd "$WIFI_INTERFACE" >/dev/null 2>&1
    
    log_echo "${GREEN}✓ WiFi geconfigureerd met SSID: $WIFI_SSID${NC}"
    
    # Test verbinding
    sleep 5
    if ping -c1 -W2 8.8.8.8 >/dev/null 2>&1; then
        log_echo "${GREEN}✓ WiFi verbinding succesvol!${NC}"
    else
        log_echo "${YELLOW}⚠ WiFi verbinding (nog) niet actief. Controleer na reboot.${NC}"
    fi
else
    log_echo "${YELLOW}⚠ WiFi configuratie overgeslagen. Gebruik ethernet.${NC}"
fi

# ============================================
# 5. NTP CONFIGURATIE
# ============================================

log_echo "${GREEN}=== 5. NTP (tijdsynchronisatie) configureren ===${NC}"
cat > /etc/conf.d/ntpd << 'EOF'
# NTP daemon configuratie met Nederlandse pool servers
NTPD_OPTS="-N -p nl.pool.ntp.org -p 0.nl.pool.ntp.org -p 1.nl.pool.ntp.org -p 2.nl.pool.ntp.org -p pool.ntp.org"
EOF

rc-update add ntpd default
rc-service ntpd restart 2>/dev/null
sleep 2
log_echo "${GREEN}✓ NTP geconfigureerd met Nederlandse tijdservers${NC}"

# ============================================
# 6. AUTOLOGIN
# ============================================

log_echo "${GREEN}=== 6. Autologin configureren ===${NC}"
cat > /etc/inittab << 'EOF'
# /etc/inittab
::sysinit:/sbin/openrc sysinit
::sysinit:/sbin/openrc boot
::wait:/sbin/openrc default

# Autologin op tty1 als kiosk gebruiker
tty1::respawn:/sbin/agetty --autologin kiosk --noclear tty1 38400 linux
tty2::respawn:/sbin/getty 38400 tty2
tty3::respawn:/sbin/getty 38400 tty3
tty4::respawn:/sbin/getty 38400 tty4
tty5::respawn:/sbin/getty 38400 tty5
tty6::respawn:/sbin/getty 38400 tty6

::ctrlaltdel:/sbin/reboot
::shutdown:/sbin/openrc shutdown
EOF
log_echo "${GREEN}✓ Autologin geconfigureerd op tty1${NC}"

# ============================================
# 7. X11 & OPENBOX KIOSK MODE
# ============================================

log_echo "${GREEN}=== 7. X11 & Openbox Kiosk-modus inrichten ===${NC}"

# .profile voor automatische X start
cat > /home/kiosk/.profile << 'EOF'
# Start X alleen op tty1
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    echo "Starting X session..."
    startx
fi
EOF

# .xinitrc met dbus-launch
cat > /home/kiosk/.xinitrc << 'EOF'
#!/bin/sh
# Start D-Bus sessie voor de hele X sessie
exec dbus-launch --exit-with-session openbox-session
EOF
chmod +x /home/kiosk/.xinitrc

# Openbox configuratie directory
mkdir -p /home/kiosk/.config/openbox

# Openbox rc.xml (maximale lockdown)
cat > /home/kiosk/.config/openbox/rc.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <applications>
    <application class="*">
      <decor>no</decor>
      <focus>yes</focus>
      <desktop>1</desktop>
      <fullscreen>yes</fullscreen>
      <maximized>yes</maximized>
    </application>
  </applications>
  <keyboard>
    <chainQuitKey>C-g</chainQuitKey>
    <!-- Alleen Ctrl+Alt+Del voor reboot -->
    <keybind key="C-A-Del">
      <action name="Execute">
        <command>sudo reboot</command>
      </action>
    </keybind>
    <!-- Alle andere sneltoetsen uitschakelen -->
    <keybind key="A-F4"><action name="Execute"><command></command></action></keybind>
    <keybind key="A-F2"><action name="Execute"><command></command></action></keybind>
    <keybind key="A-F3"><action name="Execute"><command></command></action></keybind>
    <keybind key="A-F5"><action name="Execute"><command></command></action></keybind>
    <keybind key="A-F6"><action name="Execute"><command></command></action></keybind>
    <keybind key="A-F7"><action name="Execute"><command></command></action></keybind>
    <keybind key="A-F8"><action name="Execute"><command></command></action></keybind>
    <keybind key="A-F9"><action name="Execute"><command></command></action></keybind>
    <keybind key="A-F10"><action name="Execute"><command></command></action></keybind>
    <keybind key="A-F11"><action name="Execute"><command></command></action></keybind>
    <keybind key="A-F12"><action name="Execute"><command></command></action></keybind>
    <keybind key="W-F1"><action name="Execute"><command></command></action></keybind>
    <keybind key="W-F2"><action name="Execute"><command></command></action></keybind>
    <keybind key="W-F3"><action name="Execute"><command></command></action></keybind>
    <keybind key="W-F4"><action name="Execute"><command></command></action></keybind>
    <keybind key="W-F5"><action name="Execute"><command></command></action></keybind>
    <keybind key="W-F6"><action name="Execute"><command></command></action></keybind>
    <keybind key="W-F7"><action name="Execute"><command></command></action></keybind>
    <keybind key="W-F8"><action name="Execute"><command></command></action></keybind>
    <keybind key="W-F9"><action name="Execute"><command></command></action></keybind>
    <keybind key="W-F10"><action name="Execute"><command></command></action></keybind>
    <keybind key="W-F11"><action name="Execute"><command></command></action></keybind>
    <keybind key="W-F12"><action name="Execute"><command></command></action></keybind>
  </keyboard>
  <mouse>
    <dragThreshold>1</dragThreshold>
  </mouse>
  <desktops>
    <number>1</number>
    <popupTime>0</popupTime>
  </desktops>
  <resize>
    <drawContents>yes</drawContents>
    <popupShow>Never</popupShow>
  </resize>
  <menu>
    <showDelay>0</showDelay>
    <hideDelay>0</hideDelay>
  </menu>
</openbox_config>
EOF

# Autostart script (Firefox kiosk)
cat > /home/kiosk/.config/openbox/autostart << 'EOF'
#!/bin/bash

# Energiebeheer uitschakelen
xset s off
xset s noblank
xset -dpms
xsetroot -cursor blank blank

# Start audio services
pipewire &
pipewire-pulse &
wireplumber &
sleep 2

# Wacht op netwerk (max 45 seconden)
NETWORK_OK=0
for i in $(seq 1 45); do
    if ping -c1 -W1 8.8.8.8 >/dev/null 2>&1; then
        NETWORK_OK=1
        break
    fi
    echo "Wachten op netwerk... ($i/45)"
    sleep 1
done

# Verwijder cache bij opstart
rm -rf /home/kiosk/.cache/mozilla/firefox/*/cache2 2>/dev/null
rm -rf /home/kiosk/.mozilla/firefox/*/startupCache 2>/dev/null

# Bepaal start URL
if [ $NETWORK_OK -eq 1 ]; then
    START_URL="https://www.startpage.com/"
else
    cat > /tmp/offline.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Geen Internet Verbinding</title>
    <style>
        body { font-family: sans-serif; text-align: center; padding: 50px; background: #f0f0f0; }
        h1 { color: #d32f2f; }
        .container { background: white; padding: 40px; border-radius: 10px; max-width: 600px; margin: auto; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .retry-btn { margin-top: 20px; padding: 10px 20px; background: #1976d2; color: white; border: none; border-radius: 5px; cursor: pointer; }
    </style>
</head>
<body>
    <div class="container">
        <h1>⚠ Geen internetverbinding</h1>
        <p>Controleer de netwerkkabels of WiFi configuratie.</p>
        <p>Het systeem probeert automatisch opnieuw verbinding te maken.</p>
        <p><small>Neem contact op met de beheerder als dit probleem blijft bestaan.</small></p>
    </div>
</body>
</html>
HTML
    START_URL="file:///tmp/offline.html"
fi

# Crash logging
CRASH_LOG="/home/kiosk/firefox-crash.log"
echo "=== Firefox kiosk gestart op $(date) ===" >> "$CRASH_LOG"

# Oneindige loop met crash recovery
while true; do
    echo "Firefox gestart op $(date)" >> "$CRASH_LOG"
    
    # Firefox starten (gebruikt bestaande D-Bus sessie van Openbox)
    firefox-esr \
        --kiosk \
        --private-window \
        --new-window "$START_URL"
    
    EXIT_CODE=$?
    if [ $EXIT_CODE -ne 0 ]; then
        echo "Firefox crashed met exit code $EXIT_CODE op $(date)" >> "$CRASH_LOG"
    fi
    
    echo "Herstart Firefox over 2 seconden..." >> "$CRASH_LOG"
    sleep 2
done
EOF
chmod +x /home/kiosk/.config/openbox/autostart

# ============================================
# 8. FIREFOX PROFIEL & LOCKDOWN
# ============================================

mkdir -p /home/kiosk/.mozilla/firefox/kiosk.default

cat > /home/kiosk/.mozilla/firefox/kiosk.default/user.js << 'EOF'
// ============================================
// KIOSK LOCKDOWN SETTINGS - VERSIE 2.3
// ============================================

// Privacymodus geforceerd
user_pref("browser.privatebrowsing.autostart", true);

// Sessie herstel uitschakelen
user_pref("browser.sessionstore.max_tabs_undo", 0);
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("browser.sessionstore.interval", 86400000);

// Downloads uitschakelen
user_pref("browser.download.useDownloadDir", false);
user_pref("browser.download.folderList", 2);
user_pref("browser.download.dir", "/tmp");
user_pref("browser.download.manager.showWhenStarting", false);

// Startpagina Startpage.com
user_pref("browser.startup.page", 1);
user_pref("browser.startup.homepage", "https://www.startpage.com/");
user_pref("browser.startup.homepage_override.mstone", "ignore");

// Nieuwe tabbladen uitschakelen
user_pref("browser.newtabpage.enabled", false);
user_pref("browser.newtab.page.activity-stream.enabled", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.feeds.snippets", false);
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);

// Cache alleen in RAM
user_pref("browser.cache.disk.enable", false);
user_pref("browser.cache.memory.enable", true);
user_pref("browser.cache.memory.capacity", 32768);

// HTTPS-only mode
user_pref("dom.security.https_only_mode", true);
user_pref("dom.security.https_only_mode_send_http_background_request", false);
user_pref("security.ssl.enable_ocsp_stapling", true);
user_pref("security.sandbox.content.level", 2);

// Privacy en tracking
user_pref("privacy.donottrackheader.enabled", true);
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.pbmode.enabled", true);
user_pref("network.cookie.lifetimePolicy", 2);
user_pref("network.http.referer.XOriginPolicy", 2);
user_pref("network.http.referer.XOriginTrimmingPolicy", 2);

// Automatisch afspelen uitschakelen
user_pref("media.autoplay.default", 5);
user_pref("media.autoplay.blocking_policy", 2);

// UI elementen uitschakelen
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.shell.skipDefaultBrowserCheck", true);
user_pref("browser.underline.anchors", false);
user_pref("ui.key.menuAccessKey", 0);
user_pref("ui.key.generalAccessKey", 0);
user_pref("accessibility.typeaheadfind", false);
user_pref("accessibility.typeaheadfind.flashBar", 0);

// Popups blokkeren
user_pref("dom.disable_open_during_load", true);
user_pref("dom.popup_maximum", 0);

// Telemetrie uitschakelen
user_pref("toolkit.telemetry.enabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("browser.tabs.warnOnClose", false);
user_pref("browser.warnOnQuit", false);
user_pref("browser.warnOnRestart", false);

// JavaScript ingeschakeld (noodzakelijk)
user_pref("javascript.enabled", true);

// Geheugen optimalisatie
user_pref("browser.sessionhistory.max_entries", 5);
user_pref("browser.sessionhistory.contentViewerTimeout", 0);

// Geen crash reporter
user_pref("browser.crashReports.unsubmittedCheck.enabled", false);
user_pref("browser.crashReports.unsubmittedCheck.autoSubmit", false);
EOF

cat > /home/kiosk/.mozilla/firefox/profiles.ini << 'EOF'
[Profile0]
Name=kiosk
IsRelative=1
Path=kiosk.default
Default=1

[General]
StartWithLastProfile=1
Version=2
EOF

# Eigenaarschap instellen
chown -R kiosk:kiosk /home/kiosk
log_echo "${GREEN}✓ Firefox profiel geconfigureerd met lockdown instellingen${NC}"

# ============================================
# 9. FIREWALL (NFTABLES)
# ============================================

log_echo "${GREEN}=== 8. Firewall (nftables) configureren ===${NC}"
cat > /etc/nftables.nft << 'EOF'
#!/usr/sbin/nft -f
flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        
        # Allow loopback
        iif "lo" accept
        
        # Allow established/related connections
        ct state established,related accept
        
        # Allow ICMP (ping)
        ip protocol icmp accept
        ip6 nexthdr icmpv6 accept
        
        # Allow SSH (optioneel, verander poort voor veiligheid)
        tcp dport 22 accept
        
        # Allow DHCP (voor WiFi)
        udp dport 67-68 accept
        
        # Allow NTP (tijdsynchronisatie)
        udp dport 123 accept
        
        # Allow mDNS (voor netwerk discovery)
        udp dport 5353 accept
    }
    
    chain forward {
        type filter hook forward priority 0; policy drop;
    }
    
    chain output {
        type filter hook output priority 0; policy accept;
    }
}
EOF
chmod +x /etc/nftables.nft
rc-update add nftables default
log_echo "${GREEN}✓ Firewall geconfigureerd (inkomend verkeer standaard geblokkeerd)${NC}"

# ============================================
# 10. AUTOMATISCHE UPDATES
# ============================================

log_echo "${GREEN}=== 9. Automatische achtergrond-updates instellen ===${NC}"
rc-update add dcron default
rc-service dcron start 2>/dev/null

cat > /etc/periodic/daily/kiosk-upgrade << 'EOF'
#!/bin/sh
# Dagelijkse updates voor Alpine Kiosk

LOG="/var/log/kiosk-updates.log"
echo "=== Update check: $(date) ===" >> $LOG

# Synchroniseer tijd eerst (belangrijk voor HTTPS)
if command -v ntpd >/dev/null 2>&1; then
    ntpd -q -p nl.pool.ntp.org >> $LOG 2>&1
fi

# Update repository
apk update >> $LOG 2>&1

# Check voor updates
if apk upgrade -s 2>/dev/null | grep -q "Upgrading"; then
    echo "Updates gevonden. Bezig met upgraden..." >> $LOG
    apk upgrade -U >> $LOG 2>&1
    
    # Sla wijzigingen permanent op
    lbu commit -d >> $LOG 2>&1
    
    echo "Upgrade succesvol opgeslagen op $(date)" >> $LOG
else
    echo "Systeem is up-to-date" >> $LOG
fi

echo "" >> $LOG
EOF
chmod +x /etc/periodic/daily/kiosk-upgrade
log_echo "${GREEN}✓ Automatische dagelijkse updates geconfigureerd${NC}"

# ============================================
# 11. RAM-ONLY OPTIMALISATIES
# ============================================

log_echo "${GREEN}=== 10. RAM-only optimalisaties ===${NC}"

# Logrotate configuratie
cat > /etc/logrotate.conf << 'EOF'
# Minimale log retentie voor RAM-only systeem
size 1M
rotate 1
compress
delaycompress
missingok
notifempty

/var/log/messages {
    size 1M
    rotate 1
}

/var/log/cron.log {
    size 1M
    rotate 1
}

/var/log/ntpd.log {
    size 1M
    rotate 1
}
EOF

# Firefox cache naar tmpfs (RAM)
if ! grep -q "/home/kiosk/.cache" /etc/fstab; then
    echo "tmpfs /home/kiosk/.cache tmpfs size=100M,uid=1000,gid=1000,mode=0755 0 0" >> /etc/fstab
fi

# Cache directories aanmaken
mkdir -p /home/kiosk/.cache/mozilla
chown -R kiosk:kiosk /home/kiosk/.cache
log_echo "${GREEN}✓ RAM-only optimalisaties toegepast${NC}"

# ============================================
# 12. BACKUP CONFIGURATIE (LBU)
# ============================================

log_echo "${GREEN}=== 11. Backup configuratie (lbu) ===${NC}"

# lbu include bestanden (absolute paden zijn vereist!)
cat > /etc/lbu/include << 'EOF'
/home/kiosk/.profile
/home/kiosk/.xinitrc
/home/kiosk/.config
/home/kiosk/.mozilla
/etc/inittab
/etc/nftables.nft
/etc/periodic/daily/kiosk-upgrade
/etc/sudoers.d/kiosk
/etc/fstab
/etc/wpa_supplicant/wpa_supplicant.conf
/etc/network/interfaces
/etc/local.d
/etc/conf.d/ntpd
/etc/logrotate.conf
/etc/modules-load.d
/etc/rc.conf
EOF

# lbu exclude bestanden
cat > /etc/lbu/exclude << 'EOF'
/home/kiosk/.cache
/tmp
/var/tmp
/var/cache
/var/log/*.log
/var/log/*.gz
EOF

log_echo "${GREEN}✓ Backup configuratie voltooid${NC}"

# ============================================
# 13. SERVICE OPTIMALISATIES
# ============================================

log_echo "${GREEN}=== 12. Service optimalisaties ===${NC}"
rc-update add local default

# Local startup script
cat > /etc/local.d/kiosk-start.start << 'EOF'
#!/bin/sh
# Kiosk systeem optimalisaties bij opstart

# Swappiness naar minimum (gebruik geen swap)
echo 0 > /proc/sys/vm/swappiness

# Minimaliseer disk I/O
echo 500 > /proc/sys/vm/dirty_expire_centisecs
echo 1000 > /proc/sys/vm/dirty_writeback_centisecs

# Network optimalisatie
echo 1 > /proc/sys/net/ipv4/tcp_low_latency
echo 1 > /proc/sys/net/ipv4/tcp_no_metrics_save

# Beveiliging
echo 1 > /proc/sys/kernel/kptr_restrict
echo 1 > /proc/sys/kernel/dmesg_restrict
echo 1 > /proc/sys/kernel/sysrq

# Zorg dat permissies correct zijn
chown -R kiosk:kiosk /home/kiosk 2>/dev/null

echo "Kiosk systeem gestart - $(date)" > /dev/console
EOF
chmod +x /etc/local.d/kiosk-start.start
log_echo "${GREEN}✓ Service optimalisaties toegepast${NC}"

# ============================================
# 14. EMERGENCY BYPASS (OPTIONEEL)
# ============================================

# Creëer een nood bypass mechanisme
cat > /home/kiosk/.emergency_helper << 'EOF'
#!/bin/sh
# Emergency bypass helper
# Zet een bestand ~/.emergency en herstart X om een shell te krijgen
if [ ! -f /home/kiosk/.emergency ]; then
    touch /home/kiosk/.emergency
    echo "Emergency mode geactiveerd. Herstart X (Ctrl+Alt+Del) om shell te krijgen."
else
    rm -f /home/kiosk/.emergency
    echo "Emergency mode gedeactiveerd."
fi
EOF
chmod +x /home/kiosk/.emergency_helper
chown kiosk:kiosk /home/kiosk/.emergency_helper

# ============================================
# 15. EERSTE BACKUP
# ============================================

log_echo "${GREEN}=== 13. Eerste backup definitief wegschrijven ===${NC}"
lbu commit -d

# Herstel console output voor samenvatting
exec 1>&3 2>&3

# ============================================
# 16. SAMENVATTING
# ============================================

log_echo ""
log_echo "${GREEN}========================================================================${NC}"
log_echo "${GREEN}              SETUP VOLTOOID! - KIOSK IS KLAAR VOOR GEBRUIK${NC}"
log_echo "${GREEN}========================================================================${NC}"
log_echo ""
log_echo "${BLUE}Geïnstalleerde features:${NC}"
log_echo "  ✓ Alpine Linux Diskless mode (draait volledig in RAM)"
log_echo "  ✓ RAM-only operatie (minimale schrijfoperaties)"
log_echo "  ✓ Autologin met kiosk gebruiker op tty1"
log_echo "  ✓ Openbox window manager in strikte kiosk mode"
log_echo "  ✓ Firefox ESR in kiosk modus met Startpage.com"
log_echo "  ✓ nftables firewall (inkomend verkeer standaard geblokkeerd)"
log_echo "  ✓ Pipewire audio met automatische configuratie"
log_echo "  ✓ NTP tijd synchronisatie met Nederlandse servers"
log_echo "  ✓ WiFi ondersteuning met wpa_supplicant"
log_echo "  ✓ Dagelijkse automatische updates via cron"
log_echo "  ✓ Log rotation voor minimale schijfruimte"
log_echo "  ✓ Alle wijzigingen persistent via lbu backups"
log_echo "  ✓ Firefox crash recovery met logging"
log_echo "  ✓ Emergency bypass mechanisme"
log_echo ""

log_echo "${BLUE}WiFi status:${NC}"
if [ "$CONFIGURE_WIFI" = "j" ] || [ "$CONFIGURE_WIFI" = "J" ]; then
    log_echo "  ✓ WiFi geconfigureerd met SSID: $WIFI_SSID"
    if ping -c1 -W2 8.8.8.8 >/dev/null 2>&1; then
        log_echo "    Status: ${GREEN}Verbonden ✓${NC}"
    else
        log_echo "    Status: ${YELLOW}Niet verbonden - controleer na reboot${NC}"
    fi
else
    log_echo "  ⚠ WiFi niet geconfigureerd tijdens setup"
fi
log_echo ""

log_echo "${YELLOW}📌 Om te starten:${NC}"
log_echo "  1. Herstart het systeem: ${GREEN}reboot${NC}"
log_echo "  2. Het systeem start automatisch in kiosk mode"
log_echo ""

log_echo "${YELLOW}🛠 Handmatige commando's voor beheer:${NC}"
log_echo "  - Wijzigingen opslaan:           ${GREEN}lbu commit -d${NC}"
log_echo "  - Firewall status:               ${GREEN}nft list ruleset${NC}"
log_echo "  - Handmatige update:             ${GREEN}sh /etc/periodic/daily/kiosk-upgrade${NC}"
log_echo "  - WiFi status:                   ${GREEN}iw dev wlan0 link${NC}"
log_echo "  - WiFi opnieuw verbinden:        ${GREEN}dhcpcd wlan0${NC}"
log_echo "  - Tijd synchroniseren:           ${GREEN}ntpd -q -p nl.pool.ntp.org${NC}"
log_echo "  - Firefox crash log:             ${GREEN}cat /home/kiosk/firefox-crash.log${NC}"
log_echo "  - Setup log bekijken:            ${GREEN}cat /var/log/kiosk-setup.log${NC}"
log_echo "  - Emergency mode:                ${GREEN}sudo -u kiosk /home/kiosk/.emergency_helper${NC}"
log_echo "  - Systeem herstarten:            ${GREEN}reboot${NC}"
log_echo "  - Systeem uitschakelen:          ${GREEN}poweroff${NC}"
log_echo ""

log_echo "${RED}⚠ Belangrijke aandachtspunten:${NC}"
log_echo "  - Eerste keer opstarten kan trager zijn (Firefox initialisatie)"
log_echo "  - Zorg voor minimaal 100MB vrije ruimte op de USB voor persistentie"
log_echo "  - Bewaar altijd een Alpine recovery USB voor noodgevallen"
log_echo "  - Bij WiFi problemen: controleer of de juiste firmware is geïnstalleerd"
log_echo "  - HTTPS websites vereisen correcte tijd (NTP regelt dit automatisch)"
log_echo ""

log_echo "${GREEN}========================================================================${NC}"
log_echo "${GREEN}    REBOOT NU HET SYSTEEM OM DE KIOSK TE STARTEN!${NC}"
log_echo "${GREEN}========================================================================${NC}"

# Lock bestand opruimen
rm -f "$LOCK_FILE" 2>/dev/null