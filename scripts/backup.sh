#!/bin/bash

# Backup Script for Homelab
# Creates timestamped backup of all configurations and data

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

HOMELAB_DIR="$HOME/homelab"
BACKUP_DIR="$HOME/homelab-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="homelab-backup-${TIMESTAMP}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Stop services before backup
log_info "Stopping services..."
cd "$HOMELAB_DIR"
podman-compose down

# Create backup
log_info "Creating backup..."
tar -czf "$BACKUP_PATH" -C "$HOME" homelab

# Restart services
log_info "Restarting services..."
podman-compose up -d

# Display info
log_info "Backup created successfully!"
log_info "Backup location: $BACKUP_PATH"
log_info "Backup size: $(du -h "$BACKUP_PATH" | cut -f1)"

# Cleanup old backups (keep last 5)
log_info "Cleaning up old backups (keeping last 5)..."
ls -t "$BACKUP_DIR"/homelab-backup-*.tar.gz | tail -n +6 | xargs -r rm

log_info "Backup complete!"
