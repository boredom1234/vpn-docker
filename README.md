# VPN Docker Proxy

A containerized solution that combines OpenVPN client connectivity with an HTTP proxy server, allowing you to route traffic through a VPN connection via a simple proxy interface.

## Overview

This project creates a Docker container that:

- Connects to an OpenVPN server using your `.ovpn` configuration file
- Runs a Tinyproxy HTTP proxy server on port 8888
- Routes all proxy traffic through the established VPN tunnel
- Provides network isolation and security for your browsing

## Architecture

```
┌─────────────────┐      ┌──────────────────┐    ┌─────────────────┐
│   Your Device   │───▶ │  Docker Container│───▶│   VPN Server    │
│                 │      │                  │    │                 │
│ HTTP Proxy      │      │ OpenVPN Client + │    │ Internet Access │
│ (Port 8888)     │      │ Tinyproxy Server │    │                 │
└─────────────────┘      └──────────────────┘    └─────────────────┘
```

## Features

- **VPN Integration**: Automatically connects to your OpenVPN server
- **HTTP Proxy**: Provides HTTP/HTTPS proxy on port 8888
- **Network Security**: All traffic routed through VPN tunnel
- **Container Isolation**: Runs in isolated Docker environment
- **Auto-restart**: Container restarts automatically unless stopped
- **Health Monitoring**: Built-in connection verification and logging

## Prerequisites

- Docker and Docker Compose installed
- A valid OpenVPN configuration file (`.ovpn`)
- VPN service credentials (if required by your `.ovpn` file)

## Quick Start

### 1. Setup Configuration

Place your OpenVPN configuration file in the `openvpn/` directory:

```bash
cp your-vpn-config.ovpn openvpn/client.ovpn
```

### 2. Start the Container

```bash
docker-compose up -d
```

### 3. Configure Your Applications

Set your applications to use the HTTP proxy:

- **Proxy Host**: `localhost` (or your Docker host IP)
- **Proxy Port**: `8888`
- **Protocol**: HTTP

## Project Structure

```
vpn-docker/
├── docker-compose.yml    # Container orchestration
├── Dockerfile           # Container build instructions
├── entrypoint.sh        # Startup script
├── tinyproxy.conf       # Proxy server configuration
├── openvpn/            # OpenVPN configuration directory
│   └── client.ovpn     # Your VPN configuration file
└── scripts/            # Additional scripts (if needed)
```

## Configuration Files

### Docker Compose (`docker-compose.yml`)

- Builds the container with necessary privileges (`NET_ADMIN`)
- Mounts TUN device for VPN connectivity
- Exposes proxy port 8888
- Mounts OpenVPN config directory

### Dockerfile

- Based on Ubuntu 22.04
- Installs OpenVPN, Tinyproxy, and networking tools
- Configures container environment

### Entrypoint Script (`entrypoint.sh`)

- Validates OpenVPN configuration presence
- Starts OpenVPN client in daemon mode
- Waits for VPN tunnel establishment
- Starts Tinyproxy server

### Tinyproxy Configuration (`tinyproxy.conf`)

- Listens on port 8888
- Allows connections from Docker networks
- Configured for HTTP/HTTPS traffic

## Usage Examples

### Browser Configuration

Configure your browser to use `localhost:8888` as HTTP proxy.

### Command Line Tools

```bash
# Using curl
curl --proxy http://localhost:8888 https://ipinfo.io

# Using wget
wget --proxy=on --http-proxy=localhost:8888 https://ipinfo.io
```

### Environment Variables

```bash
export http_proxy=http://localhost:8888
export https_proxy=http://localhost:8888
```

## Monitoring and Troubleshooting

### View Container Logs

```bash
docker-compose logs -f vpn-proxy
```

### Check VPN Connection

```bash
docker exec vpn-proxy ip addr show tun0
docker exec vpn-proxy ip route
```

### Test Proxy Connection

```bash
curl --proxy http://localhost:8888 https://ipinfo.io
```

### Common Issues

1. **OpenVPN config not found**: Ensure `client.ovpn` exists in `openvpn/` directory
2. **Permission denied**: Container needs `NET_ADMIN` capability and TUN device access
3. **Connection timeout**: Check your VPN credentials and server availability
4. **Proxy not responding**: Verify container is running and port 8888 is accessible

## Security Considerations

- The container runs with elevated privileges (`NET_ADMIN`) for VPN functionality
- Proxy access is restricted to Docker networks and localhost
- All traffic is encrypted through the VPN tunnel
- Consider using Docker secrets for sensitive VPN credentials

## Customization

### Changing Proxy Port

1. Modify `Port` in `tinyproxy.conf`
2. Update port mapping in `docker-compose.yml`
3. Rebuild container: `docker-compose up --build -d`

### Adding Authentication

Edit `tinyproxy.conf` to add basic authentication or IP restrictions.

### Multiple VPN Configs

Create multiple compose files or modify the existing one to support different VPN configurations.
