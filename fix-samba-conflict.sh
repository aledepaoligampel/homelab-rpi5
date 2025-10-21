#!/bin/bash

# Script para resolver conflicto de puertos Samba
# Ejecutar antes de docker-compose up -d

echo "🔧 Resolviendo conflicto de puertos Samba..."

# Detener servicios de Samba del sistema
echo "Deteniendo servicios de Samba del sistema..."
sudo systemctl stop smbd 2>/dev/null || true
sudo systemctl stop nmbd 2>/dev/null || true

# Deshabilitar servicios para evitar que se inicien automáticamente
echo "Deshabilitando servicios de Samba..."
sudo systemctl disable smbd 2>/dev/null || true
sudo systemctl disable nmbd 2>/dev/null || true

# Verificar que los puertos estén libres
echo "Verificando puertos 139 y 445..."
if netstat -tuln 2>/dev/null | grep -q ":139\|:445"; then
    echo "⚠️  Aún hay procesos usando los puertos SMB"
    echo "Procesos encontrados:"
    netstat -tuln | grep ":139\|:445"
    echo ""
    echo "Para resolver manualmente:"
    echo "sudo lsof -i :139"
    echo "sudo lsof -i :445"
    echo "sudo kill -9 <PID>"
else
    echo "✅ Puertos 139 y 445 están libres"
fi

echo ""
echo "🎉 Conflicto resuelto. Ahora puedes ejecutar:"
echo "docker-compose down"
echo "docker-compose up -d"
