# Grafana + Prometheus — Setup Guide

## Deploy (CT208 on pve-02)

```bash
git clone https://github.com/gaiagent0/homelab-monitoring-stack.git
cd homelab-monitoring-stack/grafana
cp ../configs/env.example ../configs/env && nano ../configs/env
docker compose up -d
```

## Dashboard imports

| Dashboard | ID | Purpose |
|---|---|---|
| Node Exporter Full | 1860 | PVE host CPU/RAM/disk/net |
| cAdvisor Docker | 193 | Container resource metrics |
| Proxmox Cluster | custom | Quorum, CT status |

## Access

- Grafana: `http://GRAFANA_IP:3000` (or `grafana.lan` via AdGuard DNS rewrite)
- Prometheus: `http://GRAFANA_IP:9090`

## DNS routing

Use **direct AdGuard DNS rewrite** — NOT NPM — for Grafana:
```
grafana.lan → 10.10.40.208
```
NPM + Grafana WebSocket connections are unreliable. Direct bind avoids the issue.

## cAdvisor note

cAdvisor runs on port `8082` (not 8080) because qBittorrent occupies 8080 on docker-host:
```yaml
ports:
  - "8082:8080"
```
Update prometheus.yml target accordingly.

## Data source config

```
Connections → Data sources → Prometheus
URL: http://prometheus:9090   # internal Docker network
```
