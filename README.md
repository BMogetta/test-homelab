# Homelab Setup - Debian 12 + Podman

Complete setup for self-hosted services using Debian 12 and Podman.

## Services Included

- UniFi Network Application
- Pi-hole (DNS Ad-blocker)
- Nginx Proxy Manager
- Uptime Kuma
- Home Assistant
- Stirling PDF
- Cockpit (Web UI for system management)

## Prerequisites

- Debian 12 (Bookworm)
- Systemd enabled
- Internet connection
- Sudo privileges

**For repository management:**
- Git configured with your email and name
- The setup script will prompt you to configure git if needed

## Quick Start

```bash
# Clone this repository
git clone https://github.com/YOUR_USERNAME/homelab-setup.git
cd homelab-setup

# Run the setup script (will prompt for git config if needed)
chmod +x setup.sh
./setup.sh
```

## First Time Setup (For Repository Owners)

If you're setting up this repository for the first time:

1. **Configure Git** (if not already done):
```bash
./scripts/setup-git.sh
# Or manually:
git config --global user.email "your.email@example.com"
git config --global user.name "Your Name"
git config --global init.defaultBranch main
```

2. **Run the setup**:
```bash
./setup.sh
```

3. **Encrypt your environment** (optional but recommended):
```bash
./scripts/encrypt-env.sh
```

4. **Initialize repository**:
```bash
git init -b main
git add .
git commit -m "feat: initial setup for test homelab"
git remote add origin https://github.com/YOUR_USERNAME/homelab-setup.git
git push -u origin main
```

## Manual Installation Steps

If you prefer to run steps individually:

### 1. System Preparation

```bash
./scripts/01-system-prep.sh
```

This will:
- Update system packages
- Install essential tools
- Configure timezone
- Verify systemd

### 2. Install Podman

```bash
./scripts/02-install-podman.sh
```

This will:
- Install Podman and podman-compose
- Enable podman socket
- Configure rootless mode

### 3. Install Cockpit

```bash
./scripts/03-install-cockpit.sh
```

This will:
- Install Cockpit and cockpit-podman
- Enable and start Cockpit service
- Configure firewall (if needed)

### 4. Deploy Services

```bash
./scripts/04-deploy-services.sh
```

This will:
- Create directory structure
- Generate configuration files
- Start all containers

## Service Access

After deployment, services will be available at:

- **Cockpit**: https://localhost:9090
- **Nginx Proxy Manager**: http://localhost:81
- **Pi-hole**: http://localhost:8080 (admin: /admin)
- **UniFi Controller**: https://localhost:8443
- **Uptime Kuma**: http://localhost:3001
- **Home Assistant**: http://localhost:8123
- **Stirling PDF**: http://localhost:8082

## Directory Structure

```
~/homelab/
├── unifi/
│   ├── data/
│   └── mongodb/
├── pihole/
│   ├── etc-pihole/
│   └── etc-dnsmasq.d/
├── nginx-proxy-manager/
│   ├── data/
│   └── letsencrypt/
├── uptime-kuma/
│   └── data/
├── homeassistant/
│   └── config/
├── stirling-pdf/
│   ├── data/
│   └── configs/
└── compose.yml
```

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and customize:

```bash
cp .env.example .env
nano .env
```

### Encrypted Environment Variables (Optional but Recommended)

You can encrypt your `.env` file to safely store it in the repository:

```bash
# After configuring your .env with real passwords
./scripts/encrypt-env.sh

# Commit the encrypted file
git add .env.age
git commit -m "feat: add encrypted environment"
```

### Optional Configuration Backups (Advanced)

You can also backup and encrypt your personalized configurations:

```bash
# After customizing services (git, SSH, Homarr, etc.)
./scripts/encrypt-config.sh

# Commit encrypted configs
git add configs/
git commit -m "feat: add encrypted configurations"
```

This allows you to restore:
- Git configuration (user/email)
- SSH keys
- Service customizations (Homarr dashboard, Nginx proxy hosts, Pi-hole lists)

On a fresh installation, the setup script will automatically detect and offer to decrypt both `.env.age` and any configs in `configs/`.

**See [ENCRYPTION.md](./ENCRYPTION.md) and [configs/README.md](./configs/README.md) for detailed instructions.**

### Podman Compose File

The main compose file is located at `~/homelab/compose.yml`

To manage services:

```bash
cd ~/homelab

# Start all services
podman-compose up -d

# Stop all services
podman-compose down

# View logs
podman-compose logs -f

# Restart a specific service
podman-compose restart pihole
```

## Backup and Restore

### Backup

```bash
./scripts/backup.sh
```

Creates a timestamped backup in `~/homelab-backups/`

### Restore

```bash
./scripts/restore.sh ~/homelab-backups/backup-TIMESTAMP.tar.gz
```

## Troubleshooting

### Check Podman Status

```bash
systemctl --user status podman.socket
podman ps -a
```

### Check Service Logs

```bash
cd ~/homelab
podman-compose logs SERVICE_NAME
```

### Reset Everything

```bash
./scripts/reset.sh
```

**WARNING**: This will remove all containers, volumes, and data!

## Updates

### Update System

```bash
sudo apt update && sudo apt upgrade -y
```

### Update Containers

```bash
cd ~/homelab
podman-compose pull
podman-compose up -d
```

## Platform Support

- ✅ WSL2 (Debian)
- ✅ Raspberry Pi 5 (Debian 12 ARM64)
- ✅ Proxmox LXC (Debian 12)
- ✅ Bare metal Debian 12

## License

MIT

## Contributing

Pull requests welcome!
