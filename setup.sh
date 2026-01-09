#!/bin/bash

# Homelab Setup - Main Installation Script
# This script is idempotent and can be run multiple times safely
# Uses checkpoints to track progress across reboots/re-logins

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Checkpoint file
CHECKPOINT_FILE="$HOME/.homelab_setup_checkpoint"

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

# Checkpoint functions
get_checkpoint() {
    if [ -f "$CHECKPOINT_FILE" ]; then
        cat "$CHECKPOINT_FILE"
    else
        echo "0"
    fi
}

set_checkpoint() {
    echo "$1" > "$CHECKPOINT_FILE"
}

clear_checkpoint() {
    rm -f "$CHECKPOINT_FILE"
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
    CURRENT_CHECKPOINT=$(get_checkpoint)
    
    log_info "Starting Homelab Setup..."
    log_info "Current checkpoint: $CURRENT_CHECKPOINT"
    echo ""
    
    # Pre-flight checks (always run)
    log_info "Running pre-flight checks..."
    check_debian
    check_systemd

    # WSL2 detection and warning
    if grep -qi microsoft /proc/version 2>/dev/null; then
        log_warn "WSL2 environment detected"
        
        # Check if WSL2 fixes have been applied
        if ! sysctl net.ipv4.ip_unprivileged_port_start 2>/dev/null | grep -q "= 53"; then
            echo ""
            log_error "WSL2 fixes have NOT been applied yet"
            log_info "Please run the following BEFORE setup.sh:"
            echo ""
            echo "  ./scripts/wsl2-fixes.sh"
            echo "  exit"
            echo "  # From PowerShell: wsl --shutdown"
            echo "  # Then: wsl -d Debian"
            echo "  # Finally: ./setup.sh"
            echo ""
            read -p "Continue anyway? (not recommended) (y/N): " continue_wsl
            if [[ ! "$continue_wsl" =~ ^[Yy]$ ]]; then
                log_info "Setup cancelled. Apply WSL2 fixes first."
                exit 1
            fi
        else
            log_info "✓ WSL2 fixes already applied"
        fi
    fi
    
    echo ""
    
    # CHECKPOINT 0: Git setup
    if [ "$CURRENT_CHECKPOINT" -lt 1 ]; then
        git_setup_script="${SCRIPT_DIR}/scripts/setup-git.sh"
        if [ -f "$git_setup_script" ]; then
            log_info "Checking Git configuration..."
            chmod +x "$git_setup_script"
            bash "$git_setup_script"
            echo ""
        fi
        set_checkpoint 1
    else
        log_info "✓ Skipping git setup (already done)"
    fi
    
    # CHECKPOINT 1: Copy .env.age
    if [ "$CURRENT_CHECKPOINT" -lt 2 ]; then
        if [ -f "$SCRIPT_DIR/.env.age" ]; then
            mkdir -p "$HOME/homelab"
            if [ ! -f "$HOME/homelab/.env.age" ]; then
                log_info "Copying .env.age to homelab directory..."
                cp "$SCRIPT_DIR/.env.age" "$HOME/homelab/.env.age"
            fi
        fi
        set_checkpoint 2
    else
        log_info "✓ Skipping .env.age copy (already done)"
    fi
    
    # CHECKPOINT 2: Decrypt .env
    if [ "$CURRENT_CHECKPOINT" -lt 3 ]; then
        if [ -f "$HOME/homelab/.env.age" ]; then
            if [ ! -f "$HOME/homelab/.env" ]; then
                echo ""
                log_info "=========================================="
                log_info "Encrypted environment file detected"
                log_info "=========================================="
                echo ""
                log_info "Found: ~/homelab/.env.age"
                log_warn "Decryption is REQUIRED to continue"
                echo ""
                
                decrypt_script="${SCRIPT_DIR}/scripts/decrypt-env.sh"
                if [ -f "$decrypt_script" ]; then
                    chmod +x "$decrypt_script"
                    bash "$decrypt_script"
                    
                    # Verify decryption succeeded
                    if [ ! -f "$HOME/homelab/.env" ]; then
                        log_error "Decryption failed or was cancelled"
                        log_error "Cannot continue without .env"
                        exit 1
                    fi
                else
                    log_error "Decrypt script not found"
                    exit 1
                fi
            else
                log_info "✓ .env already exists"
            fi
        elif [ ! -f "$HOME/homelab/.env" ]; then
            log_error "No .env.age or .env found"
            log_error "This repository requires encrypted credentials"
            exit 1
        fi
        set_checkpoint 3
    else
        log_info "✓ Skipping .env decryption (already done)"
    fi
    
    echo ""
    
    # Run installation scripts in order
    scripts=(
        "01-system-prep.sh:4"
        "02-install-podman.sh:5"
        "03-install-cockpit.sh:6"
        "04-deploy-services.sh:7"
    )
    
    for script_info in "${scripts[@]}"; do
        script="${script_info%%:*}"
        checkpoint="${script_info##*:}"
        script_path="${SCRIPT_DIR}/scripts/${script}"
        
        if [ "$CURRENT_CHECKPOINT" -lt "$checkpoint" ]; then
            if [ -f "$script_path" ]; then
                log_info "Running ${script}..."
                chmod +x "$script_path"
                
                if bash "$script_path"; then
                    log_info "✓ ${script} completed successfully"
                    set_checkpoint "$checkpoint"
                else
                    log_error "✗ ${script} failed"
                    exit 1
                fi
                echo ""
            else
                log_warn "Script not found: ${script_path}"
            fi
        else
            log_info "✓ Skipping ${script} (already done)"
        fi
    done
    
    # Check if optional encrypted configs exist and offer to restore
    if [ "$CURRENT_CHECKPOINT" -lt 8 ]; then
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
        set_checkpoint 8
    else
        log_info "✓ Skipping optional configs (already done)"
    fi
    
    # Final message
    echo ""
    log_info "=========================================="
    log_info "Homelab Setup Complete!"
    log_info "=========================================="
    echo ""
    log_info "Services are now running. Access them at:"
    echo ""
    echo "  Homarr Dashboard:     http://localhost:7575"
    echo "  Dozzle (Logs):        http://localhost:8888"
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
    echo "  podman ps"
    echo "  podman-compose logs -f"
    echo "  podman-compose restart SERVICE_NAME"
    echo ""
    log_info "Configuration directory: ~/homelab"
    echo ""
    
    # Clear checkpoint on successful completion
    clear_checkpoint
    log_info "Setup checkpoint cleared - setup is complete!"
}

# Run main function
main "$@"
