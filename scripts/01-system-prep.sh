#!/bin/bash

# System Preparation Script
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
        "age"
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
    configure_timezone
    verify_systemd
    create_directories
    
    log_info "System preparation complete!"
}

main "$@"
