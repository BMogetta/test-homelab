#!/bin/bash

# Services Deployment Script
# Idempotent - can be run multiple times safely
# All services use macvlan networking (no port mapping)

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

HOMELAB_DIR="$HOME/homelab"

# Cleanup existing containers and networks (idempotent)
cleanup_existing() {
    log_info "Checking for existing containers and networks..."
    
    cd "$HOMELAB_DIR" 2>/dev/null || return 0
    
    if [ -f "compose.yml" ]; then
        log_info "Stopping and removing existing containers..."
        podman-compose down 2>/dev/null || true
        
        # Force remove any stuck containers
        log_info "Cleaning up any remaining containers..."
        podman ps -a --format "{{.Names}}" | grep -E "(nginx-proxy-manager|pihole|unifi|uptime-kuma|homeassistant|stirling-pdf|homarr|dozzle)" | xargs -r podman rm -f 2>/dev/null || true
        
        # Remove macvlan network if it exists
        log_info "Cleaning up networks..."
        podman network rm macvlan_network 2>/dev/null || true
        
        log_info "✓ Cleanup complete"
    else
        log_info "No existing deployment found"
    fi
}

# Detect network configuration
detect_network() {
    log_info "Detecting network configuration..."
    
    # Detect network interface (usually eth0 or wlan0 on Raspberry Pi)
    NETWORK_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
    
    if [ -z "$NETWORK_INTERFACE" ]; then
        log_error "Could not detect network interface automatically"
        log_info "Common interfaces: eth0 (ethernet), wlan0 (wifi), end0 (modern naming)"
        read -p "Enter your network interface name: " NETWORK_INTERFACE
    else
        log_info "Detected network interface: $NETWORK_INTERFACE"
    fi
    
    # Warn about WiFi limitations with macvlan
    if [[ "$NETWORK_INTERFACE" == wlan* ]]; then
        echo ""
        log_warn "=========================================="
        log_warn "WARNING: WiFi detected"
        log_warn "=========================================="
        echo ""
        log_warn "macvlan may not work properly over WiFi due to 802.11 limitations."
        log_warn "Most WiFi adapters do not support multiple MAC addresses."
        echo ""
        log_info "Recommendations:"
        echo "  1. Use Ethernet connection (highly recommended)"
        echo "  2. Or use a router/AP that supports WDS (Wireless Distribution System)"
        echo ""
        read -p "Continue with WiFi anyway? (y/N): " wifi_continue
        if [[ ! "$wifi_continue" =~ ^[Yy]$ ]]; then
            log_info "Setup cancelled. Please connect via Ethernet."
            exit 1
        fi
    fi
    
    # Detect network configuration
    NETWORK_INFO=$(ip -4 addr show "$NETWORK_INTERFACE" | grep inet | head -n1)
    CURRENT_IP=$(echo "$NETWORK_INFO" | awk '{print $2}' | cut -d'/' -f1)
    NETWORK_CIDR=$(echo "$NETWORK_INFO" | awk '{print $2}')
    NETWORK_SUBNET=$(echo "$NETWORK_CIDR" | cut -d'.' -f1-3).0/24
    NETWORK_GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n1)
    
    log_info "Network configuration detected:"
    log_info "  Interface: $NETWORK_INTERFACE"
    log_info "  Current IP: $CURRENT_IP"
    log_info "  Subnet: $NETWORK_SUBNET"
    log_info "  Gateway: $NETWORK_GATEWAY"
    
    echo ""
    log_info "You need to assign static IPs for each container in your network range"
    log_info "Recommended IP range: $(echo "$NETWORK_SUBNET" | cut -d'.' -f1-3).200-250"
    echo ""
    
    # Base IP for calculations
    BASE_IP=$(echo "$NETWORK_SUBNET" | cut -d'.' -f1-3)
    
    # Ask for container IPs
    echo "Please assign IPs for each service:"
    echo ""
    
    read -p "Nginx Proxy Manager (default: ${BASE_IP}.200): " NGINX_IP
    NGINX_IP=${NGINX_IP:-${BASE_IP}.200}
    
    read -p "Pi-hole (default: ${BASE_IP}.201): " PIHOLE_IP
    PIHOLE_IP=${PIHOLE_IP:-${BASE_IP}.201}
    
    read -p "UniFi Controller (default: ${BASE_IP}.202): " UNIFI_IP
    UNIFI_IP=${UNIFI_IP:-${BASE_IP}.202}
    
    read -p "Uptime Kuma (default: ${BASE_IP}.203): " UPTIME_IP
    UPTIME_IP=${UPTIME_IP:-${BASE_IP}.203}
    
    read -p "Home Assistant (default: ${BASE_IP}.204): " HOMEASSISTANT_IP
    HOMEASSISTANT_IP=${HOMEASSISTANT_IP:-${BASE_IP}.204}
    
    read -p "Stirling PDF (default: ${BASE_IP}.205): " STIRLING_IP
    STIRLING_IP=${STIRLING_IP:-${BASE_IP}.205}
    
    read -p "Homarr Dashboard (default: ${BASE_IP}.206): " HOMARR_IP
    HOMARR_IP=${HOMARR_IP:-${BASE_IP}.206}
    
    read -p "Dozzle (default: ${BASE_IP}.207): " DOZZLE_IP
    DOZZLE_IP=${DOZZLE_IP:-${BASE_IP}.207}
    
    echo ""
    log_info "Container IPs configured:"
    log_info "  Nginx Proxy Manager:  $NGINX_IP"
    log_info "  Pi-hole:              $PIHOLE_IP"
    log_info "  UniFi Controller:     $UNIFI_IP"
    log_info "  Uptime Kuma:          $UPTIME_IP"
    log_info "  Home Assistant:       $HOMEASSISTANT_IP"
    log_info "  Stirling PDF:         $STIRLING_IP"
    log_info "  Homarr Dashboard:     $HOMARR_IP"
    log_info "  Dozzle:               $DOZZLE_IP"
    echo ""
    
    # Confirm
    read -p "Are these IPs correct? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Configuration cancelled. Please run setup again."
        exit 1
    fi
}

# Create directory structure
create_directories() {
    log_info "Creating directory structure..."
    
    directories=(
        "$HOMELAB_DIR/unifi/data"
        "$HOMELAB_DIR/unifi/mongodb"
        "$HOMELAB_DIR/pihole/etc-pihole"
        "$HOMELAB_DIR/pihole/etc-dnsmasq.d"
        "$HOMELAB_DIR/nginx-proxy-manager/data"
        "$HOMELAB_DIR/nginx-proxy-manager/letsencrypt"
        "$HOMELAB_DIR/uptime-kuma/data"
        "$HOMELAB_DIR/homeassistant/config"
        "$HOMELAB_DIR/stirling-pdf/data"
        "$HOMELAB_DIR/stirling-pdf/configs"
        "$HOMELAB_DIR/homarr/configs"
        "$HOMELAB_DIR/homarr/icons"
        "$HOMELAB_DIR/homarr/data"
    )
    
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log_info "Created: $dir"
        else
            log_info "✓ Exists: $dir"
        fi
    done
}

# Create .env file
create_env_file() {
    if [ -f "$HOMELAB_DIR/.env" ]; then
        log_info "✓ .env file already exists"
        return
    fi
    
    log_error ".env file not found at $HOMELAB_DIR/.env"
    
    if [ -f "$HOMELAB_DIR/.env.age" ]; then
        log_error ".env.age exists but was not decrypted"
        log_info "Please decrypt it first:"
        echo "  cd ~/homelab"
        echo "  ./scripts/encryption/decrypt-env.sh"
        echo "  Then run setup again"
    else
        log_error "No .env or .env.age found"
        log_info "This repository requires an encrypted .env.age"
    fi
    
    exit 1
}

# Create compose file with full macvlan
create_compose_file() {
    if [ -f "$HOMELAB_DIR/compose.yml" ]; then
        log_warn "compose.yml already exists, backing up..."
        mv "$HOMELAB_DIR/compose.yml" "$HOMELAB_DIR/compose.yml.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    log_info "Creating compose.yml with macvlan networking..."
    
    # Get user UID for Podman socket
    USER_UID=$(id -u)
    
    cat > "$HOMELAB_DIR/compose.yml" << EOF
version: '3.8'

networks:
  macvlan_network:
    driver: macvlan
    driver_opts:
      parent: ${NETWORK_INTERFACE}
    ipam:
      config:
        - subnet: ${NETWORK_SUBNET}
          gateway: ${NETWORK_GATEWAY}

services:
  # Nginx Proxy Manager - Reverse Proxy with Web UI
  nginx-proxy-manager:
    image: docker.io/jc21/nginx-proxy-manager:latest
    container_name: nginx-proxy-manager
    restart: unless-stopped
    networks:
      macvlan_network:
        ipv4_address: ${NGINX_IP}
    volumes:
      - ./nginx-proxy-manager/data:/data
      - ./nginx-proxy-manager/letsencrypt:/etc/letsencrypt
    environment:
      - TZ=\${TZ}

  # Pi-hole - DNS Ad Blocker
  pihole:
    image: docker.io/pihole/pihole:latest
    container_name: pihole
    restart: unless-stopped
    networks:
      macvlan_network:
        ipv4_address: ${PIHOLE_IP}
    environment:
      - TZ=\${TZ}
      - WEBPASSWORD=\${PIHOLE_WEBPASSWORD}
    volumes:
      - ./pihole/etc-pihole:/etc/pihole
      - ./pihole/etc-dnsmasq.d:/etc/dnsmasq.d
    cap_add:
      - NET_ADMIN

  # UniFi Network Application - MongoDB Database
  unifi-db:
    image: docker.io/mongo:4.4
    container_name: unifi-db
    restart: unless-stopped
    networks:
      macvlan_network:
    volumes:
      - ./unifi/mongodb:/data/db
    environment:
      - TZ=\${TZ}
      - MONGO_INITDB_ROOT_USERNAME=\${MONGO_USER}
      - MONGO_INITDB_ROOT_PASSWORD=\${MONGO_PASS}

  # UniFi Network Application - Controller
  unifi-controller:
    image: docker.io/linuxserver/unifi-network-application:latest
    container_name: unifi-controller
    restart: unless-stopped
    depends_on:
      - unifi-db
    networks:
      macvlan_network:
        ipv4_address: ${UNIFI_IP}
    environment:
      - PUID=\${PUID}
      - PGID=\${PGID}
      - TZ=\${TZ}
      - MONGO_USER=\${MONGO_USER}
      - MONGO_PASS=\${MONGO_PASS}
      - MONGO_HOST=unifi-db
      - MONGO_PORT=27017
      - MONGO_DBNAME=\${MONGO_DBNAME}
      - MONGO_AUTHSOURCE=admin
    volumes:
      - ./unifi/data:/config

  # Uptime Kuma - Monitoring
  uptime-kuma:
    image: docker.io/louislam/uptime-kuma:latest
    container_name: uptime-kuma
    restart: unless-stopped
    networks:
      macvlan_network:
        ipv4_address: ${UPTIME_IP}
    volumes:
      - ./uptime-kuma/data:/app/data
    environment:
      - TZ=\${TZ}

  # Home Assistant
  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    restart: unless-stopped
    privileged: true
    networks:
      macvlan_network:
        ipv4_address: ${HOMEASSISTANT_IP}
    volumes:
      - ./homeassistant/config:/config
      - /etc/localtime:/etc/localtime:ro
    environment:
      - TZ=\${TZ}

  # Stirling PDF - PDF Tools
  stirling-pdf:
    image: docker.io/frooodle/s-pdf:latest
    container_name: stirling-pdf
    restart: unless-stopped
    networks:
      macvlan_network:
        ipv4_address: ${STIRLING_IP}
    volumes:
      - ./stirling-pdf/data:/usr/share/tessdata
      - ./stirling-pdf/configs:/configs
    environment:
      - TZ=\${TZ}
      - DOCKER_ENABLE_SECURITY=false

  # Homarr - Modern Dashboard
  homarr:
    image: ghcr.io/ajnart/homarr:latest
    container_name: homarr
    restart: unless-stopped
    networks:
      macvlan_network:
        ipv4_address: ${HOMARR_IP}
    volumes:
      - ./homarr/configs:/app/data/configs
      - ./homarr/icons:/app/public/icons
      - ./homarr/data:/data
    environment:
      - TZ=\${TZ}

  # Dozzle - Real-time logs and resource monitoring
  dozzle:
    image: docker.io/amir20/dozzle:latest
    container_name: dozzle
    restart: unless-stopped
    networks:
      macvlan_network:
        ipv4_address: ${DOZZLE_IP}
    environment:
      - TZ=\${TZ}
    volumes:
      - /run/user/${USER_UID}/podman/podman.sock:/var/run/docker.sock:ro
EOF
    
    log_info "✓ Created compose.yml with full macvlan networking"
}

# Pull images
pull_images() {
    log_info "Pulling container images (this may take a while)..."
    cd "$HOMELAB_DIR"
    
    podman-compose pull || log_warn "Some images may have failed to pull"
}

# Start services
start_services() {
    log_info "Starting services..."
    cd "$HOMELAB_DIR"
    
    log_warn "Ignoring systemd warnings - containers will start correctly"
    echo ""
    
    podman-compose up -d || {
        log_error "Failed to start services"
        log_info "Checking container status..."
        podman ps -a
        return 1
    }
    
    log_info "Services started!"
    
    echo ""
    log_info "Configuring macvlan routes..."
    if sudo systemctl is-active --quiet macvlan-routes.service; then
        log_info "Restarting macvlan-routes service..."
        sudo systemctl restart macvlan-routes.service
    else
        log_info "Starting macvlan-routes service..."
        sudo systemctl start macvlan-routes.service
        sudo systemctl enable macvlan-routes.service
    fi
    
    if sudo systemctl is-active --quiet macvlan-routes.service; then
        log_info "✓ macvlan routes configured"
    else
        log_warn "macvlan-routes service failed to start"
        log_info "You can start it manually: sudo systemctl start macvlan-routes.service"
    fi
}

# Display service info
display_info() {
    echo ""
    log_info "=========================================="
    log_info "Services Deployed Successfully!"
    log_info "=========================================="
    echo ""
    log_info "All services are accessible from ANY device on your network:"
    echo ""
    echo "  Nginx Proxy Manager:  http://${NGINX_IP}:81 (Admin)"
    echo "                        http://${NGINX_IP} (HTTP)"
    echo "                        https://${NGINX_IP} (HTTPS)"
    echo "    Default login: admin@example.com / changeme"
    echo ""
    echo "  Pi-hole:              http://${PIHOLE_IP}/admin"
    echo "    Set this as your DNS server: ${PIHOLE_IP}"
    echo "    Password set in .env file"
    echo ""
    echo "  UniFi Controller:     https://${UNIFI_IP}:8443"
    echo ""
    echo "  Uptime Kuma:          http://${UPTIME_IP}:3001"
    echo ""
    echo "  Home Assistant:       http://${HOMEASSISTANT_IP}:8123"
    echo ""
    echo "  Stirling PDF:         http://${STIRLING_IP}:8080"
    echo ""
    echo "  Homarr Dashboard:     http://${HOMARR_IP}:7575"
    echo ""
    echo "  Dozzle (Logs):        http://${DOZZLE_IP}:8080"
    echo ""
    log_info "Useful commands:"
    echo "  cd ~/homelab"
    echo "  podman ps                      # List containers"
    echo "  podman-compose logs -f         # View logs"
    echo "  podman-compose restart SERVICE # Restart service"
    echo "  podman-compose down            # Stop all"
    echo "  podman-compose up -d           # Start all"
    echo ""
    log_warn "Important macvlan notes:"
    echo "  - All services have their own IPs on your network"
    echo "  - They appear as separate devices on your router"
    echo "  - Access them from any device: phones, tablets, other computers"
    echo "  - To use Pi-hole as DNS, set ${PIHOLE_IP} as DNS server in your router"
    echo "  - The Raspberry Pi itself CANNOT access these IPs directly"
    echo "    (this is a macvlan limitation - use another device to configure them)"
    echo ""
}

# Main execution
main() {
    log_info "=== Services Deployment ==="
    echo ""
    
    cleanup_existing
    echo ""
    detect_network
    echo ""
    create_directories
    echo ""
    create_env_file
    echo ""
    create_compose_file
    echo ""
    pull_images
    echo ""
    start_services
    echo ""
    display_info
}

main "$@"