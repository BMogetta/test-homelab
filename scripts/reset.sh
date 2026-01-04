#!/bin/bash

# Reset Script - Remove all containers and data
# WARNING: This is destructive!

set -e

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
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

HOMELAB_DIR="$HOME/homelab"

# Warning
echo ""
log_error "╔════════════════════════════════════════════════════════╗"
log_error "║              WARNING - DESTRUCTIVE ACTION              ║"
log_error "╚════════════════════════════════════════════════════════╝"
echo ""
log_warn "This will:"
log_warn "  - Stop all containers"
log_warn "  - Remove all containers"
log_warn "  - Remove all container data and configurations"
log_warn "  - Delete the homelab directory"
echo ""
log_error "THIS CANNOT BE UNDONE!"
echo ""
read -p "Type 'DELETE EVERYTHING' to continue: " confirm

if [ "$confirm" != "DELETE EVERYTHING" ]; then
    log_info "Reset cancelled"
    exit 0
fi

echo ""
read -p "Are you ABSOLUTELY sure? (yes/no): " confirm2

if [ "$confirm2" != "yes" ]; then
    log_info "Reset cancelled"
    exit 0
fi

# Stop and remove containers
if [ -d "$HOMELAB_DIR" ] && [ -f "$HOMELAB_DIR/compose.yml" ]; then
    log_info "Stopping and removing containers..."
    cd "$HOMELAB_DIR"
    podman-compose down -v 2>/dev/null || true
fi

# Remove homelab directory
if [ -d "$HOMELAB_DIR" ]; then
    log_info "Removing homelab directory..."
    rm -rf "$HOMELAB_DIR"
fi

# Remove any orphaned containers
log_info "Cleaning up any orphaned containers..."
podman container prune -f 2>/dev/null || true

# Remove unused images
log_info "Removing unused images..."
podman image prune -f 2>/dev/null || true

# Remove unused volumes
log_info "Removing unused volumes..."
podman volume prune -f 2>/dev/null || true

log_info "Reset complete!"
log_info "You can now run setup.sh to start fresh"
