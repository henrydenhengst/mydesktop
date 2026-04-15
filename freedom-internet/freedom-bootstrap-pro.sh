#!/bin/sh
set -e

#########################################
# CONFIG
#########################################

OPNSENSE_HOST="https://127.0.0.1"
API_KEY="YOUR_API_KEY"
API_SECRET="YOUR_API_SECRET"

WAN_IF="igb0"
LAN_IF="igb1"

VLAN6_TAG="6"
VLAN4_TAG="4"

log() {
  echo "[*] $1"
}

api() {
  curl -sk -u "${API_KEY}:${API_SECRET}" \
    -H "Content-Type: application/json" \
    "$@"
}

#########################################
# 1. VLANs aanmaken
#########################################

log "VLAN6 aanmaken (Internet)"
api -X POST "${OPNSENSE_HOST}/api/interfaces/vlan/add" \
  -d "{
    \"parent\": \"${WAN_IF}\",
    \"tag\": ${VLAN6_TAG},
    \"descr\": \"WAN_VLAN6\"
  }"

log "VLAN4 aanmaken (IPTV)"
api -X POST "${OPNSENSE_HOST}/api/interfaces/vlan/add" \
  -d "{
    \"parent\": \"${WAN_IF}\",
    \"tag\": ${VLAN4_TAG},
    \"descr\": \"WAN_VLAN4_TV\"
  }"

#########################################
# 2. Interfaces toewijzen
#########################################

log "Interfaces toewijzen"

api -X POST "${OPNSENSE_HOST}/api/interfaces/assign" \
  -d '{"device":"pppoe0","enable":true}'

#########################################
# 3. PPPoE op VLAN6
#########################################

log "PPPoE configureren"

api -X POST "${OPNSENSE_HOST}/api/ppps/settings/set" \
  -d "{
    \"ppps\": {
      \"ppp\": [
        {
          \"type\": \"pppoe\",
          \"if\": \"${WAN_IF}_vlan6\",
          \"username\": \"fake@freedom.nl\",
          \"password\": \"1234\",
          \"descr\": \"Freedom PPPoE\"
        }
      ]
    }
  }"

#########################################
# 4. WAN instellingen (MTU FIX)
#########################################

log "WAN MTU instellen"

api -X POST "${OPNSENSE_HOST}/api/interfaces/settings/set" \
  -d "{
    \"interfaces\": {
      \"wan\": {
        \"mtu\": 1510,
        \"ipaddrv6\": \"dhcp6\",
        \"dhcp6-ia-pd-len\": 48
      }
    }
  }"

#########################################
# 5. VLAN4 DHCP (IPTV WAN side fix)
#########################################

log "VLAN4 DHCP client activeren"

api -X POST "${OPNSENSE_HOST}/api/interfaces/settings/set" \
  -d "{
    \"interfaces\": {
      \"wan_vlan4\": {
        \"if\": \"${WAN_IF}_vlan4\",
        \"ipv4\": \"dhcp\"
      }
    }
  }"

#########################################
# 6. LAN DHCP IPTV subnet
#########################################

log "LAN DHCP instellen"

api -X POST "${OPNSENSE_HOST}/api/dhcpd/settings/set" \
  -d "{
    \"lan\": {
      \"enable\": 1,
      \"range\": \"192.168.100.10 192.168.100.200\"
    }
  }"

#########################################
# 7. IGMP proxy (correct model)
#########################################

log "IGMP proxy instellen"

api -X POST "${OPNSENSE_HOST}/api/igmpproxy/settings/set" \
  -d "{
    \"general\": {
      \"enable\": 1
    },
    \"igmp\": {
      \"interfaces\": [
        {
          \"type\": \"upstream\",
          \"name\": \"${WAN_IF}_vlan4\"
        },
        {
          \"type\": \"downstream\",
          \"name\": \"${LAN_IF}\"
        }
      ]
    }
  }"

#########################################
# 8. Apply
#########################################

log "Apply config"

api -X POST "${OPNSENSE_HOST}/api/core/firmware/reconfigure"

log "Klaar. Reboot aanbevolen."