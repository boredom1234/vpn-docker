# VPN Docker Proxy

A robust, containerized solution that combines OpenVPN client connectivity with HTTP and SOCKS5 proxy servers. It routes all traffic through a VPN connection with enterprise-grade security features including a kill switch and DNS leak prevention.

## Overview

This project creates a Docker container that:

- Connects to an OpenVPN server using your `.ovpn` configuration file
- Runs a **Tinyproxy** HTTP proxy server on port 8888
- Runs a **Dante** SOCKS5 proxy server on port 1080
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
│ SOCKS5 Proxy    │      │ Dante Server     │    │                 │
│ (Port 1080)     │      │                  │    │                 │
└─────────────────┘      └──────────────────┘    └─────────────────┘
```

## Features

- **Dual Proxy Support**: HTTP/HTTPS (8888) and SOCKS5 (1080)
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

### 3. Configure Your Applications

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

### Check Status

```bash
docker-compose ps
# Look for "healthy" status
```

### View Logs

Logs are persisted to the `./logs` directory on your host:

- `logs/openvpn.log`: VPN connection logs
- `logs/tinyproxy.log`: HTTP proxy access logs
- `logs/danted.log`: SOCKS5 proxy logs

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
