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
if [ ! -f ~/homelab/.env.age ]; then
    log_error "~/homelab/.env.age not found"
    echo ""
    echo "This could mean:"
    echo "  1. You haven't encrypted your .env yet (use ./scripts/encrypt-env.sh)"
    echo "  2. The encrypted file wasn't committed to the repository"
    echo "  3. You need to copy .env.age to ~/homelab/"
    exit 1
fi

# Check if .env already exists
if [ -f ~/homelab/.env ]; then
    log_warn "~/homelab/.env already exists"
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
age -d ~/homelab/.env.age > ~/homelab/.env

if [ $? -eq 0 ]; then
    echo ""
    log_info "✓ Successfully decrypted: ~/homelab/.env"
    echo ""
    log_info "Your environment variables are ready!"
    log_info "You can now start your services:"
    echo "  cd ~/homelab"
    echo "  podman-compose up -d"
else
    log_error "Decryption failed"
    log_error "Make sure you entered the correct passphrase"
    rm -f ~/homelab/.env  # Remove partial file
    exit 1
fi
