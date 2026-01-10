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

# Get current MACs from containers (skip empty lines)
NGINX_MAC=$(podman inspect nginx-proxy-manager --format '{{range .NetworkSettings.Networks}}{{.MacAddress}}{{end}}' 2>/dev/null)
PIHOLE_MAC=$(podman inspect pihole --format '{{range .NetworkSettings.Networks}}{{.MacAddress}}{{end}}' 2>/dev/null)

# Add ARP entries if containers exist
if [ ! -z "$NGINX_MAC" ]; then
    sudo ip neigh add 192.168.100.200 lladdr $NGINX_MAC dev $IFACE 2>/dev/null || \
    sudo ip neigh replace 192.168.100.200 lladdr $NGINX_MAC dev $IFACE
    echo "Added ARP route for Nginx: 192.168.100.200 → $NGINX_MAC on $IFACE"
fi

if [ ! -z "$PIHOLE_MAC" ]; then
    sudo ip neigh add 192.168.100.201 lladdr $PIHOLE_MAC dev $IFACE 2>/dev/null || \
    sudo ip neigh replace 192.168.100.201 lladdr $PIHOLE_MAC dev $IFACE
    echo "Added ARP route for Pi-hole: 192.168.100.201 → $PIHOLE_MAC on $IFACE"
fi

exit 0
