#!/bin/bash

# Watchdog script to monitor OpenVPN connection
LOG_FILE="/var/log/vpn/watchdog.log"
OVPN_PID_FILE="/var/run/openvpn.pid"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "Starting VPN Watchdog..."
TUN_STATUS="DOWN"

while true; do
    # Check if OpenVPN process is running
    if ! pgrep -x openvpn > /dev/null; then
        log "CRITICAL: OpenVPN process is not running! Restarting..."
        
        # Get active config
        if [ -f /etc/vpn-active-config ]; then
            ACTIVE_CONFIG=$(cat /etc/vpn-active-config)
        else
            ACTIVE_CONFIG="/vpn/client.ovpn" # Fallback
        fi

        log "Restarting with config: $ACTIVE_CONFIG"
        
        # Restart OpenVPN
        openvpn --config "$ACTIVE_CONFIG" --daemon --log "/var/log/vpn/openvpn.log" --writepid /var/run/openvpn.pid
        
        # Wait for it to initialize
        sleep 5
    fi

    # Check if tun0 interface exists
    if ip addr show tun0 > /dev/null 2>&1; then
        # tun0 is UP
        if [ "$TUN_STATUS" != "UP" ]; then
            log "VPN Connection Restored (tun0 up). Restarting proxies..."
            TUN_STATUS="UP"
            
            # Restart Proxies to bind to new interface
            killall tinyproxy danted 2>/dev/null || true
            sleep 1
            tinyproxy -c /etc/tinyproxy/tinyproxy.conf
            danted -D -f /etc/danted.conf
        fi
    else
        # tun0 is DOWN
        if [ "$TUN_STATUS" == "UP" ]; then
            log "WARNING: VPN Connection dropped (tun0 down)."
            TUN_STATUS="DOWN"
        fi
        
        # If tun0 is down for too long, maybe we should force kill OpenVPN?
        # For now, we rely on OpenVPN's internal reconnect or the process dying.
    fi

    sleep 5
done
