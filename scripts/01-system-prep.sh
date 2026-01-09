#!/bin/bash

# System Preparation Script
# Idempotent - can be run multiple times safely
# Now includes DietPi systemd-logind fixes

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

# Configure timezone (compatible with DietPi)
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
        # Fallback for systems without systemd (like DietPi minimal)
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

# Fix DietPi systemd-logind (critical for Podman)
fix_dietpi_systemd() {
    if ! is_dietpi; then
        log_info "Not DietPi, skipping systemd-logind fixes"
        return 0
    fi
    
    log_info "Detected DietPi - applying systemd-logind fixes..."
    
    # CRITICAL: Install D-Bus if not present
    if ! command -v dbus-daemon &> /dev/null; then
        log_warn "D-Bus not found - installing..."
        sudo apt install -y dbus dbus-user-session dbus-x11
        log_info "✓ D-Bus installed"
    else
        log_info "✓ D-Bus already installed"
    fi
    
    # Ensure D-Bus system service is running
    if ! sudo systemctl is-active --quiet dbus.service; then
        log_info "Starting D-Bus system service..."
        sudo systemctl start dbus.service
        sudo systemctl enable dbus.service
    else
        log_info "✓ D-Bus system service running"
    fi
    
    # Re-enable systemd-logind if disabled
    if [ -L /etc/systemd/system/systemd-logind.service ] && [ "$(readlink /etc/systemd/system/systemd-logind.service)" = "/dev/null" ]; then
        log_info "Re-enabling systemd-logind..."
        sudo rm /etc/systemd/system/systemd-logind.service
        sudo systemctl unmask systemd-logind.service 2>/dev/null || true
    fi
    
    # Start systemd-logind FIRST
    if ! sudo systemctl is-active --quiet systemd-logind.service; then
        log_info "Starting systemd-logind..."
        sudo systemctl start systemd-logind.service
        
        # Wait for it to be fully active
        sleep 2
        
        if sudo systemctl is-active --quiet systemd-logind.service; then
            log_info "✓ systemd-logind started successfully"
        else
            log_error "Failed to start systemd-logind"
            sudo systemctl status systemd-logind.service --no-pager
            exit 1
        fi
    else
        log_info "✓ systemd-logind already running"
    fi
    
    # Verify PAM has systemd enabled
    if ! grep -q "pam_systemd.so" /etc/pam.d/common-session; then
        log_info "Adding pam_systemd to PAM configuration..."
        echo "session optional pam_systemd.so" | sudo tee -a /etc/pam.d/common-session > /dev/null
    else
        log_info "✓ pam_systemd already configured"
    fi
    
    # Enable lingering for current user (requires systemd-logind running)
    current_user=$(whoami)
    USER_UID=$(id -u)
    
    if ! loginctl show-user "$current_user" 2>/dev/null | grep -q "Linger=yes"; then
        log_info "Enabling user lingering..."
        if sudo loginctl enable-linger "$current_user" 2>&1; then
            log_info "✓ User lingering enabled"
        else
            log_warn "Could not enable lingering (will be set on next login)"
        fi
    else
        log_info "✓ User lingering already enabled"
    fi
    
    # Ensure /run/user/UID exists
    if [ ! -d "/run/user/$USER_UID" ]; then
        log_info "Creating /run/user/$USER_UID..."
        sudo mkdir -p "/run/user/$USER_UID"
        sudo chown "$current_user:$current_user" "/run/user/$USER_UID"
        sudo chmod 700 "/run/user/$USER_UID"
    else
        log_info "✓ /run/user/$USER_UID exists"
    fi
    
    # Add environment variables to .bashrc
    if ! grep -q "XDG_RUNTIME_DIR" "$HOME/.bashrc" 2>/dev/null; then
        log_info "Adding XDG_RUNTIME_DIR to .bashrc..."
        cat >> "$HOME/.bashrc" << 'EOF'

# Runtime directory for systemd user session
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
EOF
    else
        log_info "✓ XDG_RUNTIME_DIR already in .bashrc"
    fi
    
    # Try to start user service (may fail on first run, that's OK)
    if ! sudo systemctl is-active --quiet "user@$USER_UID.service"; then
        log_info "Starting user@$USER_UID.service..."
        if sudo systemctl start "user@$USER_UID.service" 2>&1; then
            log_info "✓ user@$USER_UID.service started"
        else
            log_warn "user@$USER_UID.service failed to start (will work after re-login)"
        fi
    else
        log_info "✓ user@$USER_UID.service already running"
    fi
    
    # Check if re-login is needed
    if [ -z "$XDG_RUNTIME_DIR" ] || [ ! -S "$XDG_RUNTIME_DIR/bus" ]; then
        echo ""
        log_warn "=========================================="
        log_warn "SESSION RESTART REQUIRED"
        log_warn "=========================================="
        echo ""
        log_info "systemd-logind has been configured, but you need to"
        log_info "restart your session for changes to take effect."
        echo ""
        log_info "After reconnecting, run:"
        echo ""
        echo "  cd ~/test-homelab && ./setup.sh"
        echo ""
        log_info "The setup will automatically continue from where it left off."
        echo ""
        log_info "Exiting now... please reconnect via SSH."
        sleep 2
        
        # Exit the script - user will be disconnected
        exit 0
    else
        log_info "✓ systemd user session is active"
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

# Create homelab directory
create_directories() {
    if [ ! -d "$HOME/homelab" ]; then
        log_info "Creating homelab directory..."
        mkdir -p "$HOME/homelab"
    else
        log_info "✓ Homelab directory already exists"
    fi
}

# Install macvlan routes service (for Raspberry Pi/physical deployments)
install_macvlan_service() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    
    # Check if the macvlan script exists in the repo
    if [ ! -f "$SCRIPT_DIR/scripts/systemd/setup-macvlan-routes.sh" ]; then
        log_warn "macvlan routes script not found, skipping installation"
        log_info "This is normal for WSL2 or if not using macvlan networking"
        return 0
    fi
    
    log_info "Installing macvlan routes service..."
    
    # Copy script to system location
    sudo cp "$SCRIPT_DIR/scripts/systemd/setup-macvlan-routes.sh" /usr/local/bin/
    sudo chmod +x /usr/local/bin/setup-macvlan-routes.sh
    
    # Create systemd service file
    sudo tee /etc/systemd/system/macvlan-routes.service > /dev/null << 'EOF'
[Unit]
Description=Setup macvlan ARP routes for containers
After=network-online.target podman.service
Wants=network-online.target

[Service]
Type=oneshot
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
    
    update_system
    install_essentials
    install_age
    configure_timezone
    verify_systemd
    fix_dietpi_systemd  # This may exit and ask for re-login
    create_directories
    install_macvlan_service  # Install macvlan routes service
    
    echo ""
    log_info "System preparation complete!"
    log_info "Installed tools:"
    echo "  - age: $(age --version 2>&1 | head -n1)"
    echo "  - git: $(git --version)"
    echo "  - curl: $(curl --version | head -n1)"
}

main "$@"