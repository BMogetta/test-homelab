# Troubleshooting Guide

## Common Issues and Solutions

### Podman Issues

#### podman-compose not found

**Problem**: `podman-compose: command not found`

**Solution**:
```bash
# Reload your shell configuration
source ~/.bashrc

# Or manually add to PATH
export PATH="$HOME/.local/bin:$PATH"

# Verify installation
which podman-compose
```

#### Permission Denied on Socket

**Problem**: Cannot connect to Podman socket

**Solution**:
```bash
# Enable and start user socket
systemctl --user enable podman.socket --now

# Verify it's running
systemctl --user status podman.socket

# Set XDG_RUNTIME_DIR if not set
export XDG_RUNTIME_DIR=/run/user/$(id -u)
```

#### Containers Won't Start

**Problem**: Containers fail to start with various errors

**Solution**:
```bash
# Check logs
cd ~/homelab
podman-compose logs SERVICE_NAME

# Check Podman status
podman ps -a

# Try restarting services
podman-compose restart

# If all else fails, recreate containers
podman-compose down
podman-compose up -d
```

### UniFi Controller Issues

#### UniFi Controller Won't Start

**Problem**: UniFi controller container crashes or won't start

**Solution**:
```bash
# Check MongoDB is running
podman ps | grep unifi-db

# Check UniFi logs
podman logs unifi-controller

# Verify database connection
podman exec -it unifi-db mongosh --eval "db.version()"

# Common fix: recreate containers
cd ~/homelab
podman-compose stop unifi-controller unifi-db
podman-compose rm -f unifi-controller unifi-db
podman-compose up -d unifi-controller
```

#### Can't Access UniFi on Port 8443

**Problem**: https://localhost:8443 doesn't load

**Solution**:
```bash
# Verify port is listening
ss -tlnp | grep 8443

# Check if container is running
podman ps | grep unifi-controller

# Check container ports
podman port unifi-controller

# Check logs for errors
podman logs unifi-controller | tail -50
```

### Pi-hole Issues

#### Pi-hole Web Interface Not Accessible

**Problem**: Can't access http://localhost:8080/admin

**Solution**:
```bash
# Check if container is running
podman ps | grep pihole

# Check logs
podman logs pihole

# Verify password is set
cd ~/homelab
grep PIHOLE_WEBPASSWORD .env

# Reset password
podman exec -it pihole pihole -a -p newpassword
```

#### DNS Not Working

**Problem**: DNS queries not being answered

**Solution**:
```bash
# Check if port 53 is available
sudo ss -tulnp | grep :53

# Verify Pi-hole is running
podman ps | grep pihole

# Test DNS
dig @127.0.0.1 google.com

# Check Pi-hole logs
podman logs pihole | grep -i error
```

### Cockpit Issues

#### Can't Access Cockpit

**Problem**: https://localhost:9090 doesn't load

**Solution**:
```bash
# Check if Cockpit is running
sudo systemctl status cockpit.socket

# Start if not running
sudo systemctl start cockpit.socket

# Check firewall (if using UFW)
sudo ufw status

# Allow through firewall if needed
sudo ufw allow 9090/tcp
```

#### Podman Containers Not Visible in Cockpit

**Problem**: Cockpit doesn't show Podman containers

**Solution**:
```bash
# Verify cockpit-podman is installed
dpkg -l | grep cockpit-podman

# Install if missing
sudo apt install cockpit-podman

# Restart Cockpit
sudo systemctl restart cockpit.socket

# Verify Podman socket is running
systemctl --user status podman.socket
```

### Network Issues

#### Port Already in Use

**Problem**: Error: "address already in use"

**Solution**:
```bash
# Find what's using the port (example: port 80)
sudo ss -tlnp | grep :80

# Kill the process if needed
sudo kill <PID>

# Or change the port in compose.yml
# For example, change "80:80" to "8090:80"
```

#### Can't Access Services from Other Devices

**Problem**: Services work on localhost but not from other machines

**Solution**:
```bash
# Check if listening on all interfaces
ss -tlnp | grep <PORT>
# Should show 0.0.0.0:<PORT>, not 127.0.0.1:<PORT>

# If on WSL, you may need to forward ports from Windows
# In PowerShell as Administrator:
netsh interface portproxy add v4tov4 listenport=<PORT> listenaddress=0.0.0.0 connectport=<PORT> connectaddress=<WSL_IP>

# Get WSL IP
wsl hostname -I
```

### Storage Issues

#### Out of Space

**Problem**: No space left on device

**Solution**:
```bash
# Check disk usage
df -h

# Check Podman storage
podman system df

# Clean up unused images
podman image prune -a

# Clean up unused volumes
podman volume prune

# Clean up unused containers
podman container prune
```

### WSL-Specific Issues

#### systemd Not Available

**Problem**: systemd commands don't work in WSL

**Solution**:
```bash
# Enable systemd in WSL
sudo nano /etc/wsl.conf

# Add:
[boot]
systemd=true

# Exit WSL and shutdown from PowerShell
wsl --shutdown

# Restart WSL
wsl
```

#### Podman Network Errors (nftables/netavark)

**Problem**: Containers fail to start with errors like:
```
Error: netavark: nftables error: nft did not return successfully
failed to move the rootless netns pasta process to the systemd user.slice
dial unix /run/user/1000/bus: connect: no such file or directory
```

**Solution**:

WSL2 has limitations with nftables and systemd user sessions. Configure Podman to work around these:

```bash
# Create Podman configuration for WSL2
mkdir -p ~/.config/containers

cat > ~/.config/containers/containers.conf << 'EOF'
[engine]
cgroup_manager = "cgroupfs"
events_logger = "file"

[network]
network_backend = "netavark"
firewall_driver = "none"
EOF

# Reset Podman
podman system reset --force

# Restart WSL from PowerShell
exit
```

Then from PowerShell:
```powershell
wsl --shutdown
wsl -d Debian
```

Start services again:
```bash
cd ~/homelab
podman-compose up -d
```

**Note**: This configuration is **only needed for WSL2**. On a real Raspberry Pi or native Linux installation, this workaround is not necessary.

#### Privileged Ports Error (Ports < 1024)

**Problem**: Containers fail to start with errors like:
```
Error: rootlessport cannot expose privileged port 80
Error: rootlessport cannot expose privileged port 53
you can add 'net.ipv4.ip_unprivileged_port_start=80' to /etc/sysctl.conf
```

**Explanation**: In rootless Podman, ports below 1024 are considered "privileged" and require special permissions.

**Solution - Option 1: Lower the privileged port range (Recommended for WSL2)**

```bash
# Allow unprivileged ports starting from 53
echo "net.ipv4.ip_unprivileged_port_start=53" | sudo tee -a /etc/sysctl.conf

# Apply the change
sudo sysctl -p

# Restart WSL from PowerShell
exit
```

From PowerShell:
```powershell
wsl --shutdown
wsl -d Debian
```

Start services:
```bash
cd ~/homelab
podman-compose up -d
```

**Solution - Option 2: Change ports in compose.yml (Alternative)**

Edit `~/homelab/compose.yml` and change problematic ports:

```yaml
# Example: Change Nginx Proxy Manager ports
nginx-proxy-manager:
  ports:
    - "8080:80"    # Changed from 80:80
    - "81:81"      # Keep as is
    - "8443:443"   # Changed from 443:443

# Example: Change Pi-hole DNS port
pihole:
  ports:
    - "5353:53/tcp"   # Changed from 53:53/tcp
    - "5353:53/udp"   # Changed from 53:53/udp
    - "8080:80/tcp"   # Keep as is
```

Then restart:
```bash
cd ~/homelab
podman-compose down
podman-compose up -d
```

**Solution - Option 3: Run specific containers as root (Not Recommended)**

Only use this for testing:
```bash
# Run a specific container with sudo (loses rootless benefits)
sudo podman run -d --name pihole -p 53:53 pihole/pihole
```

#### Port 1900 Already in Use (UniFi Controller)

**Problem**: 
```
Error: rootlessport listen udp 0.0.0.0:1900: bind: address already in use
```

**Cause**: Windows services often use UDP port 1900 (SSDP for UPnP)

**Solution - Option 1: Change the port in compose.yml**

Edit `~/homelab/compose.yml`:

```yaml
unifi-controller:
  ports:
    # Comment out or remove the 1900 port
    # - "1900:1900/udp"  # L2 discovery - not critical
    - "8443:8443"   # Keep
    - "3478:3478/udp"  # Keep
    # ... other ports
```

The 1900 port is only used for UPnP device discovery and is not critical for UniFi operation.

**Solution - Option 2: Find and stop the Windows service using port 1900**

From PowerShell as Administrator:
```powershell
# Find what's using port 1900
netstat -ano | findstr :1900

# Stop SSDP Discovery service (if you don't need it)
Stop-Service SSDPSRV
Set-Service SSDPSRV -StartupType Disabled
```

#### Shared Mount Warnings

**Problem**: Warnings about "/" not being a shared mount

```
WARN[0000] "/" is not a shared mount, this could cause issues
```

**Solution**: These warnings are cosmetic in WSL2 and can usually be ignored. If you experience actual mount issues:

```bash
# Add to /etc/wsl.conf (requires WSL restart)
sudo nano /etc/wsl.conf

# Add:
[automount]
options = "metadata"
```

Then restart WSL from PowerShell:
```powershell
wsl --shutdown
```

#### Services Don't Start on Boot

**Problem**: Containers don't start when WSL starts

**Solution**:

Create a startup script:
```bash
# Create script
cat > ~/start-homelab.sh << 'EOF'
#!/bin/bash
cd ~/homelab
podman-compose up -d
EOF

chmod +x ~/start-homelab.sh

# Add to .bashrc
echo '~/start-homelab.sh &' >> ~/.bashrc
```

#### Performance Considerations

**Important**: WSL2 may have slower I/O performance compared to native Linux. For production use, always prefer:
- Raspberry Pi with native Debian
- Proxmox LXC container
- Bare metal Linux installation

WSL2 is excellent for testing and development, but not recommended for production homelab deployments.

## Getting Help

If you're still having issues:

1. Check the logs: `podman-compose logs -f`
2. Search for your error message online
3. Check Podman documentation: https://docs.podman.io/
4. Check service-specific documentation
5. Open an issue on the GitHub repository

## Useful Commands

```bash
# View all containers (running and stopped)
podman ps -a

# View logs for all services
cd ~/homelab && podman-compose logs -f

# Restart a specific service
cd ~/homelab && podman-compose restart SERVICE_NAME

# Rebuild a container
cd ~/homelab && podman-compose up -d --force-recreate SERVICE_NAME

# Check resource usage
podman stats

# Enter a container shell
podman exec -it CONTAINER_NAME /bin/bash

# Clean up everything
podman system prune -a --volumes
```
