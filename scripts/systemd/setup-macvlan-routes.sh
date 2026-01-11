#!/bin/bash
# Setup macvlan ARP routes for Docker containers
# Auto-detects eth0 or wlan0
# Updated for new IP scheme with Portainer

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

# Get base IP from network configuration
if [ -f /opt/homelab/.network_subnet ]; then
    NETWORK_SUBNET=$(cat /opt/homelab/.network_subnet)
    BASE_IP=$(echo "$NETWORK_SUBNET" | cut -d'.' -f1-3)
else
    # Fallback to default
    BASE_IP="192.168.100"
fi

echo "Using base IP: $BASE_IP"

# Array of containers and their IPs
declare -A CONTAINERS=(
    ["portainer"]="${BASE_IP}.200"
    ["unifi-controller"]="${BASE_IP}.201"
    ["nginx-proxy-manager"]="${BASE_IP}.202"
    ["pihole"]="${BASE_IP}.203"
    ["uptime-kuma"]="${BASE_IP}.204"
    ["homeassistant"]="${BASE_IP}.205"
    ["stirling-pdf"]="${BASE_IP}.206"
    ["homarr"]="${BASE_IP}.207"
    ["dozzle"]="${BASE_IP}.208"
)

# Configure ARP routes for all containers
for container in "${!CONTAINERS[@]}"; do
    IP="${CONTAINERS[$container]}"
    
    # Check if container exists and is running
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        MAC=$(docker inspect "$container" --format '{{range .NetworkSettings.Networks}}{{.MacAddress}}{{end}}' 2>/dev/null)
        
        if [ ! -z "$MAC" ]; then
            sudo ip neigh add "$IP" lladdr "$MAC" dev "$IFACE" 2>/dev/null || \
            sudo ip neigh replace "$IP" lladdr "$MAC" dev "$IFACE"
            echo "Added ARP route for $container: $IP → $MAC on $IFACE"
        else
            echo "Warning: Could not get MAC for $container"
        fi
    else
        echo "Container $container not running, skipping"
    fi
done

exit 0
