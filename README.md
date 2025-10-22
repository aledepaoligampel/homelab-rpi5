# Homelab - Raspberry Pi 5 with Docker Services

A complete homelab setup for Raspberry Pi 5 running Debian 13 with Docker containers for various services.

## 📋 Requirements

- Raspberry Pi 5
- Debian 13 (Bookworm) without GUI
- At least 8GB RAM recommended
- MicroSD card with at least 32GB (for OS)
- **NVMe SSD** (for Docker data and photos)
- Stable internet connection
- Static IP address (configured during installation)

## 🚀 Quick Installation

### 1. Clone the repository

```bash
git clone https://github.com/aledepaoligampel/homelab-rpi5.git
cd homelab-rpi5
```

### 2. Configure environment

```bash
cp env.example .env
nano .env  # Edit with your configuration
```

### 3. Run installation script

```bash
chmod +x install.sh
sudo ./install.sh
```

### 4. Configure services

```bash
chmod +x configure-services.sh
./configure-services.sh
```

### 5. Start all services

```bash
docker-compose up -d
```

### 6. Install Dokploy (Optional)

```bash
chmod +x scripts/install-dokploy.sh
./scripts/install-dokploy.sh
```

## 🔄 Updating Your Homelab

### For Configuration Updates (New Services, Port Changes)

```bash
chmod +x scripts/update-config.sh
./scripts/update-config.sh
```

### For System Updates (OS, Docker, Containers)

```bash
chmod +x scripts/update.sh
./scripts/update.sh
```

## 📁 Project Structure

```
homelab-rpi5/
├── README.md                 # This file
├── install.sh               # Main installation script
├── configure-services.sh     # Service configuration
├── docker-compose.yml       # Main services
├── env.example              # Environment variables template
├── .github/workflows/       # CI/CD configuration
├── config/                  # Service configurations
├── scripts/                 # Utility scripts
│   ├── backup.sh           # Backup script
│   ├── backup-immich.sh    # Immich-specific backup
│   ├── update.sh           # Update script
│   └── monitoring.sh       # Monitoring script
└── docs/                   # Additional documentation
    ├── installation.md     # Detailed installation guide
    ├── nvme-storage.md     # NVMe storage documentation
    └── ports.md            # Service ports documentation
```

## 🛠️ Included Services

- **Portainer**: Docker container management
- **Immich v2.1.0**: Photo and video management
- **Home Assistant**: Home automation
- **AdGuard Home**: DNS ad blocker
- **Samba**: File sharing
- **Nginx Proxy Manager**: Reverse proxy and SSL
- **Stremio**: Media streaming server
- **Transmission**: BitTorrent client
- **Dokploy**: Docker deployment platform

## 🌐 Service URLs

After installation, services will be available at your configured IP address:

- **Portainer**: http://YOUR_IP:9000
- **Home Assistant**: http://YOUR_IP:8123
- **AdGuard Home**: http://YOUR_IP:3001
- **Nginx Proxy Manager**: http://YOUR_IP:81
- **Immich**: http://YOUR_IP:2283
- **Transmission**: http://YOUR_IP:9091
- **Dokploy**: http://YOUR_IP:80
- **Stremio**: http://YOUR_IP:8081

## 🔧 Configuration

### Environment Variables

Copy the example file and configure your settings:

```bash
cp env.example .env
nano .env
```

### NVMe Storage

**IMPORTANT**: All Docker data is stored on NVMe for maximum performance and data safety:

- **OS**: MicroSD card (Debian 13)
- **Docker Data**: NVMe SSD (all services)
- **Photos/Videos**: NVMe SSD (Immich)
- **Backups**: NVMe SSD (automatic)

The installation script automatically:

- Detects and mounts your NVMe device
- Creates all necessary directories
- Configures proper permissions
- Sets up automatic mounting

### Network Configuration

The installation script will prompt you to configure your network settings including:

- Static IP address for your Raspberry Pi
- Gateway IP address
- DNS servers

Ensure your router is configured to assign the static IP you specify to your Raspberry Pi.

### Firewall

The installation script configures UFW firewall with necessary ports.

## 📊 Monitoring

The system includes:

- Service health monitoring
- Automatic updates
- Backup automation
- Log rotation

## 🔄 CI/CD

This repository includes GitHub Actions for:

- Configuration validation
- Service testing
- Security scanning
- Automated deployment

## 🔄 Backups

Configure automatic backups:

```bash
chmod +x scripts/backup.sh
chmod +x scripts/backup-immich.sh
crontab -e
# Add: 0 2 * * * /path/to/project/scripts/backup.sh
# Add: 0 3 * * * /path/to/project/scripts/backup-immich.sh
```

### Immich Photo Safety

Your photos and videos are protected with:

- **Primary Storage**: High-performance NVMe SSD
- **Daily Backups**: Automatic Immich-specific backups
- **Integrity Checks**: Backup verification
- **Easy Recovery**: Simple restoration process

All Immich data is stored in `/mnt/nvme/immich/` with automatic backups to `/mnt/nvme/backups/immich/`.

## 🆘 Support

If you encounter issues:

1. Check the documentation in `docs/`
2. Verify service logs: `docker-compose logs [service]`
3. Check the troubleshooting guide

## 📝 License

This project is licensed under the MIT License. See `LICENSE` for details.

## 🤝 Contributing

Contributions are welcome. Please:

1. Fork the project
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## 🔗 Useful Commands

```bash
# View running containers
docker ps

# View service logs
docker-compose logs [service]

# Restart a service
docker-compose restart [service]

# Update all services
./scripts/update.sh

# Check service status
./scripts/monitoring.sh

# Manual backup
./scripts/backup.sh
```

---

**Enjoy your new homelab! 🏠**
