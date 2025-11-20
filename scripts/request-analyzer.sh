#!/bin/bash

LOG_FILE="/var/log/vpn/tinyproxy.log"

if [ ! -f "$LOG_FILE" ]; then
    echo "Log file not found: $LOG_FILE"
    exit 1
fi

echo "=== Tinyproxy Request Analysis ==="
echo "Total Requests: $(wc -l < "$LOG_FILE")"
echo ""
echo "Top 10 Requested Domains:"
grep "CONNECT" "$LOG_FILE" | awk '{print $4}' | cut -d: -f1 | sort | uniq -c | sort -nr | head -10

echo ""
echo "Top 10 Client IPs:"
grep "CONNECT" "$LOG_FILE" | awk '{print $2}' | sort | uniq -c | sort -nr | head -10
