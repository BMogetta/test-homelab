#!/bin/bash
# Setup macvlan ARP routes for containers
# Auto-detects eth0 or wlan0

# Wait for network to be ready
sleep 10

# Auto-detect primary network interface (prefer eth0, fallback to wlan0)
if ip link show eth0 &>/dev/null && ip addr show eth0 | grep -q "inet "; then
    IFACE="eth0"
elif ip link show wlan0 &>/dev/null && ip addr show wlan0 | grep -q "inet "; then
    IFACE="wlan0"
else
    echo "No active network interface found"
    exit 1
fi

echo "Using network interface: $IFACE"

# Enable proxy ARP
sudo sysctl -w net.ipv4.conf.$IFACE.proxy_arp=1

# Wait for containers to start
sleep 20

# Array of containers and their IPs
declare -A CONTAINERS=(
    ["nginx-proxy-manager"]="192.168.0.200"
    ["pihole"]="192.168.0.201"
    ["unifi-controller"]="192.168.0.202"
    ["uptime-kuma"]="192.168.0.203"
    ["homeassistant"]="192.168.0.204"
    ["stirling-pdf"]="192.168.0.205"
    ["homarr"]="192.168.0.206"
    ["dozzle"]="192.168.0.207"
)

# Configure ARP routes for all containers
for container in "${!CONTAINERS[@]}"; do
    IP="${CONTAINERS[$container]}"
    MAC=$(podman inspect "$container" --format '{{range .NetworkSettings.Networks}}{{.MacAddress}}{{end}}' 2>/dev/null)
    
    if [ ! -z "$MAC" ]; then
        sudo ip neigh add "$IP" lladdr "$MAC" dev "$IFACE" 2>/dev/null || \
        sudo ip neigh replace "$IP" lladdr "$MAC" dev "$IFACE"
        echo "Added ARP route for $container: $IP → $MAC on $IFACE"
    fi
done

exit 0