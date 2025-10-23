#!/bin/bash

# Homelab Configuration Update Script
# Este script aplica las actualizaciones de configuración sin reinstalar todo

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir mensajes
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

# Verificar que estamos en el directorio correcto
check_directory() {
    if [ ! -f "docker-compose.yml" ]; then
        print_error "No se encontró docker-compose.yml. Ejecuta este script desde el directorio raíz del homelab."
        exit 1
    fi
    print_success "Directorio correcto detectado"
}

# Verificar que Docker está ejecutándose
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker no está ejecutándose. Por favor, inicia Docker primero."
        exit 1
    fi
    print_success "Docker está ejecutándose"
}

# Crear directorio para Dokploy
create_dokploy_directory() {
    print_status "Creando directorio para Dokploy..."
    sudo mkdir -p /mnt/nvme/dokploy
    sudo chown -R $USER:$USER /mnt/nvme/dokploy
    print_success "Directorio de Dokploy creado"
}

# Actualizar reglas de firewall
update_firewall_rules() {
    print_status "Actualizando reglas de firewall..."
    
    # Agregar nuevas reglas para los puertos actualizados
    sudo ufw allow 80/tcp    # Dokploy
    sudo ufw allow 3000/tcp # Dokploy
    sudo ufw allow 8080/tcp # Nginx Proxy Manager (nuevo puerto)
    sudo ufw allow 8081/tcp # Stremio (nuevo puerto)
    sudo ufw allow 3001/tcp # AdGuard Home (nuevo puerto)
    
    print_success "Reglas de firewall actualizadas"
}

# Detener servicios que necesitan cambios de puerto
stop_services_for_update() {
    print_status "Deteniendo servicios para actualización de puertos..."
    
    # Detener servicios que cambian de puerto
    docker-compose stop nginx-proxy-manager stremio adguardhome 2>/dev/null || true
    
    print_success "Servicios detenidos para actualización"
}

# Aplicar cambios de configuración
apply_configuration_changes() {
    print_status "Aplicando cambios de configuración..."
    
    # Crear directorio de Dokploy si no existe
    create_dokploy_directory
    
    # Actualizar firewall
    update_firewall_rules
    
    # Detener servicios que necesitan cambios
    stop_services_for_update
    
    print_success "Cambios de configuración aplicados"
}

# Reiniciar servicios con nueva configuración
restart_services() {
    print_status "Reiniciando servicios con nueva configuración..."
    
    # Levantar todos los servicios
    docker-compose up -d
    
    print_success "Servicios reiniciados"
}

# Verificar que los servicios están funcionando
verify_services() {
    print_status "Verificando servicios..."
    
    # Esperar un poco para que los servicios se inicien
    sleep 15
    
    # Verificar servicios críticos
    local services=("portainer" "homeassistant" "immich-server" "transmission" "dokploy")
    
    for service in "${services[@]}"; do
        if docker ps --format "{{.Names}}" | grep -q "$service"; then
            print_success "✓ $service está ejecutándose"
        else
            print_warning "⚠ $service no está ejecutándose"
        fi
    done
}

# Mostrar información de acceso actualizada
show_access_info() {
    print_success "¡Actualización completada!"
    echo
    echo "=========================================="
    echo "🌐 URLs de Acceso Actualizadas"
    echo "=========================================="
    echo
    echo "🆕 NUEVOS SERVICIOS:"
    echo "   Dokploy:              http://$(hostname -I | awk '{print $1}'):3002"
    echo
    echo "🔄 SERVICIOS CON PUERTOS ACTUALIZADOS:"
    echo "   Nginx Proxy Manager:  http://$(hostname -I | awk '{print $1}'):80 (puerto estándar)"
    echo "   Stremio:              http://$(hostname -I | awk '{print $1}'):8080 (puerto estándar)"
    echo "   AdGuard Home:        http://$(hostname -I | awk '{print $1}'):3000 (puerto estándar)"
    echo
    echo "📋 SERVICIOS SIN CAMBIOS:"
    echo "   Portainer:            http://$(hostname -I | awk '{print $1}'):9000"
    echo "   Home Assistant:       http://$(hostname -I | awk '{print $1}'):8123"
    echo "   Immich:               http://$(hostname -I | awk '{print $1}'):2283"
    echo "   Transmission:         http://$(hostname -I | awk '{print $1}'):9091"
    echo
    echo "=========================================="
    echo "🔧 Comandos Útiles"
    echo "=========================================="
    echo "   docker-compose ps                    # Ver estado de servicios"
    echo "   docker-compose logs dokploy           # Ver logs de Dokploy"
    echo "   docker-compose restart [servicio]     # Reiniciar servicio específico"
    echo "   ./scripts/update.sh                  # Actualizar sistema completo"
    echo
    echo "⚠️  IMPORTANTE:"
    echo "   - Actualiza tus bookmarks con los nuevos puertos"
    echo "   - Configura Dokploy a través de la interfaz web"
    echo "   - Verifica que todos los servicios funcionan correctamente"
    echo
}

# Función principal
main() {
    echo "🔄 Actualización de Configuración del Homelab"
    echo "============================================="
    echo
    
    check_directory
    check_docker
    apply_configuration_changes
    restart_services
    verify_services
    show_access_info
}

# Ejecutar script principal
main "$@"
