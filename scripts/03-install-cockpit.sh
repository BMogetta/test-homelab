#!/bin/bash

# Cockpit Installation Script
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

# Check if Cockpit is installed
check_cockpit() {
    if command -v cockpit-bridge &> /dev/null; then
        log_info "✓ Cockpit already installed"
        return 0
    else
        return 1
    fi
}

# Install Cockpit and cockpit-podman
install_cockpit() {
    log_info "Installing Cockpit and cockpit-podman..."
    
    packages=(
        "cockpit"
        "cockpit-podman"
    )
    
    to_install=()
    
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            to_install+=("$package")
        fi
    done
    
    if [ ${#to_install[@]} -gt 0 ]; then
        sudo apt install -y "${to_install[@]}"
    else
        log_info "✓ All Cockpit packages already installed"
    fi
}

# Enable Cockpit socket
enable_cockpit() {
    log_info "Enabling Cockpit service..."
    
    sudo systemctl enable --now cockpit.socket 2>/dev/null || log_warn "Cockpit socket may already be enabled"
    
    if sudo systemctl is-active --quiet cockpit.socket; then
        log_info "✓ Cockpit is active"
    else
        log_warn "Cockpit socket may not be running yet"
    fi
}

# Configure firewall (if UFW is present)
configure_firewall() {
    if command -v ufw &> /dev/null; then
        log_info "Configuring firewall for Cockpit..."
        
        if sudo ufw status | grep -q "Status: active"; then
            sudo ufw allow 9090/tcp
            log_info "✓ Firewall rule added for port 9090"
        else
            log_info "Firewall not active, skipping"
        fi
    else
        log_info "UFW not installed, skipping firewall configuration"
    fi
}

# Display access information
display_info() {
    log_info "Cockpit installation complete!"
    echo ""
    log_info "Access Cockpit at: https://localhost:9090"
    echo ""
    log_info "Login with your system username and password"
    log_info "Podman containers will be visible in the 'Podman containers' section"
}

# Main execution
main() {
    log_info "=== Cockpit Installation ==="
    
    if ! check_cockpit; then
        install_cockpit
    fi
    
    enable_cockpit
    configure_firewall
    display_info
}

main "$@"
