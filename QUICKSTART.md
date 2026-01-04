# Quick Start Guide

## You Are Here: WSL2 Debian Setup

You've already completed steps 6, 7, and 8 from the original plan. Here's what to do next.

## Current Status ✓

- ✓ Debian installed in WSL2
- ✓ System updated
- ✓ Essential tools installed
- ✓ systemd verified and working

## Next Steps

### Option 1: Quick Setup (Recommended)

Run everything automatically:

```bash
# Clone or download this repository
cd ~
git clone <YOUR_GITHUB_REPO_URL> homelab-setup
# OR if you already have the files, skip the clone

cd homelab-setup
chmod +x setup.sh
./setup.sh
```

This will:
1. Install Podman
2. Install Cockpit
3. Deploy all services
4. Set everything up automatically

### Option 2: Step-by-Step Setup

If you want more control:

```bash
cd ~/homelab-setup

# Step 1: Install Podman
chmod +x scripts/02-install-podman.sh
./scripts/02-install-podman.sh

# Step 2: Install Cockpit (Web UI)
chmod +x scripts/03-install-cockpit.sh
./scripts/03-install-cockpit.sh

# Step 3: Deploy Services
chmod +x scripts/04-deploy-services.sh
./scripts/04-deploy-services.sh
```

## After Installation

### 1. Access Your Services

Open these URLs in your browser:

- Cockpit: https://localhost:9090
- Nginx Proxy Manager: http://localhost:81
- Pi-hole: http://localhost:8080/admin
- UniFi Controller: https://localhost:8443
- Uptime Kuma: http://localhost:3001
- Home Assistant: http://localhost:8123
- Stirling PDF: http://localhost:8082

### 2. Change Default Passwords

Edit the environment file:
```bash
nano ~/homelab/.env
```

Change these values:
- `PIHOLE_WEBPASSWORD=changeme123` → Use a strong password
- `MONGO_PASS=changeme123` → Use a strong password

Then restart services:
```bash
cd ~/homelab
podman-compose restart
```

### 3. Configure Nginx Proxy Manager

1. Go to http://localhost:81
2. Login with:
   - Email: `admin@example.com`
   - Password: `changeme`
3. **Immediately change** email and password
4. Create proxy hosts for your services (optional, but recommended)

## Common Tasks

### View Running Containers
```bash
podman ps
```

### View Logs
```bash
cd ~/homelab
podman-compose logs -f
```

### Restart a Service
```bash
cd ~/homelab
podman-compose restart SERVICE_NAME
```

### Stop Everything
```bash
cd ~/homelab
podman-compose down
```

### Start Everything
```bash
cd ~/homelab
podman-compose up -d
```

### Backup Your Config
```bash
cd ~/homelab-setup
./scripts/backup.sh
```

## Troubleshooting

If something doesn't work, check `TROUBLESHOOTING.md` for common issues and solutions.

## When You Get Your Raspberry Pi

This exact same setup will work on:
- Raspberry Pi 5 (Debian 12 ARM64)
- Proxmox LXC container (Debian 12)
- Any Debian 12 system

Just clone this repo and run `./setup.sh`!

## GitHub Repository Setup

To make this replicable from GitHub:

```bash
cd ~/homelab-setup

# Initialize git (if not already done)
git init

# Add files
git add .

# Commit
git commit -m "Initial homelab setup"

# Add your GitHub remote
git remote add origin https://github.com/YOUR_USERNAME/homelab-setup.git

# Push
git push -u origin main
```

Then from any Debian system:
```bash
git clone https://github.com/YOUR_USERNAME/homelab-setup.git
cd homelab-setup
./setup.sh
```

## Notes

- All scripts are **idempotent** - you can run them multiple times safely
- The setup checks if things are already installed before installing
- You can resume from any point without breaking anything

## Need Help?

- Check `README.md` for detailed documentation
- Check `SERVICES.md` for service-specific guides
- Check `TROUBLESHOOTING.md` for common issues
