# cAdvisor — Docker Container Metrics

> cAdvisor (Container Advisor) exposes per-container CPU, memory, network, and disk metrics for Prometheus scraping from the Docker host LXC (CT302).

---

## Overview

cAdvisor runs as a container inside CT302 (docker-host) and exposes metrics at `:8082/metrics`. Prometheus scrapes this endpoint to populate Grafana container dashboards.

```
CT302 docker-host
  └── cAdvisor container (:8082)
        └── /metrics endpoint
              ↑
         Prometheus (CT208) scrapes every 15s
              ↓
         Grafana dashboard ID: 193
```

---

## Deploy cAdvisor

Add to `docker-compose.yml` on CT302:

```yaml
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    restart: unless-stopped
    privileged: true
    ports:
      - "8082:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    devices:
      - /dev/kmsg
```

```bash
docker compose up -d cadvisor
```

Verify: `curl http://localhost:8082/metrics | grep "container_cpu_usage"`

---

## Prometheus Scrape Config

Add to `grafana/prometheus.yml`:

```yaml
  - job_name: 'cadvisor'
    static_configs:
      - targets:
          - '10.10.40.32:8082'   # CT302 docker-host
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        replacement: 'ct302-docker'
```

---

## Grafana Dashboard

Import **Docker and system monitoring** (ID: `193`) from grafana.com:

```
Grafana UI → Dashboards → Import → ID: 193 → Load → Data source: Prometheus
```

Key panels: container CPU %, memory usage per container, network I/O, container uptime.

---

## Unprivileged LXC Note

If CT302 is an **unprivileged** Proxmox LXC, cAdvisor may fail to read some `/sys` paths. Add to the LXC config on the Proxmox host:

```bash
# On pve-03 host:
echo "lxc.apparmor.profile: unconfined" >> /etc/pve/lxc/302.conf
echo "lxc.cap.drop:" >> /etc/pve/lxc/302.conf
pct restart 302
```

Or use a privileged container for the docker-host LXC if full container metrics are required.

---

## Verify

```bash
# From CT302:
curl -s http://localhost:8082/healthz
# Expected: ok

# List container metrics:
curl -s http://localhost:8082/metrics | grep 'container_name="mediaserver"' | head -5

# From Prometheus host (CT208):
curl -s http://10.10.40.32:8082/metrics | grep "container_cpu" | head -3
```

---

## Useful Metric Labels

| Metric | Description |
|---|---|
| `container_cpu_usage_seconds_total` | CPU time consumed per container |
| `container_memory_usage_bytes` | Current memory usage |
| `container_network_receive_bytes_total` | Inbound network traffic |
| `container_network_transmit_bytes_total` | Outbound network traffic |
| `container_fs_usage_bytes` | Filesystem usage per container |

Filter by container name in PromQL:
```promql
container_memory_usage_bytes{name="jellyfin"}
rate(container_cpu_usage_seconds_total{name="radarr"}[5m])
```

---

*Tested on: cAdvisor v0.49, Prometheus 2.x, Proxmox LXC CT302 (privileged)*
