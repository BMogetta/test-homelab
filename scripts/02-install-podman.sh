#!/bin/bash

# Podman Installation Script
# Idempotent - can be run multiple times safely
# Compatible with Debian and DietPi

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
        "nftables"
        "iptables"
        "dbus-user-session"
        "netavark"
        "aardvark-dns"
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
    
    # Get current user UID
    USER_UID=$(id -u)
    
    # Create storage.conf if it doesn't exist
    if [ ! -f "$config_dir/storage.conf" ]; then
        cat > "$config_dir/storage.conf" << EOF
[storage]
driver = "overlay"
runroot = "/run/user/${USER_UID}/containers"
graphroot = "${HOME}/.local/share/containers/storage"

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

# Configure subuid/subgid for rootless containers
configure_subuid() {
    log_info "Configuring subuid/subgid mappings..."
    
    current_user=$(whoami)
    
    # Check if user already has subuid mapping
    if grep -q "^${current_user}:" /etc/subuid 2>/dev/null; then
        log_info "✓ subuid already configured for $current_user"
    else
        log_info "Adding subuid mapping for $current_user..."
        echo "${current_user}:100000:65536" | sudo tee -a /etc/subuid > /dev/null
    fi
    
    # Check if user already has subgid mapping
    if grep -q "^${current_user}:" /etc/subgid 2>/dev/null; then
        log_info "✓ subgid already configured for $current_user"
    else
        log_info "Adding subgid mapping for $current_user..."
        echo "${current_user}:100000:65536" | sudo tee -a /etc/subgid > /dev/null
    fi
}

# Enable user lingering (needed for rootless podman on minimal systems)
enable_user_lingering() {
    log_info "Enabling user lingering for rootless podman..."
    
    current_user=$(whoami)
    
    if loginctl show-user "$current_user" | grep -q "Linger=yes"; then
        log_info "✓ User lingering already enabled"
    else
        sudo loginctl enable-linger "$current_user"
        log_info "✓ User lingering enabled"
    fi
    
    # Ensure XDG_RUNTIME_DIR is set
    if [ -z "$XDG_RUNTIME_DIR" ]; then
        log_warn "XDG_RUNTIME_DIR not set, configuring for current session..."
        export XDG_RUNTIME_DIR="/run/user/$(id -u)"
        export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
        
        # Add to .bashrc if not already there
        if ! grep -q "XDG_RUNTIME_DIR" "$HOME/.bashrc" 2>/dev/null; then
            cat >> "$HOME/.bashrc" << 'BASHRC_EOF'
# Podman environment variables
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
BASHRC_EOF
            log_info "✓ Added environment variables to .bashrc"
        fi
    fi
    
    # Try to start user services if they're not running
    if ! systemctl --user is-active --quiet podman.socket 2>/dev/null; then
        log_info "Starting user services..."
        systemctl --user daemon-reexec 2>/dev/null || true
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
    configure_subuid
    enable_user_lingering
    configure_storage
    configure_registries
    enable_podman_socket
    test_podman
    
    log_info "Podman installation complete!"
    podman --version
    podman-compose --version 2>/dev/null || log_warn "podman-compose version check failed"
    
    echo ""
    log_info "Environment configured for current session"
    log_info "You can proceed with the next installation steps"
    echo ""
    log_info "Note: If you encounter any issues with Podman after a reboot,"
    log_info "      simply logout and login again to reload the environment"
}

main "$@"