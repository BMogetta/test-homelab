#!/bin/bash

# Cockpit Installation Script
# Idempotent - can be run multiple times safely
# Compatible with Debian, DietPi, and WSL2

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

# Detect environment
detect_environment() {
    WSL2_DETECTED=false
    SYSTEMD_AVAILABLE=false
    
    if grep -qi microsoft /proc/version 2>/dev/null; then
        WSL2_DETECTED=true
        log_warn "WSL2 environment detected"
    fi
    
    if command -v systemctl &> /dev/null && systemctl --version &> /dev/null; then
        SYSTEMD_AVAILABLE=true
        log_info "systemd is available"
    else
        log_warn "systemd not available or not fully functional"
    fi
}

# Check if Cockpit is installed
check_cockpit() {
    if command -v cockpit-bridge &> /dev/null; then
        log_info "✓ Cockpit already installed: $(dpkg -l | grep cockpit | head -n1 | awk '{print $3}')"
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
        log_info "Installing: ${to_install[*]}"
        
        # Try to install
        if sudo apt install -y "${to_install[@]}"; then
            log_info "✓ Cockpit packages installed successfully"
        else
            log_error "Failed to install Cockpit packages"
            log_info "Checking if packages are available..."
            sudo apt-cache search cockpit | grep -E "^cockpit" || true
            return 1
        fi
    else
        log_info "✓ All Cockpit packages already installed"
    fi
}

# Enable Cockpit socket
enable_cockpit() {
    if [ "$SYSTEMD_AVAILABLE" = false ]; then
        log_warn "systemd not available - cannot enable Cockpit socket automatically"
        log_info "You may need to start Cockpit manually or configure your init system"
        return 0
    fi
    
    log_info "Enabling Cockpit service..."
    
    # Try to enable and start the socket
    if sudo systemctl enable cockpit.socket 2>&1 | grep -v "Created symlink"; then
        log_info "✓ Cockpit socket enabled"
    else
        log_warn "Cockpit socket may already be enabled"
    fi
    
    if sudo systemctl start cockpit.socket 2>&1; then
        log_info "✓ Cockpit socket started"
    else
        log_warn "Could not start Cockpit socket"
    fi
    
    # Verify status
    if sudo systemctl is-active --quiet cockpit.socket; then
        log_info "✓ Cockpit is active and running"
    else
        log_warn "Cockpit socket is not active"
        log_info "Status: $(sudo systemctl status cockpit.socket --no-pager -l | head -n 5)"
    fi
}

# Configure firewall (if UFW is present)
configure_firewall() {
    if command -v ufw &> /dev/null; then
        log_info "Configuring firewall for Cockpit..."
        
        if sudo ufw status | grep -q "Status: active"; then
            if sudo ufw allow 9090/tcp; then
                log_info "✓ Firewall rule added for port 9090"
            else
                log_warn "Could not add firewall rule"
            fi
        else
            log_info "Firewall not active, skipping"
        fi
    else
        log_info "UFW not installed, skipping firewall configuration"
    fi
}

# Check if Cockpit is accessible
test_cockpit() {
    log_info "Testing Cockpit accessibility..."
    
    # Wait a moment for the service to be ready
    sleep 2
    
    # Try to connect to Cockpit
    if curl -k -s -o /dev/null -w "%{http_code}" https://localhost:9090 2>/dev/null | grep -qE "200|401"; then
        log_info "✓ Cockpit is accessible"
        return 0
    else
        log_warn "Cockpit may not be accessible yet"
        log_info "This is normal if the service is still starting"
        return 1
    fi
}

# Display access information
display_info() {
    echo ""
    log_info "=========================================="
    log_info "Cockpit Installation Complete!"
    log_info "=========================================="
    echo ""
    log_info "Access Cockpit at: https://localhost:9090"
    echo ""
    log_info "Login credentials:"
    echo "  - Username: Your system username ($(whoami))"
    echo "  - Password: Your system password"
    echo ""
    log_info "Podman containers will be visible in the 'Podman containers' section"
    echo ""
    
    if [ "$WSL2_DETECTED" = true ]; then
        log_warn "WSL2 Note:"
        echo "  - Access from Windows: https://localhost:9090"
        echo "  - Make sure Windows Firewall allows the connection"
    fi
    
    if [ "$SYSTEMD_AVAILABLE" = false ]; then
        log_warn "systemd not available:"
        echo "  - Cockpit may need manual starting"
        echo "  - Check your system's init documentation"
    fi
    
    echo ""
    log_info "Useful commands:"
    echo "  sudo systemctl status cockpit.socket    # Check status"
    echo "  sudo systemctl restart cockpit.socket   # Restart Cockpit"
    echo "  sudo journalctl -u cockpit -f           # View logs"
}

# Main execution
main() {
    log_info "=== Cockpit Installation ==="
    echo ""
    
    detect_environment
    echo ""
    
    if ! check_cockpit; then
        install_cockpit || {
            log_error "Cockpit installation failed"
            exit 1
        }
    fi
    
    echo ""
    enable_cockpit
    echo ""
    configure_firewall
    echo ""
    test_cockpit || true  # Don't fail if test fails
    
    display_info
}

main "$@"
