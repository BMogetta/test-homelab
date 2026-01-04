#!/bin/bash

# Git Configuration Script
# Sets up git user and default branch

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_info "=== Git Configuration ==="
echo ""

# Check current git config
current_email=$(git config --global user.email 2>/dev/null || echo "")
current_name=$(git config --global user.name 2>/dev/null || echo "")

if [ -n "$current_email" ] && [ -n "$current_name" ]; then
    log_info "Git is already configured:"
    echo "  Email: $current_email"
    echo "  Name:  $current_name"
    echo ""
    read -p "Keep this configuration? (Y/n): " keep_config
    
    if [[ "$keep_config" =~ ^[Nn]$ ]]; then
        current_email=""
        current_name=""
    fi
fi

# Prompt for email if not set or user wants to change
if [ -z "$current_email" ]; then
    echo ""
    read -p "Enter your Git email: " git_email
    git config --global user.email "$git_email"
    log_info "✓ Email set to: $git_email"
fi

# Prompt for name if not set or user wants to change
if [ -z "$current_name" ]; then
    echo ""
    read -p "Enter your Git name: " git_name
    git config --global user.name "$git_name"
    log_info "✓ Name set to: $git_name"
fi

# Set default branch to main
current_branch=$(git config --global init.defaultBranch 2>/dev/null || echo "")

if [ "$current_branch" != "main" ]; then
    git config --global init.defaultBranch main
    log_info "✓ Default branch set to: main"
else
    log_info "✓ Default branch already set to: main"
fi

echo ""
log_info "Git configuration complete!"
echo ""
log_info "Current configuration:"
echo "  Email:          $(git config --global user.email)"
echo "  Name:           $(git config --global user.name)"
echo "  Default branch: $(git config --global init.defaultBranch)"
