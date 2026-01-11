#!/bin/bash

# System Preparation Script
# Idempotent - can be run multiple times safely
# Supports: Debian, DietPi

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

# Detect if DietPi
is_dietpi() {
    [ -f /boot/dietpi/.hw_model ] || [ -f /boot/dietpi.txt ]
}

# Update package lists
update_system() {
    log_info "Updating package lists..."
    sudo apt update -qq
}

# Install essential packages (only if not already installed)
install_essentials() {
    log_info "Installing essential packages..."
    
    packages=(
        "curl"
        "wget"
        "git"
        "nano"
        "vim"
        "htop"
        "net-tools"
        "ca-certificates"
        "gnupg"
        "lsb-release"
        "apt-transport-https"
        "arping"
    )
    
    to_install=()
    
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            to_install+=("$package")
        else
            log_info "✓ $package already installed"
        fi
    done
    
    if [ ${#to_install[@]} -gt 0 ]; then
        log_info "Installing: ${to_install[*]}"
        sudo apt install -y "${to_install[@]}"
    else
        log_info "All essential packages already installed"
    fi
}

# Install age (encryption tool)
install_age() {
    if command -v age &> /dev/null; then
        log_info "✓ age already installed: $(age --version 2>&1 | head -n1)"
        return 0
    fi
    
    log_info "Installing age..."
    
    # Try to install from apt first
    if sudo apt install -y age 2>/dev/null; then
        log_info "✓ age installed from apt repository"
        return 0
    fi
    
    log_warn "age not available in apt, installing from GitHub releases..."
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            AGE_ARCH="amd64"
            ;;
        aarch64|arm64)
            AGE_ARCH="arm64"
            ;;
        armv7l|armv6l)
            AGE_ARCH="armv7"
            ;;
        *)
            log_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    
    # Get latest version
    AGE_VERSION=$(curl -s https://api.github.com/repos/FiloSottile/age/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$AGE_VERSION" ]; then
        log_error "Could not determine latest age version"
        exit 1
    fi
    
    log_info "Downloading age ${AGE_VERSION} for ${AGE_ARCH}..."
    
    # Download and install
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"
    
    wget -q "https://github.com/FiloSottile/age/releases/download/${AGE_VERSION}/age-${AGE_VERSION}-linux-${AGE_ARCH}.tar.gz"
    
    tar xzf "age-${AGE_VERSION}-linux-${AGE_ARCH}.tar.gz"
    
    sudo install -m 755 "age/age" /usr/local/bin/
    sudo install -m 755 "age/age-keygen" /usr/local/bin/
    
    cd - > /dev/null
    rm -rf "$TMP_DIR"
    
    if command -v age &> /dev/null; then
        log_info "✓ age installed successfully: $(age --version 2>&1 | head -n1)"
    else
        log_error "age installation failed"
        exit 1
    fi
}

# Configure timezone
configure_timezone() {
    target_tz="America/Argentina/Buenos_Aires"
    
    # Try timedatectl first (systemd)
    if command -v timedatectl &> /dev/null && timedatectl status &> /dev/null; then
        current_tz=$(timedatectl show -p Timezone --value 2>/dev/null || echo "")
        if [ "$current_tz" != "$target_tz" ]; then
            log_info "Setting timezone to $target_tz..."
            sudo timedatectl set-timezone "$target_tz"
        else
            log_info "✓ Timezone already set to $target_tz"
        fi
    else
        # Fallback for systems without systemd
        log_info "Using alternative timezone configuration..."
        if [ -f /etc/timezone ]; then
            current_tz=$(cat /etc/timezone)
        else
            current_tz=""
        fi
        
        if [ "$current_tz" != "$target_tz" ]; then
            log_info "Setting timezone to $target_tz..."
            echo "$target_tz" | sudo tee /etc/timezone > /dev/null
            sudo ln -sf "/usr/share/zoneinfo/$target_tz" /etc/localtime
            log_info "✓ Timezone set successfully"
        else
            log_info "✓ Timezone already set to $target_tz"
        fi
    fi
}

# Verify systemd
verify_systemd() {
    log_info "Verifying system init..."
    if command -v systemctl &> /dev/null; then
        systemctl --version | head -n1 || log_warn "systemd available but not fully functional"
    else
        log_warn "systemd not available (using alternative init system)"
    fi
}

# Create directories
create_directories() {
    if [ ! -d "/opt/homelab" ]; then
        log_info "Creating /opt/homelab directory..."
        sudo mkdir -p /opt/homelab
        sudo chown -R $USER:$USER /opt/homelab
    else
        log_info "✓ /opt/homelab directory already exists"
    fi
}

# Install macvlan routes service
install_macvlan_service() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    # Check if the macvlan script exists in the repo
    if [ ! -f "$SCRIPT_DIR/scripts/systemd/setup-macvlan-routes.sh" ]; then
        log_warn "macvlan routes script not found, skipping installation"
        return 0
    fi
    
    log_info "Installing macvlan routes service..."
    
    # Copy script to system location
    sudo cp "$SCRIPT_DIR/scripts/systemd/setup-macvlan-routes.sh" /usr/local/bin/
    sudo chmod +x /usr/local/bin/setup-macvlan-routes.sh
    
    # Get current username
    CURRENT_USER=$(whoami)
    
    # Create systemd service file
    sudo tee /etc/systemd/system/macvlan-routes.service > /dev/null << EOF
[Unit]
Description=Setup macvlan ARP routes for containers
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=oneshot
User=${CURRENT_USER}
ExecStart=/usr/local/bin/setup-macvlan-routes.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start the service
    sudo systemctl daemon-reload
    sudo systemctl enable macvlan-routes.service
    
    log_info "✓ macvlan routes service installed and enabled"
    log_info "  Service will configure ARP routes automatically on boot"
}

# Main execution
main() {
    log_info "=== System Preparation ==="
    echo ""
    
    # Detect OS type
    if is_dietpi; then
        log_info "Running on: DietPi"
    else
        log_info "Running on: Debian"
    fi
    echo ""
    
    update_system
    install_essentials
    install_age
    configure_timezone
    verify_systemd
    create_directories
    install_macvlan_service
    
    echo ""
    log_info "System preparation complete!"
    log_info "Installed tools:"
    echo "  - age: $(age --version 2>&1 | head -n1)"
    echo "  - git: $(git --version)"
    echo "  - curl: $(curl --version | head -n1)"
}

main "$@"
