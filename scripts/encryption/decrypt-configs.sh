#!/bin/bash

# Decrypt Optional Configuration Files
# Run this AFTER setup.sh to restore your customized configurations

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIGS_DIR="$REPO_DIR/configs"

# Check if age is installed
if ! command -v age &> /dev/null; then
    log_error "age is not installed"
    echo ""
    echo "Installing age..."
    sudo apt update
    sudo apt install -y age
fi

# Check if configs directory exists
if [ ! -d "$CONFIGS_DIR" ]; then
    log_warn "No configs directory found"
    log_info "Nothing to restore - this is a fresh configuration"
    exit 0
fi

# Check if there are any .age files
if [ -z "$(ls -A "$CONFIGS_DIR"/*.age 2>/dev/null)" ]; then
    log_warn "No encrypted configuration files found"
    log_info "Nothing to restore - this is a fresh configuration"
    exit 0
fi

log_info "=== Decrypt Optional Configurations ==="
echo ""
log_info "Found encrypted configurations:"
ls -1 "$CONFIGS_DIR"/*.age 2>/dev/null | xargs -n1 basename
echo ""
log_warn "You will be prompted for passphrases"
log_warn "Skip any configuration you don't want to restore"
echo ""

restored_count=0

# Decrypt git config
if [ -f "$CONFIGS_DIR/git-config.age" ]; then
    echo ""
    read -p "Restore git config? (Y/n): " restore_git
    if [[ ! "$restore_git" =~ ^[Nn]$ ]]; then
        log_info "Decrypting git config..."
        
        if [ -f ~/.gitconfig ]; then
            log_warn "~/.gitconfig already exists"
            read -p "Overwrite? (y/N): " overwrite
            if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
                log_info "Skipping git config"
            else
                cp ~/.gitconfig ~/.gitconfig.backup
                log_info "Backed up to ~/.gitconfig.backup"
                
                if age -d "$CONFIGS_DIR/git-config.age" > ~/.gitconfig; then
                    log_info "✓ Git config restored"
                    ((restored_count++))
                else
                    log_error "Failed to decrypt git config"
                    [ -f ~/.gitconfig.backup ] && mv ~/.gitconfig.backup ~/.gitconfig
                fi
            fi
        else
            if age -d "$CONFIGS_DIR/git-config.age" > ~/.gitconfig; then
                log_info "✓ Git config restored"
                ((restored_count++))
            else
                log_error "Failed to decrypt git config"
            fi
        fi
    fi
fi

# Decrypt SSH keys
if [ -f "$CONFIGS_DIR/ssh-keys.age" ]; then
    echo ""
    read -p "Restore SSH keys? (Y/n): " restore_ssh
    if [[ ! "$restore_ssh" =~ ^[Nn]$ ]]; then
        log_info "Decrypting SSH keys..."
        
        if [ -d ~/.ssh ] && [ -n "$(ls -A ~/.ssh 2>/dev/null)" ]; then
            log_warn "~/.ssh/ already exists and is not empty"
            read -p "Overwrite? (y/N): " overwrite
            if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
                log_info "Skipping SSH keys"
            else
                tar -czf ~/.ssh-backup.tar.gz -C ~/.ssh . 2>/dev/null || true
                log_info "Backed up to ~/.ssh-backup.tar.gz"
                
                mkdir -p ~/.ssh
                if age -d "$CONFIGS_DIR/ssh-keys.age" > /tmp/ssh-restore.tar.gz; then
                    tar -xzf /tmp/ssh-restore.tar.gz -C ~/.ssh
                    chmod 700 ~/.ssh
                    chmod 600 ~/.ssh/* 2>/dev/null || true
                    chmod 644 ~/.ssh/*.pub 2>/dev/null || true
                    rm -f /tmp/ssh-restore.tar.gz
                    log_info "✓ SSH keys restored"
                    ((restored_count++))
                else
                    log_error "Failed to decrypt SSH keys"
                    rm -f /tmp/ssh-restore.tar.gz
                fi
            fi
        else
            mkdir -p ~/.ssh
            if age -d "$CONFIGS_DIR/ssh-keys.age" > /tmp/ssh-restore.tar.gz; then
                tar -xzf /tmp/ssh-restore.tar.gz -C ~/.ssh
                chmod 700 ~/.ssh
                chmod 600 ~/.ssh/* 2>/dev/null || true
                chmod 644 ~/.ssh/*.pub 2>/dev/null || true
                rm -f /tmp/ssh-restore.tar.gz
                log_info "✓ SSH keys restored"
                ((restored_count++))
            else
                log_error "Failed to decrypt SSH keys"
                rm -f /tmp/ssh-restore.tar.gz
            fi
        fi
    fi
fi

# Decrypt Homarr config
if [ -f "$CONFIGS_DIR/homarr-config.age" ]; then
    echo ""
    read -p "Restore Homarr config? (Y/n): " restore_homarr
    if [[ ! "$restore_homarr" =~ ^[Nn]$ ]]; then
        log_info "Decrypting Homarr config..."
        
        if [ ! -d /opt/homarr ]; then
            log_warn "/opt/homarr doesn't exist yet"
            log_info "Run setup.sh first, then try again"
        else
            if age -d "$CONFIGS_DIR/homarr-config.age" > /tmp/homarr-restore.tar.gz; then
                tar -xzf /tmp/homarr-restore.tar.gz -C /opt/homarr/
                rm -f /tmp/homarr-restore.tar.gz
                log_info "✓ Homarr config restored"
                ((restored_count++))
            else
                log_error "Failed to decrypt Homarr config"
                rm -f /tmp/homarr-restore.tar.gz
            fi
        fi
    fi
fi

# Decrypt Nginx Proxy Manager config
if [ -f "$CONFIGS_DIR/nginx-proxy-manager.age" ]; then
    echo ""
    read -p "Restore Nginx Proxy Manager config? (Y/n): " restore_nginx
    if [[ ! "$restore_nginx" =~ ^[Nn]$ ]]; then
        log_info "Decrypting Nginx Proxy Manager config..."
        
        if [ ! -d /opt/nginx-proxy-manager ]; then
            log_warn "/opt/nginx-proxy-manager doesn't exist yet"
            log_info "Run setup.sh first, then try again"
        else
            if age -d "$CONFIGS_DIR/nginx-proxy-manager.age" > /tmp/nginx-restore.tar.gz; then
                tar -xzf /tmp/nginx-restore.tar.gz -C /opt/nginx-proxy-manager/
                rm -f /tmp/nginx-restore.tar.gz
                log_info "✓ Nginx Proxy Manager config restored"
                log_warn "Restart nginx-proxy-manager container for changes to take effect"
                ((restored_count++))
            else
                log_error "Failed to decrypt Nginx Proxy Manager config"
                rm -f /tmp/nginx-restore.tar.gz
            fi
        fi
    fi
fi

# Decrypt Pi-hole config
if [ -f "$CONFIGS_DIR/pihole-config.age" ]; then
    echo ""
    read -p "Restore Pi-hole config? (Y/n): " restore_pihole
    if [[ ! "$restore_pihole" =~ ^[Nn]$ ]]; then
        log_info "Decrypting Pi-hole config..."
        
        if [ ! -d /opt/pihole ]; then
            log_warn "/opt/pihole doesn't exist yet"
            log_info "Run setup.sh first, then try again"
        else
            if age -d "$CONFIGS_DIR/pihole-config.age" > /tmp/pihole-restore.tar.gz; then
                tar -xzf /tmp/pihole-restore.tar.gz -C /opt/pihole/
                rm -f /tmp/pihole-restore.tar.gz
                log_info "✓ Pi-hole config restored"
                log_warn "Restart pihole container for changes to take effect"
                ((restored_count++))
            else
                log_error "Failed to decrypt Pi-hole config"
                rm -f /tmp/pihole-restore.tar.gz
            fi
        fi
    fi
fi

# Summary
echo ""
log_info "=========================================="
log_info "Decryption Complete!"
log_info "=========================================="
echo ""
log_info "Restored $restored_count configuration file(s)"
echo ""

if [ $restored_count -gt 0 ]; then
    log_info "Configurations have been restored"
    log_warn "You may need to restart some containers:"
    echo ""
    echo "Via Portainer:"
    echo "  1. Go to Containers"
    echo "  2. Select container (nginx-proxy-manager, pihole, homarr)"
    echo "  3. Click Restart"
    echo ""
    echo "Via CLI:"
    echo "  cd /opt/homelab"
    echo "  docker compose restart nginx-proxy-manager"
    echo "  docker compose restart pihole"
    echo "  docker compose restart homarr"
else
    log_info "No configurations were restored"
    log_info "This is a fresh installation - configure services manually"
fi