#!/bin/bash
set -e

# Configuration
OVPN_CONFIG_DIR="/vpn"
OVPN_FILE="${OVPN_CONFIG_DIR}/${OVPN_FILE:-client.ovpn}"
LOG_DIR="/var/log/vpn"

# Function to handle shutdown
cleanup() {
    echo "Shutting down..."
    killall openvpn tinyproxy danted 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT

echo "=== VPN Docker Proxy Starting ==="

# 1. Validate OpenVPN Config
if [ ! -f "$OVPN_FILE" ]; then
    echo "ERROR: OpenVPN config not found at $OVPN_FILE"
    echo "Available files in $OVPN_CONFIG_DIR:"
    ls -1 "$OVPN_CONFIG_DIR"
    echo "Please mount your config to $OVPN_CONFIG_DIR and set OVPN_FILE env var if needed."
    sleep 60
    exit 1
fi

# 2. Setup DNS (Prevent Leaks)
echo "Configuring DNS..."
echo -n > /etc/resolv.conf
for dns in $DNS_SERVERS; do
    echo "nameserver $dns" >> /etc/resolv.conf
done

# Add static routes for DNS servers via default gateway to ensure they are always reachable via eth0
# This prevents DNS resolution failures when OpenVPN restarts and the default route is messed up
DEFAULT_GW=$(ip route show default | awk '/default/ {print $3}')
if [ -n "$DEFAULT_GW" ]; then
    echo "Adding static routes for DNS servers via $DEFAULT_GW..."
    for dns in $DNS_SERVERS; do
        ip route add "$dns" via "$DEFAULT_GW" dev eth0 2>/dev/null || true
    done
fi

# 3. Setup Tinyproxy Auth if provided
if [ -n "$PROXY_USER" ] && [ -n "$PROXY_PASS" ]; then
    echo "Enabling Basic Auth for Tinyproxy..."
    sed -i "s/# BasicAuth user password/BasicAuth $PROXY_USER $PROXY_PASS/" /etc/tinyproxy/tinyproxy.conf
fi

# 4. Start OpenVPN
echo "Starting OpenVPN..."
# Create tun device if not exists (sometimes needed in certain docker envs)
mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then
    mknod /dev/net/tun c 10 200
fi

# Initialize active config tracking
echo "$OVPN_FILE" > /etc/vpn-active-config

openvpn --config "$(cat /etc/vpn-active-config)" --daemon --log "$LOG_DIR/openvpn.log" --writepid /var/run/openvpn.pid

# 5. Wait for VPN Connection
echo "Waiting for tun0 interface..."
MAX_RETRIES=30
COUNT=0
while [ $COUNT -lt $MAX_RETRIES ]; do
    if ip addr show dev tun0 >/dev/null 2>&1; then
        echo "VPN Connected! (tun0 is up)"
        break
    fi
    sleep 1
    COUNT=$((COUNT+1))
    echo -n "."
done

if [ $COUNT -eq $MAX_RETRIES ]; then
    echo "ERROR: VPN connection failed to establish within $MAX_RETRIES seconds."
    echo "Check logs at $LOG_DIR/openvpn.log"
    cat "$LOG_DIR/openvpn.log"
    exit 1
fi

# 6. Configure Kill Switch (IPTables)
echo "Configuring Kill Switch..."
# Flush existing rules
iptables -F
iptables -X
# Default policy: Drop everything
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow Docker internal network (so proxy can be reached)
# Assuming standard docker subnets, adjust if needed or use specific ranges
iptables -A INPUT -s 172.16.0.0/12 -j ACCEPT
iptables -A OUTPUT -d 172.16.0.0/12 -j ACCEPT
iptables -A INPUT -s 192.168.0.0/16 -j ACCEPT
iptables -A OUTPUT -d 192.168.0.0/16 -j ACCEPT
iptables -A INPUT -s 10.0.0.0/8 -j ACCEPT
iptables -A OUTPUT -d 10.0.0.0/8 -j ACCEPT

# Allow VPN connection establishment (UDP/TCP 1194 usually, but we allow output to VPN remote)
# We need to allow traffic to the VPN server IP on the physical interface (eth0)
# Since we don't know the VPN server IP easily without parsing config, we rely on the route
# A simpler approach for container: Allow output on eth0 only for VPN port? 
# Or better: Allow all traffic on tun0, and only VPN traffic on eth0.
iptables -A OUTPUT -o tun0 -j ACCEPT
iptables -A INPUT -i tun0 -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow connection to VPN server (this is tricky if dynamic, but essential)
# For now, we allow all output on eth0 to establish the tunnel, but we could restrict it if we parsed the remote.
# STRICT MODE: Only allow UDP/TCP to specific ports on eth0
iptables -A OUTPUT -o eth0 -p udp -m multiport --dports 1194,443,1195 -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp -m multiport --dports 1194,443,1195 -j ACCEPT
iptables -A INPUT -i eth0 -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow DNS on eth0 for initial resolution (essential for VPN server lookup)
iptables -A OUTPUT -o eth0 -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --dport 53 -j ACCEPT

# Allow DNS through VPN tunnel (port 53 UDP/TCP)
iptables -A OUTPUT -o tun0 -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -o tun0 -p tcp --dport 53 -j ACCEPT
iptables -A INPUT -i tun0 -p udp --sport 53 -j ACCEPT
iptables -A INPUT -i tun0 -p tcp --sport 53 -j ACCEPT

# 7. Start Proxies
echo "Starting Tinyproxy..."
tinyproxy -c /etc/tinyproxy/tinyproxy.conf

echo "Starting Dante (SOCKS5)..."
# Dante needs to bind to tun0, which might not have IP immediately ready or stable?
# danted.conf uses 'external: tun0', so it should be fine.
danted -D -f /etc/danted.conf

# 8. Start Watchdog
/scripts/vpn-watchdog.sh &

# 9. Start Dashboard
echo "Starting Dashboard..."
python3 /dashboard/app.py > /var/log/vpn/dashboard.log 2>&1 &

echo "=== Setup Complete ==="
echo "HTTP Proxy: Port 8888"
echo "SOCKS5 Proxy: Port 1080"
echo "Dashboard: http://localhost:9090"
echo "Public IP via VPN:"
curl --socks5-hostname localhost:1080 https://ifconfig.me --max-time 10 || echo "Check failed"

# Keep container running and tail logs
tail -f "$LOG_DIR/openvpn.log" "$LOG_DIR/tinyproxy.log" "$LOG_DIR/danted.log" &
wait
