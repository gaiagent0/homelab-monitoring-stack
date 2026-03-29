# DNS Routing — AdGuard Direct Rewrite vs NPM for grafana.lan

> Why Grafana bypasses Nginx Proxy Manager and uses a direct AdGuard DNS rewrite instead.

---

## The Problem with NPM + Grafana

Grafana uses WebSocket connections for live dashboard updates and streaming logs. NPM (Nginx Proxy Manager) proxy rules for Grafana are unreliable because:

1. **WebSocket timeout**: NPM's default proxy timeout is 60 seconds. Grafana WebSocket sessions stay open indefinitely — they get dropped and the UI shows disconnected state.
2. **Extra hop**: NPM adds a DNS→NPM→Grafana chain with no benefit for a LAN-only service.
3. **Reconnect loop**: After a WebSocket drop, the Grafana UI reconnects, creating a repeating cycle of disconnects visible in the browser console.

---

## The Solution: Direct AdGuard DNS Rewrite

Instead of routing `grafana.lan` through NPM, point it directly to the Grafana container port via AdGuard:

```
AdGuard DNS Rewrites:
  grafana.lan  →  10.10.40.208    (CT208 IP, port 3000)
```

Clients access `http://grafana.lan:3000` directly — no NPM involved.

---

## AdGuard Configuration

**AdGuard Home UI:** `http://adguard.lan` → Filters → DNS Rewrites

| Domain | Answer | Via |
|---|---|---|
| `grafana.lan` | `10.10.40.208` | **direct** (skip NPM) |
| `prometheus.lan` | `10.10.40.208` | **direct** (port 9090) |
| All other services | `10.10.40.105` | NPM → proxied |

Add via AdGuard CLI (if UI unavailable):

```yaml
# In AdGuard config (dns_rewrites section):
dns_rewrites:
  - domain: grafana.lan
    answer: 10.10.40.208
  - domain: prometheus.lan
    answer: 10.10.40.208
```

---

## Port Access

Since there is no NPM proxy, clients must include the port number:

| Service | URL | Port |
|---|---|---|
| Grafana | `http://grafana.lan:3000` | 3000 |
| Prometheus | `http://prometheus.lan:9090` | 9090 |

To avoid typing ports, add port-aware bookmarks in browsers, or use a homepage dashboard (e.g. `homepage` container) that handles the port internally.

Alternatively, configure NPM with WebSocket support for Grafana only:

```nginx
# In NPM custom Nginx config for grafana.lan proxy host:
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_read_timeout 86400s;
proxy_send_timeout 86400s;
```

This resolves the WebSocket timeout issue — but the direct AdGuard approach is simpler and avoids NPM entirely for LAN-only use.

---

## Which Services Should Bypass NPM?

| Service | NPM | Reason |
|---|---|---|
| Grafana | ❌ Direct | WebSocket connections |
| VaultWarden | ❌ Direct | Caddy handles HTTPS inside CT |
| AdGuard admin | ❌ Direct | DNS authority — must be reachable before NPM |
| All other services | ✅ NPM | Standard HTTP/HTTPS proxy |

---

## Verifying DNS Resolution

```bash
# From a LAN client:
nslookup grafana.lan 10.10.40.101
# Expected: Address: 10.10.40.208  (not 10.10.40.105)

# From the Proxmox host:
dig @10.10.40.101 grafana.lan
# Expected: ANSWER SECTION: grafana.lan. 0 IN A 10.10.40.208

# Test HTTP access:
curl -s http://10.10.40.208:3000/api/health | python3 -m json.tool
# Expected: {"commit":"...","database":"ok","version":"..."}
```

---

*Reference: [homelab-core-services/docs/adguard.md](https://github.com/gaiagent0/homelab-core-services/blob/main/docs/adguard.md)*
