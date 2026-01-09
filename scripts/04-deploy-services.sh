#!/bin/bash

# Services Deployment Script
# Idempotent - can be run multiple times safely
# Now with improved macvlan support and cleanup

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

# Detect environment
detect_environment() {
    WSL2_DETECTED=false
    NETWORK_INTERFACE=""
    NETWORK_SUBNET=""
    NETWORK_GATEWAY=""
    
    if grep -qi microsoft /proc/version 2>/dev/null; then
        WSL2_DETECTED=true
        log_warn "WSL2 detected - macvlan not supported, using port remapping"
    else
        log_info "Physical/VM environment detected - macvlan will be used"
        
        # Try to detect network interface (usually eth0 or wlan0 on Raspberry Pi)
        NETWORK_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
        
        if [ -z "$NETWORK_INTERFACE" ]; then
            log_error "Could not detect network interface automatically"
            log_info "Common interfaces: eth0 (ethernet), wlan0 (wifi)"
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
            echo "  2. Or accept that macvlan might not work and use port mapping instead"
            echo ""
            read -p "Continue with WiFi anyway? (y/N): " wifi_continue
            if [[ ! "$wifi_continue" =~ ^[Yy]$ ]]; then
                log_info "Setup cancelled. Please connect via Ethernet or configure for port mapping."
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
        log_warn "You need to assign static IPs for containers in your network range"
        log_info "Recommended IP range: $(echo "$NETWORK_SUBNET" | cut -d'.' -f1-3).200-250"
        echo ""
        
        # Ask for container IPs
        read -p "Enter IP for Nginx Proxy Manager (default: $(echo "$NETWORK_SUBNET" | cut -d'.' -f1-3).200): " NGINX_IP
        NGINX_IP=${NGINX_IP:-$(echo "$NETWORK_SUBNET" | cut -d'.' -f1-3).200}
        
        read -p "Enter IP for Pi-hole (default: $(echo "$NETWORK_SUBNET" | cut -d'.' -f1-3).201): " PIHOLE_IP
        PIHOLE_IP=${PIHOLE_IP:-$(echo "$NETWORK_SUBNET" | cut -d'.' -f1-3).201}
        
        log_info "Container IPs configured:"
        log_info "  Nginx Proxy Manager: $NGINX_IP"
        log_info "  Pi-hole: $PIHOLE_IP"
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
    
    # If .env doesn't exist, something is wrong
    log_error ".env file not found at $HOMELAB_DIR/.env"
    
    if [ -f "$HOMELAB_DIR/.env.age" ]; then
        log_error ".env.age exists but was not decrypted"
        log_info "Please decrypt it first:"
        echo "  cd ~/test-homelab"
        echo "  ./scripts/decrypt-env.sh"
        echo "  Then run setup again"
    else
        log_error "No .env or .env.age found"
        log_info "This repository requires an encrypted .env.age"
        log_info "If this is a fresh repository setup, you need to:"
        echo "  1. Create .env manually with your credentials"
        echo "  2. Encrypt it: ./scripts/encrypt-env.sh"
        echo "  3. Commit .env.age to repository"
    fi
    
    exit 1
}

# Create compose file
create_compose_file() {
    if [ -f "$HOMELAB_DIR/compose.yml" ]; then
        log_warn "compose.yml already exists, backing up..."
        mv "$HOMELAB_DIR/compose.yml" "$HOMELAB_DIR/compose.yml.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    log_info "Creating compose.yml..."
    
    if [ "$WSL2_DETECTED" = true ]; then
        create_compose_wsl2
    else
        create_compose_macvlan
    fi
    
    log_info "✓ Created compose.yml"
}

# Create compose file for WSL2 (port remapping)
create_compose_wsl2() {
    cat > "$HOMELAB_DIR/compose.yml" << 'EOF'
version: '3.8'

services:
  # Nginx Proxy Manager - Reverse Proxy with Web UI
  nginx-proxy-manager:
    image: docker.io/jc21/nginx-proxy-manager:latest
    container_name: nginx-proxy-manager
    restart: unless-stopped
    ports:
      - "8080:80"      # HTTP on 8080 instead of 80
      - "81:81"        # Admin UI
      - "8443:443"     # HTTPS on 8443 instead of 443
    volumes:
      - ./nginx-proxy-manager/data:/data
      - ./nginx-proxy-manager/letsencrypt:/etc/letsencrypt
    environment:
      - TZ=${TZ}

  # Pi-hole - DNS Ad Blocker
  pihole:
    image: docker.io/pihole/pihole:latest
    container_name: pihole
    restart: unless-stopped
    ports:
      - "5353:53/tcp"  # DNS on 5353 instead of 53
      - "5353:53/udp"
      - "8081:80/tcp"  # Web UI on 8081
    environment:
      - TZ=${TZ}
      - WEBPASSWORD=${PIHOLE_WEBPASSWORD}
    volumes:
      - ./pihole/etc-pihole:/etc/pihole
      - ./pihole/etc-dnsmasq.d:/etc/dnsmasq.d
    cap_add:
      - NET_ADMIN

  # UniFi Network Application
  unifi-db:
    image: docker.io/mongo:4.4
    container_name: unifi-db
    restart: unless-stopped
    volumes:
      - ./unifi/mongodb:/data/db
    environment:
      - TZ=${TZ}
      - MONGO_INITDB_ROOT_USERNAME=${MONGO_USER}
      - MONGO_INITDB_ROOT_PASSWORD=${MONGO_PASS}

  unifi-controller:
    image: docker.io/linuxserver/unifi-network-application:latest
    container_name: unifi-controller
    restart: unless-stopped
    depends_on:
      - unifi-db
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
      - MONGO_USER=${MONGO_USER}
      - MONGO_PASS=${MONGO_PASS}
      - MONGO_HOST=unifi-db
      - MONGO_PORT=27017
      - MONGO_DBNAME=${MONGO_DBNAME}
      - MONGO_AUTHSOURCE=admin
    volumes:
      - ./unifi/data:/config
    ports:
      - "8444:8443"    # Changed from 8443 to avoid conflict
      - "3478:3478/udp"
      - "10001:10001/udp"
      - "8082:8080"    # Changed from 8080 to avoid conflict
      - "1900:1900/udp"
      - "8843:8843"
      - "8880:8880"
      - "6789:6789"
      - "5514:5514/udp"

  # Uptime Kuma - Monitoring
  uptime-kuma:
    image: docker.io/louislam/uptime-kuma:latest
    container_name: uptime-kuma
    restart: unless-stopped
    volumes:
      - ./uptime-kuma/data:/app/data
    ports:
      - "3001:3001"
    environment:
      - TZ=${TZ}

  # Home Assistant
  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    restart: unless-stopped
    privileged: true
    network_mode: host
    volumes:
      - ./homeassistant/config:/config
      - /etc/localtime:/etc/localtime:ro
    environment:
      - TZ=${TZ}

  # Stirling PDF - PDF Tools
  stirling-pdf:
    image: docker.io/frooodle/s-pdf:latest
    container_name: stirling-pdf
    restart: unless-stopped
    ports:
      - "8083:8080"
    volumes:
      - ./stirling-pdf/data:/usr/share/tessdata
      - ./stirling-pdf/configs:/configs
    environment:
      - TZ=${TZ}
      - DOCKER_ENABLE_SECURITY=false

  # Homarr - Modern Dashboard
  homarr:
    image: ghcr.io/ajnart/homarr:latest
    container_name: homarr
    restart: unless-stopped
    ports:
      - "7575:7575"
    volumes:
      - ./homarr/configs:/app/data/configs
      - ./homarr/icons:/app/public/icons
      - ./homarr/data:/data
    environment:
      - TZ=${TZ}

  # Dozzle - Real-time logs and resource monitoring
  dozzle:
    image: docker.io/amir20/dozzle:latest
    container_name: dozzle
    restart: unless-stopped
    ports:
      - "8888:8080"
    environment:
      - TZ=${TZ}
    volumes:
      - /run/user/1000/podman/podman.sock:/var/run/docker.sock:ro
EOF
    
    log_warn "WSL2 configuration created with remapped ports"
}

# Create compose file for Raspberry Pi/Physical (macvlan)
create_compose_macvlan() {
    cat > "$HOMELAB_DIR/compose.yml" << EOF
version: '3.8'

networks:
  default:
    driver: bridge
  
  macvlan_network:
    driver: macvlan
    driver_opts:
      parent: ${NETWORK_INTERFACE}
    ipam:
      config:
        - subnet: ${NETWORK_SUBNET}
          gateway: ${NETWORK_GATEWAY}

services:
  # Nginx Proxy Manager - Reverse Proxy with Web UI (with macvlan)
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

  # Pi-hole - DNS Ad Blocker (with macvlan)
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

  # UniFi Network Application
  unifi-db:
    image: docker.io/mongo:4.4
    container_name: unifi-db
    restart: unless-stopped
    volumes:
      - ./unifi/mongodb:/data/db
    environment:
      - TZ=\${TZ}
      - MONGO_INITDB_ROOT_USERNAME=\${MONGO_USER}
      - MONGO_INITDB_ROOT_PASSWORD=\${MONGO_PASS}

  unifi-controller:
    image: docker.io/linuxserver/unifi-network-application:latest
    container_name: unifi-controller
    restart: unless-stopped
    depends_on:
      - unifi-db
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
    ports:
      - "8443:8443"
      - "3478:3478/udp"
      - "10001:10001/udp"
      - "8080:8080"
      - "1900:1900/udp"
      - "8843:8843"
      - "8880:8880"
      - "6789:6789"
      - "5514:5514/udp"

  # Uptime Kuma - Monitoring
  uptime-kuma:
    image: docker.io/louislam/uptime-kuma:latest
    container_name: uptime-kuma
    restart: unless-stopped
    volumes:
      - ./uptime-kuma/data:/app/data
    ports:
      - "3001:3001"
    environment:
      - TZ=\${TZ}

  # Home Assistant
  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    restart: unless-stopped
    privileged: true
    network_mode: host
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
    ports:
      - "8082:8080"
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
    ports:
      - "7575:7575"
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
    ports:
      - "8888:8080"
    environment:
      - TZ=\${TZ}
    volumes:
      - /run/user/1000/podman/podman.sock:/var/run/docker.sock:ro
EOF
    
    log_info "Macvlan configuration created"
}

# Pull images
pull_images() {
    log_info "Pulling container images (this may take a while)..."
    cd "$HOMELAB_DIR"
    
    log_warn "You may see 'systemd user session' warnings - these are harmless"
    echo ""
    
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
}

# Display service info
display_info() {
    echo ""
    log_info "=========================================="
    log_info "Services Deployed Successfully!"
    log_info "=========================================="
    echo ""
    log_info "Access your services at:"
    echo ""
    
    if [ "$WSL2_DETECTED" = true ]; then
        cat << 'EOF'
  Homarr Dashboard:     http://localhost:7575
  Dozzle (Logs):        http://localhost:8888
  Nginx Proxy Manager:  http://localhost:81
                        HTTP: http://localhost:8080
                        HTTPS: https://localhost:8443
    Default login: admin@example.com / changeme

  Pi-hole:              http://localhost:8081/admin
    DNS: localhost:5353
    Password set in .env file

  UniFi Controller:     https://localhost:8444
  Uptime Kuma:          http://localhost:3001
  Home Assistant:       http://localhost:8123
  Stirling PDF:         http://localhost:8083
EOF
    else
        cat << EOF
  Homarr Dashboard:     http://localhost:7575
  Dozzle (Logs):        http://localhost:8888
  
  === Macvlan Services (accessible from any device on your network) ===
  Nginx Proxy Manager:  http://${NGINX_IP}:81 (Admin)
                        http://${NGINX_IP} (HTTP)
                        https://${NGINX_IP} (HTTPS)
    Default login: admin@example.com / changeme

  Pi-hole:              http://${PIHOLE_IP}/admin
    Set this as your DNS server: ${PIHOLE_IP}
    Password set in .env file

  === Bridge Network Services (accessible from Raspberry Pi) ===
  UniFi Controller:     https://localhost:8443
  Uptime Kuma:          http://localhost:3001
  Home Assistant:       http://localhost:8123
  Stirling PDF:         http://localhost:8082
EOF
    fi
    
    echo ""
    log_info "Useful commands:"
    echo "  cd ~/homelab"
    echo "  podman ps                      # List containers"
    echo "  podman-compose logs -f         # View logs"
    echo "  podman-compose restart SERVICE # Restart service"
    echo "  podman-compose down            # Stop all"
    echo "  podman-compose up -d           # Start all"
    echo ""
    
    if [ "$WSL2_DETECTED" = false ]; then
        log_warn "Important notes about macvlan:"
        echo "  - Nginx and Pi-hole have their own IPs on your network"
        echo "  - Access them from any device: http://${NGINX_IP} and http://${PIHOLE_IP}"
        echo "  - They will appear as separate devices on your router"
        echo "  - To use Pi-hole as DNS, set ${PIHOLE_IP} as DNS server in your router"
        echo ""
    fi
}

# Main execution
main() {
    log_info "=== Services Deployment ==="
    echo ""
    
    cleanup_existing
    echo ""
    detect_environment
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
