# Deploying to Portainer - Step by Step Guide

This guide walks you through deploying your homelab stack using Portainer's web interface.

## Prerequisites

- Portainer installed and running at `http://192.168.100.200:9000`
- Docker Compose file created at `/opt/homelab/compose.yml`
- Environment variables in `/opt/homelab/.env`

## Option 1: Deploy via Portainer Web UI (Recommended)

### Step 1: Access Portainer

1. Open your browser (from any device EXCEPT the Raspberry Pi)
2. Navigate to: `http://192.168.100.200:9000`
3. Log in with your admin credentials

> **First time?** You'll need to create an admin account. Choose a strong password!

### Step 2: Select Environment

1. Click on **Home** or **Environments** in the left sidebar
2. Click on your local Docker environment (usually called "local")

### Step 3: Create Stack

1. Click **Stacks** in the left sidebar
2. Click **Add stack** button
3. Name your stack: `homelab`

### Step 4: Add Compose File

You have two options:

**Option A: Upload File**
1. Select **Upload** tab
2. Click **Select file**
3. Navigate to and select `/opt/homelab/compose.yml`

**Option B: Paste Content**
1. Select **Web editor** tab
2. Copy the entire content of `/opt/homelab/compose.yml`
3. Paste it into the editor

### Step 5: Add Environment Variables

Scroll down to the **Environment variables** section:

1. Click **Advanced mode** toggle
2. Copy the content of `/opt/homelab/.env` file
3. Paste it into the text area

Example:
```
TZ=America/Argentina/Buenos_Aires
PUID=1000
PGID=1000
PIHOLE_WEBPASSWORD=your_password
MONGO_ROOT_PASS=your_mongo_root_password
MONGO_USER=unifi
MONGO_PASS=your_unifi_password
MONGO_DBNAME=unifi
```

### Step 6: Deploy

1. Review your configuration
2. Click **Deploy the stack** button at the bottom
3. Wait for deployment to complete (this may take a few minutes)

### Step 7: Verify Deployment

1. You'll be redirected to the stack page
2. Check that all containers show "running" status
3. If any containers show errors, click on them to view logs

### Step 8: Configure ARP Routes

Back on your Raspberry Pi terminal:

```bash
sudo systemctl restart macvlan-routes.service
sudo systemctl enable macvlan-routes.service
```

Wait 30 seconds, then verify:

```bash
sudo systemctl status macvlan-routes.service
```

You should see ARP routes configured for all containers.

## Option 2: Deploy via CLI (Alternative)

If you prefer command line:

```bash
cd /opt/homelab
docker compose up -d
```

Then configure ARP routes:

```bash
sudo systemctl restart macvlan-routes.service
```

## Managing Your Stack in Portainer

### View Container Logs

1. Go to **Stacks** → **homelab**
2. Click on any container name
3. Click **Logs** tab
4. Enable **Auto-refresh logs** for real-time viewing

### Restart a Service

1. Go to **Stacks** → **homelab**
2. Find the container you want to restart
3. Click the **Restart** icon (circular arrow)

### Update a Service

1. Go to **Stacks** → **homelab**
2. Find the container to update
3. Click on the container name
4. Scroll down and click **Recreate**
5. Enable **Pull latest image**
6. Click **Recreate** button

### Stop the Entire Stack

1. Go to **Stacks** → **homelab**
2. Click **Stop this stack** button
3. Confirm the action

### Start the Stack Again

1. Go to **Stacks** → **homelab**
2. Click **Start this stack** button

### Update the Entire Stack

1. Go to **Stacks** → **homelab**
2. Click **Editor** tab
3. Make your changes
4. Click **Update the stack** at the bottom
5. Select **Re-pull image and redeploy** if you want to update images
6. Click **Update**

## Accessing Services

Remember: Due to macvlan limitations, you **cannot** access these services from the Raspberry Pi itself. Use another device on your network:

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| Portainer | http://192.168.100.200:9000 | Your admin account |
| UniFi Controller | https://192.168.100.201:8443 | Setup wizard |
| Nginx Proxy Manager | http://192.168.100.202:81 | admin@example.com / changeme |
| Pi-hole | http://192.168.100.203/admin | Password from .env |
| Uptime Kuma | http://192.168.100.204:3001 | Setup wizard |
| Home Assistant | http://192.168.100.205:8123 | Setup wizard |
| Stirling PDF | http://192.168.100.206:8080 | No login |
| Homarr | http://192.168.100.207:7575 | Setup wizard |
| Dozzle | http://192.168.100.208:8080 | No login |

## Troubleshooting

### Stack Won't Deploy

**Check the logs:**
1. Go to **Stacks** → **homelab**
2. Look for red error messages
3. Click on containers with errors to see detailed logs

**Common issues:**
- Missing environment variables
- Typos in compose file
- Network conflicts

### Containers Keep Restarting

1. Click on the problematic container
2. Go to **Logs** tab
3. Look for error messages
4. Common causes:
   - Missing volumes/directories
   - Incorrect permissions
   - Database connection issues
   - Port conflicts

### Can't Access Services from Network

```bash
# On Raspberry Pi terminal:
sudo systemctl status macvlan-routes.service
sudo systemctl restart macvlan-routes.service

# Check ARP table:
ip neigh show | grep "192.168.100"
```

### Services Accessible but Showing Errors

Check container logs in Portainer. Most common issues:
- Database not ready (wait 1-2 minutes)
- Missing configuration files
- Permission issues

## Best Practices

1. **Before major changes**: Create a backup
   - Go to **Stacks** → **homelab** → **Editor**
   - Copy the entire compose file to a safe location

2. **Update regularly**: 
   - Check for updates weekly
   - Update one service at a time
   - Monitor logs after updates

3. **Monitor resources**:
   - Use Portainer's dashboard to monitor CPU/RAM
   - Check Dozzle for container logs
   - Set up alerts in Uptime Kuma

4. **Security**:
   - Change default passwords immediately
   - Use Nginx Proxy Manager for SSL certificates
   - Keep containers updated

## Advanced: Automated Deployment

You can also deploy using Portainer's API:

```bash
# Get your API key from Portainer UI:
# Settings → Users → Your user → Add API key

# Deploy stack via API:
curl -X POST "http://192.168.100.200:9000/api/stacks?type=2&method=file&endpointId=1" \
  -H "X-API-Key: YOUR_API_KEY" \
  -F "file=@/opt/homelab/compose.yml" \
  -F "env=@/opt/homelab/.env"
```

However, for most users, the web UI method is simpler and more reliable.

---

## Quick Reference Commands

```bash
# View stack status from CLI
cd /opt/homelab
docker compose ps

# View logs
docker compose logs -f

# Restart specific service
docker compose restart SERVICE_NAME

# Stop all
docker compose down

# Start all
docker compose up -d

# Update and restart
docker compose pull
docker compose up -d
```

---

**Need More Help?**
- Check container logs in Portainer
- Review the main [README.md](README.md)
- See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues
