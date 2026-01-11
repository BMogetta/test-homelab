#!/bin/bash

# Automated Portainer Stack Deployment
# Deploys homelab stack via Portainer API
# Optional - can also deploy manually via Portainer UI

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
PORTAINER_URL="http://192.168.100.200:9000"

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if [ ! -f "$HOMELAB_DIR/compose.yml" ]; then
        log_error "compose.yml not found at $HOMELAB_DIR"
        log_info "Run the setup script first: ./setup.sh"
        exit 1
    fi
    
    if [ ! -f "$HOMELAB_DIR/.env" ]; then
        log_error ".env file not found at $HOMELAB_DIR"
        log_info "Decrypt it first or create one"
        exit 1
    fi
    
    # Check if Portainer is accessible
    if ! curl -s -o /dev/null -w "%{http_code}" "$PORTAINER_URL/api/status" | grep -q "200"; then
        log_error "Portainer not accessible at $PORTAINER_URL"
        log_info "Make sure Portainer is running and accessible"
        exit 1
    fi
    
    log_info "✓ All prerequisites met"
}

# Get Portainer API key
get_api_key() {
    echo ""
    log_warn "=========================================="
    log_warn "Portainer API Key Required"
    log_warn "=========================================="
    echo ""
    log_info "To get your API key:"
    echo "  1. Open Portainer: $PORTAINER_URL"
    echo "  2. Go to: User menu (top right) → My account"
    echo "  3. Scroll to 'Access tokens'"
    echo "  4. Click 'Add access token'"
    echo "  5. Give it a name (e.g., 'homelab-deploy')"
    echo "  6. Copy the token (it's shown only once!)"
    echo ""
    
    read -sp "Paste your Portainer API key: " API_KEY
    echo ""
    
    if [ -z "$API_KEY" ]; then
        log_error "API key is required"
        exit 1
    fi
    
    # Test API key
    if ! curl -s -H "X-API-Key: $API_KEY" "$PORTAINER_URL/api/users/admin/check" | grep -q "message"; then
        log_error "Invalid API key or Portainer connection failed"
        exit 1
    fi
    
    log_info "✓ API key validated"
}

# Get endpoint ID
get_endpoint_id() {
    log_info "Getting Docker endpoint ID..."
    
    ENDPOINT_ID=$(curl -s -H "X-API-Key: $API_KEY" \
      "$PORTAINER_URL/api/endpoints" | \
      grep -o '"Id":[0-9]*' | head -n1 | cut -d: -f2)
    
    if [ -z "$ENDPOINT_ID" ]; then
        log_error "Could not get endpoint ID"
        exit 1
    fi
    
    log_info "✓ Using endpoint ID: $ENDPOINT_ID"
}

# Check if stack exists
check_existing_stack() {
    log_info "Checking for existing stack..."
    
    STACK_EXISTS=$(curl -s -H "X-API-Key: $API_KEY" \
      "$PORTAINER_URL/api/stacks" | \
      grep -o '"Name":"homelab"' || echo "")
    
    if [ ! -z "$STACK_EXISTS" ]; then
        log_warn "Stack 'homelab' already exists"
        read -p "Do you want to update it? (y/N): " update_stack
        
        if [[ ! "$update_stack" =~ ^[Yy]$ ]]; then
            log_info "Deployment cancelled"
            exit 0
        fi
        
        # Get stack ID for update
        STACK_ID=$(curl -s -H "X-API-Key: $API_KEY" \
          "$PORTAINER_URL/api/stacks" | \
          grep -B5 '"Name":"homelab"' | \
          grep -o '"Id":[0-9]*' | cut -d: -f2)
        
        log_info "Will update existing stack (ID: $STACK_ID)"
        UPDATE_MODE=true
    else
        log_info "No existing stack found - will create new"
        UPDATE_MODE=false
    fi
}

# Deploy stack
deploy_stack() {
    log_info "Deploying homelab stack to Portainer..."
    
    if [ "$UPDATE_MODE" = true ]; then
        # Update existing stack
        log_info "Updating stack..."
        
        # Prepare stack file with env vars
        COMPOSE_CONTENT=$(cat "$HOMELAB_DIR/compose.yml")
        ENV_CONTENT=$(cat "$HOMELAB_DIR/.env" | grep -v '^#' | grep -v '^$' | sed 's/^/  - /')
        
        # Create update payload
        cat > /tmp/portainer_update.json << EOF
{
  "stackFileContent": $(echo "$COMPOSE_CONTENT" | jq -Rs .),
  "env": [
$(cat "$HOMELAB_DIR/.env" | grep -v '^#' | grep -v '^$' | while IFS='=' read -r key value; do
    echo "    {\"name\": \"$key\", \"value\": \"$value\"},"
done | sed '$ s/,$//')
  ],
  "prune": false,
  "pullImage": true
}
EOF
        
        RESPONSE=$(curl -s -X PUT \
          -H "X-API-Key: $API_KEY" \
          -H "Content-Type: application/json" \
          -d @/tmp/portainer_update.json \
          "$PORTAINER_URL/api/stacks/$STACK_ID?endpointId=$ENDPOINT_ID")
        
        rm /tmp/portainer_update.json
        
    else
        # Create new stack
        log_info "Creating new stack..."
        
        RESPONSE=$(curl -s -X POST \
          -H "X-API-Key: $API_KEY" \
          -F "Name=homelab" \
          -F "StackFileContent=<$HOMELAB_DIR/compose.yml" \
          -F "Env=<$HOMELAB_DIR/.env" \
          "$PORTAINER_URL/api/stacks?type=2&method=string&endpointId=$ENDPOINT_ID")
    fi
    
    # Check response
    if echo "$RESPONSE" | grep -q '"Id"'; then
        log_info "✓ Stack deployed successfully!"
    else
        log_error "Deployment failed"
        echo "Response: $RESPONSE"
        exit 1
    fi
}

# Configure ARP routes
configure_arp_routes() {
    log_info "Configuring ARP routes..."
    
    if sudo systemctl is-active --quiet macvlan-routes.service; then
        sudo systemctl restart macvlan-routes.service
    else
        sudo systemctl start macvlan-routes.service
    fi
    
    sleep 5
    
    if sudo systemctl is-active --quiet macvlan-routes.service; then
        log_info "✓ ARP routes configured"
    else
        log_warn "macvlan-routes service failed"
        log_info "You may need to configure routes manually"
    fi
}

# Display access info
display_info() {
    # Load network configuration
    BASE_IP=$(cat /opt/homelab/.network_subnet | cut -d'.' -f1-3)
    
    echo ""
    log_info "=========================================="
    log_info "Deployment Complete!"
    log_info "=========================================="
    echo ""
    log_info "Your homelab stack is now running!"
    echo ""
    log_info "Access your services:"
    echo ""
    echo "  Portainer:            http://${BASE_IP}.200:9000"
    echo "  UniFi Controller:     https://${BASE_IP}.201:8443"
    echo "  Nginx Proxy Manager:  http://${BASE_IP}.202:81"
    echo "  Pi-hole:              http://${BASE_IP}.203/admin"
    echo "  Uptime Kuma:          http://${BASE_IP}.204:3001"
    echo "  Home Assistant:       http://${BASE_IP}.205:8123"
    echo "  Stirling PDF:         http://${BASE_IP}.206:8080"
    echo "  Homarr:               http://${BASE_IP}.207:7575"
    echo "  Dozzle:               http://${BASE_IP}.208:8080"
    echo ""
    log_warn "Remember: Access from ANOTHER device (not the Pi itself)"
    echo ""
    log_info "Manage your stack in Portainer:"
    echo "  $PORTAINER_URL → Stacks → homelab"
    echo ""
}

# Main execution
main() {
    log_info "=== Automated Portainer Deployment ==="
    echo ""
    
    check_prerequisites
    echo ""
    get_api_key
    echo ""
    get_endpoint_id
    echo ""
    check_existing_stack
    echo ""
    deploy_stack
    echo ""
    configure_arp_routes
    echo ""
    display_info
}

main "$@"
