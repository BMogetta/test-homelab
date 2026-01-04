# Test Homelab - Debian 12 + Podman

Complete self-hosted homelab setup using Debian 12 and Podman.

## Services Included

- **UniFi Network Application** - Network controller
- **Pi-hole** - DNS ad-blocker
- **Nginx Proxy Manager** - Reverse proxy with SSL
- **Uptime Kuma** - Uptime monitoring
- **Home Assistant** - Home automation
- **Stirling PDF** - PDF tools
- **Homarr** - Modern dashboard
- **Dozzle** - Container logs and monitoring
- **Cockpit** - System management web UI

## Quick Start

### For Debian / Raspberry Pi
```bash
# Install git
sudo apt update && sudo apt install -y git

# Clone repository
cd ~
git clone https://github.com/BMogetta/test-homelab.git
cd test-homelab

# Run setup
chmod +x setup.sh
./setup.sh
```

The setup will:
- Install all dependencies (Podman, Cockpit, etc.)
- Configure git (prompts for email/name)
- Detect and decrypt `.env.age` (prompts for passphrase)
- Deploy all services automatically

### For WSL2 (Testing Only)

**Important:** WSL2 is for testing only. For production, use Raspberry Pi or native Debian.
```bash
sudo apt update && sudo apt install -y git && \
cd ~ && git clone https://github.com/BMogetta/test-homelab.git && \
cd test-homelab && chmod +x scripts/*.sh && ./scripts/wsl2-fixes.sh
```

```bash
# Exit and restart WSL
exit
```

From PowerShell:
```powershell
wsl --shutdown
wsl -d Debian
```
```bash
# Now run setup
cd ~/test-homelab && ./setup.sh
```

**WSL2 Limitations:** See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for issues.

## Service Access

After deployment:

| Service | URL | Notes |
|---------|-----|-------|
| Homarr Dashboard | http://localhost:7575 | Create admin on first run |
| Dozzle (Logs) | http://localhost:8888 | Real-time container logs |
| Cockpit | https://localhost:9090 | System management |
| Nginx Proxy Manager | http://localhost:81 | admin@example.com / changeme |
| Pi-hole | http://localhost:8080/admin | Password in .env |
| UniFi Controller | https://localhost:8443 | Follow setup wizard |
| Uptime Kuma | http://localhost:3001 | Create admin on first run |
| Home Assistant | http://localhost:8123 | Follow setup wizard |
| Stirling PDF | http://localhost:8082 | Ready to use |

## Configuration

### Encrypted Environment Variables

Your `.env.age` contains encrypted credentials. The setup script will prompt for the passphrase to decrypt it.

To update credentials later:
```bash
# Edit .env
nano ~/homelab/.env

# Re-encrypt
./scripts/encrypt-env.sh

# Commit changes
git add .env.age
git commit -m "chore: update credentials"
git push
```

### Optional Configuration Backups

Backup your customizations (git config, SSH keys, service configs):
```bash
# After customizing your homelab
./scripts/encrypt-config.sh

# Commit
git add configs/
git commit -m "feat: add encrypted configurations"
git push
```

On next fresh install, these will be automatically restored.

## Useful Commands
```bash
# View running containers
podman ps

# View logs
cd ~/homelab
podman-compose logs -f

# Restart a service
podman-compose restart SERVICE_NAME

# Stop all services
podman-compose down

# Start all services
podman-compose up -d

# Backup configuration
cd ~/test-homelab
./scripts/backup.sh
```

## Documentation

- [ENCRYPTION.md](./ENCRYPTION.md) - Detailed encryption guide
- [SERVICES.md](./SERVICES.md) - Service-specific documentation
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - Common issues and solutions
- [configs/README.md](./configs/README.md) - Optional configs guide

## Platform Support

- ✅ Raspberry Pi 5 (Debian 12 ARM64) - **Recommended**
- ✅ Proxmox LXC (Debian 12)
- ✅ Bare metal Debian 12
- ⚠️  WSL2 (Testing only - has limitations)

## License

MIT
