#!/bin/sh

###############################################################################
# Freedom Internet + TV PRO bootstrap script voor OPNsense
#
# INSTALLATIE / GEBRUIK:
# 1. Upload dit script naar OPNsense:
#    scp freedom-bootstrap-pro.sh root@opnsense:/tmp/
# 2. Login via SSH:
#    ssh root@opnsense
# 3. Maak het script uitvoerbaar:
#    chmod +x /tmp/freedom-bootstrap-pro.sh
# 4. Voer het script uit:
#    /tmp/freedom-bootstrap-pro.sh
#
# WAT DOET DIT SCRIPT:
# - Backup van config.xml
# - VLAN 6 configuratie (Freedom Internet)
# - VLAN 4 configuratie (TV)
# - PPPoE setup (fake@freedom.nl / 1234)
# - MSS clamping fix (1448)
# - IPv6 DHCPv6 + /48 prefix delegation
# - DHCP/NAT setup voor TV subnet
# - IGMP proxy inschakelen voor TV
# - XML validatie (indien xmllint aanwezig)
# - Config reload + interface restart
# - Automatische reboot
#
# BELANGRIJK:
# - WAN interface moet igb0 zijn
# - LAN interface moet igb1 zijn
# - SSH verbinding gaat weg bij reboot
###############################################################################

set -e

LOG="/var/log/freedom-bootstrap.log"
CONFIG="/conf/config.xml"
BACKUP="/conf/config.xml.bak.$(date +%s)"
TMP="/tmp/config.xml.new"

WAN_IF="igb0"
LAN_IF="igb1"

PPPOE_USER="fake@freedom.nl"
PPPOE_PASS="1234"

# TV VLAN subnet (DHCP)
TV_SUBNET="192.168.100.0/24"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a ${LOG}
}

rollback() {
  log "[!] FOUT GEDTECTEERD - rollback uitvoeren"
  cp ${BACKUP} ${CONFIG}
  configctl system reload
  log "[!] Oude configuratie hersteld"
  exit 1
}

trap rollback ERR

log "[*] Start Freedom + TV PRO bootstrap"

# Backup
log "[*] Backup maken"
cp ${CONFIG} ${BACKUP}

# Temp config
cp ${CONFIG} ${TMP}

### VLAN 6 voor Internet ###
if ! grep -q "<tag>6</tag>" ${TMP}; then
  log "[*] VLAN 6 toevoegen voor Internet"
  sed -i '' '/<vlans>/a\
    <vlan>\
      <if>'${WAN_IF}'</if>\
      <tag>6</tag>\
      <descr>WAN_VLAN6</descr>\
    </vlan>' ${TMP}
fi

### VLAN 4 voor TV ###
if ! grep -q "<tag>4</tag>" ${TMP}; then
  log "[*] VLAN 4 toevoegen voor TV"
  sed -i '' '/<vlans>/a\
    <vlan>\
      <if>'${WAN_IF}'</if>\
      <tag>4</tag>\
      <descr>WAN_VLAN4_TV</descr>\
    </vlan>' ${TMP}
fi

### PPPoE voor VLAN6 ###
if ! grep -q "<ppps>" ${TMP}; then
  log "[*] PPPoE toevoegen"
  sed -i '' '/<\/opnsense>/i\
  <ppps>\
    <ppp>\
      <ptpid>0</ptpid>\
      <type>pppoe</type>\
      <if>'${WAN_IF}'_vlan6</if>\
      <username>'${PPPOE_USER}'</username>\
      <password>'${PPPOE_PASS}'</password>\
      <descr>Freedom PPPoE</descr>\
    </ppp>\
  </ppps>' ${TMP}
fi

# WAN → PPPoE
sed -i '' 's|<if>'${WAN_IF}'</if>|<if>pppoe0</if>|' ${TMP}

### MSS Clamping ###
if ! grep -q "<maxmss>1448</maxmss>" ${TMP}; then
  sed -i '' '/<firewall>/a\
    <scrub>\
      <maxmss>1448</maxmss>\
    </scrub>' ${TMP}
fi

### IPv6 ###
if ! grep -q "<ipaddrv6>dhcp6</ipaddrv6>" ${TMP}; then
  sed -i '' '/<wan>/a\
      <ipaddrv6>dhcp6</ipaddrv6>\
      <dhcp6-ia-pd-len>48</dhcp6-ia-pd-len>' ${TMP}
fi

### TV DHCP/NAT setup (VLAN4) ###
log "[*] DHCP/NAT configuratie voor TV VLAN4"
if ! grep -q "<dhcpd>" ${TMP}; then
  sed -i '' '/<\/opnsense>/i\
  <dhcpd>\
    <lan>\
      <enable>1</enable>\
      <range>'${TV_SUBNET%.*}.10' - '${TV_SUBNET%.*}.200'</range>\
      <interface>'${WAN_IF}'_vlan4</interface>\
    </lan>\
  </dhcpd>' ${TMP}
fi

# IGMP Proxy voor TV
log "[*] IGMP proxy inschakelen"
if ! grep -q "<igmpd>" ${TMP}; then
  sed -i '' '/<\/opnsense>/i\
  <igmpd>\
    <enable>1</enable>\
    <interfaces>\
      <wan>'${WAN_IF}'_vlan4</wan>\
      <lan>'${LAN_IF}'</lan>\
    </interfaces>\
  </igmpd>' ${TMP}
fi

### XML Validatie ###
if command -v xmllint >/dev/null 2>&1; then
  log "[*] XML validatie"
  xmllint --noout ${TMP} || rollback
fi

# Apply config
cp ${TMP} ${CONFIG}
configctl system reload
configctl interface reload all

log "[*] Reboot over 5 seconden"
sleep 5

# Cleanup tijdelijk bestand
rm -f /tmp/freedom-bootstrap-pro.sh

reboot