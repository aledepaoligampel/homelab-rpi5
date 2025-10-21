#!/bin/bash

# Immich Backup Script
# This script creates backups of Immich data stored on NVMe

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
IMMICH_BASE_DIR="/mnt/nvme/immich"
BACKUP_BASE_DIR="/mnt/nvme/backups/immich"
DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="$BACKUP_BASE_DIR/$DATE"

# Create backup directory
create_backup_dir() {
    print_status "Creating backup directory..."
    mkdir -p "$BACKUP_DIR"
    print_success "Backup directory created: $BACKUP_DIR"
}

# Backup Immich database
backup_database() {
    print_status "Backing up Immich database..."
    
    # Stop Immich services temporarily
    docker-compose stop immich-server immich-postgres
    
    # Create database backup
    docker run --rm \
        -v immich-postgres:/var/lib/postgresql/data \
        -v "$BACKUP_DIR":/backup \
        postgres:15-alpine \
        pg_dump -h immich-postgres -U immich immich > "$BACKUP_DIR/immich_database.sql"
    
    # Restart Immich services
    docker-compose start immich-postgres immich-server
    
    print_success "Database backup completed"
}

# Backup Immich files
backup_files() {
    print_status "Backing up Immich files..."
    
    # Backup upload directory (where all photos are stored)
    if [ -d "$IMMICH_BASE_DIR/upload" ]; then
        print_status "Backing up upload directory (photos/videos)..."
        tar -czf "$BACKUP_DIR/immich_upload.tar.gz" -C "$IMMICH_BASE_DIR" upload
        print_success "Upload directory backed up"
    fi
    
    # Backup Redis data
    if [ -d "$IMMICH_BASE_DIR/redis" ]; then
        print_status "Backing up Redis data..."
        tar -czf "$BACKUP_DIR/immich_redis.tar.gz" -C "$IMMICH_BASE_DIR" redis
        print_success "Redis data backed up"
    fi
}

# Create backup manifest
create_manifest() {
    print_status "Creating backup manifest..."
    
    cat > "$BACKUP_DIR/backup_manifest.txt" << EOF
Immich Backup Manifest
=====================
Date: $(date)
Backup Directory: $BACKUP_DIR
Immich Version: $(docker-compose exec immich-server node --version 2>/dev/null || echo "Unknown")

Directories Backed Up:
- upload: $(du -sh "$IMMICH_BASE_DIR/upload" 2>/dev/null | cut -f1 || echo "N/A") (photos/videos)
- redis: $(du -sh "$IMMICH_BASE_DIR/redis" 2>/dev/null | cut -f1 || echo "N/A") (cache)

Database:
- PostgreSQL dump: immich_database.sql

Total Backup Size: $(du -sh "$BACKUP_DIR" | cut -f1)
EOF
    
    print_success "Backup manifest created"
}

# Verify backup integrity
verify_backup() {
    print_status "Verifying backup integrity..."
    
    # Check if all expected files exist
    expected_files=("immich_database.sql" "immich_upload.tar.gz" "immich_redis.tar.gz")
    
    for file in "${expected_files[@]}"; do
        if [ -f "$BACKUP_DIR/$file" ]; then
            print_success "✓ $file"
        else
            print_warning "⚠ $file not found"
        fi
    done
    
    # Check file sizes
    print_status "Backup file sizes:"
    ls -lh "$BACKUP_DIR"/*.tar.gz "$BACKUP_DIR"/*.sql 2>/dev/null || true
}

# Clean old backups
clean_old_backups() {
    print_status "Cleaning old backups..."
    
    # Keep only last 7 days of backups
    find "$BACKUP_BASE_DIR" -type d -name "20*" -mtime +7 -exec rm -rf {} \; 2>/dev/null || true
    
    print_success "Old backups cleaned"
}

# Show backup summary
show_summary() {
    print_success "Immich backup completed!"
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
    echo "   1. Stop Immich services: docker-compose stop immich-server immich-postgres"
    echo "   2. Restore database: docker exec -i immich-postgres psql -U immich immich < $BACKUP_DIR/immich_database.sql"
    echo "   3. Restore files: tar -xzf $BACKUP_DIR/immich_*.tar.gz -C $IMMICH_BASE_DIR"
    echo "   4. Start services: docker-compose start immich-postgres immich-server"
    echo
    echo "⚠️  IMPORTANT: All Immich data is safely stored on NVMe at $IMMICH_BASE_DIR"
    echo "   Backup location: $BACKUP_DIR"
}

# Main function
main() {
    echo "📸 Immich Backup Script"
    echo "======================="
    echo
    
    # Check if Immich is running
    if ! docker-compose ps | grep -q "immich-server.*Up"; then
        print_warning "Immich services are not running. Starting them first..."
        docker-compose up -d immich-postgres immich-redis immich-server
        sleep 30
    fi
    
    # Check if NVMe is mounted
    if ! mountpoint -q /mnt/nvme; then
        print_error "NVMe is not mounted at /mnt/nvme"
        exit 1
    fi
    
    create_backup_dir
    backup_database
    backup_files
    create_manifest
    verify_backup
    clean_old_backups
    show_summary
}

# Run main script
main "$@"
