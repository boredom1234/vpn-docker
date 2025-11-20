# VPN Docker Proxy

A robust, containerized solution that combines OpenVPN client connectivity with HTTP and SOCKS5 proxy servers, plus a web dashboard for monitoring. It routes all traffic through a VPN connection with enterprise-grade security features including a kill switch and DNS leak prevention.

## Overview

This project creates a Docker container that:

- Connects to an OpenVPN server using your `.ovpn` configuration file
- Runs a **Tinyproxy** HTTP proxy server on port 8888
- Runs a **Dante** SOCKS5 proxy server on port 1080
- Provides a **Web Dashboard** on port 9090 for monitoring and control
- Routes all proxy traffic through the established VPN tunnel
- **Kill Switch**: Blocks all non-VPN traffic if the connection drops
- **DNS Leak Protection**: Forces DNS queries through the VPN
- **Health Monitoring**: Auto-restarts if components fail

## Architecture

```
┌─────────────────┐      ┌──────────────────┐    ┌─────────────────┐
│   Your Device   │───▶ │  Docker Container│───▶│   VPN Server    │
│                 │      │                  │    │                 │
│ HTTP Proxy      │      │ OpenVPN Client + │    │ Internet Access │
│ (Port 8888)     │      │ Tinyproxy +      │    │                 │
│ SOCKS5 Proxy    │      │ Dante Server +   │    │                 │
│ (Port 1080)     │      │ Web Dashboard    │    │                 │
│ Dashboard       │      │                  │    │                 │
│ (Port 9090)     │      │                  │    │                 │
└─────────────────┘      └──────────────────┘    └─────────────────┘
```

## Features

- **Dual Proxy Support**: HTTP/HTTPS (8888) and SOCKS5 (1080)
- **Web Dashboard**: Real-time monitoring interface on port 9090
  - Live VPN status and public IP display
  - Bandwidth usage graphs
  - System logs viewer
  - VPN restart controls
- **Security First**:
  - **Kill Switch**: Firewall rules prevent traffic leakage if VPN drops
  - **DNS Leak Prevention**: Custom DNS configuration
  - **Isolated**: Runs in a secure Docker container
- **Reliability**:
  - **Health Checks**: Docker native health monitoring
  - **Watchdog Script**: Monitors VPN connection internally
  - **Auto-Recovery**: Services restart on failure
- **Observability**:
  - **Structured Logging**: Logs to `./logs` on host
  - **Traffic Analysis**: Built-in script to analyze usage

## Prerequisites

- Docker and Docker Compose installed
- A valid OpenVPN configuration file (`.ovpn`)

## Quick Start

### 1. Setup Configuration

Place your OpenVPN configuration file in the `openvpn/` directory. You can name it `client.ovpn` or specify the name in `docker-compose.yml`.

```bash
cp your-vpn-config.ovpn openvpn/client.ovpn
```

### 2. Start the Container

```bash
docker-compose up -d --build
```

### 3. Access Services

**Web Dashboard:**

- URL: `http://localhost:9090`
- Features: Real-time status, bandwidth graphs, logs, and controls

**HTTP Proxy:**

- Host: `localhost`
- Port: `8888`

**SOCKS5 Proxy:**

- Host: `localhost`
- Port: `1080`

## Configuration

### Environment Variables

You can configure the container via `docker-compose.yml`:

| Variable           | Default           | Description                         |
| ------------------ | ----------------- | ----------------------------------- |
| `OVPN_FILE`        | `client.ovpn`     | Name of the config file in `/vpn`   |
| `HTTP_PROXY_PORT`  | `8888`            | Port for HTTP proxy                 |
| `SOCKS_PROXY_PORT` | `1080`            | Port for SOCKS5 proxy               |
| `PROXY_USER`       | -                 | Username for Basic Auth (Tinyproxy) |
| `PROXY_PASS`       | -                 | Password for Basic Auth (Tinyproxy) |
| `DNS_SERVERS`      | `8.8.8.8 1.1.1.1` | DNS servers to use                  |

### Authentication

To enable Basic Authentication for the HTTP proxy, set `PROXY_USER` and `PROXY_PASS` in `docker-compose.yml`.

## Monitoring & Troubleshooting

### Web Dashboard

The easiest way to monitor your VPN proxy is through the web dashboard at `http://localhost:9090`. It provides:

- Real-time VPN connection status
- Current public IP address
- System uptime
- Live bandwidth usage graphs
- Recent system logs
- Quick restart button

### Check Status (CLI)

```bash
docker-compose ps
# Look for "healthy" status
```

### View Logs

Logs are persisted to the `./logs` directory on your host:

- `logs/openvpn.log`: VPN connection logs
- `logs/tinyproxy.log`: HTTP proxy access logs
- `logs/danted.log`: SOCKS5 proxy logs
- `logs/dashboard.log`: Web dashboard logs

### Analyze Traffic

Run the built-in analyzer script:

```bash
docker exec vpn-proxy /scripts/request-analyzer.sh
```

### Test Connection

```bash
# Test HTTP Proxy
curl --proxy http://localhost:8888 https://ipinfo.io

# Test SOCKS5 Proxy
curl --socks5-hostname localhost:1080 https://ipinfo.io
```

## Security Notes

- The container requires `NET_ADMIN` capability to manage network interfaces and iptables.
- The Kill Switch uses `iptables` to drop all outgoing traffic that doesn't go through the `tun0` interface (except for the initial VPN connection).
- DNS queries are forced through the VPN tunnel to prevent DNS leaks.
- All services run in an isolated Docker container with minimal privileges.

## Project Structure

```
vpn-docker/
├── docker-compose.yml       # Container orchestration
├── Dockerfile              # Container build instructions
├── entrypoint.sh           # Startup script
├── tinyproxy.conf          # HTTP proxy configuration
├── danted.conf             # SOCKS5 proxy configuration
├── logrotate.conf          # Log rotation configuration
├── openvpn/               # OpenVPN configuration directory
│   └── client.ovpn        # Your VPN configuration file
├── scripts/               # Utility scripts
│   ├── vpn-watchdog.sh    # VPN monitoring script
│   └── request-analyzer.sh # Traffic analysis script
├── dashboard/             # Web dashboard
│   ├── app.py            # Flask backend
│   └── templates/
│       └── index.html    # Dashboard UI
└── logs/                 # Log files (auto-created)
```

## License

MIT License - Feel free to use and modify as needed.
