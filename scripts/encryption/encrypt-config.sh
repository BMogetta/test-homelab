#!/bin/bash

# Encrypt Optional Configuration Files
# Run this AFTER you've customized your homelab to backup configurations

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
    echo "Install with:"
    echo "  sudo apt install age"
    exit 1
fi

# Create configs directory
mkdir -p "$CONFIGS_DIR"

log_info "=== Encrypt Optional Configurations ==="
echo ""
log_warn "You will be prompted for a passphrase for EACH file"
log_warn "You can use the same passphrase for all, or different ones"
echo ""

encrypted_count=0

# Encrypt git config
if [ -f ~/.gitconfig ]; then
    read -p "Encrypt git config (~/.gitconfig)? (Y/n): " encrypt_git
    if [[ ! "$encrypt_git" =~ ^[Nn]$ ]]; then
        log_info "Encrypting git config..."
        if age -p -o "$CONFIGS_DIR/git-config.age" ~/.gitconfig; then
            log_info "✓ git-config.age created"
            ((encrypted_count++))
        else
            log_warn "Failed to encrypt git config"
        fi
    fi
else
    log_warn "~/.gitconfig not found, skipping"
fi

echo ""

# Encrypt SSH keys
if [ -d ~/.ssh ] && [ -n "$(ls -A ~/.ssh 2>/dev/null)" ]; then
    read -p "Encrypt SSH keys (~/.ssh/)? (Y/n): " encrypt_ssh
    if [[ ! "$encrypt_ssh" =~ ^[Nn]$ ]]; then
        log_info "Encrypting SSH keys..."
        tar -czf /tmp/ssh-backup.tar.gz -C ~/.ssh .
        if age -p -o "$CONFIGS_DIR/ssh-keys.age" /tmp/ssh-backup.tar.gz; then
            log_info "✓ ssh-keys.age created"
            ((encrypted_count++))
        else
            log_warn "Failed to encrypt SSH keys"
        fi
        rm -f /tmp/ssh-backup.tar.gz
    fi
else
    log_warn "~/.ssh/ not found or empty, skipping"
fi

echo ""

# Encrypt Homarr config
if [ -d /opt/homarr/configs ] && [ -n "$(ls -A /opt/homarr/configs 2>/dev/null)" ]; then
    read -p "Encrypt Homarr config? (Y/n): " encrypt_homarr
    if [[ ! "$encrypt_homarr" =~ ^[Nn]$ ]]; then
        log_info "Encrypting Homarr config..."
        tar -czf /tmp/homarr-config.tar.gz -C /opt/homarr configs
        if age -p -o "$CONFIGS_DIR/homarr-config.age" /tmp/homarr-config.tar.gz; then
            log_info "✓ homarr-config.age created"
            ((encrypted_count++))
        else
            log_warn "Failed to encrypt Homarr config"
        fi
        rm -f /tmp/homarr-config.tar.gz
    fi
else
    log_warn "Homarr config not found, skipping"
fi

echo ""

# Encrypt Nginx Proxy Manager data
if [ -d /opt/nginx-proxy-manager/data ] && [ -n "$(ls -A /opt/nginx-proxy-manager/data 2>/dev/null)" ]; then
    read -p "Encrypt Nginx Proxy Manager config? (Y/n): " encrypt_nginx
    if [[ ! "$encrypt_nginx" =~ ^[Nn]$ ]]; then
        log_info "Encrypting Nginx Proxy Manager config..."
        log_warn "This may take a moment for large configurations..."
        tar -czf /tmp/nginx-config.tar.gz -C /opt/nginx-proxy-manager data
        if age -p -o "$CONFIGS_DIR/nginx-proxy-manager.age" /tmp/nginx-config.tar.gz; then
            log_info "✓ nginx-proxy-manager.age created"
            ((encrypted_count++))
        else
            log_warn "Failed to encrypt Nginx Proxy Manager config"
        fi
        rm -f /tmp/nginx-config.tar.gz
    fi
else
    log_warn "Nginx Proxy Manager config not found, skipping"
fi

echo ""

# Encrypt Pi-hole config (custom lists, etc.)
if [ -d /opt/pihole/etc-pihole ] && [ -n "$(ls -A /opt/pihole/etc-pihole 2>/dev/null)" ]; then
    read -p "Encrypt Pi-hole custom config? (Y/n): " encrypt_pihole
    if [[ ! "$encrypt_pihole" =~ ^[Nn]$ ]]; then
        log_info "Encrypting Pi-hole config..."
        tar -czf /tmp/pihole-config.tar.gz -C /opt/pihole etc-pihole etc-dnsmasq.d
        if age -p -o "$CONFIGS_DIR/pihole-config.age" /tmp/pihole-config.tar.gz; then
            log_info "✓ pihole-config.age created"
            ((encrypted_count++))
        else
            log_warn "Failed to encrypt Pi-hole config"
        fi
        rm -f /tmp/pihole-config.tar.gz
    fi
else
    log_warn "Pi-hole config not found, skipping"
fi

echo ""

# Summary
log_info "=========================================="
log_info "Encryption Complete!"
log_info "=========================================="
echo ""
log_info "Encrypted $encrypted_count configuration file(s)"
echo ""

if [ $encrypted_count -gt 0 ]; then
    log_info "Files created in: $CONFIGS_DIR"
    ls -lh "$CONFIGS_DIR"/*.age 2>/dev/null || true
    echo ""
    log_info "Next steps:"
    echo "  1. git add configs/"
    echo "  2. git commit -m 'feat: add encrypted configurations'"
    echo "  3. git push"
    echo ""
    log_warn "REMEMBER YOUR PASSPHRASES!"
else
    log_warn "No configurations were encrypted"
fi