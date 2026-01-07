#!/bin/bash

# System Preparation Script
# Idempotent - can be run multiple times safely

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

# Configure timezone (skip if already set)
configure_timezone() {
    current_tz=$(timedatectl show -p Timezone --value)
    target_tz="America/Argentina/Buenos_Aires"
    
    if [ "$current_tz" != "$target_tz" ]; then
        log_info "Setting timezone to $target_tz..."
        sudo timedatectl set-timezone "$target_tz"
    else
        log_info "✓ Timezone already set to $target_tz"
    fi
}

# Verify systemd
verify_systemd() {
    log_info "Verifying systemd..."
    systemctl --version | head -n1
}

# Create homelab directory
create_directories() {
    if [ ! -d "$HOME/homelab" ]; then
        log_info "Creating homelab directory..."
        mkdir -p "$HOME/homelab"
    else
        log_info "✓ Homelab directory already exists"
    fi
}

# Main execution
main() {
    log_info "=== System Preparation ==="
    
    update_system
    install_essentials
    install_age
    configure_timezone
    verify_systemd
    create_directories
    
    log_info "System preparation complete!"
    log_info "Installed tools:"
    echo "  - age: $(age --version 2>&1 | head -n1)"
    echo "  - git: $(git --version)"
    echo "  - curl: $(curl --version | head -n1)"
}

main "$@"