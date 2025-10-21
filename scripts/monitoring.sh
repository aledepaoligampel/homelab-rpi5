#!/bin/bash

# Homelab Monitoring Script
# This script monitors the status of the system and services

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

# Function to get system metrics
get_system_metrics() {
    print_status "Getting system metrics..."
    
    # CPU
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    
    # Memory
    MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    MEMORY_TOTAL=$(free -h | grep Mem | awk '{print $2}')
    MEMORY_USED=$(free -h | grep Mem | awk '{print $3}')
    
    # Disk
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | cut -d'%' -f1)
    DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
    
    # NVMe usage
    if mountpoint -q /mnt/nvme; then
        NVME_USAGE=$(df -h /mnt/nvme | awk 'NR==2 {print $5}' | cut -d'%' -f1)
        NVME_TOTAL=$(df -h /mnt/nvme | awk 'NR==2 {print $2}')
        NVME_USED=$(df -h /mnt/nvme | awk 'NR==2 {print $3}')
    else
        NVME_USAGE="N/A"
        NVME_TOTAL="N/A"
        NVME_USED="N/A"
    fi
    
    # Temperature (if available)
    if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
        TEMP_RAW=$(cat /sys/class/thermal/thermal_zone0/temp)
        TEMPERATURE=$(echo "scale=1; $TEMP_RAW/1000" | bc)
    else
        TEMPERATURE="N/A"
    fi
    
    # Uptime
    UPTIME=$(uptime -p)
    
    echo "📊 System Metrics"
    echo "=================="
    echo "🖥️  CPU: ${CPU_USAGE}%"
    echo "🧠 Memory: ${MEMORY_USAGE}% (${MEMORY_USED}/${MEMORY_TOTAL})"
    echo "💾 Disk (OS): ${DISK_USAGE}% (${DISK_USED}/${DISK_TOTAL})"
    echo "🚀 NVMe (Data): ${NVME_USAGE}% (${NVME_USED}/${NVME_TOTAL})"
    echo "🌡️  Temperature: ${TEMPERATURE}°C"
    echo "⏰ Uptime: ${UPTIME}"
    echo
}

# Function to check system services
check_system_services() {
    print_status "Checking system services..."
    
    # List of important services
    SERVICES=(
        "docker"
        "ssh"
        "ufw"
    )
    
    echo "🔧 System Services"
    echo "==================="
    
    for service in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "$service"; then
            echo "✅ $service: Active"
        else
            echo "❌ $service: Inactive"
        fi
    done
    echo
}

# Function to check Docker containers
check_docker_containers() {
    print_status "Checking Docker containers..."
    
    echo "🐳 Docker Containers"
    echo "===================="
    
    # Get list of containers
    CONTAINERS=$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}")
    
    if [[ -n "$CONTAINERS" ]]; then
        echo "$CONTAINERS"
        
        # Count containers by state
        RUNNING_COUNT=$(docker ps -q | wc -l)
        STOPPED_COUNT=$(docker ps -a --filter "status=exited" -q | wc -l)
        
        echo
        echo "📈 Summary:"
        echo "   - Running: $RUNNING_COUNT"
        echo "   - Stopped: $STOPPED_COUNT"
    else
        echo "❌ No containers running"
    fi
    echo
}

# Function to check Docker volumes
check_docker_volumes() {
    print_status "Checking Docker volumes..."
    
    echo "💾 Docker Volumes"
    echo "================="
    
    VOLUMES=$(docker volume ls --format "table {{.Name}}\t{{.Driver}}\t{{.Size}}")
    
    if [[ -n "$VOLUMES" ]]; then
        echo "$VOLUMES"
        
        # Calculate total size
        TOTAL_SIZE=$(docker system df -v | grep "Local Volumes" | awk '{print $3}')
        echo
        echo "📏 Total volume size: $TOTAL_SIZE"
    else
        echo "❌ No Docker volumes"
    fi
    echo
}

# Function to check Docker networks
check_docker_networks() {
    print_status "Checking Docker networks..."
    
    echo "🌐 Docker Networks"
    echo "=================="
    
    NETWORKS=$(docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}")
    
    if [[ -n "$NETWORKS" ]]; then
        echo "$NETWORKS"
    else
        echo "❌ No Docker networks"
    fi
    echo
}

# Function to check service connectivity
check_service_connectivity() {
    print_status "Checking service connectivity..."
    
    echo "🔗 Service Connectivity"
    echo "======================="
    
    # List of services and their ports
    declare -A SERVICES=(
        ["Portainer"]="9000"
        ["Home Assistant"]="8123"
        ["AdGuard Home"]="3000"
        ["Nginx Proxy Manager"]="81"
        ["Immich"]="2283"
        ["Transmission"]="9091"
        ["Stremio"]="11470"
    )
    
    for service in "${!SERVICES[@]}"; do
        port="${SERVICES[$service]}"
        if nc -z localhost "$port" 2>/dev/null; then
            echo "✅ $service (port $port): Accessible"
        else
            echo "❌ $service (port $port): Not accessible"
        fi
    done
    echo
}

# Function to check error logs
check_error_logs() {
    print_status "Checking error logs..."
    
    echo "📋 Recent Error Logs"
    echo "===================="
    
    # Check system logs
    SYSTEM_ERRORS=$(journalctl --since "1 hour ago" --priority=err --no-pager | head -10)
    
    if [[ -n "$SYSTEM_ERRORS" ]]; then
        echo "🔴 System errors (last hour):"
        echo "$SYSTEM_ERRORS"
    else
        echo "✅ No system errors in the last hour"
    fi
    
    # Check Docker logs
    DOCKER_ERRORS=$(docker logs --since 1h $(docker ps -q) 2>&1 | grep -i error | head -5)
    
    if [[ -n "$DOCKER_ERRORS" ]]; then
        echo
        echo "🐳 Docker errors (last hour):"
        echo "$DOCKER_ERRORS"
    else
        echo "✅ No Docker errors in the last hour"
    fi
    echo
}

# Function to check disk space
check_disk_space() {
    print_status "Checking disk space..."
    
    echo "💾 Disk Usage"
    echo "============="
    
    # Show disk usage by directory
    df -h | grep -E "(Filesystem|/dev/)" | while read line; do
        echo "$line"
    done
    
    # Check important directories
    echo
    echo "📁 Important directories:"
    for dir in "/opt" "/var/lib/docker" "/home" "/mnt/nvme"; do
        if [[ -d "$dir" ]]; then
            SIZE=$(du -sh "$dir" 2>/dev/null | cut -f1)
            echo "   $dir: $SIZE"
        fi
    done
    echo
}

# Function to check backups
check_backups() {
    print_status "Checking backups..."
    
    echo "💾 Backup Status"
    echo "================"
    
    BACKUP_DIR="/mnt/nvme/backups"
    
    if [[ -d "$BACKUP_DIR" ]]; then
        BACKUP_COUNT=$(find "$BACKUP_DIR" -type d -name "20*" | wc -l)
        LATEST_BACKUP=$(find "$BACKUP_DIR" -type d -name "20*" -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2)
        
        if [[ -n "$LATEST_BACKUP" ]]; then
            BACKUP_DATE=$(stat -c %y "$LATEST_BACKUP" | cut -d' ' -f1)
            BACKUP_SIZE=$(du -sh "$LATEST_BACKUP" | cut -f1)
            
            echo "📦 Available backups: $BACKUP_COUNT"
            echo "🕒 Latest backup: $BACKUP_DATE"
            echo "📏 Size: $BACKUP_SIZE"
        else
            echo "❌ No backups found"
        fi
    else
        echo "❌ Backup directory does not exist"
    fi
    echo
}

# Function to check Immich specific metrics
check_immich_metrics() {
    print_status "Checking Immich metrics..."
    
    echo "📸 Immich Metrics"
    echo "=================="
    
    IMMICH_DIR="/mnt/nvme/immich"
    
    if [[ -d "$IMMICH_DIR" ]]; then
        # Check upload directory
        if [[ -d "$IMMICH_DIR/upload" ]]; then
            UPLOAD_SIZE=$(du -sh "$IMMICH_DIR/upload" | cut -f1)
            PHOTO_COUNT=$(find "$IMMICH_DIR/upload" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.mp4" -o -name "*.mov" \) | wc -l)
            echo "📁 Upload directory: $UPLOAD_SIZE ($PHOTO_COUNT files)"
        fi
        
        # Check database size
        if [[ -d "$IMMICH_DIR/postgres" ]]; then
            DB_SIZE=$(du -sh "$IMMICH_DIR/postgres" | cut -f1)
            echo "🗄️  Database size: $DB_SIZE"
        fi
        
        # Check Redis cache
        if [[ -d "$IMMICH_DIR/redis" ]]; then
            REDIS_SIZE=$(du -sh "$IMMICH_DIR/redis" | cut -f1)
            echo "⚡ Redis cache: $REDIS_SIZE"
        fi
    else
        echo "❌ Immich directory not found"
    fi
    echo
}

# Function to generate complete report
generate_report() {
    print_status "Generating complete report..."
    
    REPORT_FILE="/tmp/homelab_monitoring_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "🏠 Homelab Monitoring Report"
        echo "============================"
        echo "📅 Date: $(date)"
        echo "🖥️  Hostname: $(hostname)"
        echo "🌐 IP: $(hostname -I | awk '{print $1}')"
        echo
        
        get_system_metrics
        check_system_services
        check_docker_containers
        check_docker_volumes
        check_docker_networks
        check_service_connectivity
        check_error_logs
        check_disk_space
        check_backups
        check_immich_metrics
        
    } > "$REPORT_FILE"
    
    print_success "Report generated: $REPORT_FILE"
}

# Function to show summary
show_summary() {
    print_success "Monitoring completed!"
    echo
    echo "=========================================="
    echo "📊 Monitoring Summary"
    echo "=========================================="
    echo
    echo "🕒 Date: $(date)"
    echo "⏱️  Duration: $(date -d@$(($(date +%s) - START_TIME)) -u +%H:%M:%S)"
    echo
    echo "📈 Metrics checked:"
    echo "   - System (CPU, Memory, Disk, NVMe)"
    echo "   - System services"
    echo "   - Docker containers"
    echo "   - Volumes and networks"
    echo "   - Service connectivity"
    echo "   - Error logs"
    echo "   - Disk space"
    echo "   - Backup status"
    echo "   - Immich metrics"
    echo
    echo "📋 Complete report saved to: /tmp/homelab_monitoring_*.txt"
    echo
}

# Main function
main() {
    START_TIME=$(date +%s)
    
    echo "📊 Homelab Monitoring Script"
    echo "============================="
    echo
    
    get_system_metrics
    check_system_services
    check_docker_containers
    check_docker_volumes
    check_docker_networks
    check_service_connectivity
    check_error_logs
    check_disk_space
    check_backups
    check_immich_metrics
    generate_report
    show_summary
}

# Run main script
main "$@"