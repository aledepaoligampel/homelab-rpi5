#!/bin/bash

# Script de instalación de Dokploy para Homelab
# Este script instala Dokploy usando Docker Compose en lugar del script oficial

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para imprimir mensajes
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar que estamos en el directorio correcto
if [ ! -f "docker-compose.yml" ]; then
    print_error "No se encontró docker-compose.yml. Ejecuta este script desde el directorio raíz del homelab."
    exit 1
fi

# Verificar que Docker está ejecutándose
if ! docker info > /dev/null 2>&1; then
    print_error "Docker no está ejecutándose. Por favor, inicia Docker primero."
    exit 1
fi

# Verificar que Docker Compose está disponible
if ! command -v docker-compose > /dev/null 2>&1; then
    print_error "Docker Compose no está instalado. Por favor, instálalo primero."
    exit 1
fi

print_status "Iniciando instalación de Dokploy..."

# Crear directorio para datos de Dokploy
print_status "Creando directorio para datos de Dokploy..."
sudo mkdir -p /mnt/nvme/dokploy
sudo chown -R $USER:$USER /mnt/nvme/dokploy

# Verificar que los puertos están libres
print_status "Verificando puertos..."
if netstat -tuln | grep -q ":80 "; then
    print_warning "Puerto 80 está en uso. Verificando configuración..."
fi

if netstat -tuln | grep -q ":3000 "; then
    print_warning "Puerto 3000 está en uso. Verificando configuración..."
fi

# Levantar solo el servicio de Dokploy
print_status "Levantando servicio de Dokploy..."
docker-compose up -d dokploy

# Esperar a que el servicio esté listo
print_status "Esperando a que Dokploy esté listo..."
sleep 10

# Verificar que el servicio está ejecutándose
if docker-compose ps dokploy | grep -q "Up"; then
    print_status "✅ Dokploy se ha instalado correctamente!"
    print_status "🌐 Accede a Dokploy en: http://tu-ip:80"
    print_status "🔧 O usando el dominio: http://dokploy.${DOMAIN:-localhost}"
    print_status ""
    print_status "📋 Información importante:"
    print_status "   - Puerto 80: Interfaz web de Dokploy"
    print_status "   - Puerto 3000: Servidor de aplicación de Dokploy"
    print_status "   - Datos almacenados en: /mnt/nvme/dokploy"
    print_status ""
    print_status "🔄 Para reiniciar: docker-compose restart dokploy"
    print_status "🛑 Para detener: docker-compose stop dokploy"
    print_status "📊 Para ver logs: docker-compose logs dokploy"
else
    print_error "❌ Error al instalar Dokploy. Revisa los logs:"
    docker-compose logs dokploy
    exit 1
fi

print_status "🎉 ¡Instalación de Dokploy completada!"
