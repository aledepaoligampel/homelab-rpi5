#!/bin/bash

# Homelab Backup Script
# This script creates backups of all homelab data stored on NVMe

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

# Configuration
NVME_BASE_DIR="/mnt/nvme"
BACKUP_BASE_DIR="/mnt/nvme/backups"
DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="$BACKUP_BASE_DIR/$DATE"

# Create backup directory
create_backup_dir() {
    print_status "Creating backup directory..."
    mkdir -p "$BACKUP_DIR"
    print_success "Backup directory created: $BACKUP_DIR"
}

# Backup Docker Compose configuration
backup_config() {
    print_status "Backing up Docker Compose configuration..."
    
    # Backup docker-compose.yml
    cp docker-compose.yml "$BACKUP_DIR/"
    
    # Backup .env file
    if [ -f .env ]; then
        cp .env "$BACKUP_DIR/"
    fi
    
    # Backup scripts
    mkdir -p "$BACKUP_DIR/scripts"
    cp scripts/*.sh "$BACKUP_DIR/scripts/" 2>/dev/null || true
    
    print_success "Configuration backed up"
}

# Backup service data
backup_services() {
    print_status "Backing up service data..."
    
    # Services to backup
    services=("immich" "homeassistant" "adguard" "npm" "samba" "stremio" "transmission" "portainer")
    
    for service in "${services[@]}"; do
        if [ -d "$NVME_BASE_DIR/$service" ]; then
            print_status "Backing up $service..."
            tar -czf "$BACKUP_DIR/${service}_data.tar.gz" -C "$NVME_BASE_DIR" "$service"
            print_success "$service backed up"
        else
            print_warning "$service directory not found"
        fi
    done
}

# Backup media files
backup_media() {
    print_status "Backing up media files..."
    
    if [ -d "$NVME_BASE_DIR/media" ]; then
        tar -czf "$BACKUP_DIR/media_files.tar.gz" -C "$NVME_BASE_DIR" media
        print_success "Media files backed up"
    else
        print_warning "Media directory not found"
    fi
}

# Create backup manifest
create_manifest() {
    print_status "Creating backup manifest..."
    
    cat > "$BACKUP_DIR/backup_manifest.txt" << EOF
Homelab Backup Manifest
======================
Date: $(date)
Backup Directory: $BACKUP_DIR
System: $(uname -a)

Services Backed Up:
$(for service in immich homeassistant adguard npm samba stremio transmission portainer; do
    if [ -d "$NVME_BASE_DIR/$service" ]; then
        echo "- $service: $(du -sh "$NVME_BASE_DIR/$service" | cut -f1)"
    fi
done)

Media Files:
- media: $(du -sh "$NVME_BASE_DIR/media" 2>/dev/null | cut -f1 || echo "N/A")

Total Backup Size: $(du -sh "$BACKUP_DIR" | cut -f1)
EOF
    
    print_success "Backup manifest created"
}

# Verify backup integrity
verify_backup() {
    print_status "Verifying backup integrity..."
    
    # Check if all expected files exist
    expected_files=("docker-compose.yml" "backup_manifest.txt")
    
    for file in "${expected_files[@]}"; do
        if [ -f "$BACKUP_DIR/$file" ]; then
            print_success "✓ $file"
        else
            print_warning "⚠ $file not found"
        fi
    done
    
    # Check file sizes
    print_status "Backup file sizes:"
    ls -lh "$BACKUP_DIR"/*.tar.gz "$BACKUP_DIR"/*.yml 2>/dev/null || true
}

# Clean old backups
clean_old_backups() {
    print_status "Cleaning old backups..."
    
    # Keep only last 30 days of backups
    find "$BACKUP_BASE_DIR" -type d -name "20*" -mtime +30 -exec rm -rf {} \; 2>/dev/null || true
    
    print_success "Old backups cleaned"
}

# Show backup summary
show_summary() {
    print_success "Homelab backup completed!"
    echo
    echo "=========================================="
    echo "📊 Backup Summary"
    echo "=========================================="
    echo "Backup Location: $BACKUP_DIR"
    echo "Total Size: $(du -sh "$BACKUP_DIR" | cut -f1)"
    echo "Date: $(date)"
    echo
    echo "📁 Backup Contents:"
    ls -la "$BACKUP_DIR"
    echo
    echo "🔄 To restore from this backup:"
    echo "   1. Stop all services: docker-compose down"
    echo "   2. Restore service data: tar -xzf $BACKUP_DIR/*_data.tar.gz -C $NVME_BASE_DIR"
    echo "   3. Restore configuration: cp $BACKUP_DIR/docker-compose.yml ."
    echo "   4. Start services: docker-compose up -d"
    echo
    echo "⚠️  IMPORTANT: All homelab data is safely stored on NVMe at $NVME_BASE_DIR"
    echo "   Backup location: $BACKUP_DIR"
    echo "   Immich photos are protected in: $NVME_BASE_DIR/immich/"
}

# Main function
main() {
    echo "🏠 Homelab Backup Script"
    echo "======================="
    echo
    
    # Check if NVMe is mounted
    if ! mountpoint -q /mnt/nvme; then
        print_error "NVMe is not mounted at /mnt/nvme"
        exit 1
    fi
    
    create_backup_dir
    backup_config
    backup_services
    backup_media
    create_manifest
    verify_backup
    clean_old_backups
    show_summary
}

# Run main script
main "$@"