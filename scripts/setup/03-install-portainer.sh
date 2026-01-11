#!/bin/bash

# Portainer Installation Script
# Idempotent - can be run multiple times safely
# Installs Portainer with macvlan on 192.168.100.200

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Portainer is already running
check_portainer() {
    if docker ps | grep -q portainer; then
        log_info "✓ Portainer already running"
        docker ps | grep portainer
        return 0
    else
        return 1
    fi
}

# Detect network configuration
detect_network() {
    log_info "Detecting network configuration..."
    
    # Detect network interface
    NETWORK_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
    
    if [ -z "$NETWORK_INTERFACE" ]; then
        log_error "Could not detect network interface automatically"
        log_info "Common interfaces: eth0 (ethernet), wlan0 (wifi)"
        read -p "Enter your network interface name: " NETWORK_INTERFACE
    else
        log_info "Detected network interface: $NETWORK_INTERFACE"
    fi
    
    # Get network info
    NETWORK_INFO=$(ip -4 addr show "$NETWORK_INTERFACE" | grep inet | head -n1)
    CURRENT_IP=$(echo "$NETWORK_INFO" | awk '{print $2}' | cut -d'/' -f1)
    NETWORK_CIDR=$(echo "$NETWORK_INFO" | awk '{print $2}')
    NETWORK_SUBNET=$(echo "$NETWORK_CIDR" | cut -d'.' -f1-3).0/24
    NETWORK_GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n1)
    
    # Portainer IP
    BASE_IP=$(echo "$NETWORK_SUBNET" | cut -d'.' -f1-3)
    PORTAINER_IP="${BASE_IP}.200"
    
    log_info "Network configuration:"
    log_info "  Interface: $NETWORK_INTERFACE"
    log_info "  Subnet: $NETWORK_SUBNET"
    log_info "  Gateway: $NETWORK_GATEWAY"
    log_info "  Portainer IP: $PORTAINER_IP"
    echo ""
    
    # Save for later use
    echo "$NETWORK_INTERFACE" > /opt/homelab/.network_interface
    echo "$NETWORK_SUBNET" > /opt/homelab/.network_subnet
    echo "$NETWORK_GATEWAY" > /opt/homelab/.network_gateway
    echo "$PORTAINER_IP" > /opt/homelab/.portainer_ip
}

# Create macvlan network for Portainer
create_macvlan() {
    log_info "Creating macvlan network for Portainer..."
    
    # Remove existing network if it exists
    if docker network ls | grep -q portainer_macvlan; then
        log_info "Removing existing portainer_macvlan network..."
        docker network rm portainer_macvlan 2>/dev/null || true
    fi
    
    # Create macvlan network
    docker network create -d macvlan \
      --subnet="$NETWORK_SUBNET" \
      --gateway="$NETWORK_GATEWAY" \
      -o parent="$NETWORK_INTERFACE" \
      portainer_macvlan
    
    log_info "✓ macvlan network created"
}

# Install Portainer
install_portainer() {
    log_info "Installing Portainer..."
    
    # Create Portainer data directory
    sudo mkdir -p /opt/portainer/data
    sudo chown -R $USER:$USER /opt/portainer
    
    # Stop and remove existing Portainer if it exists
    docker stop portainer 2>/dev/null || true
    docker rm portainer 2>/dev/null || true
    
    # Run Portainer with macvlan
    docker run -d \
      --name=portainer \
      --restart=unless-stopped \
      --network=portainer_macvlan \
      --ip="$PORTAINER_IP" \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v /opt/portainer/data:/data \
      portainer/portainer-ce:latest
    
    log_info "✓ Portainer started"
}

# Configure ARP route for Portainer
configure_arp_route() {
    log_info "Configuring ARP route for Portainer..."
    
    # Wait for container to get MAC address
    sleep 5
    
    # Get Portainer MAC address
    PORTAINER_MAC=$(docker inspect portainer --format '{{range .NetworkSettings.Networks}}{{.MacAddress}}{{end}}')
    
    if [ ! -z "$PORTAINER_MAC" ]; then
        sudo ip neigh add "$PORTAINER_IP" lladdr "$PORTAINER_MAC" dev "$NETWORK_INTERFACE" 2>/dev/null || \
        sudo ip neigh replace "$PORTAINER_IP" lladdr "$PORTAINER_MAC" dev "$NETWORK_INTERFACE"
        
        log_info "✓ ARP route configured: $PORTAINER_IP → $PORTAINER_MAC"
    else
        log_warn "Could not get Portainer MAC address"
    fi
}

# Display access information
display_info() {
    echo ""
    log_info "=========================================="
    log_info "Portainer Installation Complete!"
    log_info "=========================================="
    echo ""
    log_info "Access Portainer at: http://$PORTAINER_IP:9000"
    echo ""
    log_info "First-time setup:"
    echo "  1. Open http://$PORTAINER_IP:9000 in your browser"
    echo "  2. Create an admin account"
    echo "  3. Select 'Docker' as the environment"
    echo "  4. Click 'Connect'"
    echo ""
    log_info "After setup, you can deploy your homelab stack:"
    echo "  1. Go to 'Stacks' in Portainer"
    echo "  2. Click 'Add stack'"
    echo "  3. Upload or paste your docker-compose.yml"
    echo "  4. Set environment variables from .env file"
    echo "  5. Click 'Deploy the stack'"
    echo ""
    log_warn "Note: Access Portainer from ANOTHER device (not the Pi itself)"
    log_info "This is a macvlan limitation - use phone, laptop, or desktop"
    echo ""
}

# Main execution
main() {
    log_info "=== Portainer Installation ==="
    echo ""
    
    if ! check_portainer; then
        detect_network
        echo ""
        create_macvlan
        echo ""
        install_portainer
        echo ""
        configure_arp_route
    fi
    
    display_info
}

main "$@"
