#!/bin/bash

# Services Deployment Script
# Creates docker-compose.yml with proper IP assignments
# All services use macvlan networking

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

HOMELAB_DIR="/opt/homelab"

# Load network configuration
load_network_config() {
    if [ -f "$HOMELAB_DIR/.network_interface" ]; then
        NETWORK_INTERFACE=$(cat "$HOMELAB_DIR/.network_interface")
        NETWORK_SUBNET=$(cat "$HOMELAB_DIR/.network_subnet")
        NETWORK_GATEWAY=$(cat "$HOMELAB_DIR/.network_gateway")
        
        log_info "Loaded network configuration:"
        log_info "  Interface: $NETWORK_INTERFACE"
        log_info "  Subnet: $NETWORK_SUBNET"
        log_info "  Gateway: $NETWORK_GATEWAY"
    else
        log_error "Network configuration not found"
        log_error "Please run Portainer installation first"
        exit 1
    fi
}

# Create directory structure
create_directories() {
    log_info "Creating directory structure in /opt..."
    
    directories=(
        "/opt/unifi/data"
        "/opt/unifi/mongodb"
        "/opt/pihole/etc-pihole"
        "/opt/pihole/etc-dnsmasq.d"
        "/opt/nginx-proxy-manager/data"
        "/opt/nginx-proxy-manager/letsencrypt"
        "/opt/uptime-kuma/data"
        "/opt/homeassistant/config"
        "/opt/stirling-pdf/data"
        "/opt/stirling-pdf/configs"
        "/opt/homarr/configs"
        "/opt/homarr/icons"
        "/opt/homarr/data"
    )
    
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            sudo mkdir -p "$dir"
            log_info "Created: $dir"
        else
            log_info "✓ Exists: $dir"
        fi
    done
    
    # Set permissions
    sudo chown -R $USER:$USER /opt/unifi
    sudo chown -R $USER:$USER /opt/nginx-proxy-manager
    sudo chown -R $USER:$USER /opt/uptime-kuma
    sudo chown -R $USER:$USER /opt/homeassistant
    sudo chown -R $USER:$USER /opt/stirling-pdf
    sudo chown -R $USER:$USER /opt/homarr
    
    log_info "✓ Permissions set"
}

# Create MongoDB init script
create_mongo_init_script() {
    log_info "Creating MongoDB initialization script..."
    
    cat > /opt/unifi/init-mongo.sh << 'EOF'
#!/bin/bash
if which mongosh > /dev/null 2>&1; then
  mongo_init_bin='mongosh'
else
  mongo_init_bin='mongo'
fi
"${mongo_init_bin}" <<MONGOEOF
use ${MONGO_AUTHSOURCE}
db.auth("${MONGO_INITDB_ROOT_USERNAME}", "${MONGO_INITDB_ROOT_PASSWORD}")
db.createUser({
  user: "${MONGO_USER}",
  pwd: "${MONGO_PASS}",
  roles: [
    { db: "${MONGO_DBNAME}", role: "dbOwner" },
    { db: "${MONGO_DBNAME}_stat", role: "dbOwner" },
    { db: "${MONGO_DBNAME}_audit", role: "dbOwner" }
  ]
})
MONGOEOF
EOF
    
    chmod +x /opt/unifi/init-mongo.sh
    log_info "✓ MongoDB init script created"
}

# Check if .env exists
check_env_file() {
    if [ -f "$HOMELAB_DIR/.env" ]; then
        log_info "✓ .env file exists"
        return 0
    fi
    
    log_error ".env file not found at $HOMELAB_DIR/.env"
    
    if [ -f "$HOMELAB_DIR/.env.age" ]; then
        log_error ".env.age exists but was not decrypted"
        log_info "Please decrypt it first and run setup again"
    else
        log_error "No .env or .env.age found"
    fi
    
    exit 1
}

# Create docker-compose.yml
create_compose_file() {
    if [ -f "$HOMELAB_DIR/compose.yml" ]; then
        log_warn "compose.yml already exists, backing up..."
        mv "$HOMELAB_DIR/compose.yml" "$HOMELAB_DIR/compose.yml.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    log_info "Creating compose.yml with macvlan networking..."
    
    # Get base IP from subnet
    BASE_IP=$(echo "$NETWORK_SUBNET" | cut -d'.' -f1-3)
    
    cat > "$HOMELAB_DIR/compose.yml" << EOF
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
  # UniFi Network Application - MongoDB Database (MongoDB 7.0)
  unifi-db:
    image: docker.io/mongo:7.0
    container_name: unifi-db
    restart: unless-stopped
    networks:
      macvlan_network:
    volumes:
      - /opt/unifi/mongodb:/data/db
      - /opt/unifi/init-mongo.sh:/docker-entrypoint-initdb.d/init-mongo.sh:ro
    environment:
      - TZ=\${TZ}
      - MONGO_INITDB_ROOT_USERNAME=root
      - MONGO_INITDB_ROOT_PASSWORD=\${MONGO_ROOT_PASS}
      - MONGO_USER=\${MONGO_USER}
      - MONGO_PASS=\${MONGO_PASS}
      - MONGO_DBNAME=\${MONGO_DBNAME}
      - MONGO_AUTHSOURCE=admin

  # UniFi Network Application - Controller (IP: ${BASE_IP}.201)
  unifi-controller:
    image: docker.io/linuxserver/unifi-network-application:latest
    container_name: unifi-controller
    restart: unless-stopped
    depends_on:
      - unifi-db
    networks:
      macvlan_network:
        ipv4_address: ${BASE_IP}.201
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
      - /opt/unifi/data:/config

  # Nginx Proxy Manager - Reverse Proxy (IP: ${BASE_IP}.202)
  nginx-proxy-manager:
    image: docker.io/jc21/nginx-proxy-manager:latest
    container_name: nginx-proxy-manager
    restart: unless-stopped
    networks:
      macvlan_network:
        ipv4_address: ${BASE_IP}.202
    volumes:
      - /opt/nginx-proxy-manager/data:/data
      - /opt/nginx-proxy-manager/letsencrypt:/etc/letsencrypt
    environment:
      - TZ=\${TZ}

  # Pi-hole - DNS Ad Blocker (IP: ${BASE_IP}.203)
  pihole:
    image: docker.io/pihole/pihole:latest
    container_name: pihole
    restart: unless-stopped
    networks:
      macvlan_network:
        ipv4_address: ${BASE_IP}.203
    environment:
      - TZ=\${TZ}
      - WEBPASSWORD=\${PIHOLE_WEBPASSWORD}
    volumes:
      - /opt/pihole/etc-pihole:/etc/pihole
      - /opt/pihole/etc-dnsmasq.d:/etc/dnsmasq.d
    cap_add:
      - NET_ADMIN

  # Uptime Kuma - Monitoring (IP: ${BASE_IP}.204)
  uptime-kuma:
    image: docker.io/louislam/uptime-kuma:latest
    container_name: uptime-kuma
    restart: unless-stopped
    networks:
      macvlan_network:
        ipv4_address: ${BASE_IP}.204
    volumes:
      - /opt/uptime-kuma/data:/app/data
    environment:
      - TZ=\${TZ}

  # Home Assistant (IP: ${BASE_IP}.205)
  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    restart: unless-stopped
    privileged: true
    networks:
      macvlan_network:
        ipv4_address: ${BASE_IP}.205
    volumes:
      - /opt/homeassistant/config:/config
      - /etc/localtime:/etc/localtime:ro
    environment:
      - TZ=\${TZ}

  # Stirling PDF - PDF Tools (IP: ${BASE_IP}.206)
  stirling-pdf:
    image: docker.io/frooodle/s-pdf:latest
    container_name: stirling-pdf
    restart: unless-stopped
    networks:
      macvlan_network:
        ipv4_address: ${BASE_IP}.206
    volumes:
      - /opt/stirling-pdf/data:/usr/share/tessdata
      - /opt/stirling-pdf/configs:/configs
    environment:
      - TZ=\${TZ}
      - DOCKER_ENABLE_SECURITY=false

  # Homarr - Dashboard (IP: ${BASE_IP}.207)
  homarr:
    image: ghcr.io/ajnart/homarr:latest
    container_name: homarr
    restart: unless-stopped
    networks:
      macvlan_network:
        ipv4_address: ${BASE_IP}.207
    volumes:
      - /opt/homarr/configs:/app/data/configs
      - /opt/homarr/icons:/app/public/icons
      - /opt/homarr/data:/data
    environment:
      - TZ=\${TZ}

  # Dozzle - Logs Viewer (IP: ${BASE_IP}.208)
  dozzle:
    image: docker.io/amir20/dozzle:latest
    container_name: dozzle
    restart: unless-stopped
    networks:
      macvlan_network:
        ipv4_address: ${BASE_IP}.208
    environment:
      - TZ=\${TZ}
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
EOF
    
    log_info "✓ Created compose.yml"
    
    # Display IP assignments
    echo ""
    log_info "Service IP Assignments:"
    echo "  Portainer:            ${BASE_IP}.200:9000"
    echo "  UniFi Controller:     ${BASE_IP}.201:8443"
    echo "  Nginx Proxy Manager:  ${BASE_IP}.202:81 (admin), :80/:443 (proxy)"
    echo "  Pi-hole:              ${BASE_IP}.203/admin"
    echo "  Uptime Kuma:          ${BASE_IP}.204:3001"
    echo "  Home Assistant:       ${BASE_IP}.205:8123"
    echo "  Stirling PDF:         ${BASE_IP}.206:8080"
    echo "  Homarr Dashboard:     ${BASE_IP}.207:7575"
    echo "  Dozzle:               ${BASE_IP}.208:8080"
    echo ""
}

# Display deployment instructions
display_instructions() {
    BASE_IP=$(echo "$NETWORK_SUBNET" | cut -d'.' -f1-3)
    
    echo ""
    log_info "=========================================="
    log_info "Docker Compose File Created!"
    log_info "=========================================="
    echo ""
    log_info "File location: $HOMELAB_DIR/compose.yml"
    echo ""
    log_info "DEPLOYMENT OPTIONS:"
    echo ""
    log_info "Option 1: Deploy via Portainer (Recommended)"
    echo "  1. Access Portainer: http://${BASE_IP}.200:9000"
    echo "  2. Go to 'Stacks' → 'Add stack'"
    echo "  3. Name it: 'homelab'"
    echo "  4. Upload the compose.yml file OR paste its contents"
    echo "  5. Add environment variables from .env file"
    echo "  6. Click 'Deploy the stack'"
    echo ""
    log_info "Option 2: Deploy via command line"
    echo "  cd /opt/homelab"
    echo "  docker compose up -d"
    echo ""
    log_warn "IMPORTANT: Access all services from ANOTHER device"
    log_info "Due to macvlan limitations, the Pi cannot access these IPs"
    log_info "Use a phone, laptop, or desktop to configure services"
    echo ""
    log_info "After deployment, configure ARP routes:"
    echo "  sudo systemctl restart macvlan-routes.service"
    echo ""
}

# Main execution
main() {
    log_info "=== Services Deployment Preparation ==="
    echo ""
    
    load_network_config
    echo ""
    check_env_file
    echo ""
    create_directories
    echo ""
    create_mongo_init_script
    echo ""
    create_compose_file
    echo ""
    display_instructions
}

main "$@"
