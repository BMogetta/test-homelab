#!/bin/bash

# Homelab Setup - Main Installation Script
# This script is idempotent and can be run multiple times safely

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Logging
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on Debian
check_debian() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" != "debian" ]; then
            log_error "This script is designed for Debian. Detected: $ID"
            exit 1
        fi
        log_info "Detected Debian $VERSION_ID"
    else
        log_error "Cannot detect OS"
        exit 1
    fi
}

# Check if systemd is available
check_systemd() {
    if ! command -v systemctl &> /dev/null; then
        log_error "systemd is not available"
        exit 1
    fi
    log_info "systemd is available: $(systemctl --version | head -n1)"
}

# Main installation flow
main() {
    log_info "Starting Homelab Setup..."
    echo ""
    
    # Pre-flight checks
    log_info "Running pre-flight checks..."
    check_debian
    check_systemd
    echo ""
    
    # Setup git if not configured
    git_setup_script="${SCRIPT_DIR}/scripts/setup-git.sh"
    if [ -f "$git_setup_script" ]; then
        log_info "Checking Git configuration..."
        chmod +x "$git_setup_script"
        bash "$git_setup_script"
        echo ""
    fi
    
    # Run installation scripts in order
    scripts=(
        "01-system-prep.sh"
        "02-install-podman.sh"
        "03-install-cockpit.sh"
        "04-deploy-services.sh"
    )
    
    for script in "${scripts[@]}"; do
        script_path="${SCRIPT_DIR}/scripts/${script}"
        
        if [ -f "$script_path" ]; then
            log_info "Running ${script}..."
            chmod +x "$script_path"
            
            if bash "$script_path"; then
                log_info "✓ ${script} completed successfully"
            else
                log_error "✗ ${script} failed"
                exit 1
            fi
            echo ""
        else
            log_warn "Script not found: ${script_path}"
        fi
    done
    
    # Check if encrypted .env exists and offer to decrypt
    if [ -f "$HOME/homelab/.env.age" ] && [ ! -f "$HOME/homelab/.env" ]; then
        echo ""
        log_info "=========================================="
        log_info "Encrypted environment file detected"
        log_info "=========================================="
        echo ""
        log_info "Found: ~/homelab/.env.age"
        echo ""
        read -p "Would you like to decrypt it now? (Y/n): " decrypt_response
        
        if [[ ! "$decrypt_response" =~ ^[Nn]$ ]]; then
            decrypt_script="${SCRIPT_DIR}/scripts/decrypt-env.sh"
            if [ -f "$decrypt_script" ]; then
                chmod +x "$decrypt_script"
                bash "$decrypt_script"
            else
                log_warn "Decrypt script not found"
                log_info "Run manually: ./scripts/decrypt-env.sh"
            fi
        else
            log_info "Skipping decryption"
            log_info "You can decrypt later with: ./scripts/decrypt-env.sh"
        fi
    fi
    
    # Check if optional encrypted configs exist and offer to restore
    if [ -d "${SCRIPT_DIR}/configs" ] && [ -n "$(ls -A "${SCRIPT_DIR}/configs"/*.age 2>/dev/null)" ]; then
        echo ""
        log_info "=========================================="
        log_info "Optional encrypted configs detected"
        log_info "=========================================="
        echo ""
        log_info "Found encrypted configurations:"
        ls -1 "${SCRIPT_DIR}/configs"/*.age 2>/dev/null | xargs -n1 basename | sed 's/^/  - /'
        echo ""
        log_info "These are optional backups of:"
        echo "  - Git configuration (user/email)"
        echo "  - SSH keys"
        echo "  - Service customizations (Homarr, Nginx, Pi-hole)"
        echo ""
        read -p "Would you like to restore these configurations? (y/N): " restore_configs
        
        if [[ "$restore_configs" =~ ^[Yy]$ ]]; then
            decrypt_configs_script="${SCRIPT_DIR}/scripts/decrypt-configs.sh"
            if [ -f "$decrypt_configs_script" ]; then
                chmod +x "$decrypt_configs_script"
                bash "$decrypt_configs_script"
            else
                log_warn "Decrypt configs script not found"
                log_info "Run manually: ./scripts/decrypt-configs.sh"
            fi
        else
            log_info "Skipping optional configs restore"
            log_info "This is a fresh installation - configure manually"
            log_info "You can restore later with: ./scripts/decrypt-configs.sh"
        fi
    fi
    
    # Final message
    echo ""
    log_info "=========================================="
    log_info "Homelab Setup Complete!"
    log_info "=========================================="
    echo ""
    log_info "Services are now running. Access them at:"
    echo ""
    echo "  Cockpit:              https://localhost:9090"
    echo "  Nginx Proxy Manager:  http://localhost:81"
    echo "  Pi-hole:              http://localhost:8080/admin"
    echo "  UniFi Controller:     https://localhost:8443"
    echo "  Uptime Kuma:          http://localhost:3001"
    echo "  Home Assistant:       http://localhost:8123"
    echo "  Stirling PDF:         http://localhost:8082"
    echo ""
    log_info "To manage services:"
    echo "  cd ~/homelab"
    echo "  podman-compose logs -f"
    echo "  podman-compose restart SERVICE_NAME"
    echo ""
    log_info "Configuration directory: ~/homelab"
}

# Run main function
main "$@"
