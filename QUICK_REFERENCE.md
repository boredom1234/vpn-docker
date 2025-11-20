# VPN Docker Proxy - Quick Reference

## 🚀 Quick Start

```bash
# 1. Add your VPN config
cp your-config.ovpn openvpn/client.ovpn

# 2. Start the container
docker-compose up -d --build

# 3. Access dashboard
open http://localhost:9090
```

## 📡 Service Ports

| Service          | Port | Usage                 |
| ---------------- | ---- | --------------------- |
| **Dashboard**    | 9090 | Web UI for monitoring |
| **HTTP Proxy**   | 8888 | HTTP/HTTPS traffic    |
| **SOCKS5 Proxy** | 1080 | All TCP/UDP traffic   |

## 🔧 Common Commands

```bash
# View logs
docker-compose logs -f vpn-proxy

# Restart container
docker-compose restart

# Stop container
docker-compose down

# Rebuild after config changes
docker-compose up -d --build

# Check health
docker-compose ps

# Analyze traffic
docker exec vpn-proxy /scripts/request-analyzer.sh

# Access container shell
docker exec -it vpn-proxy bash
```

## 🌐 Browser Setup

### Firefox

1. Settings → Network Settings → Manual proxy configuration
2. HTTP Proxy: `localhost`, Port: `8888`
3. Check "Also use this proxy for HTTPS"
4. SOCKS Host: `localhost`, Port: `1080`, SOCKS v5

### Chrome/Edge

1. Settings → System → Open proxy settings
2. Manual proxy: `localhost:8888`

## 💻 CLI Usage

```bash
# Using HTTP proxy
curl --proxy http://localhost:8888 https://ipinfo.io

# Using SOCKS5 proxy
curl --socks5-hostname localhost:1080 https://ipinfo.io

# Set environment variables
export http_proxy=http://localhost:8888
export https_proxy=http://localhost:8888
export all_proxy=socks5://localhost:1080
```

## 🔐 Security Features

✅ **Kill Switch** - Blocks all non-VPN traffic  
✅ **DNS Leak Protection** - Forces DNS through VPN  
✅ **Health Monitoring** - Auto-restart on failure  
✅ **Proxy Authentication** - Optional HTTP auth  
✅ **Container Isolation** - Sandboxed environment

## 📊 Dashboard Features

- **Real-time Status**: VPN connection state
- **Public IP**: Current exit IP address
- **Uptime**: System running time
- **Bandwidth**: Live traffic graphs
- **Logs**: Recent system events
- **Controls**: Restart VPN button

## 🐛 Troubleshooting

### Container keeps restarting

```bash
# Check logs
docker logs vpn-proxy

# Common issue: Missing .ovpn file
ls -la openvpn/
```

### DNS resolution fails

```bash
# Verify VPN is connected
docker exec vpn-proxy ip addr show tun0

# Check DNS servers
docker exec vpn-proxy cat /etc/resolv.conf
```

### Proxy not accessible

```bash
# Check if ports are listening
docker exec vpn-proxy netstat -tlnp

# Verify firewall rules
docker exec vpn-proxy iptables -L -n
```

### Dashboard not loading

```bash
# Check dashboard logs
docker exec vpn-proxy tail -f /var/log/vpn/dashboard.log

# Restart container
docker-compose restart
```

## 🎯 Performance Tips

1. **Use SOCKS5** for better performance with non-HTTP traffic
2. **Monitor bandwidth** via dashboard to identify heavy usage
3. **Check VPN server location** - closer is faster
4. **Adjust Tinyproxy settings** in `tinyproxy.conf` for more connections

## 📝 Configuration Examples

### Enable Proxy Authentication

```yaml
# docker-compose.yml
environment:
  - PROXY_USER=myuser
  - PROXY_PASS=mypassword
```

### Change DNS Servers

```yaml
# docker-compose.yml
environment:
  - DNS_SERVERS=1.1.1.1 1.0.0.1
```

### Use Different VPN Config

```yaml
# docker-compose.yml
environment:
  - OVPN_FILE=my-custom-vpn.ovpn
```

## 🔄 Updates

```bash
# Pull latest changes
git pull

# Rebuild container
docker-compose down
docker-compose up -d --build
```

---

**Need help?** Check the full [README.md](README.md) for detailed documentation.
