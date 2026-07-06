# LibreNMS — Dashboard és alert best-practice ajánlások

Ez a dokumentum a 2026-07-06-i troubleshooting sessionből származó
iparági best-practice kutatás összefoglalója. Ezek UI-ban kézzel
létrehozandó elemek, nincs hozzájuk automatizált script (a rule builder
JSON-ját garantáltan helyesen csak a UI generálja — lásd RUNBOOK.md
6. szakasz a manuális DB-manipuláció veszélyeiről).

## Ajánlott alert szabályok

A rendszeren már megvan (2026-07-06 állapot szerint): device down, port
down, ping latency, port utilization, sensor over/under limit, service
up/down, wireless sensor, state sensor critical, storage warning 80%,
high CPU 85%, high memory 85%.

**Hiányzik / újra létrehozandó** (lásd RUNBOOK.md #6 hiba):
- Storage CRITICAL 90pct: `storage.storage_perc >= 90`, critical, delay 60s
- Memory CRITICAL 95pct: `mempools.mempool_perc >= 95`, critical, delay 120s

**Megfontolandó további szabályok:**
- BGP Session Down (ha van router): `bgpPeers.bgpPeerState != "established"`
- Interface Errors: `ports.ifInErrors_delta > 100 OR ports.ifOutErrors_delta > 100`
  — csak `ifAdminStatus = "up"` portokon (admin-down portokat érdemes explicit
  adminisztratíven letiltani az eszközön, hogy ne zajongjon a riasztás)
- SSL cert expiry service check (ha van HTTP service monitorozás)

**Timing best practice:**
- 2-5 perc kezdő delay a rövid "blip" jellegű téves riasztások elkerülésére
- Recovery notification mindig bekapcsolva
- Kritikus → gyors transport (Telegram/webhook), warning → email digest

## Ajánlott alert transport

Jelenleg (2026-07-06) nincs transport konfigurálva. Javasolt:
- Kritikus riasztásokhoz Telegram vagy a meglévő n8n/Hermes gateway felé
  webhook, onnan route-olva egységes formátumban
- Warning szintű riasztásokhoz email

## Ajánlott dashboardok

### 1. "Network Overview"
- Availability Map (eszközök up/down vizuálisan)
- Top 10 Devices by Traffic (bits/sec)
- Top 10 Ports by Errors
- Alert Log widget (utolsó 24h)
- Device Uptime widget

### 2. "Capacity Planning"
- Top 10 by CPU usage
- Top 10 by Memory usage
- Top 10 by Disk usage
- Bandwidth trend grafikon a kulcs uplink portokra (3-6 hónapos trend)

### 3. "NOC / TV mód"
- Globális Availability Map teljes képernyőn
- Auto-refresh 30s
- Elérhető: `/dashboard/tv-mode` a UI-ban

Widget hozzáadás: Overview > Dashboards > "+" gomb.

## Teljesítmény-optimalizálási megjegyzések

- rrdcached bekötve (lásd RUNBOOK.md #3) — ~30-40% disk IO Ops/sec csökkenés várható
  egy poll ciklus után (Devices > localhost > Health > Disk I/O alatt ellenőrizhető)
- Poller modul időzítés: Gear > Pollers > Performance alatt látszik, mely modulok
  viszik a legtöbb időt — ha van felesleges modul (pl. nem használt device típushoz
  tartozó discovery modul), érdemes kikapcsolni

## Források

- https://docs.librenms.org/Support/Cleanup-options/
- https://docs.librenms.org/Extensions/RRDCached/
- https://docs.librenms.org/Support/Performance/
- https://docs.librenms.org/Alerting/Rules/
- https://docs.librenms.org/Alerting/Templates/
