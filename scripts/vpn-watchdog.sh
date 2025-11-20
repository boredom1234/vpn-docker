#!/bin/bash

# Watchdog script to monitor OpenVPN connection
LOG_FILE="/var/log/vpn/watchdog.log"
OVPN_PID_FILE="/var/run/openvpn.pid"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "Starting VPN Watchdog..."

while true; do
    # Check if OpenVPN process is running
    if ! pgrep -x openvpn > /dev/null; then
        log "CRITICAL: OpenVPN process is not running!"
        # In a real scenario, we might want to trigger a restart or exit the container
        # For now, we'll just log it, as the main entrypoint should handle restarts or the container will die
    fi

    # Check if tun0 interface exists
    if ! ip addr show tun0 > /dev/null 2>&1; then
        log "WARNING: tun0 interface not found!"
    else
        # Optional: Ping check to verify connectivity through tunnel
        # ping -c 1 -I tun0 8.8.8.8 > /dev/null 2>&1
        # if [ $? -ne 0 ]; then
        #     log "WARNING: Connectivity check through tun0 failed!"
        # fi
        :
    fi

    sleep 30
done
