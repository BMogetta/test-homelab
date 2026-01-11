#!/bin/bash

# Docker Installation Script
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

# Check if Docker is installed
check_docker() {
    if command -v docker &> /dev/null; then
        log_info "✓ Docker already installed: $(docker --version)"
        return 0
    else
        return 1
    fi
}

# Install Docker dependencies
install_dependencies() {
    log_info "Installing Docker dependencies..."
    
    deps=(
        "ca-certificates"
        "curl"
        "gnupg"
        "lsb-release"
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

# Add Docker's official GPG key
add_docker_gpg() {
    if [ -f /etc/apt/keyrings/docker.gpg ]; then
        log_info "✓ Docker GPG key already exists"
        return 0
    fi
    
    log_info "Adding Docker's official GPG key..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    log_info "✓ Docker GPG key added"
}

# Add Docker repository
add_docker_repo() {
    if [ -f /etc/apt/sources.list.d/docker.list ]; then
        log_info "✓ Docker repository already configured"
        return 0
    fi
    
    log_info "Adding Docker repository..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    log_info "✓ Docker repository added"
}

# Install Docker Engine
install_docker() {
    log_info "Installing Docker Engine..."
    
    sudo apt update -qq
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    log_info "✓ Docker Engine installed"
}

# Add current user to docker group
add_user_to_docker_group() {
    current_user=$(whoami)
    
    if groups $current_user | grep -q docker; then
        log_info "✓ User $current_user already in docker group"
        return 0
    fi
    
    log_info "Adding user $current_user to docker group..."
    sudo usermod -aG docker $current_user
    
    log_warn "=========================================="
    log_warn "GROUP MEMBERSHIP UPDATED"
    log_warn "=========================================="
    echo ""
    log_info "You need to log out and log back in for"
    log_info "docker group membership to take effect."
    echo ""
    log_info "After reconnecting, run:"
    echo ""
    echo "  cd $(pwd) && ./setup.sh"
    echo ""
    log_info "The setup will automatically continue from where it left off."
    echo ""
    read -p "Press ENTER to continue (you'll need to re-login after this)..."
}

# Enable and start Docker service
enable_docker_service() {
    log_info "Enabling Docker service..."
    
    sudo systemctl enable docker
    sudo systemctl start docker
    
    if sudo systemctl is-active --quiet docker; then
        log_info "✓ Docker service is running"
    else
        log_error "Docker service failed to start"
        sudo systemctl status docker --no-pager
        exit 1
    fi
}

# Test Docker installation
test_docker() {
    log_info "Testing Docker installation..."
    
    if docker run --rm hello-world &> /dev/null; then
        log_info "✓ Docker test successful"
    else
        log_warn "Docker test requires group membership refresh"
        log_info "This will work after you log back in"
    fi
}

# Main execution
main() {
    log_info "=== Docker Installation ==="
    echo ""
    
    if ! check_docker; then
        install_dependencies
        add_docker_gpg
        add_docker_repo
        install_docker
        enable_docker_service
    fi
    
    echo ""
    add_user_to_docker_group
    
    echo ""
    test_docker
    
    echo ""
    log_info "=========================================="
    log_info "Docker installation complete!"
    log_info "=========================================="
    echo ""
    docker --version
    docker compose version
    
    echo ""
    log_info "You can now proceed with Portainer installation"
}

main "$@"
