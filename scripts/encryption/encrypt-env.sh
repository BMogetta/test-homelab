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
if [ ! -f /opt/homelab/.env ]; then
    log_error "/opt/homelab/.env not found"
    echo ""
    echo "Make sure you've deployed services first:"
    echo "  cd ~/homelab-setup"
    echo "  ./setup.sh"
    exit 1
fi

log_info "Encrypting environment file..."
echo ""
log_warn "You will be prompted for a passphrase"
log_warn "REMEMBER THIS PASSPHRASE - you'll need it for decryption!"
echo ""

# Encrypt the file
age -p -o /opt/homelab/.env.age /opt/homelab/.env

if [ $? -eq 0 ]; then
    echo ""
    log_info "✓ Successfully encrypted: /opt/homelab/.env.age"
    echo ""
    log_info "Next steps:"
    echo "  1. Copy to repo: cp /opt/homelab/.env.age ~/your-repo/"
    echo "  2. Add to git: git add .env.age"
    echo "  3. Commit: git commit -m 'feat: update encrypted environment'"
    echo "  4. Push: git push"
    echo ""
    log_warn "NEVER commit /opt/homelab/.env (unencrypted)"
    log_warn "Add to .gitignore: echo '.env' >> .gitignore"
else
    log_error "Encryption failed"
    exit 1
fi