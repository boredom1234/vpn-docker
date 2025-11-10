set -e

OVPN_FILE="/vpn/client.ovpn"

if [ ! -f "$OVPN_FILE" ]; then
  echo "ERROR: OpenVPN config not found at $OVPN_FILE"
  echo "Place your .ovpn file at ./openvpn/client.ovpn before starting."
  sleep 86400
  exit 1
fi

echo "Starting OpenVPN..."
openvpn --config "$OVPN_FILE" --daemon --log /var/log/openvpn.log

echo "Waiting for tun device..."
i=0
while [ $i -lt 30 ]; do
  if ip addr show dev tun0 >/dev/null 2>&1; then
    echo "tun0 available"
    break
  fi
  i=$((i+1))
  sleep 1
done

echo "=== ip addr ==="
ip addr
echo "=== ip route ==="
ip route

echo "Starting tinyproxy..."
tinyproxy -d
