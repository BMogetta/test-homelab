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
    
    # Apply immediately (will be lost on restart, persisted via wsl.conf)
    sudo sysctl -w net.ipv4.ip_unprivileged_port_start=53
    
    log_info "✓ Unprivileged ports configured (ports 53+ allowed)"
    log_info "  (Will be persisted via /etc/wsl.conf)"
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
    
    # Check if [boot] section exists
    if ! sudo grep -q "^\[boot\]" /etc/wsl.conf; then
        # No [boot] section, add everything
        echo "" | sudo tee -a /etc/wsl.conf > /dev/null
        echo "[boot]" | sudo tee -a /etc/wsl.conf > /dev/null
        echo "systemd=true" | sudo tee -a /etc/wsl.conf > /dev/null
        echo 'command="sysctl -w net.ipv4.ip_unprivileged_port_start=53"' | sudo tee -a /etc/wsl.conf > /dev/null
        log_info "✓ Added boot configuration to /etc/wsl.conf"
    else
        # [boot] section exists, check what's missing
        
        # Check if systemd=true exists
        if ! sudo grep -q "^systemd=true" /etc/wsl.conf; then
            sudo sed -i '/^\[boot\]/a systemd=true' /etc/wsl.conf
            log_info "✓ Added systemd=true to [boot] section"
        fi
        
        # Check if command line exists
        if ! sudo grep -q '^command=' /etc/wsl.conf; then
            # Add command after the [boot] section
            sudo sed -i '/^\[boot\]/a command="sysctl -w net.ipv4.ip_unprivileged_port_start=53"' /etc/wsl.conf
            log_info "✓ Added sysctl command to [boot] section"
        else
            # Command exists, check if it has our sysctl
            if ! sudo grep -q 'ip_unprivileged_port_start=53' /etc/wsl.conf; then
                log_warn "command= exists but doesn't set ip_unprivileged_port_start"
                log_warn "Current command: $(sudo grep '^command=' /etc/wsl.conf)"
                log_warn "You may need to manually add: sysctl -w net.ipv4.ip_unprivileged_port_start=53"
            else
                log_info "✓ Boot configuration already correct"
            fi
        fi
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
    display_summary
    
    log_info "WSL2 fixes complete!"
    log_warn "Remember to restart WSL (wsl --shutdown from PowerShell)"
}

main "$@"
