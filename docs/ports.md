# Port Configuration Summary

This document lists all ports used by the homelab services to ensure no conflicts.

## Port Usage Summary

| Service                 | Port  | Protocol | Description                 |
| ----------------------- | ----- | -------- | --------------------------- |
| **Portainer**           | 9000  | TCP      | Docker management interface |
| **Immich**              | 2283  | TCP      | Photo/video management      |
| **Home Assistant**      | 8123  | TCP      | Home automation             |
| **AdGuard Home**        | 53    | TCP/UDP  | DNS server                  |
| **AdGuard Home**        | 3000  | TCP      | Web interface               |
| **Samba**               | 139   | TCP      | SMB protocol                |
| **Samba**               | 445   | TCP      | SMB protocol                |
| **Nginx Proxy Manager** | 80    | TCP      | HTTP                        |
| **Nginx Proxy Manager** | 81    | TCP      | Admin interface             |
| **Nginx Proxy Manager** | 443   | TCP      | HTTPS                       |
| **Stremio**             | 11470 | TCP      | Media streaming             |
| **Transmission**        | 9091  | TCP      | Web interface               |
| **Transmission**        | 51413 | TCP/UDP  | BitTorrent                  |

## Port Verification

✅ **No conflicts detected** - All ports are unique and properly assigned.

## Reserved Ports

The following ports are reserved for system services and should not be used:

- **22**: SSH
- **25**: SMTP
- **53**: DNS (used by AdGuard Home)
- **80**: HTTP (used by Nginx Proxy Manager)
- **443**: HTTPS (used by Nginx Proxy Manager)
- **139**: SMB (used by Samba)
- **445**: SMB (used by Samba)

## Network Configuration

All services are configured to run on the homelab network (172.20.0.0/16) with external access through the specified ports on your configured IP address.

## Firewall Rules

The installation script automatically configures UFW firewall with the following rules:

```bash
# Allow SSH
sudo ufw allow ssh

# Allow homelab services
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 9000/tcp  # Portainer
sudo ufw allow 8123/tcp  # Home Assistant
sudo ufw allow 3000/tcp  # AdGuard Home
sudo ufw allow 3001/tcp  # AdGuard Home (if needed)
sudo ufw allow 9091/tcp  # Transmission
sudo ufw allow 11470/tcp # Stremio
sudo ufw allow 2283/tcp  # Immich
```

## Troubleshooting Port Issues

If you encounter port conflicts:

1. **Check if port is in use:**

   ```bash
   sudo netstat -tulpn | grep :PORT_NUMBER
   ```

2. **Kill process using port:**

   ```bash
   sudo kill -9 PID
   ```

3. **Check Docker port usage:**

   ```bash
   docker ps --format "table {{.Names}}\t{{.Ports}}"
   ```

4. **Verify firewall rules:**
   ```bash
   sudo ufw status
   ```

## Custom Port Configuration

To change ports, modify the `docker-compose.yml` file:

```yaml
services:
  service-name:
    ports:
      - "NEW_PORT:CONTAINER_PORT"
```

Then update the firewall rules accordingly:

```bash
sudo ufw allow NEW_PORT/tcp
```

---

**All ports are properly configured and conflict-free! ✅**
