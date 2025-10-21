#!/bin/bash

# Homelab Services Configuration Script
# This script configures all services after installation

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if .env file exists
check_env_file() {
    if [[ ! -f .env ]]; then
        print_error ".env file not found. Please copy env.example to .env and configure it first."
        exit 1
    fi
    
    print_success ".env file found"
}

# Source environment variables
load_env() {
    print_status "Loading environment variables..."
    source .env
    print_success "Environment variables loaded"
}

# Create necessary directories
create_directories() {
    print_status "Creating necessary directories..."
    
    # Create main service directories
    print_status "Creating main service directories..."
    sudo mkdir -p /mnt/nvme/{immich,homeassistant,adguard,npm,samba,stremio,transmission,portainer,media,backups}
    print_success "✓ Main service directories created"
    
    # Create Immich subdirectories
    print_status "Creating Immich subdirectories..."
    sudo mkdir -p /mnt/nvme/immich/{upload,postgres,redis}
    print_success "✓ Immich directories created"
    
    # Create AdGuard Home subdirectories
    print_status "Creating AdGuard Home subdirectories..."
    sudo mkdir -p /mnt/nvme/adguard/{work,conf}
    print_success "✓ AdGuard Home directories created"
    
    # Create Nginx Proxy Manager subdirectories
    print_status "Creating Nginx Proxy Manager subdirectories..."
    sudo mkdir -p /mnt/nvme/npm/{data,letsencrypt,mysql}
    print_success "✓ Nginx Proxy Manager directories created"
    
    # Create Samba subdirectories
    print_status "Creating Samba subdirectories..."
    sudo mkdir -p /mnt/nvme/samba/{data,config}
    print_success "✓ Samba directories created"
    
    # Create Stremio subdirectories
    print_status "Creating Stremio subdirectories..."
    sudo mkdir -p /mnt/nvme/stremio/{config,data}
    print_success "✓ Stremio directories created"
    
    # Create Transmission subdirectories
    print_status "Creating Transmission subdirectories..."
    sudo mkdir -p /mnt/nvme/transmission/{config,downloads,watch}
    print_success "✓ Transmission directories created"
    
    # Create media subdirectories
    print_status "Creating media subdirectories..."
    sudo mkdir -p /mnt/nvme/media/{movies,tv,music,photos,downloads}
    print_success "✓ Media directories created"
    
    # Create backup subdirectories
    print_status "Creating backup subdirectories..."
    sudo mkdir -p /mnt/nvme/backups/{configs,databases,volumes}
    print_success "✓ Backup directories created"
    
    # Set proper ownership
    print_status "Setting directory ownership..."
    sudo chown -R $USER:$USER /mnt/nvme
    print_success "✓ Directory ownership set"
    
    # Set proper permissions
    print_status "Setting directory permissions..."
    sudo chmod -R 755 /mnt/nvme
    print_success "✓ Directory permissions set"
    
    print_success "All NVMe directories created successfully"
}

# Configure Samba
configure_samba() {
    print_status "Configuring Samba..."
    
    # Install Samba if not installed
    sudo apt install -y samba samba-common-bin
    
    # Backup original smb.conf
    sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.backup
    
    # Create Samba configuration
    cat << EOF | sudo tee /etc/samba/smb.conf
[global]
   workgroup = WORKGROUP
   server string = Homelab Server
   security = user
   map to guest = Bad User
   dns proxy = no

[$SAMBA_SHARE]
   comment = Homelab Shared Folder
   path = /mnt/nvme/samba/data
   browseable = yes
   read only = no
   valid users = $SAMBA_USER
   create mask = 0755
   directory mask = 0755

[media]
   comment = Media Folder
   path = /mnt/nvme/media
   browseable = yes
   read only = no
   valid users = $SAMBA_USER
   create mask = 0755
   directory mask = 0755
EOF
    
    # Create system user if it doesn't exist
    if ! id "$SAMBA_USER" &>/dev/null; then
        print_status "Creating system user: $SAMBA_USER"
        sudo useradd -m -s /bin/bash "$SAMBA_USER"
        print_success "System user created: $SAMBA_USER"
    else
        print_status "System user already exists: $SAMBA_USER"
    fi
    
    # Create Samba user
    print_status "Creating Samba user: $SAMBA_USER"
    echo -e "$SAMBA_PASSWORD\n$SAMBA_PASSWORD" | sudo smbpasswd -a "$SAMBA_USER"
    
    # Enable Samba user
    sudo smbpasswd -e "$SAMBA_USER"
    
    # Restart Samba
    sudo systemctl restart smbd
    sudo systemctl enable smbd
    
    print_success "Samba configured"
}

# Configure AdGuard Home
configure_adguard() {
    print_status "Configuring AdGuard Home..."
    
    # Create AdGuard Home configuration directory
    sudo mkdir -p /mnt/nvme/adguard/{work,conf}
    sudo chown -R $USER:$USER /mnt/nvme/adguard
    
    print_success "AdGuard Home directories created"
    
    # Wait for AdGuard Home to start
    print_status "Waiting for AdGuard Home to start..."
    sleep 15
    
    # Check if AdGuard Home is running
    if docker ps | grep -q adguardhome; then
        print_status "AdGuard Home is running"
        
        # Create configuration to listen on all interfaces
        print_status "Configuring AdGuard Home to listen on all interfaces..."
        
        # Create a simple configuration that binds to all interfaces
        cat > /tmp/adguard_config.json << EOF
{
  "dns": {
    "bind_hosts": ["0.0.0.0"],
    "port": 53,
    "upstream_dns": ["8.8.8.8", "8.8.4.4"],
    "protection_enabled": true,
    "ratelimit": 20,
    "blocking_mode": "default",
    "cache_size": 4194304,
    "resolve_clients": true
  },
  "tls": {
    "enabled": false
  },
  "filters": [],
  "whitelist_filters": [],
  "user_rules": [],
  "dhcp": {
    "enabled": false
  },
  "clients": {
    "persistent": [],
    "runtime_sources": {
      "whois": true,
      "arp": true,
      "rdns": true,
      "dhcp": true,
      "hosts": true
    }
  },
  "log_compress": false,
  "verbose": false,
  "schema_version": 15
}
EOF
        
        # Copy configuration to AdGuard Home
        sudo cp /tmp/adguard_config.json /mnt/nvme/adguard/conf/AdGuardHome.yaml
        sudo chown $USER:$USER /mnt/nvme/adguard/conf/AdGuardHome.yaml
        
        # Restart AdGuard Home to apply configuration
        print_status "Restarting AdGuard Home to apply configuration..."
        docker-compose restart adguardhome
        
        sleep 10
        
        print_success "AdGuard Home configured successfully!"
        echo
        echo "🌐 AdGuard Home URLs:"
        echo "   - Web Interface: http://${RPI_IP:-YOUR_IP}:3000"
        echo "   - DNS Server: ${RPI_IP:-YOUR_IP}:53"
        echo
        print_warning "Configure your router or devices to use ${RPI_IP:-YOUR_IP} as DNS server"
    else
        print_error "AdGuard Home is not running. Please check docker-compose logs"
    fi
}

# Configure Nginx Proxy Manager
configure_npm() {
    print_status "Configuring Nginx Proxy Manager..."
    
    # Create NPM directories
    sudo mkdir -p /mnt/nvme/npm/{data,letsencrypt,mysql}
    sudo chown -R $USER:$USER /mnt/nvme/npm
    
    print_success "Nginx Proxy Manager directories created"
    print_warning "Nginx Proxy Manager will be configured through the web interface at http://${RPI_IP:-YOUR_IP}:81"
    print_warning "Default login: admin@example.com / changeme"
}

# Configure Home Assistant
configure_homeassistant() {
    print_status "Configuring Home Assistant..."
    
    # Create Home Assistant configuration directory
    sudo mkdir -p /mnt/nvme/homeassistant
    sudo chown -R $USER:$USER /mnt/nvme/homeassistant
    
    print_success "Home Assistant directories created"
    print_warning "Home Assistant will be configured through the web interface at http://${RPI_IP:-YOUR_IP}:8123"
}

# Configure Immich
configure_immich() {
    print_status "Configuring Immich..."
    
    # Create Immich directories
    sudo mkdir -p /mnt/nvme/immich/{upload,postgres,redis}
    sudo chown -R $USER:$USER /mnt/nvme/immich
    
    print_success "Immich directories created"
    print_warning "Immich will be configured through the web interface at http://${RPI_IP:-YOUR_IP}:2283"
    print_warning "⚠️  IMPORTANT: All photos and videos will be stored in /mnt/nvme/immich/upload/"
    print_warning "Machine learning models will be cached for better performance"
}

# Configure Transmission
configure_transmission() {
    print_status "Configuring Transmission..."
    
    # Create Transmission directories
    sudo mkdir -p /mnt/nvme/transmission/{config,downloads,watch}
    sudo chown -R $USER:$USER /mnt/nvme/transmission
    
    print_success "Transmission directories created"
    print_warning "Transmission will be configured through the web interface at http://${RPI_IP:-YOUR_IP}:9091"
}

# Configure Stremio
configure_stremio() {
    print_status "Configuring Stremio..."
    
    # Create Stremio directories
    sudo mkdir -p /mnt/nvme/stremio/{config,data}
    sudo chown -R $USER:$USER /mnt/nvme/stremio
    
    print_success "Stremio directories created"
    print_warning "Stremio will be configured through the web interface at http://${RPI_IP:-YOUR_IP}:11470"
}

# Resolve Samba port conflicts
resolve_samba_conflicts() {
    print_status "Checking for Samba port conflicts..."
    
    # Check if Samba services are running
    if systemctl is-active --quiet smbd || systemctl is-active --quiet nmbd; then
        print_warning "Samba services detected. Stopping to avoid port conflicts with Docker container..."
        
        # Stop Samba services
        sudo systemctl stop smbd 2>/dev/null || true
        sudo systemctl stop nmbd 2>/dev/null || true
        
        # Disable Samba services to prevent auto-start
        sudo systemctl disable smbd 2>/dev/null || true
        sudo systemctl disable nmbd 2>/dev/null || true
        
        print_success "✓ Samba services stopped and disabled"
        print_warning "Samba will run in Docker container instead of as system service"
    else
        print_status "✓ No Samba services detected. No conflicts expected."
    fi
    
    # Check for any processes using SMB ports
    print_status "Checking for processes using SMB ports..."
    if netstat -tuln 2>/dev/null | grep -q ":139\|:445"; then
        print_warning "Processes detected using SMB ports (139/445)"
        print_status "Attempting to kill processes using SMB ports..."
        
        # Kill processes using SMB ports
        sudo fuser -k 139/tcp 2>/dev/null || true
        sudo fuser -k 445/tcp 2>/dev/null || true
        sleep 2
        
        # Check again
        if netstat -tuln 2>/dev/null | grep -q ":139\|:445"; then
            print_warning "Some processes still using SMB ports. This may cause issues."
            print_status "You may need to manually stop these processes or change Samba ports."
        else
            print_success "✓ SMB ports are now free"
        fi
    else
        print_success "✓ SMB ports (139/445) are free"
    fi
}

# Start Docker services
start_services() {
    print_status "Starting Docker services..."
    
    # Check if Docker is running
    print_status "Checking Docker status..."
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    print_success "✓ Docker is running"
    
    # Resolve Samba conflicts before starting services
    resolve_samba_conflicts
    
    # Start services
    print_status "Starting all Docker containers..."
    print_status "This may take several minutes for first-time setup..."
    docker-compose up -d
    
    print_success "✓ Docker services started"
    print_status "Waiting for containers to initialize..."
    sleep 10
}

# Wait for services to be ready
wait_for_services() {
    print_status "Waiting for services to be ready..."
    
    # Wait for Portainer
    print_status "Waiting for Portainer..."
    timeout 60 bash -c 'until curl -s http://localhost:9000 > /dev/null; do sleep 2; done' || print_warning "Portainer may not be ready yet"
    
    # Wait for Home Assistant
    print_status "Waiting for Home Assistant..."
    timeout 60 bash -c 'until curl -s http://localhost:8123 > /dev/null; do sleep 2; done' || print_warning "Home Assistant may not be ready yet"
    
    # Wait for AdGuard Home
    print_status "Waiting for AdGuard Home..."
    timeout 60 bash -c 'until curl -s http://localhost:3000 > /dev/null; do sleep 2; done' || print_warning "AdGuard Home may not be ready yet"
    
    print_success "Services are starting up"
}

# Show service status
show_service_status() {
    print_status "Checking service status..."
    
    echo
    echo "=========================================="
    echo "📊 Service Status"
    echo "=========================================="
    
    # Check Docker containers
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo
    echo "=========================================="
    echo "🌐 Service URLs"
    echo "=========================================="
    echo "Portainer:           http://${RPI_IP:-YOUR_IP}:9000"
    echo "Home Assistant:      http://${RPI_IP:-YOUR_IP}:8123"
    echo "AdGuard Home:        http://${RPI_IP:-YOUR_IP}:3000"
    echo "Nginx Proxy Manager: http://${RPI_IP:-YOUR_IP}:81"
    echo "Immich:              http://${RPI_IP:-YOUR_IP}:2283"
    echo "Transmission:        http://${RPI_IP:-YOUR_IP}:9091"
    echo "Stremio:             http://${RPI_IP:-YOUR_IP}:11470"
    echo
    echo "=========================================="
    echo "🔐 Default Credentials"
    echo "=========================================="
    echo "Nginx Proxy Manager: admin@example.com / changeme"
    echo "Transmission:        $TRANSMISSION_USER / $TRANSMISSION_PASSWORD"
    echo "Samba:              $SAMBA_USER / $SAMBA_PASSWORD"
    echo
}

# Setup automatic updates
setup_auto_updates() {
    print_status "Setting up automatic updates..."
    
    # Create update script
    cat << EOF > scripts/update-services.sh
#!/bin/bash
# Automatic update script for homelab services

set -e

echo "🔄 Updating homelab services..."

# Pull latest images
docker-compose pull

# Restart services
docker-compose up -d

# Clean up old images
docker image prune -f

echo "✅ Services updated successfully"
EOF
    
    chmod +x scripts/update-services.sh
    
    # Add to crontab if AUTO_UPDATE is enabled
    if [[ "$AUTO_UPDATE" == "true" ]]; then
        (crontab -l 2>/dev/null; echo "$UPDATE_SCHEDULE $(pwd)/scripts/update-services.sh") | crontab -
        print_success "Automatic updates configured"
    fi
}

# Setup monitoring
setup_monitoring() {
    print_status "Setting up monitoring..."
    
    # Create monitoring script
    cat << EOF > scripts/monitor-services.sh
#!/bin/bash
# Service monitoring script

SERVICES=("portainer" "homeassistant" "adguardhome" "immich-server" "transmission" "stremio")

for service in "\${SERVICES[@]}"; do
    if ! docker ps --format "{{.Names}}" | grep -q "\$service"; then
        echo "⚠️  Service \$service is not running"
        # Add notification logic here if needed
    fi
done
EOF
    
    chmod +x scripts/monitor-services.sh
    
    # Add to crontab for monitoring
    (crontab -l 2>/dev/null; echo "*/5 * * * * $(pwd)/scripts/monitor-services.sh") | crontab -
    
    print_success "Monitoring configured"
}

# Show final information
show_final_info() {
    print_success "Configuration completed!"
    echo
    echo "=========================================="
    echo "🎉 Your homelab is configured!"
    echo "=========================================="
    echo
    echo "📋 Next steps:"
    echo "   1. Access each service through the URLs above"
    echo "   2. Configure AdGuard Home DNS settings"
    echo "   3. Set up Nginx Proxy Manager for SSL certificates"
    echo "   4. Configure Home Assistant integrations"
    echo "   5. Set up Immich for photo management"
    echo
    echo "🔧 Useful commands:"
    echo "   docker-compose ps              # View service status"
    echo "   docker-compose logs [service]  # View service logs"
    echo "   docker-compose restart [service] # Restart specific service"
    echo "   ./scripts/update-services.sh   # Update all services"
    echo "   ./scripts/monitor-services.sh  # Check service status"
    echo
    echo "📚 Documentation:"
    echo "   - README.md: General information"
    echo "   - docs/installation.md: Detailed installation guide"
    echo "   - docs/services.md: Service documentation"
    echo
    print_warning "Remember to configure your router to assign static IP ${RPI_IP:-YOUR_IP}"
}

# Main function
main() {
    echo "🔧 Homelab Services Configuration"
    echo "================================="
    echo
    
    check_env_file
    load_env
    create_directories
    configure_samba
    configure_adguard
    configure_npm
    configure_homeassistant
    configure_immich
    configure_transmission
    configure_stremio
    start_services
    wait_for_services
    show_service_status
    setup_auto_updates
    setup_monitoring
    show_final_info
}

# Run main script
main "$@"