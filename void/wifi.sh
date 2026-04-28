#!/bin/bash
# wifi.sh - Automatische WiFi setup voor Repair Café

# Zoek de naam van de draadloze interface (begint meestal met 'wl')
IFACE=$(ip link | awk '/state UP/ || /wlan/ || /wlp/ {print $2}' | tr -d ':' | head -n1)

if [ -z "$IFACE" ]; then
    echo "Geen WiFi interface gevonden!"
    exit 1
fi

echo "Verbinden via interface: $IFACE"

sudo wpa_passphrase "hoh1a" "nasimix!" | sudo tee /etc/wpa_supplicant/wpa_supplicant-$IFACE.conf
sudo wpa_supplicant -B -i "$IFACE" -c /etc/wpa_supplicant/wpa_supplicant-$IFACE.conf
sudo dhcpcd "$IFACE"

echo "Wachten op IP-adres..."
sleep 5
ping -c 3 google.com
