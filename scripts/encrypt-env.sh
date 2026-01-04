#!/bin/bash

# Encrypt .env file for safe repository storage
# Use this BEFORE committing your environment variables

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
    echo "Install with:"
    echo "  sudo apt install age"
    exit 1
fi

# Check if .env exists
if [ ! -f ~/homelab/.env ]; then
    log_error "~/homelab/.env not found"
    echo ""
    echo "Make sure you've deployed services first:"
    echo "  cd ~/homelab-setup"
    echo "  ./scripts/04-deploy-services.sh"
    exit 1
fi

log_info "Encrypting environment file..."
echo ""
log_warn "You will be prompted for a passphrase"
log_warn "REMEMBER THIS PASSPHRASE - you'll need it for decryption!"
echo ""

# Encrypt the file
age -p -o ~/homelab/.env.age ~/homelab/.env

if [ $? -eq 0 ]; then
    echo ""
    log_info "✓ Successfully encrypted: ~/homelab/.env.age"
    echo ""
    log_info "Next steps:"
    echo "  1. Add to git: git add ~/homelab/.env.age"
    echo "  2. Commit: git commit -m 'Update encrypted environment'"
    echo "  3. Push: git push"
    echo ""
    log_warn "NEVER commit ~/homelab/.env (unencrypted)"
else
    log_error "Encryption failed"
    exit 1
fi
