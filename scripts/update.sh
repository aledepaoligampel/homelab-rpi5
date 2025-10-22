#!/bin/bash

# Homelab Update Script
# This script updates all services and the system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Check if Docker is running
check_docker() {
    print_status "Checking Docker..."
    
    if ! systemctl is-active --quiet docker; then
        print_error "Docker is not running. Run: sudo systemctl start docker"
        exit 1
    fi
    
    print_success "Docker is running"
}

# Update operating system
update_system() {
    print_status "Updating operating system..."
    
    sudo apt update
    sudo apt upgrade -y
    sudo apt autoremove -y
    sudo apt autoclean
    
    print_success "Operating system updated"
}

# Update Docker
update_docker() {
    print_status "Updating Docker..."
    
    # Get latest Docker version
    DOCKER_VERSION=$(curl -s https://api.github.com/repos/docker/docker-ce/releases/latest | grep tag_name | cut -d'"' -f4)
    
    print_status "Installing Docker $DOCKER_VERSION..."
    
    # Update Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    print_success "Docker updated"
}

# Update Docker containers
update_containers() {
    print_status "Updating Docker containers..."
    
    # Stop all containers
    print_status "Stopping containers..."
    docker-compose down
    
    # Update images
    print_status "Updating Docker images..."
    docker-compose pull
    
    # Remove orphaned images
    print_status "Cleaning orphaned images..."
    docker image prune -f
    
    # Restart containers
    print_status "Restarting containers..."
    docker-compose up -d
    
    print_success "Containers updated"
}

# Update Docker Compose
update_docker_compose() {
    print_status "Updating Docker Compose..."
    
    # Get latest version
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d'"' -f4)
    
    # Download and install
    sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    print_success "Docker Compose updated"
}

# Clean system
cleanup_system() {
    print_status "Cleaning system..."
    
    # Clean Docker
    docker system prune -f
    docker volume prune -f
    
    # Clean old logs
    sudo journalctl --vacuum-time=7d
    
    # Clean package cache
    sudo apt clean
    
    print_success "System cleaned"
}

# Verify services
verify_services() {
    print_status "Verifying services..."
    
    # List of important services
    SERVICES=(
        "docker"
        "ssh"
        "ufw"
    )
    
    for service in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "$service"; then
            print_success "Service $service is running"
        else
            print_warning "Service $service is not running"
        fi
    done
    
    # Check containers
    print_status "Checking containers..."
    RUNNING_CONTAINERS=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep -v "NAMES")
    
    if [[ -n "$RUNNING_CONTAINERS" ]]; then
        echo "$RUNNING_CONTAINERS"
        print_success "Containers verified"
    else
        print_warning "No containers running"
    fi
}

# Create backup before updating
create_pre_update_backup() {
    print_status "Creating backup before update..."
    
    if [[ -f "scripts/backup.sh" ]]; then
        ./scripts/backup.sh
        print_success "Backup created"
    else
        print_warning "Backup script not found"
    fi
}

# Check NVMe health
check_nvme_health() {
    print_status "Checking NVMe health..."
    
    if mountpoint -q /mnt/nvme; then
        # Check NVMe device
        NVME_DEVICE=$(lsblk -o NAME,TYPE | grep disk | grep nvme | head -1 | awk '{print $1}')
        
        if [[ -n "$NVME_DEVICE" ]]; then
            # Check SMART status
            if command -v smartctl >/dev/null 2>&1; then
                SMART_STATUS=$(sudo smartctl -H /dev/$NVME_DEVICE | grep "SMART overall-health" | awk '{print $6}')
                if [[ "$SMART_STATUS" == "PASSED" ]]; then
                    print_success "NVMe health: PASSED"
                else
                    print_warning "NVMe health: $SMART_STATUS"
                fi
            else
                print_warning "smartctl not installed, cannot check NVMe health"
            fi
            
            # Check disk usage
            NVME_USAGE=$(df -h /mnt/nvme | awk 'NR==2 {print $5}' | cut -d'%' -f1)
            if [[ $NVME_USAGE -gt 90 ]]; then
                print_warning "NVMe usage is high: ${NVME_USAGE}%"
            else
                print_success "NVMe usage: ${NVME_USAGE}%"
            fi
        else
            print_warning "NVMe device not found"
        fi
    else
        print_warning "NVMe not mounted"
    fi
}

# Show update information
show_update_info() {
    print_success "Update completed!"
    echo
    echo "=========================================="
    echo "🔄 Update Summary"
    echo "=========================================="
    echo
    echo "📅 Date: $(date)"
    echo "🕒 Duration: $(date -d@$(($(date +%s) - START_TIME)) -u +%H:%M:%S)"
    echo
    echo "✅ Updated:"
    echo "   - Operating system"
    echo "   - Docker"
    echo "   - Docker containers (including Dokploy)"
    echo "   - Docker Compose"
    echo
    echo "🧹 Cleanup performed:"
    echo "   - Orphaned Docker images"
    echo "   - System logs"
    echo "   - Package cache"
    echo
    echo "🔍 Verification:"
    verify_services
    echo
    echo "💾 Storage check:"
    check_nvme_health
    echo
    echo "⚠️  RECOMMENDATION:"
    echo "   - Reboot the system to apply all updates"
    echo "   - Verify all services are working correctly"
    echo "   - Check logs if there are any issues"
    echo
}

# Main function
main() {
    START_TIME=$(date +%s)
    
    echo "🔄 Homelab Update Script"
    echo "========================"
    echo
    
    check_docker
    create_pre_update_backup
    update_system
    update_docker
    update_docker_compose
    update_containers
    cleanup_system
    show_update_info
}

# Run main script
main "$@"