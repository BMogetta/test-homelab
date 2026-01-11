#!/bin/bash

# Decrypt .env file after cloning repository
# Use this AFTER running setup.sh on a fresh installation

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

# Check if age is installed
if ! command -v age &> /dev/null; then
    log_error "age is not installed"
    echo ""
    echo "Installing age..."
    sudo apt update
    sudo apt install -y age
fi

# Check if encrypted file exists
if [ ! -f /opt/homelab/.env.age ]; then
    log_error "/opt/homelab/.env.age not found"
    echo ""
    echo "This could mean:"
    echo "  1. You haven't encrypted your .env yet (use ./scripts/encryption/encrypt-env.sh)"
    echo "  2. The encrypted file wasn't committed to the repository"
    echo "  3. You need to copy .env.age to /opt/homelab/"
    exit 1
fi

# Check if .env already exists
if [ -f /opt/homelab/.env ]; then
    log_warn "/opt/homelab/.env already exists"
    read -p "Overwrite? (y/N): " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "Decryption cancelled"
        exit 0
    fi
fi

log_info "Decrypting environment file..."
echo ""
log_warn "Enter the passphrase you used during encryption"
echo ""

# Decrypt the file
age -d /opt/homelab/.env.age > /opt/homelab/.env

if [ $? -eq 0 ]; then
    # Set secure permissions
    chmod 600 /opt/homelab/.env
    
    echo ""
    log_info "✓ Successfully decrypted: /opt/homelab/.env"
    log_info "✓ Permissions set to 600 (owner read/write only)"
    echo ""
    log_info "Your environment variables are ready!"
    log_info "You can now deploy your services via Portainer or CLI:"
    echo "  Option 1: Access Portainer at http://192.168.100.200:9000"
    echo "  Option 2: cd /opt/homelab && docker compose up -d"
else
    log_error "Decryption failed"
    log_error "Make sure you entered the correct passphrase"
    rm -f /opt/homelab/.env  # Remove partial file
    exit 1
fi