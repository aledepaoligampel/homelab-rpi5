#!/bin/bash

# Homelab Quick Setup Commands

# Copy and paste these commands to set up your homelab

echo "🏠 Homelab Quick Setup Commands"
echo "==============================="
echo
echo "Follow these commands to set up your homelab on Raspberry Pi 5:"
echo

echo "1. Clone the repository:"
echo "git clone https://github.com/your-username/homelab.git"
echo "cd homelab"
echo

echo "2. Configure environment:"
echo "cp env.example .env"
echo "nano .env # Edit with your configuration"
echo

echo "3. Make scripts executable:"
echo "chmod +x _.sh"
echo "chmod +x scripts/_.sh"
echo

echo "4. Run installation script:"
echo "sudo ./install.sh"
echo

echo "5. Configure services:"
echo "./configure-services.sh"
echo

echo "6. Start all services:"
echo "docker-compose up -d"
echo

echo "7. Check service status:"
echo "docker-compose ps"
echo

echo "8. Access services:"
echo "Portainer: http://YOUR_IP:9000"
echo "Home Assistant: http://YOUR_IP:8123"
echo "AdGuard Home: http://YOUR_IP:3000"
echo "Nginx Proxy Manager: http://YOUR_IP:81"
echo "Immich: http://YOUR_IP:2283"
echo "Transmission: http://YOUR_IP:9091"
echo "Stremio: http://YOUR_IP:11470"
echo

echo "9. Useful commands:"
echo "docker ps # View containers"
echo "docker-compose logs [service] # View service logs"
echo "docker-compose restart [service] # Restart service"
echo "./scripts/update-services.sh # Update all services"
echo "./scripts/monitor-services.sh # Check service status"
echo "./scripts/backup.sh # Manual backup"
echo

echo "10. Configure CI/CD (optional):"
echo "Add these secrets to your GitHub repository:"
echo "- RPI_HOST: YOUR_IP"
echo "- RPI_USER: your_username"
echo "- RPI_SSH_KEY: your_private_ssh_key"
echo

echo "⚠️ Important Notes:"
echo "- Configure your static IP during installation"
echo "- Change all default passwords in .env file"
echo "- Connect NVMe SSD before installation (all Docker data will be stored there)"
echo "- Immich photos are safely stored on NVMe with automatic backups"
echo "- OS runs from microSD, data from NVMe for maximum performance"
echo "- Reboot after installation to apply network changes"
echo "- Configure SSL certificates via Nginx Proxy Manager"
echo

echo "📚 Documentation:"
echo "- README.md: General information"
echo "- docs/installation.md: Detailed installation guide"
echo "- docs/services.md: Service documentation"
echo "- docs/ports.md: Port configuration"
echo

echo "🎉 Your homelab will be ready!"
