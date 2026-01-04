# Services Guide

Detailed information about each service in the homelab setup.

## Nginx Proxy Manager

**Purpose**: Reverse proxy with SSL/TLS management via web UI

**Access**: http://localhost:81

**Default Credentials**:
- Email: `admin@example.com`
- Password: `changeme`

**First Time Setup**:
1. Log in with default credentials
2. Change email and password immediately
3. Add proxy hosts for your services
4. Enable SSL certificates (Let's Encrypt)

**Common Use Cases**:
- Create custom domains for your services (e.g., pihole.local → localhost:8080)
- Enable HTTPS with automatic SSL certificates
- Add authentication to services that don't have it

**Documentation**: https://nginxproxymanager.com/guide/

---

## Pi-hole

**Purpose**: Network-wide ad blocker and DNS server

**Access**: http://localhost:8080/admin

**Password**: Set in `.env` file (`PIHOLE_WEBPASSWORD`)

**First Time Setup**:
1. Access the admin interface
2. Configure your network to use this as DNS server
3. Add custom blocklists if desired
4. Review dashboard and statistics

**Common Configuration**:
```bash
# Reset password
podman exec -it pihole pihole -a -p newpassword

# Update gravity (blocklists)
podman exec -it pihole pihole -g

# View logs
podman logs pihole -f
```

**Recommended Blocklists**:
- Included by default
- Add more from: https://firebog.net/

**Documentation**: https://docs.pi-hole.net/

---

## UniFi Network Application

**Purpose**: Network controller for UniFi devices (APs, Switches, Gateways)

**Access**: https://localhost:8443

**First Time Setup**:
1. Accept security warning (self-signed certificate)
2. Follow setup wizard
3. Create admin account
4. Skip UniFi Cloud setup (or configure if desired)
5. Adopt your UniFi devices

**Database**: MongoDB 4.4 (runs as separate container)

**Important Ports**:
- 8443: Web UI (HTTPS)
- 8080: Device communication
- 3478: STUN
- 10001: AP discovery

**Common Tasks**:
```bash
# View UniFi logs
podman logs unifi-controller -f

# Restart controller
cd ~/homelab && podman-compose restart unifi-controller

# Access MongoDB
podman exec -it unifi-db mongosh
```

**Documentation**: https://help.ui.com/

---

## Uptime Kuma

**Purpose**: Self-hosted monitoring tool (like Uptime Robot)

**Access**: http://localhost:3001

**First Time Setup**:
1. Create admin account
2. Add monitors for your services
3. Configure notifications (email, Discord, Telegram, etc.)

**Common Monitors to Add**:
- HTTP(s) monitors for all your web services
- Ping monitors for network devices
- Port monitors for non-HTTP services
- Keyword monitors to check page content

**Features**:
- Beautiful status pages
- Multi-language support
- Notifications via 90+ services
- Certificate expiry monitoring

**Documentation**: https://github.com/louislam/uptime-kuma/wiki

---

## Home Assistant

**Purpose**: Home automation platform

**Access**: http://localhost:8123

**First Time Setup**:
1. Create your account
2. Set up your location
3. Discover devices on your network
4. Install integrations for your smart devices

**Common Integrations**:
- UniFi Network (to monitor network devices)
- Pi-hole (to see stats)
- Weather integrations
- Smart home devices (lights, sensors, etc.)

**Configuration**: 
- Config files in `~/homelab/homeassistant/config/`
- Edit `configuration.yaml` for advanced settings

**Add-ons**: Not available in Docker version (use HAOS for add-ons)

**Documentation**: https://www.home-assistant.io/docs/

---

## Stirling PDF

**Purpose**: PDF manipulation tools (merge, split, convert, OCR, etc.)

**Access**: http://localhost:8082

**No Setup Required**: Just start using!

**Features**:
- Merge/Split PDFs
- Convert to/from PDF
- Compress PDFs
- OCR (Optical Character Recognition)
- Add/Remove pages
- Rotate pages
- Add watermarks
- Fill forms
- Sign PDFs

**Privacy**: All processing happens locally, nothing sent to cloud

**Documentation**: https://github.com/Stirling-Tools/Stirling-PDF

---

## Cockpit

**Purpose**: Web-based system administration interface

**Access**: https://localhost:9090

**Login**: Use your system username and password

**Features**:
- System overview (CPU, RAM, disk usage)
- Podman container management
- Storage management
- Network configuration
- Logs viewer
- Terminal access

**Useful for**:
- Viewing system resources
- Managing containers visually
- Quick system checks
- Log analysis

**Documentation**: https://cockpit-project.org/guide/latest/

---

## Service Dependencies

Some services depend on others:

```
unifi-controller → unifi-db (MongoDB)
```

All other services are independent and can run standalone.

---

## Resource Usage (Approximate)

Based on Raspberry Pi 5 with 8GB RAM:

| Service | RAM Usage | Notes |
|---------|-----------|-------|
| Nginx Proxy Manager | ~100MB | Lightweight |
| Pi-hole | ~50MB | Very lightweight |
| UniFi Controller | ~500MB | Most resource-intensive |
| MongoDB (UniFi DB) | ~200MB | Required for UniFi |
| Uptime Kuma | ~100MB | Lightweight |
| Home Assistant | ~200MB | Can increase with integrations |
| Stirling PDF | ~150MB | On-demand usage |
| **Total** | **~1.3GB** | Leaves ~6.7GB free on 8GB system |

---

## Backup Recommendations

**Critical Data** (backup regularly):
- UniFi configuration: `~/homelab/unifi/`
- Pi-hole configuration: `~/homelab/pihole/`
- Home Assistant: `~/homelab/homeassistant/`

**Less Critical**:
- Uptime Kuma: `~/homelab/uptime-kuma/`
- Nginx Proxy Manager: `~/homelab/nginx-proxy-manager/`

**Use the backup script**:
```bash
cd homelab-setup
./scripts/backup.sh
```

---

## Security Recommendations

1. **Change Default Passwords**
   - Nginx Proxy Manager: First login
   - Pi-hole: In `.env` file

2. **Use Nginx Proxy Manager for SSL**
   - Enable HTTPS for all services
   - Use Let's Encrypt certificates

3. **Network Isolation**
   - Consider running on isolated VLAN
   - Use firewall rules if exposed to internet

4. **Regular Updates**
   ```bash
   cd ~/homelab
   podman-compose pull
   podman-compose up -d
   ```

5. **Backup Regularly**
   ```bash
   ./scripts/backup.sh
   ```

---

## Optional Enhancements

Consider adding these services later:

- **Vaultwarden**: Password manager
- **Jellyfin/Plex**: Media server
- **Nextcloud**: File sync and sharing
- **Grafana + Prometheus**: Advanced monitoring
- **Authentik/Authelia**: Single Sign-On (SSO)
- **Tailscale**: Secure remote access
- **Watchtower**: Auto-update containers
