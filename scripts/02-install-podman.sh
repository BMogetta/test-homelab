#!/bin/bash

# Podman Installation Script
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

# Check if podman is installed
check_podman() {
    if command -v podman &> /dev/null; then
        log_info "✓ Podman already installed: $(podman --version)"
        return 0
    else
        return 1
    fi
}

# Install dependencies
install_dependencies() {
    log_info "Installing Podman dependencies..."
    
    deps=(
        "fuse-overlayfs"
        "slirp4netns"
        "uidmap"
    )
    
    to_install=()
    
    for dep in "${deps[@]}"; do
        if ! dpkg -l | grep -q "^ii  $dep "; then
            to_install+=("$dep")
        fi
    done
    
    if [ ${#to_install[@]} -gt 0 ]; then
        log_info "Installing: ${to_install[*]}"
        sudo apt install -y "${to_install[@]}"
    else
        log_info "✓ All dependencies already installed"
    fi
}

# Install Podman
install_podman() {
    log_info "Installing Podman..."
    sudo apt install -y podman
}

# Install podman-compose
install_podman_compose() {
    if command -v podman-compose &> /dev/null; then
        log_info "✓ podman-compose already installed: $(podman-compose --version)"
        return 0
    fi
    
    log_info "Installing podman-compose from Debian repository..."
    sudo apt install -y podman-compose
}

# Enable podman socket (for Cockpit and other tools)
enable_podman_socket() {
    log_info "Enabling Podman socket..."
    
    # Enable user socket
    systemctl --user enable podman.socket --now 2>/dev/null || log_warn "User socket may already be enabled"
    
    # Check status
    if systemctl --user is-active --quiet podman.socket; then
        log_info "✓ Podman socket is active"
    else
        log_warn "Podman socket may not be running yet"
    fi
}

# Configure storage for rootless podman
configure_storage() {
    log_info "Configuring Podman storage..."
    
    config_dir="$HOME/.config/containers"
    mkdir -p "$config_dir"
    
    # Create storage.conf if it doesn't exist
    if [ ! -f "$config_dir/storage.conf" ]; then
        cat > "$config_dir/storage.conf" << 'EOF'
[storage]
driver = "overlay"
runroot = "/run/user/$UID/containers"
graphroot = "/home/$USER/.local/share/containers/storage"

[storage.options]
mount_program = "/usr/bin/fuse-overlayfs"
EOF
        log_info "✓ Created storage.conf"
    else
        log_info "✓ storage.conf already exists"
    fi
}

# Configure registries
configure_registries() {
    log_info "Configuring container registries..."
    
    config_dir="$HOME/.config/containers"
    mkdir -p "$config_dir"
    
    if [ ! -f "$config_dir/registries.conf" ]; then
        cat > "$config_dir/registries.conf" << 'EOF'
unqualified-search-registries = ["docker.io"]

[[registry]]
location = "docker.io"
EOF
        log_info "✓ Created registries.conf"
    else
        log_info "✓ registries.conf already exists"
    fi
}

# Test podman installation
test_podman() {
    log_info "Testing Podman installation..."
    
    if podman run --rm hello-world &> /dev/null; then
        log_info "✓ Podman test successful"
    else
        log_warn "Podman test failed, but installation may still be OK"
    fi
}

# Main execution
main() {
    log_info "=== Podman Installation ==="
    
    if ! check_podman; then
        install_dependencies
        install_podman
    fi
    
    install_podman_compose
    configure_storage
    configure_registries
    enable_podman_socket
    test_podman
    
    log_info "Podman installation complete!"
    podman --version
    podman-compose --version 2>/dev/null || log_warn "podman-compose version check failed (may need to restart shell)"
}

main "$@"
