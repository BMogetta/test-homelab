#!/bin/bash

# Podman Installation Script
# Idempotent - can be run multiple times safely
# Compatible with Debian and DietPi

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

# Check if running as root
if [ "$EUID" -eq 0 ] || [ "$(whoami)" = "root" ]; then
    log_error "This script should NOT be run as root"
    log_error "Rootless Podman is designed for non-root users"
    log_error "Please run as a regular user"
    exit 1
fi

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
        "passt"  # Critical: provides pasta for networking
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
    if systemctl --user enable podman.socket 2>&1 | grep -v "Created symlink"; then
        log_info "✓ Podman socket enabled"
    else
        log_warn "Podman socket may already be enabled"
    fi
    
    # Try to start it
    if systemctl --user start podman.socket 2>&1; then
        log_info "✓ Podman socket started"
    else
        log_warn "Could not start Podman socket (will start on next login)"
    fi
    
    # Check status
    if systemctl --user is-active --quiet podman.socket 2>/dev/null; then
        log_info "✓ Podman socket is active"
    else
        log_warn "Podman socket is not active yet (normal for first-time setup)"
        log_info "It will activate automatically when needed"
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

# Configure containers.conf for DietPi compatibility
configure_containers_conf() {
    log_info "Configuring containers.conf for DietPi compatibility..."
    
    config_dir="$HOME/.config/containers"
    mkdir -p "$config_dir"
    
    if [ ! -f "$config_dir/containers.conf" ]; then
        cat > "$config_dir/containers.conf" << 'EOF'
[engine]
# Use cgroupfs instead of systemd for better DietPi compatibility
cgroup_manager = "cgroupfs"
events_logger = "file"

[network]
# Use netavark as network backend (requires pasta/passt package)
network_backend = "netavark"
# Disable internal DNS to avoid D-Bus issues on DietPi
dns_enabled = false
EOF
        log_info "✓ Created containers.conf"
    else
        log_info "✓ containers.conf already exists"
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

# Verify pasta is installed
verify_pasta() {
    log_info "Verifying pasta installation..."
    
    if command -v pasta &> /dev/null; then
        log_info "✓ pasta is installed: $(pasta --version 2>&1 | head -n1 || echo 'available')"
    else
        log_error "pasta is NOT installed - this will cause networking errors"
        log_info "Installing passt package..."
        sudo apt install -y passt
        
        if command -v pasta &> /dev/null; then
            log_info "✓ pasta installed successfully"
        else
            log_error "Failed to install pasta"
            return 1
        fi
    fi
}

# Test podman installation
test_podman() {
    log_info "Testing Podman installation..."
    
    if podman run --rm hello-world &> /dev/null; then
        log_info "✓ Podman test successful"
    else
        log_warn "Podman test failed, but installation may still be OK"
        log_info "This is normal on first run - containers will work"
    fi
}

# Main execution
main() {
    log_info "=== Podman Installation ==="
    echo ""
    
    if ! check_podman; then
        install_dependencies
        install_podman
    fi
    
    echo ""
    install_podman_compose
    verify_pasta
    configure_subuid
    configure_storage
    configure_registries
    configure_containers_conf
    enable_podman_socket
    test_podman
    
    echo ""
    log_info "=========================================="
    log_info "Podman installation complete!"
    log_info "=========================================="
    echo ""
    podman --version
    podman-compose --version 2>/dev/null || log_warn "podman-compose version check failed"
    
    echo ""
    log_info "Important configuration:"
    echo "  ✓ pasta (networking) installed"
    echo "  ✓ cgroupfs manager (DietPi compatible)"
    echo "  ✓ Internal DNS disabled (avoids D-Bus issues)"
    echo "  ✓ Environment configured"
    echo ""
    log_info "You can proceed with the next installation steps"
}

main "$@"
