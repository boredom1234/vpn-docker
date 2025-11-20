FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install OpenVPN + Tinyproxy + Dante (SOCKS5) + tools
RUN apt-get update \
   && apt-get install -y --no-install-recommends \
   openvpn \
   tinyproxy \
   dante-server \
   iproute2 \
   iputils-ping \
   ca-certificates \
   curl \
   iptables \
   procps \
   psmisc \
   netcat-openbsd \
   logrotate \
   dos2unix \
   && rm -rf /var/lib/apt/lists/*

# Copy config and startup script
COPY tinyproxy.conf /etc/tinyproxy/tinyproxy.conf
COPY danted.conf /etc/danted.conf
COPY logrotate.conf /etc/logrotate.d/vpn-proxy
COPY entrypoint.sh /entrypoint.sh
COPY scripts/ /scripts/

# Fix line endings for scripts and config files
RUN dos2unix /entrypoint.sh /scripts/*.sh /etc/tinyproxy/tinyproxy.conf /etc/danted.conf /etc/logrotate.d/vpn-proxy \
   && chmod +x /entrypoint.sh /scripts/*.sh

# Create directories for logs and cache
RUN mkdir -p /var/log/vpn /var/cache/tinyproxy \
   && chown -R nobody:nogroup /var/cache/tinyproxy \
   && touch /var/log/vpn/openvpn.log /var/log/vpn/tinyproxy.log /var/log/vpn/danted.log \
   && chmod 777 /var/log/vpn/*.log

# Mount folder with your .ovpn
VOLUME ["/vpn"]

# Expose proxy ports (HTTP + SOCKS5)
EXPOSE 8888/tcp 1080/tcp

ENTRYPOINT ["/entrypoint.sh"]
