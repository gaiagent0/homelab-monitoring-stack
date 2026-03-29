# homelab-monitoring-stack

> **Full-stack observability for Proxmox homelabs: LibreNMS (SNMP/network) + Grafana + Prometheus + Node Exporter + cAdvisor.**  
> The two stacks complement each other — LibreNMS owns network-layer visibility (router, switches, SNMP traps), Prometheus/Grafana owns node and container metrics.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## Stack Overview

```
LibreNMS (CT203)           Grafana + Prometheus (CT208)
  SNMP polling               Node Exporter  → pve-01/02/03
  Network topology           cAdvisor       → docker-host CT
  Telegram alerts            Grafana dashboards (1860, 193)
  Blade template alerts      Alertmanager (optional)
```

### Why both?

| Dimension | LibreNMS | Prometheus/Grafana |
|---|---|---|
| Protocol | SNMP v2c | HTTP scrape (pull) |
| Scope | Router, switches, all SNMP devices | Host CPU/RAM/disk, Docker container metrics |
| Retention | Built-in RRD (~1yr) | Configurable TSDB (default 30d) |
| Alerting | Built-in + Telegram | Alertmanager (configurable) |
| Setup complexity | High (LAMP stack) | Medium (Docker Compose) |

---

## Repository Structure

```
homelab-monitoring-stack/
├── README.md
├── docs/
│   ├── librenms-install.md        — LXC setup, SNMP mass-deployment
│   ├── librenms-alerts.md         — Blade template fix, Telegram spam filter
│   ├── grafana-prometheus.md      — Docker Compose, data source, dashboards
│   ├── node-exporter.md           — Install script for all PVE nodes
│   ├── cadvisor.md                — Docker container metrics on port 8082
│   └── dns-routing.md             — AdGuard direct rewrite vs NPM for grafana.lan
├── grafana/
│   ├── docker-compose.yml         — Prometheus + Grafana stack
│   └── prometheus.yml             — Scrape config (node-exporter + cAdvisor targets)
├── librenms/
│   ├── snmp-deploy.sh             — Mass SNMP install across all CTs
│   └── alert-templates/
│       └── proxmox-homelab.blade  — Fixed Blade template (no string|array error)
└── configs/
    └── env.example
```

---

## Quick Start — Grafana + Prometheus

```bash
# On CT208 (grafana LXC):
git clone https://github.com/gaiagent0/homelab-monitoring-stack.git
cd homelab-monitoring-stack
cp configs/env.example configs/env && nano configs/env
cd grafana
docker compose up -d

# Import dashboards:
# Node Exporter Full: https://grafana.com/dashboards/1860
# cAdvisor Docker:    https://grafana.com/dashboards/193
```

## DNS Routing Note

`grafana.lan` is best served as a **direct AdGuard DNS rewrite** to `10.10.40.208:3000`, NOT via NPM. Routing through NPM adds an extra DNS→NPM→Grafana hop with no benefit, and NPM proxy rules for Grafana are unreliable with websockets.

```
AdGuard → DNS Rewrites → grafana.lan → 10.10.40.208
(skip NPM entirely for Grafana)
```

---

## LibreNMS Alert Optimization

The default Blade template produces `string|array` PHP errors in Telegram notifications. Fixed template in `librenms/alert-templates/proxmox-homelab.blade`.

SQL commands for alert spam prevention (5 min delay, 1 h repeat interval):

```sql
UPDATE alert_rules
SET extra = JSON_SET(extra, '$.delay', 300, '$.interval', 3600, '$.count', -1);
```

See [docs/librenms-alerts.md](docs/librenms-alerts.md) for full procedure.

---

*Tested on: LibreNMS 24.x, Prometheus 2.x, Grafana 11.x, Node Exporter 1.8.2*
