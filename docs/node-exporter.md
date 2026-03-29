# Node Exporter — Install on All Proxmox Nodes

> Deploy Prometheus Node Exporter on all three PVE nodes for host-level CPU, RAM, disk, and network metrics.

---

## Quick Install (via script)

```bash
# On each Proxmox node (pve-01, pve-02, pve-03):
bash scripts/install-node-exporter.sh

# Or deploy remotely from pve-01:
for NODE in 10.10.40.12 10.10.40.13; do
    ssh root@$NODE "bash -s" < scripts/install-node-exporter.sh
done
```

---

## Manual Install

```bash
NE_VERSION="1.8.2"
wget -q "https://github.com/prometheus/node_exporter/releases/download/v${NE_VERSION}/node_exporter-${NE_VERSION}.linux-amd64.tar.gz"
tar xf "node_exporter-${NE_VERSION}.linux-amd64.tar.gz"
cp "node_exporter-${NE_VERSION}.linux-amd64/node_exporter" /usr/local/bin/
chmod +x /usr/local/bin/node_exporter
useradd --no-create-home --shell /bin/false node_exporter

cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --collector.systemd --collector.processes
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now node_exporter
```

---

## Prometheus Scrape Config

Defined in `grafana/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'proxmox-nodes'
    static_configs:
      - targets:
          - '10.10.40.11:9100'   # pve-01
          - '10.10.40.12:9100'   # pve-02
          - '10.10.40.13:9100'   # pve-03
    relabel_configs:
      - source_labels: [__address__]
        regex: '10\.10\.40\.(\d+):\d+'
        replacement: 'pve-${1}'
        target_label: instance
```

After adding targets, verify in Prometheus UI (port 9090): **Status → Targets** — all three should show `UP`.

---

## Grafana Dashboard

Import **Node Exporter Full** (ID: `1860`) from grafana.com:

```
Grafana UI → Dashboards → Import → ID: 1860 → Load → Data source: Prometheus
```

Key panels: CPU usage per core, memory breakdown, disk I/O, network throughput, systemd service status.

---

## Verify

```bash
# Check service is running:
systemctl status node_exporter

# Test metrics endpoint locally:
curl -s http://localhost:9100/metrics | grep "node_load1"

# Test from another host:
curl -s http://10.10.40.11:9100/metrics | grep "node_load1"
```

---

## Troubleshooting

```bash
# Port 9100 not reachable:
ss -tulpn | grep 9100
iptables -I INPUT -p tcp --dport 9100 -j ACCEPT

# Service fails to start:
journalctl -u node_exporter -n 30

# Not showing in Prometheus targets:
# Check prometheus.yml IPs match actual node IPs
# Restart Prometheus: docker compose restart prometheus
```

---

*Tested on: Proxmox VE 8.3, Node Exporter 1.8.2, Debian 12*
