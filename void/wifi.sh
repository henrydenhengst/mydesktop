#!/bin/bash
# wifi.sh - Robuuste WiFi setup voor Void Linux Live ISO

SSID="hoh1a"
PASS="nasimix!"

echo "--- WiFi Architect Scan ---"

# 1. Zoek de draadloze interface via sysfs (meest betrouwbaar)
IFACE=$(ls /sys/class/net | while read -r dev; do
    [ -d "/sys/class/net/$dev/wireless" ] && echo "$dev" && break
done)

# 2. Fallback: Zoek naar namen die met 'wl' beginnen
if [ -z "$IFACE" ]; then
    IFACE=$(ip link | awk -F': ' '/wl/ {print $2}' | head -n1)
fi

# 3. Check of we iets gevonden hebben
if [ -z "$IFACE" ]; then
    echo "FOUT: Geen WiFi-interface gevonden!"
    echo "Mogelijke oorzaken: Broadcom kaart zonder driver of hardware switch staat uit."
    ip link
    exit 1
fi

echo "Gevonden interface: $IFACE"

# 4. Zorg dat de interface 'up' is
sudo ip link set "$IFACE" up

# 5. Genereer configuratie en start verbinding
echo "Verbinden met $SSID..."
sudo wpa_passphrase "$SSID" "$PASS" | sudo tee "/etc/wpa_supplicant/wpa_supplicant-$IFACE.conf" > /dev/null
sudo wpa_supplicant -B -i "$IFACE" -c "/etc/wpa_supplicant/wpa_supplicant-$IFACE.conf"

# 6. Verkrijg IP adres via DHCP
echo "IP-adres aanvragen..."
sudo dhcpcd "$IFACE"

# 7. Controleer verbinding
sleep 3
if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
    echo "--- VERBINDING GESLAAGD! ---"
    ip addr show "$IFACE" | grep "inet "
else
    echo "--- VERBINDING MISLUKT ---"
    echo "Check je wachtwoord of DHCP-instellingen."
    exit 1
fi
