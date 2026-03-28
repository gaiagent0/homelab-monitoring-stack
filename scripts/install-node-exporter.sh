#!/bin/bash
# Install Node Exporter on all Proxmox nodes
# Run from pve-01 as root
# Source: https://github.com/gaiagent0/homelab-monitoring-stack
set -euo pipefail
source "$(dirname "$0")/../configs/env" 2>/dev/null || true

NODE_EXPORTER_VERSION="${NODE_EXPORTER_VERSION:-1.8.2}"
ARCH="${ARCH:-linux-amd64}"
DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.${ARCH}.tar.gz"

install_node_exporter() {
    local host=$1
    echo "Installing node_exporter on $host..."
    ssh -o StrictHostKeyChecking=no root@"$host" bash << ENDSSH
cd /tmp
wget -q "$DOWNLOAD_URL" -O node_exporter.tar.gz
tar xf node_exporter.tar.gz
cp node_exporter-${NODE_EXPORTER_VERSION}.${ARCH}/node_exporter /usr/local/bin/
useradd -rs /bin/false node_exporter 2>/dev/null || true
cat > /etc/systemd/system/node_exporter.service << 'SERVICE'
[Unit]
Description=Prometheus Node Exporter
After=network.target
[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter
Restart=always
[Install]
WantedBy=multi-user.target
SERVICE
systemctl daemon-reload
systemctl enable --now node_exporter
echo "node_exporter v${NODE_EXPORTER_VERSION} running on \$(hostname)"
ENDSSH
}

for node in ${PVE01_IP:-10.10.40.11} ${PVE02_IP:-10.10.40.12} ${PVE03_IP:-10.10.40.13}; do
    install_node_exporter "$node"
done

echo "Verify: curl http://10.10.40.11:9100/metrics | head -5"
