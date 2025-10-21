#!/bin/bash

# Homelab Installation Script for Raspberry Pi 5 with Debian 13
# This script installs Docker and configures the basic environment

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

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root. Please run as a regular user with sudo privileges."
        exit 1
    fi
}

# Verify we're on Debian
check_system() {
    print_status "Checking system..."
    
    if [[ ! -f /etc/debian_version ]]; then
        print_error "This script is designed for Debian. Detected system: $(cat /etc/os-release | grep PRETTY_NAME)"
        exit 1
    fi
    
    DEBIAN_VERSION=$(cat /etc/debian_version)
    print_success "Debian system detected: $DEBIAN_VERSION"
    
    # Check ARM64 architecture
    ARCH=$(uname -m)
    if [[ "$ARCH" != "aarch64" ]]; then
        print_warning "Detected architecture: $ARCH. This script is optimized for ARM64 (Raspberry Pi 5)"
    fi
}

# Update system
update_system() {
    print_status "Updating system..."
    
    sudo apt update
    sudo apt upgrade -y
    sudo apt install -y curl wget git htop network-manager
    
    print_status "Cleaning up unnecessary packages..."
    sudo apt autoremove -y
    
    print_success "System updated and cleaned"
}

# Install Docker
install_docker() {
    print_status "Installing Docker..."
    
    # Remove old versions
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Install dependencies
    sudo apt install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add current user to docker group
    sudo usermod -aG docker $USER
    
    # Enable Docker on boot
    sudo systemctl enable docker
    sudo systemctl start docker
    
    print_success "Docker installed successfully"
}

# Configure Docker to use NVMe storage
configure_docker_nvme() {
    print_status "Configuring Docker to use NVMe storage..."
    
    # Stop Docker service
    print_status "Stopping Docker service..."
    sudo systemctl stop docker
    print_success "✓ Docker service stopped"
    
    # Create Docker directory on NVMe
    print_status "Creating Docker directory on NVMe..."
    sudo mkdir -p /mnt/nvme/docker
    print_success "✓ Docker directory created on NVMe"
    
    # Move existing Docker data if it exists
    if [[ -d /var/lib/docker ]]; then
        print_status "Moving existing Docker data to NVMe..."
        print_status "This may take a while depending on data size..."
        sudo mv /var/lib/docker/* /mnt/nvme/docker/ 2>/dev/null || true
        print_success "✓ Docker data moved to NVMe"
        
        print_status "Cleaning up old Docker directory..."
        sudo rm -rf /var/lib/docker
        print_success "✓ Old Docker directory removed"
    else
        print_status "No existing Docker data found, skipping move"
    fi
    
    # Create symlink to NVMe
    print_status "Creating symlink to NVMe storage..."
    sudo ln -sf /mnt/nvme/docker /var/lib/docker
    print_success "✓ Symlink created"
    
    # Set proper permissions
    print_status "Setting proper permissions..."
    sudo chown -R root:root /mnt/nvme/docker
    sudo chmod -R 755 /mnt/nvme/docker
    print_success "✓ Permissions set"
    
    # Start Docker service
    print_status "Starting Docker service..."
    sudo systemctl start docker
    print_success "✓ Docker service started"
    
    print_success "Docker configured to use NVMe storage"
}

# Get IP configuration from user
get_ip_config() {
    print_status "Configuring network settings..."
    
    # Ask for IP address
    while true; do
        read -p "Enter the static IP address for your Raspberry Pi (e.g., 192.168.1.100): " RPI_IP
        if [[ $RPI_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            break
        else
            print_error "Invalid IP address format. Please enter a valid IP address."
        fi
    done
    
    # Ask for gateway
    while true; do
        read -p "Enter the gateway IP address (e.g., 192.168.1.1): " GATEWAY
        if [[ $GATEWAY =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            break
        else
            print_error "Invalid gateway IP format. Please enter a valid IP address."
        fi
    done
    
    # Ask for DNS servers
    read -p "Enter primary DNS server (default: 8.8.8.8): " DNS_PRIMARY
    DNS_PRIMARY=${DNS_PRIMARY:-8.8.8.8}
    
    read -p "Enter secondary DNS server (default: 8.8.4.4): " DNS_SECONDARY
    DNS_SECONDARY=${DNS_SECONDARY:-8.8.4.4}
    
    # Store configuration in .env file
    print_status "Saving network configuration to .env file..."
    
    # Create or update .env file
    if [[ -f .env ]]; then
        # Update existing .env file
        sed -i "s/RPI_IP=.*/RPI_IP=$RPI_IP/" .env
        sed -i "s/GATEWAY=.*/GATEWAY=$GATEWAY/" .env
        sed -i "s/DNS_PRIMARY=.*/DNS_PRIMARY=$DNS_PRIMARY/" .env
        sed -i "s/DNS_SECONDARY=.*/DNS_SECONDARY=$DNS_SECONDARY/" .env
    else
        # Create new .env file
        cat > .env << EOF
# Configuration for Raspberry Pi 5
RPI_IP=$RPI_IP
GATEWAY=$GATEWAY
DNS_PRIMARY=$DNS_PRIMARY
DNS_SECONDARY=$DNS_SECONDARY

# Add other configuration variables as needed
EOF
    fi
    
    print_success "Network configuration saved to .env file"
}

# Verify NetworkManager is working
verify_networkmanager() {
    print_status "Verifying NetworkManager configuration..."
    
    # Check if NetworkManager is running
    if ! systemctl is-active --quiet NetworkManager; then
        print_error "NetworkManager is not running. Starting it..."
        sudo systemctl start NetworkManager
    fi
    
    # Wait for NetworkManager to be ready
    sleep 3
    
    # Check connection status
    if nmcli -t -f STATE connection show | grep -q "activated"; then
        print_success "NetworkManager is working correctly"
        
        # Show current IP
        CURRENT_IP=$(ip route get 1.1.1.1 | awk '{print $7}' | head -1)
        print_status "Current IP address: $CURRENT_IP"
    else
        print_warning "NetworkManager may need additional configuration"
    fi
}

# Install and configure NetworkManager
install_networkmanager() {
    print_status "Configuring NetworkManager..."
    
    # Enable NetworkManager service
    sudo systemctl enable NetworkManager
    sudo systemctl start NetworkManager
    
    print_success "NetworkManager enabled and started"
}

# Configure static IP using nmcli
configure_network() {
    print_status "Configuring network..."
    
    # Install NetworkManager first
    install_networkmanager
    
    # Get IP configuration from user
    get_ip_config
    
    # Wait a moment for NetworkManager to be ready
    sleep 2
    
    # Get the connection name (usually the interface name)
    CONNECTION_NAME=$(nmcli -t -f NAME,TYPE connection show | grep ethernet | head -1 | cut -d: -f1)
    
    if [[ -z "$CONNECTION_NAME" ]]; then
        # If no connection exists, create one
        INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
        CONNECTION_NAME="Wired connection 1"
        
        print_status "Creating new connection: $CONNECTION_NAME"
        sudo nmcli connection add type ethernet ifname $INTERFACE con-name "$CONNECTION_NAME"
    fi
    
    print_status "Configuring static IP: $RPI_IP on connection: $CONNECTION_NAME"
    
    # Configure static IP using nmcli
    sudo nmcli connection modify "$CONNECTION_NAME" \
        ipv4.addresses "$RPI_IP/24" \
        ipv4.gateway "$GATEWAY" \
        ipv4.dns "$DNS_PRIMARY,$DNS_SECONDARY" \
        ipv4.method manual \
        connection.autoconnect yes
    
    # Apply the configuration
    sudo nmcli connection up "$CONNECTION_NAME"
    
    # Verify the configuration
    verify_networkmanager
    
    print_success "Network configured successfully using NetworkManager"
    print_warning "Network configuration applied immediately. No reboot required."
}

# Configure firewall
configure_firewall() {
    print_status "Configuring firewall..."
    
    # Install ufw if not installed
    sudo apt install -y ufw
    
    # Configure basic rules
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # Allow SSH
    sudo ufw allow ssh
    
    # Allow homelab ports
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow 9000/tcp  # Portainer
    sudo ufw allow 8123/tcp  # Home Assistant
    sudo ufw allow 3000/tcp  # AdGuard Home
    sudo ufw allow 3001/tcp  # AdGuard Home
    sudo ufw allow 9091/tcp  # Transmission
    sudo ufw allow 11470/tcp # Stremio
    sudo ufw allow 2283/tcp  # Immich
    
    # Enable firewall
    sudo ufw --force enable
    
    print_success "Firewall configured"
}

# Configure swap
configure_swap() {
    print_status "Configuring swap..."
    
    # Check if swap already exists
    if swapon --show | grep -q "/"; then
        print_warning "Swap already configured"
        return
    fi
    
    # Create 2GB swap file
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    
    # Make it permanent
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    
    # Configure swappiness
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
    
    print_success "Swap configured (2GB)"
}

# Optimize system for Raspberry Pi
optimize_system() {
    print_status "Optimizing system for Raspberry Pi..."
    
    # Configure GPU memory split
    if ! grep -q "gpu_mem=" /boot/firmware/config.txt; then
        echo "gpu_mem=16" | sudo tee -a /boot/firmware/config.txt
    fi
    
    # Configure basic overclock (optional)
    if ! grep -q "arm_freq=" /boot/firmware/config.txt; then
        echo "# Basic overclock for Pi 5" | sudo tee -a /boot/firmware/config.txt
        echo "arm_freq=2400" | sudo tee -a /boot/firmware/config.txt
        echo "gpu_freq=750" | sudo tee -a /boot/firmware/config.txt
    fi
    
    # Configure Docker memory limits
    sudo mkdir -p /etc/docker
    cat << EOF | sudo tee /etc/docker/daemon.json
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "default-address-pools": [
        {
            "base": "172.17.0.0/12",
            "size": 24
        }
    ]
}
EOF
    
    print_success "System optimized"
}

# Install additional tools
install_additional_tools() {
    print_status "Installing additional tools..."
    
    # Useful tools
    sudo apt install -y \
        vim \
        nano \
        tree \
        jq \
        unzip \
        zip \
        rsync \
        fail2ban \
        logrotate \
        cron
    
    # Install Docker Compose standalone (backup)
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    print_success "Additional tools installed"
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
        
        print_success "Samba services stopped and disabled"
        print_warning "Samba will run in Docker container instead of as system service"
    else
        print_status "No Samba services detected. No conflicts expected."
    fi
    
    # Check for any processes using SMB ports
    if netstat -tuln 2>/dev/null | grep -q ":139\|:445"; then
        print_warning "Processes detected using SMB ports (139/445)"
        print_status "These will be handled by Docker container"
    fi
}

# Force unmount NVMe device
force_unmount_nvme() {
    print_status "Checking for processes using /mnt/nvme..."
    
    # Kill any processes using the mount point
    if lsof /mnt/nvme 2>/dev/null; then
        print_status "Killing processes using /mnt/nvme..."
        sudo fuser -km /mnt/nvme
        sleep 2
    fi
    
    # Force unmount
    print_status "Force unmounting NVMe device..."
    sudo umount -f /mnt/nvme 2>/dev/null || true
    
    # If still mounted, try lazy unmount
    if mountpoint -q /mnt/nvme; then
        print_status "Trying lazy unmount..."
        sudo umount -l /mnt/nvme 2>/dev/null || true
    fi
    
    # Final check
    if mountpoint -q /mnt/nvme; then
        print_error "Could not unmount /mnt/nvme. Please manually stop services and try again."
        print_warning "You can try: sudo umount -f /mnt/nvme"
        exit 1
    fi
    
    print_success "NVMe device unmounted successfully"
}

# Configure NVMe storage
configure_nvme() {
    print_status "Configuring NVMe storage..."
    
    # Check if NVMe device exists
    if ! lsblk | grep -q nvme; then
        print_warning "No NVMe device found. Please ensure NVMe is connected."
        return
    fi
    
    # Get NVMe device (assuming first NVMe device)
    NVME_DEVICE=$(lsblk -o NAME,TYPE | grep disk | grep nvme | head -1 | awk '{print $1}')
    
    if [[ -z "$NVME_DEVICE" ]]; then
        print_error "Could not find NVMe device"
        exit 1
    fi
    
    print_status "Found NVMe device: $NVME_DEVICE"
    
    # Check if NVMe is already mounted
    if mountpoint -q /mnt/nvme; then
        print_warning "NVMe already mounted at /mnt/nvme"
        print_warning "⚠️  WARNING: This NVMe device already contains data!"
        echo
        echo "Options:"
        echo "1. Format the NVMe device (WARNING: This will erase all data!)"
        echo "2. Use the existing filesystem and continue"
        echo "3. Skip NVMe configuration and continue without it"
        echo
        read -p "Choose an option (1/2/3): " nvme_choice
        
        case $nvme_choice in
            1)
                print_warning "Formatting NVMe device - ALL DATA WILL BE LOST!"
                read -p "Are you sure? Type 'yes' to confirm: " confirm_format
                if [[ "$confirm_format" == "yes" ]]; then
                    force_unmount_nvme
                    print_status "Formatting NVMe device..."
                    sudo mkfs.ext4 -F /dev/$NVME_DEVICE
                    print_success "NVMe formatted with ext4"
                    print_status "Remounting NVMe device..."
                    sudo mount /dev/$NVME_DEVICE /mnt/nvme
                else
                    print_warning "Format cancelled. Using existing filesystem."
                fi
                ;;
            2)
                print_status "Using existing filesystem on NVMe device"
                ;;
            3)
                print_warning "Skipping NVMe configuration. Docker data will be stored on microSD."
                print_warning "This may result in slower performance and reduced lifespan of the microSD."
                force_unmount_nvme
                return
                ;;
            *)
                print_error "Invalid option. Exiting."
                exit 1
                ;;
        esac
    else
        # Create mount point
        sudo mkdir -p /mnt/nvme
        
        # Check if NVMe has a filesystem
        if ! sudo blkid /dev/$NVME_DEVICE | grep -q "TYPE="; then
            print_status "NVMe device has no filesystem. Formatting..."
            sudo mkfs.ext4 -F /dev/$NVME_DEVICE
            print_success "NVMe formatted with ext4"
        else
            print_status "NVMe device already has a filesystem"
            print_warning "⚠️  WARNING: This NVMe device already contains data!"
            echo
            echo "Options:"
            echo "1. Format the NVMe device (WARNING: This will erase all data!)"
            echo "2. Use the existing filesystem and continue"
            echo "3. Skip NVMe configuration and continue without it"
            echo
            read -p "Choose an option (1/2/3): " nvme_choice
            
            case $nvme_choice in
                1)
                    print_warning "Formatting NVMe device - ALL DATA WILL BE LOST!"
                    read -p "Are you sure? Type 'yes' to confirm: " confirm_format
                    if [[ "$confirm_format" == "yes" ]]; then
                        print_status "Formatting NVMe device..."
                        sudo mkfs.ext4 -F /dev/$NVME_DEVICE
                        print_success "NVMe formatted with ext4"
                    else
                        print_warning "Format cancelled. Skipping NVMe configuration."
                        return
                    fi
                    ;;
                2)
                    print_status "Using existing filesystem on NVMe device"
                    ;;
                3)
                    print_warning "Skipping NVMe configuration. Docker data will be stored on microSD."
                    print_warning "This may result in slower performance and reduced lifespan of the microSD."
                    return
                    ;;
                *)
                    print_error "Invalid option. Exiting."
                    exit 1
                    ;;
            esac
        fi
        
        # Mount NVMe
        print_status "Mounting NVMe device..."
        sudo mount /dev/$NVME_DEVICE /mnt/nvme
        
        # Verify mount was successful
        if mountpoint -q /mnt/nvme; then
            print_success "NVMe mounted successfully at /mnt/nvme"
            
            # Add to fstab for permanent mounting
            if ! grep -q "/mnt/nvme" /etc/fstab; then
                echo "/dev/$NVME_DEVICE /mnt/nvme ext4 defaults 0 2" | sudo tee -a /etc/fstab
                print_success "Added NVMe to /etc/fstab for automatic mounting"
            fi
        else
            print_error "Failed to mount NVMe device"
            print_warning "The NVMe device may have an incompatible filesystem or corrupted data."
            echo
            echo "Options:"
            echo "1. Format the NVMe device (WARNING: This will erase all data!)"
            echo "2. Skip NVMe configuration and continue without it"
            echo "3. Exit and fix the NVMe manually"
            echo
            read -p "Choose an option (1/2/3): " nvme_choice
            
            case $nvme_choice in
                1)
                    print_warning "Formatting NVMe device - ALL DATA WILL BE LOST!"
                    read -p "Are you sure? Type 'yes' to confirm: " confirm_format
                    if [[ "$confirm_format" == "yes" ]]; then
                        print_status "Formatting NVMe device..."
                        sudo mkfs.ext4 -F /dev/$NVME_DEVICE
                        print_success "NVMe formatted with ext4"
                        
                        # Try to mount again
                        print_status "Mounting NVMe device..."
                        sudo mount /dev/$NVME_DEVICE /mnt/nvme
                        
                        if mountpoint -q /mnt/nvme; then
                            print_success "NVMe mounted successfully at /mnt/nvme"
                            
                            # Add to fstab for permanent mounting
                            if ! grep -q "/mnt/nvme" /etc/fstab; then
                                echo "/dev/$NVME_DEVICE /mnt/nvme ext4 defaults 0 2" | sudo tee -a /etc/fstab
                                print_success "Added NVMe to /etc/fstab for automatic mounting"
                            fi
                        else
                            print_error "Still failed to mount NVMe after formatting"
                            exit 1
                        fi
                    else
                        print_warning "Format cancelled. Skipping NVMe configuration."
                        return
                    fi
                    ;;
                2)
                    print_warning "Skipping NVMe configuration. Docker data will be stored on microSD."
                    print_warning "This may result in slower performance and reduced lifespan of the microSD."
                    return
                    ;;
                3)
                    print_error "Please fix the NVMe device manually and run the script again."
                    exit 1
                    ;;
                *)
                    print_error "Invalid option. Exiting."
                    exit 1
                    ;;
            esac
        fi
    fi
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

# Setup automatic backups
setup_backups() {
    print_status "Setting up automatic backups..."
    
    # Create backup directory
    sudo mkdir -p /mnt/nvme/backups
    sudo chown $USER:$USER /mnt/nvme/backups
    
    # Make backup script executable
    chmod +x scripts/backup.sh
    
    print_success "Backups configured"
}

# Create environment file if it doesn't exist
create_env_file() {
    if [[ ! -f .env ]]; then
        print_status "Creating .env file from template..."
        cp env.example .env
        print_warning "Please edit .env file with your configuration before running docker-compose"
    fi
}

# Final system cleanup
final_cleanup() {
    print_status "Performing final system cleanup..."
    
    # Clean package cache
    sudo apt clean
    
    # Remove unnecessary packages
    sudo apt autoremove -y
    
    # Clean temporary files
    sudo rm -rf /tmp/*
    
    print_success "System cleanup completed"
}

# Show final information
show_final_info() {
    # Load IP from .env file
    if [[ -f .env ]]; then
        source .env
    fi
    
    print_success "Installation completed!"
    echo
    echo "=========================================="
    echo "🎉 Your homelab is ready!"
    echo "=========================================="
    echo
    echo "📋 Next steps:"
    echo "   1. Edit .env file with your configuration"
    echo "   2. Run: ./configure-services.sh"
    echo "   3. Run: docker-compose up -d"
    echo
    echo "🌐 Services will be available at:"
    echo "   - Portainer: http://${RPI_IP:-YOUR_IP}:9000"
    echo "   - Home Assistant: http://${RPI_IP:-YOUR_IP}:8123"
    echo "   - AdGuard Home: http://${RPI_IP:-YOUR_IP}:3000"
    echo "   - Nginx Proxy Manager: http://${RPI_IP:-YOUR_IP}:81"
    echo "   - Immich: http://${RPI_IP:-YOUR_IP}:2283"
    echo "   - Transmission: http://${RPI_IP:-YOUR_IP}:9091"
    echo "   - Stremio: http://${RPI_IP:-YOUR_IP}:11470"
    echo
    echo "🔧 Useful commands:"
    echo "   docker ps                       # View containers"
    echo "   docker-compose logs [service]  # View service logs"
    echo "   ./scripts/backup.sh            # Manual backup"
    echo
    echo "📚 Documentation:"
    echo "   - README.md: General information"
    echo "   - docs/installation.md: Detailed installation guide"
    echo "   - docs/services.md: Service documentation"
    echo
    echo "⚠️  IMPORTANT:"
    echo "   - Network configuration applied immediately (no reboot needed)"
    echo "   - Configure your router to assign static IP ${RPI_IP:-YOUR_IP}"
    echo "   - Review firewall configuration"
    echo "   - Optional: Reboot to ensure all configurations are properly loaded"
    echo
    print_warning "Optional reboot: sudo reboot"
}

# Main function
main() {
    echo "🏠 Homelab Installation Script"
    echo "=============================="
    echo
    
    check_root
    check_system
    update_system
    configure_nvme
    install_docker
    configure_docker_nvme
    create_directories
    configure_network
    configure_firewall
    configure_swap
    optimize_system
    install_additional_tools
    resolve_samba_conflicts
    setup_backups
    create_env_file
    final_cleanup
    show_final_info
}

# Run main script
main "$@"
