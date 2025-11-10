FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install OpenVPN + Tinyproxy + tools
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    openvpn tinyproxy iproute2 iputils-ping ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*

# Copy config and startup script
COPY tinyproxy.conf /etc/tinyproxy/tinyproxy.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Mount folder with your .ovpn
VOLUME ["/vpn"]

# Expose proxy port
EXPOSE 8888/tcp

ENTRYPOINT ["/entrypoint.sh"]
