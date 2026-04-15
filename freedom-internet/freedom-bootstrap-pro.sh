#!/bin/sh
set -e

###############################################################################
# Freedom Internet + TV PRO (FIXED BOOTSTRAP)
###############################################################################

LOG="/var/log/freedom-bootstrap.log"
CONFIG="/conf/config.xml"
BACKUP="/conf/config.xml.bak.$(date +%s)"
TMP="/tmp/config.xml.new"

WAN_IF="igb0"
LAN_IF="igb1"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a $LOG
}

rollback() {
  log "[!] FOUT - rollback"
  cp $BACKUP $CONFIG
  configctl system reload
  exit 1
}

trap rollback ERR

log "[*] Start bootstrap"

cp $CONFIG $BACKUP
cp $CONFIG $TMP

###############################################################################
# VLAN 6 (Internet)
###############################################################################
if ! grep -q "<tag>6</tag>" $TMP; then
  log "[*] VLAN6 toevoegen"
  sed -i '' "/<vlans>/a\\
    <vlan>\\
      <if>${WAN_IF}</if>\\
      <tag>6</tag>\\
      <descr>WAN_VLAN6</descr>\\
    </vlan>" $TMP
fi

###############################################################################
# VLAN 4 (IPTV)
###############################################################################
if ! grep -q "<tag>4</tag>" $TMP; then
  log "[*] VLAN4 toevoegen"
  sed -i '' "/<vlans>/a\\
    <vlan>\\
      <if>${WAN_IF}</if>\\
      <tag>4</tag>\\
      <descr>WAN_VLAN4_TV</descr>\\
    </vlan>" $TMP
fi

###############################################################################
# PPPoE op VLAN6
###############################################################################
if ! grep -q "freedom_pppoe" $TMP; then
  log "[*] PPPoE toevoegen"

  sed -i '' "/<opnsense>/i\\
  <ppps>\\
    <ppp>\\
      <ptpid>0</ptpid>\\
      <type>pppoe</type>\\
      <if>${WAN_IF}_vlan6</if>\\
      <username>fake@freedom.nl</username>\\
      <password>1234</password>\\
      <descr>freedom_pppoe</descr>\\
    </ppp>\\
  </ppps>" $TMP
fi

###############################################################################
# WAN -> PPPoE (belangrijk)
###############################################################################
sed -i '' "s|<if>${WAN_IF}</if>|<if>pppoe0</if>|" $TMP

###############################################################################
# MTU FIX (geen MSS clamp)
###############################################################################
if ! grep -q "<mtu>1510</mtu>" $TMP; then
  log "[*] MTU instellen"
  sed -i '' "/<wan>/a\\
      <mtu>1510</mtu>" $TMP
fi

###############################################################################
# IPv6 (PD /48)
###############################################################################
if ! grep -q "dhcp6" $TMP; then
  log "[*] IPv6 toevoegen"
  sed -i '' "/<wan>/a\\
      <ipaddrv6>dhcp6</ipaddrv6>\\
      <dhcp6-ia-pd-len>48</dhcp6-ia-pd-len>" $TMP
fi

###############################################################################
# VLAN4 DHCP CLIENT OP WAN (BELANGRIJK FIX)
###############################################################################
if ! grep -q "igb0_vlan4_dhcp" $TMP; then
  log "[*] VLAN4 DHCP client toevoegen"

  sed -i '' "/<opnsense>/i\\
  <dhcpd>\\
    <wan_vlan4>\\
      <enable>1</enable>\\
      <interface>${WAN_IF}_vlan4</interface>\\
    </wan_vlan4>\\
  </dhcpd>" $TMP
fi

###############################################################################
# IPTV LAN subnet (simpel + stabiel)
###############################################################################
TV_NET="192.168.100"

if ! grep -q "192.168.100" $TMP; then
  log "[*] IPTV LAN DHCP"

  sed -i '' "/<dhcpd>/a\\
    <lan>\\
      <enable>1</enable>\\
      <range>${TV_NET}.10 ${TV_NET}.200</range>\\
      <interface>${LAN_IF}</interface>\\
    </lan>" $TMP
fi

###############################################################################
# IGMP PROXY (basic correct model)
###############################################################################
if ! grep -q "igmpproxy" $TMP; then
  log "[*] IGMP proxy"

  sed -i '' "/<opnsense>/i\\
  <igmpproxy>\\
    <enable>1</enable>\\
    <interfaces>\\
      <upstream>${WAN_IF}_vlan4</upstream>\\
      <downstream>${LAN_IF}</downstream>\\
    </interfaces>\\
  </igmpproxy>" $TMP
fi

###############################################################################
# VALIDATE
###############################################################################
if command -v xmllint >/dev/null 2>&1; then
  log "[*] XML check"
  xmllint --noout $TMP || rollback
fi

###############################################################################
# APPLY
###############################################################################
cp $TMP $CONFIG

log "[*] Reload config"
configctl system reload
configctl interface reload all

log "[*] Reboot in 5s"
sleep 5
reboot