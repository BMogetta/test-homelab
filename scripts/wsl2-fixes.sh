#!/bin/bash

# WSL2 Fixes for Podman
# This script applies necessary fixes for running Podman in WSL2
# NOT needed for Raspberry Pi or native Linux installations

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

# Check if running in WSL2
check_wsl() {
    if ! grep -qi microsoft /proc/version; then
        log_error "This script is only for WSL2"
        log_error "You're running native Linux - these fixes are not needed!"
        exit 1
    fi
    log_info "Detected WSL2 environment"
}

# Fix 1: Configure Podman for WSL2 networking
configure_podman_networking() {
    log_info "Configuring Podman networking for WSL2..."
    
    mkdir -p ~/.config/containers
    
    if [ -f ~/.config/containers/containers.conf ]; then
        log_warn "containers.conf already exists, backing up..."
        cp ~/.config/containers/containers.conf ~/.config/containers/containers.conf.backup
    fi
    
    cat > ~/.config/containers/containers.conf << 'EOF'
[engine]
cgroup_manager = "cgroupfs"
events_logger = "file"

[network]
network_backend = "netavark"
firewall_driver = "none"
EOF
    
    log_info "✓ Podman networking configured"
}

# Fix 2: Allow unprivileged ports starting from 53
configure_unprivileged_ports() {
    log_info "Configuring unprivileged port access..."
    
    # Check current value
    current_port=$(sysctl -n net.ipv4.ip_unprivileged_port_start 2>/dev/null || echo "1024")
    
    if [ "$current_port" = "53" ]; then
        log_info "✓ Unprivileged ports already configured (start: 53)"
        return
    fi
    
    # Add to sysctl.conf if not already there
    if ! grep -q "net.ipv4.ip_unprivileged_port_start" /etc/sysctl.conf; then
        echo "net.ipv4.ip_unprivileged_port_start=53" | sudo tee -a /etc/sysctl.conf
        log_info "Added to /etc/sysctl.conf"
    fi
    
    # Apply immediately
    sudo sysctl -w net.ipv4.ip_unprivileged_port_start=53
    
    log_info "✓ Unprivileged ports configured (ports 53+ allowed)"
}

# Fix 3: Configure WSL to persist sysctl settings
configure_wsl_conf() {
    log_info "Configuring WSL persistent settings..."
    
    if [ ! -f /etc/wsl.conf ]; then
        sudo touch /etc/wsl.conf
    fi
    
    # Backup existing wsl.conf
    if [ -s /etc/wsl.conf ]; then
        sudo cp /etc/wsl.conf /etc/wsl.conf.backup
        log_info "Backed up existing /etc/wsl.conf"
    fi
    
    # Check if boot section exists
    if ! sudo grep -q "^\[boot\]" /etc/wsl.conf; then
        echo "" | sudo tee -a /etc/wsl.conf
        echo "[boot]" | sudo tee -a /etc/wsl.conf
        echo "systemd=true" | sudo tee -a /etc/wsl.conf
        echo 'command="sysctl -w net.ipv4.ip_unprivileged_port_start=53"' | sudo tee -a /etc/wsl.conf
        log_info "✓ Added boot configuration to /etc/wsl.conf"
    else
        log_warn "/etc/wsl.conf already has [boot] section"
        log_warn "Manually add: command=\"sysctl -w net.ipv4.ip_unprivileged_port_start=53\""
    fi
}

# Fix 4: Adjust Pi-hole ports for WSL2 (optional)
adjust_pihole_ports() {
    log_warn "Pi-hole Port Configuration"
    echo ""
    echo "In WSL2, port 53 might conflict with Windows DNS services."
    echo "You have two options:"
    echo ""
    echo "  1. Keep default ports (53, 8080) - Recommended for testing compatibility"
    echo "  2. Change to alternate ports (5353, 8081) - If you have conflicts"
    echo ""
    read -p "Change Pi-hole ports? (y/N): " response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        if [ -f ~/homelab/compose.yml ]; then
            log_info "Backing up compose.yml..."
            cp ~/homelab/compose.yml ~/homelab/compose.yml.backup
            
            log_info "Updating Pi-hole ports..."
            sed -i 's/"53:53\/tcp"/"5353:53\/tcp"/' ~/homelab/compose.yml
            sed -i 's/"53:53\/udp"/"5353:53\/udp"/' ~/homelab/compose.yml
            sed -i 's/"8080:80\/tcp"/"8081:80\/tcp"/' ~/homelab/compose.yml
            
            log_info "✓ Pi-hole ports changed to 5353 (DNS) and 8081 (Web)"
            log_info "Access Pi-hole at: http://localhost:8081/admin"
        else
            log_warn "~/homelab/compose.yml not found, skipping"
        fi
    else
        log_info "Keeping default Pi-hole ports"
    fi
}

# Display summary
display_summary() {
    echo ""
    log_info "=========================================="
    log_info "WSL2 Fixes Applied Successfully!"
    log_info "=========================================="
    echo ""
    log_info "Changes made:"
    echo "  ✓ Podman networking configured for WSL2"
    echo "  ✓ Unprivileged ports allowed from port 53"
    echo "  ✓ WSL boot configuration updated"
    echo ""
    log_warn "IMPORTANT: You must restart WSL for all changes to take effect"
    echo ""
    log_info "To restart WSL:"
    echo "  1. Exit this terminal (type 'exit')"
    echo "  2. Open PowerShell and run: wsl --shutdown"
    echo "  3. Restart WSL: wsl -d Debian"
    echo ""
    log_info "After restart, verify with:"
    echo "  sysctl net.ipv4.ip_unprivileged_port_start"
    echo "  (should show: net.ipv4.ip_unprivileged_port_start = 53)"
    echo ""
}

# Main execution
main() {
    log_info "=== WSL2 Fixes for Podman ==="
    echo ""
    
    check_wsl
    configure_podman_networking
    configure_unprivileged_ports
    configure_wsl_conf
    adjust_pihole_ports
    display_summary
    
    log_info "WSL2 fixes complete!"
    log_warn "Remember to restart WSL (wsl --shutdown from PowerShell)"
}

main "$@"
