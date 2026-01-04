#!/bin/bash

# Services Deployment Script
# Idempotent - can be run multiple times safely

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

HOMELAB_DIR="$HOME/homelab"

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
        log_warn "compose.yml already exists, skipping creation"
        return
    fi

    # Detect WSL2 and adjust ports
    WSL2_DETECTED=false
    if grep -qi microsoft /proc/version 2>/dev/null; then
        WSL2_DETECTED=true
        log_warn "WSL2 detected - using alternate ports for Pi-hole"
        PIHOLE_DNS_PORT="5353"
        PIHOLE_WEB_PORT="8081"
    else
        PIHOLE_DNS_PORT="53"
        PIHOLE_WEB_PORT="8080"
    fi
    
    log_info "Creating compose.yml..."
    
    cat > "$HOMELAB_DIR/compose.yml" << 'EOF'
version: '3.8'

services:
  # Nginx Proxy Manager - Reverse Proxy with Web UI
  nginx-proxy-manager:
    image: docker.io/jc21/nginx-proxy-manager:latest
    container_name: nginx-proxy-manager
    restart: unless-stopped
    ports:
      - "80:80"
      - "81:81"
      - "443:443"
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
      - "$PIHOLE_DNS_PORT:53/tcp"
      - "$PIHOLE_DNS_PORT:53/udp"
      - "$PIHOLE_WEB_PORT:80/tcp"
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
      - "8443:8443"   # Web UI
      - "3478:3478/udp"  # STUN
      - "10001:10001/udp"  # AP discovery
      - "8080:8080"   # Device communication
      - "1900:1900/udp"  # L2 discovery
      - "8843:8843"   # Guest portal HTTPS
      - "8880:8880"   # Guest portal HTTP
      - "6789:6789"   # Mobile speed test
      - "5514:5514/udp"  # Remote syslog

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
      - "8082:8080"
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
EOF
    
    if [ "$WSL2_DETECTED" = true ]; then
        log_warn "Pi-hole configured for WSL2:"
        log_warn "  - DNS: localhost:$PIHOLE_DNS_PORT"
        log_warn "  - Web: http://localhost:$PIHOLE_WEB_PORT/admin"
    fi
    
    log_info "✓ Created compose.yml"
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
    podman-compose up -d
    
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
    echo "  Nginx Proxy Manager:  http://localhost:81"
    echo "    Default login: admin@example.com / changeme"
    echo ""
    echo "  Pi-hole:              http://localhost:8080/admin"
    echo "    Password set in .env file"
    echo ""
    echo "  UniFi Controller:     https://localhost:8443"
    echo "    Follow setup wizard on first run"
    echo ""
    echo "  Uptime Kuma:          http://localhost:3001"
    echo "    Create admin account on first run"
    echo ""
    echo "  Home Assistant:       http://localhost:8123"
    echo "    Follow setup wizard on first run"
    echo ""
    echo "  Stirling PDF:         http://localhost:8082"
    echo ""
    echo "  Homarr Dashboard:     http://localhost:7575"
    echo "    Create admin account on first run"
    echo ""
    echo "  Dozzle (Logs):        http://localhost:8888"
    echo ""
    log_info "Configuration directory: $HOMELAB_DIR"
    echo ""
    log_info "Useful commands:"
    echo "  cd ~/homelab"
    echo "  podman-compose ps              # List containers"
    echo "  podman-compose logs -f         # View logs"
    echo "  podman-compose restart SERVICE # Restart service"
    echo "  podman-compose down            # Stop all services"
    echo "  podman-compose up -d           # Start all services"
    echo ""
    log_warn "IMPORTANT: WSL2 users may need additional configuration."
    log_warn "Check TROUBLESHOOTING.md for WSL2-specific fixes."
    echo ""
}

# Main execution
main() {
    log_info "=== Services Deployment ==="
    
    create_directories
    create_env_file
    create_compose_file
    pull_images
    start_services
    display_info
}

main "$@"
