# Homelab Setup - Docker + Portainer

Complete homelab setup for Raspberry Pi using Docker, Portainer, and macvlan networking.

## 🚀 Features

- **Docker + Portainer**: Modern container management with web UI
- **macvlan Networking**: Each service gets its own IP address on your network
- **Automated Setup**: Idempotent scripts with checkpoint system
- **Encrypted Secrets**: Age encryption for sensitive data
- **Easy Management**: Deploy and manage services through Portainer

## 📋 Services

All services run with their own IP addresses:

| Service | IP | Ports | Description |
| --------- | ----- | ------- | ------------- |
| **Portainer** | 192.168.100.200 | 9000 | Container management UI |
| **UniFi Controller** | 192.168.100.201 | 8443 | Network management |
| **Nginx Proxy Manager** | 192.168.100.202 | 80, 443, 81 | Reverse proxy with SSL |
| **Pi-hole** | 192.168.100.203 | 80, 53 | DNS ad blocker |
| **Uptime Kuma** | 192.168.100.204 | 3001 | Uptime monitoring |
| **Home Assistant** | 192.168.100.205 | 8123 | Home automation |
| **Stirling PDF** | 192.168.100.206 | 8080 | PDF tools |
| **Homarr** | 192.168.100.207 | 7575 | Dashboard |
| **Dozzle** | 192.168.100.208 | 8080 | Container logs |

> **Note**: These IPs are examples based on `192.168.100.x` subnet. The setup script will detect your network and adjust automatically.

## 🔧 Prerequisites

- Raspberry Pi (or any Debian-based system)
- Ethernet connection (recommended for macvlan)
- SSH access

## 📥 Installation

### 1. Clone the Repository

```bash
sudo apt update && sudo apt install -y git && \
cd ~ && git clone https://github.com/BMogetta/test-homelab.git && \
cd test-homelab && chmod +x setup.sh && ./setup.sh
```

The script will:

1. Detect your system (Debian/DietPi)
2. Install essential tools
3. Install Docker and Docker Compose
4. Install Portainer with macvlan
5. Create the docker-compose.yml file
6. Configure ARP routes

### 2. Deploy Services

**Option A: Via Portainer (Recommended)**

1. Access Portainer: `http://192.168.100.200:9000`
2. Create admin account on first login
3. Go to **Stacks** → **Add stack**
4. Name it: `homelab`
5. Upload `/opt/homelab/compose.yml` OR paste its contents
6. Add environment variables from `/opt/homelab/.env`
7. Click **Deploy the stack**

**Option B: Via Command Line**

```bash
cd /opt/homelab
docker compose up -d
```

### 4. Configure ARP Routes

After deployment, ensure containers are accessible:

```bash
sudo systemctl restart macvlan-routes.service
sudo systemctl enable macvlan-routes.service
```

## 🔐 Environment Variables

Create a `.env` file in `/opt/homelab/` with:

```bash
# Timezone
TZ=America/Argentina/Buenos_Aires

# User IDs (get with: id -u / id -g)
PUID=1000
PGID=1000

# Pi-hole
PIHOLE_WEBPASSWORD=your_secure_password

# MongoDB (for UniFi)
MONGO_ROOT_PASS=your_root_password
MONGO_USER=unifi
MONGO_PASS=your_unifi_db_password
MONGO_DBNAME=unifi
```

> **Encrypted Setup**: If you have `.env.age`, decrypt it with:
>
> ```bash
> cd /opt/homelab
> age --decrypt -o .env .env.age
> ```

## 📁 Directory Structure

All service data is stored in `/opt`:

```sh
/opt/
├── homelab/
│   ├── compose.yml          # Docker Compose configuration
│   ├── .env                 # Environment variables
│   └── .env.age            # Encrypted environment (optional)
├── portainer/
│   └── data/
├── unifi/
│   ├── data/
│   ├── mongodb/
│   └── init-mongo.sh
├── nginx-proxy-manager/
│   ├── data/
│   └── letsencrypt/
├── pihole/
│   ├── etc-pihole/
│   └── etc-dnsmasq.d/
├── uptime-kuma/
│   └── data/
├── homeassistant/
│   └── config/
├── stirling-pdf/
│   ├── data/
│   └── configs/
└── homarr/
    ├── configs/
    ├── icons/
    └── data/
```

## 🌐 Network Configuration

### macvlan Explained

macvlan gives each container its own IP address on your network, making them appear as separate devices to your router.

**Advantages:**

- No port conflicts
- Easy access from any device
- Better for services like UniFi that need network discovery
- Clean separation of services

**Limitation:**

- The Raspberry Pi itself **cannot** access these IPs directly
- Use another device (phone, laptop, desktop) to configure services
- This is a Linux kernel limitation, not a bug

### Accessing Services

- **From other devices**: Just use the IP addresses (e.g., `http://192.168.100.200:9000`)
- **From the Pi itself**: Not possible due to macvlan limitation
- **DNS Configuration**: Set Pi-hole IP as DNS in your router to block ads network-wide

## 🔧 Management

### View Container Status

```bash
docker ps
```

### View Logs

```bash
# All containers
docker compose -f /opt/homelab/compose.yml logs -f

# Specific container
docker logs -f nginx-proxy-manager
```

### Restart Services

```bash
# Via Portainer: Stacks → homelab → Restart

# Via CLI:
docker compose -f /opt/homelab/compose.yml restart
docker compose -f /opt/homelab/compose.yml restart SERVICE_NAME
```

### Stop All Services

```bash
docker compose -f /opt/homelab/compose.yml down
```

### Start All Services

```bash
docker compose -f /opt/homelab/compose.yml up -d
```

## 🐛 Troubleshooting

### Services not accessible from network

```bash
# Check ARP routes
sudo systemctl status macvlan-routes.service
sudo systemctl restart macvlan-routes.service

# Manually verify routes
ip neigh show
```

### Container won't start

```bash
# Check logs
docker logs CONTAINER_NAME

# Check compose file syntax
docker compose -f /opt/homelab/compose.yml config
```

### Can't access from Pi itself

This is expected with macvlan. Use another device on your network.

### UniFi not discovering devices

1. Ensure UniFi Controller is at `.201` (critical for L3 adoption)
2. Check that macvlan routes are configured
3. Verify ARP table: `ip neigh show`

## 📊 Monitoring

- **Portainer**: Container stats, resource usage
- **Dozzle**: Real-time logs from all containers
- **Uptime Kuma**: Monitor service availability

## 🔄 Updates

### Update Single Service

Via Portainer:

1. Go to **Containers**
2. Select container
3. Click **Recreate** → Enable **Pull latest image**

Via CLI:

```bash
docker compose -f /opt/homelab/compose.yml pull SERVICE_NAME
docker compose -f /opt/homelab/compose.yml up -d SERVICE_NAME
```

### Update All Services

```bash
docker compose -f /opt/homelab/compose.yml pull
docker compose -f /opt/homelab/compose.yml up -d
```

## 🔒 Security

- Use strong passwords in `.env`
- Keep `.env` file permissions at `600`
- Regularly update containers
- Use Nginx Proxy Manager for SSL certificates
- Consider setting up a firewall (UFW)

## 🤝 Contributing

Feel free to open issues or submit pull requests!

## 📝 License

MIT License - See LICENSE file

---

## 🎯 Quick Start Checklist

- [ ] Clone repository
- [ ] Run `./setup.sh`
- [ ] Wait for Docker installation (may need to re-login)
- [ ] Access Portainer at `http://192.168.100.200:9000`
- [ ] Create admin account in Portainer
- [ ] Deploy stack via Portainer
- [ ] Configure ARP routes: `sudo systemctl restart macvlan-routes.service`
- [ ] Access services from phone/laptop (not from Pi)
- [ ] Configure each service as needed

## 📚 Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Portainer Documentation](https://docs.portainer.io/)
- [UniFi Network Application](https://help.ui.com/hc/en-us/categories/200320654-UniFi-Network-Application)
- [Pi-hole Documentation](https://docs.pi-hole.net/)
- [Nginx Proxy Manager](https://nginxproxymanager.com/)

---
