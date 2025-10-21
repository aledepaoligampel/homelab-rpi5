# Installation Guide

This guide provides detailed instructions for setting up your homelab on a Raspberry Pi 5 with Debian 13.

## Prerequisites

### Hardware Requirements

- **Raspberry Pi 5**: Latest model with ARM64 architecture
- **RAM**: Minimum 8GB (recommended for optimal performance)
- **Storage**: MicroSD card with at least 32GB (64GB+ recommended)
- **Network**: Ethernet connection for stable connectivity
- **Power**: Official Raspberry Pi 5 power supply (27W)

### Software Requirements

- **Operating System**: Debian 13 (Bookworm) without GUI
- **Architecture**: ARM64 (aarch64)
- **Network**: Static IP configuration capability

## Step-by-Step Installation

### 1. Prepare Debian 13 Image

1. Download Debian 13 Bookworm from [official website](https://www.debian.org/distrib/)
2. Use Raspberry Pi Imager to flash the image to your microSD card
3. Enable SSH and configure initial user during imaging process

### 2. Initial System Setup

1. Boot your Raspberry Pi 5 with the Debian image
2. Connect via SSH (use your configured IP):

   ```bash
   ssh username@YOUR_IP
   ```

3. Update the system:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

### 3. Clone the Repository

```bash
# Clone the homelab repository
git clone https://github.com/your-username/homelab.git
cd homelab

# Make scripts executable
chmod +x *.sh
chmod +x scripts/*.sh
```

### 4. Configure Environment

1. Copy the environment template:

   ```bash
   cp env.example .env
   ```

2. Edit the configuration:

   ```bash
   nano .env
   ```

3. Update the following critical variables:

   ```bash
   # Network configuration
   RPI_IP=YOUR_IP
   GATEWAY=192.168.1.1
   DNS_PRIMARY=8.8.8.8
   DNS_SECONDARY=1.1.1.1

   # Security (change these!)
   IMMICH_DB_PASSWORD=your_secure_password
   IMMICH_REDIS_PASSWORD=your_redis_password
   NPM_DB_ROOT_PASSWORD=your_npm_root_password
   NPM_DB_PASSWORD=your_npm_user_password
   SAMBA_PASSWORD=your_samba_password
   TRANSMISSION_PASSWORD=your_transmission_password
   ```

### 5. Run Installation Script

```bash
sudo ./install.sh
```

This script will:

- Install Docker and Docker Compose
- Configure static IP (configured during installation)
- Set up firewall rules
- Configure swap memory
- Optimize system for Raspberry Pi 5
- Install additional tools

### 6. Configure Services

```bash
./configure-services.sh
```

This script will:

- Create necessary directories
- Configure Samba file sharing
- Set up service directories
- Start all Docker services
- Configure monitoring and updates

### 7. Verify Installation

Check that all services are running:

```bash
docker-compose ps
```

Expected output should show all services as "Up".

## Network Configuration

### Router Configuration

Configure your router to assign the static IP you specified during installation:

1. Access your router's admin panel
2. Find DHCP reservation settings
3. Add entry for Raspberry Pi MAC address → YOUR_IP
4. Save and restart router

### Firewall Rules

The installation script configures UFW with these ports:

- **22**: SSH
- **80**: HTTP (Nginx Proxy Manager)
- **443**: HTTPS (Nginx Proxy Manager)
- **9000**: Portainer
- **8123**: Home Assistant
- **3000**: AdGuard Home (Web UI)
- **3001**: AdGuard Home (Admin)
- **9091**: Transmission
- **11470**: Stremio
- **2283**: Immich

## Service Configuration

### Portainer

1. Access: http://YOUR_IP:9000
2. Create admin account on first visit
3. Connect to local Docker environment

### Home Assistant

1. Access: http://YOUR_IP:8123
2. Complete initial setup wizard
3. Configure integrations as needed

### AdGuard Home

1. Access: http://YOUR_IP:3000
2. Complete initial setup
3. Configure DNS settings:
   - Upstream DNS: 8.8.8.8, 1.1.1.1
   - Block lists: Enable recommended lists

### Nginx Proxy Manager

1. Access: http://YOUR_IP:81
2. Login: admin@example.com / changeme
3. Change default password
4. Configure SSL certificates

### Immich

1. Access: http://YOUR_IP:2283
2. Create admin account
3. Configure library paths
4. Set up mobile app connection

### Transmission

1. Access: http://YOUR_IP:9091
2. Login with configured credentials
3. Configure download directories
4. Set up watch folders

### Stremio

1. Access: http://YOUR_IP:11470
2. Configure add-ons
3. Set up media sources

## Troubleshooting

### Common Issues

#### Services Not Starting

```bash
# Check service logs
docker-compose logs [service-name]

# Restart specific service
docker-compose restart [service-name]

# Restart all services
docker-compose down && docker-compose up -d
```

#### Network Issues

```bash
# Check IP configuration
ip addr show

# Test connectivity
ping 8.8.8.8

# Check DNS resolution
nslookup google.com
```

#### Permission Issues

```bash
# Fix directory permissions
sudo chown -R $USER:$USER /media
sudo chown -R $USER:$USER /opt/backups
```

#### Docker Issues

```bash
# Check Docker status
sudo systemctl status docker

# Restart Docker
sudo systemctl restart docker

# Clean up Docker
docker system prune -f
```

### Performance Optimization

#### Memory Management

```bash
# Check memory usage
free -h

# Monitor Docker memory usage
docker stats
```

#### Storage Management

```bash
# Check disk usage
df -h

# Clean up Docker volumes
docker volume prune -f
```

## Security Considerations

### Change Default Passwords

1. Update all service passwords from defaults
2. Use strong, unique passwords
3. Consider using a password manager

### Regular Updates

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Update Docker images
./scripts/update-services.sh
```

### Backup Strategy

```bash
# Manual backup
./scripts/backup.sh

# Schedule automatic backups
crontab -e
# Add: 0 2 * * * /path/to/homelab/scripts/backup.sh
```

## Next Steps

After successful installation:

1. **Configure SSL certificates** via Nginx Proxy Manager
2. **Set up external access** if needed
3. **Configure monitoring alerts**
4. **Set up automated backups**
5. **Customize service configurations**

## Support

If you encounter issues:

1. Check service logs: `docker-compose logs [service]`
2. Review troubleshooting section
3. Check GitHub issues
4. Create new issue with detailed information

---

**Your homelab is now ready! 🎉**
