#!/bin/bash

# Restore Script for Homelab
# Restores from a backup archive

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

HOMELAB_DIR="$HOME/homelab"

# Check if backup file is provided
if [ -z "$1" ]; then
    log_error "Usage: $0 <backup-file.tar.gz>"
    exit 1
fi

BACKUP_FILE="$1"

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    log_error "Backup file not found: $BACKUP_FILE"
    exit 1
fi

# Confirm restore
log_warn "This will REPLACE your current homelab configuration!"
log_warn "Current location: $HOMELAB_DIR"
log_warn "Backup file: $BACKUP_FILE"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    log_info "Restore cancelled"
    exit 0
fi

# Stop current services if they exist
if [ -d "$HOMELAB_DIR" ] && [ -f "$HOMELAB_DIR/compose.yml" ]; then
    log_info "Stopping current services..."
    cd "$HOMELAB_DIR"
    podman-compose down 2>/dev/null || true
fi

# Backup current configuration (if exists)
if [ -d "$HOMELAB_DIR" ]; then
    BACKUP_OLD="${HOMELAB_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
    log_info "Backing up current configuration to: $BACKUP_OLD"
    mv "$HOMELAB_DIR" "$BACKUP_OLD"
fi

# Extract backup
log_info "Extracting backup..."
tar -xzf "$BACKUP_FILE" -C "$HOME"

# Start services
log_info "Starting services..."
cd "$HOMELAB_DIR"
podman-compose up -d

log_info "Restore complete!"
log_info "Services have been started"
