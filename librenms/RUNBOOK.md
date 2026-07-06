# LibreNMS Troubleshooting Runbook — 2026-07-06

Konténer: CT203 (pve-01), hostname `librenms.localdomain`, IP `10.10.40.203`
LibreNMS verzió: 26.1.1 (csomagos/community-scripts telepítés, nem git)

## Kiindulási állapot (validate.php első futás)

```
[WARN]  Disk space where /opt/librenms/rrd is located is less than 512Mb
[OK]    Active pollers found
[OK]    Dispatcher Service not detected
[OK]    Python poller wrapper is polling
[WARN]  Non-git install, updates are manual or from package
```

Emellett manuális ellenőrzéssel:
- Disk: 5.9GB rootfs, 93% used (415MB szabad)
- RAM: 512MB (container config)
- rrdcached: nincs telepítve
- MariaDB innodb_buffer_pool_size: 128MB

## Elvégzett javítások (sorrendben)

### 1. Proxmox host oldali erőforrás-bővítés
```bash
# pve-01-en
pct set 203 -memory 2048
pct resize 203 rootfs +8G
```
Eredmény: RAM 512MB → 2048MB, disk 5.9GB → 14GB (40% used).

**Miért kellett:** LibreNMS + MariaDB + PHP-FPM + Redis + snmpd 512MB-on
állandó OOM/swap kockázatot jelent, és 415MB szabad hely bármelyik pillanatban
betelhetett volna (RRD írások + logok miatt).

### 2. LibreNMS config kulcsok (`lnms config:set`)

**FONTOS - tanulság:** a config kulcsnevek 26.x-ben aláhúzásos formátumúak
(`eventlog_purge`, `syslog_purge`), NEM pontozott namespace formátumúak
(`alert.default_only`, `eventlog.purge` — ezek érvénytelenek és
"This is not a valid setting" hibát adnak). A `snmp.timeout`,
`discovery.threads`, `poller.threads` viszont pontozott formátumú és érvényes.
Mindig `lnms config:get <kulcs>` -tal ellenőrizd visszaolvasva.

```bash
lnms config:set eventlog_purge 30
lnms config:set syslog_purge 14
lnms config:set alert_log_purge 90
lnms config:set authlog_purge 30
lnms config:set ports_fdb_purge 10
lnms config:set ports_nac_purge 10
lnms config:set ports_purge true
lnms config:set networks_purge true
lnms config:set snmp.timeout 1
lnms config:set snmp.retries 5
lnms config:set discovery.threads 4
lnms config:set poller.threads 4
lnms config:set rrdcached "unix:/var/run/rrdcached.sock"
```

Forrás: https://docs.librenms.org/Support/Cleanup-options/

### 3. rrdcached telepítés és konfiguráció

**FONTOS - tanulság:** a Debian `rrdcached` init.d script **kulcs=érték
formátumú** `/etc/default/rrdcached` fájlt vár (`SOCKFILE=`, `DAEMON_USER=`
stb.), NEM egy összefűzött `OPTS="..."` parancssor-stringet. Rossz formátum
esetén a service ugyan elindul, de a socket nem a várt helyen jön létre, és
a `validate.php` "rrdcached connectivity test failed" hibát ad.

```bash
apt-get install -y rrdcached
```

`/etc/default/rrdcached` (lásd `librenms/rrdcached-default.conf` ebben a repóban):
```
DAEMON=/usr/bin/rrdcached
DAEMON_USER=librenms
DAEMON_GROUP=librenms
BASE_PATH=/opt/librenms/rrd/
JOURNAL_PATH=/var/lib/rrdcached/journal/
PIDFILE=/var/run/rrdcached.pid
SOCKFILE=/var/run/rrdcached.sock
SOCKGROUP=librenms
WRITE_JITTER=1800
WRITE_TIMEOUT=1800
WRITE_THREADS=4
BASE_OPTIONS="-B -F -R"
```

```bash
mkdir -p /var/lib/rrdcached/journal
chown -R librenms:librenms /var/lib/rrdcached
chown librenms:librenms /opt/librenms/rrd
systemctl restart rrdcached
```

Forrás: https://docs.librenms.org/Extensions/RRDCached/

### 4. MariaDB tuning

`/etc/mysql/mariadb.conf.d/90-librenms-tuning.cnf`:
```ini
[mysqld]
innodb_buffer_pool_size = 1024M
innodb_flush_log_at_trx_commit = 2
innodb_file_per_table = 1
innodb_read_io_threads = 4
innodb_write_io_threads = 4
```
(1024M = ~50% a 2GB RAM-ból, RAM-emelés UTÁN alkalmazva, nem előtte —
512MB RAM mellett ez OOM-kockázatot jelentett volna.)

### 5. Scheduler telepítése

A `librenms-scheduler.timer` sosem volt telepítve ezen a rendszeren
(csak sima cron futott). 26.x-ben ez a hivatalos systemd-natív ütemező:

```bash
cp /opt/librenms/dist/librenms-scheduler.service /etc/systemd/system/
cp /opt/librenms/dist/librenms-scheduler.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now librenms-scheduler.timer
```

### 6. Kritikus hiba: hibás alert_rules sorok (PDO::prepare empty query)

**Tünet:** minden poller ciklusban minden eszközön hiba:
```
PHP Error(8192): PDO::prepare(): Passing null to parameter #1 ($query)
  of type string is deprecated in /opt/librenms/LibreNMS/Alert/AlertRules.php:83
```
A polling maga lefutott, de az alert-kiértékelés minden eszközön elhasalt.

**Ok:** két alert_rules sor (`id=28` "Storage CRITICAL 90pct" és `id=29`
"Memory CRITICAL 95pct") `builder` és `extra` mezője **érvénytelen JSON**
volt — hiányoztak az idézőjelek a kulcsok/értékek körül
(`{mute:false,count:1,...}` a helyes `{"mute":false,"count":1,...}` helyett).
Ez a két szabály valószínűleg nem a UI rule builderén keresztül lett
létrehozva, hanem közvetlen DB-insertből vagy hibás script/API hívásból.
A LibreNMS futásidőben (`daily.sh`/AlertRules) megpróbálja a `builder`
JSON-ból legenerálni a `query` mezőt; érvénytelen JSON esetén üres
stringet kap, amit aztán `PDO::prepare()`-nek ad át → hiba minden ciklusban.

**Diagnózis:**
```sql
SELECT id, name, disabled, CHAR_LENGTH(query) AS qlen
FROM alert_rules ORDER BY id;
-- a hibás soroknál qlen = 0
```

**Javítás:**
```sql
DELETE FROM alert_rules WHERE id IN (28, 29);
```
Utána a két szabályt a UI-ban (Alerts > Alert Rules > Add Rule) kell
újra létrehozni a vizuális builderrel, ami garantáltan helyes JSON-t ment:
- **Storage CRITICAL 90pct**: `storage.storage_perc >= 90`, severity critical, delay 60s, interval 300s
- **Memory CRITICAL 95pct**: `mempools.mempool_perc >= 95`, severity critical, delay 120s, interval 300s

**Ellenőrzés:**
```bash
su - librenms -c "cd /opt/librenms && ./poller-wrapper.py 1"
```
Ha nincs `PDO::prepare()` hiba a kimenetben, a javítás sikeres.

## Végállapot (validate.php utolsó futás)

```
[OK]    Active pollers found
[OK]    Python poller wrapper is polling
[OK]    Redis is functional
[OK]    rrdtool version ok
[OK]    Connected to rrdcached
[WARN]  Non-git install, updates are manual or from package   <- ártalmatlan, csomagos telepítésnél normális
```

Poller teszt: mind a 12 eszköz hiba nélkül lefutott.

## Meglévő alert rule-ok (érvényesek, nem kellett hozzájuk nyúlni)

| ID | Név | Severity |
|---|---|---|
| 1 | Device Down! Due to no ICMP response. | critical |
| 2 | Device Down (SNMP unreachable) | critical |
| 3 | Device rebooted | critical |
| 4 | Port status up/down | critical |
| 5 | Ping Latency | critical |
| 6 | Port utilisation over threshold | critical |
| 7 | Sensor over limit | critical |
| 8 | Sensor under limit | critical |
| 9 | Service up/down | critical |
| 10 | Wireless Sensor over limit | critical |
| 11 | Wireless Sensor under limit | critical |
| 12 | State Sensor Critical | critical |
| 13 | Storage Warning 80pct | warning |
| 26 | High CPU Load 85pct | warning |
| 27 | High Memory Usage 85pct | warning |

## Hátralévő teendők

- [ ] Storage CRITICAL 90pct és Memory CRITICAL 95pct újra létrehozása UI-ban (lásd fent)
- [ ] Alert transport beállítása (jelenleg egyik sincs konfigurálva — mail vagy
      Telegram/webhook a Hermes/n8n infrán keresztül javasolt)
- [ ] Dashboardok létrehozása: Network Overview, Capacity Planning, NOC/TV mód
      (lásd `librenms/dashboard-recommendations.md`)
- [ ] Fontolóra venni git-alapú telepítésre váltást a "Non-git install" warning
      megszüntetéséhez (csomagos telepítésnél ez alacsony prioritású)

## Kapcsolódó fájlok ebben a repóban

- `librenms/rrdcached-default.conf` — a helyes `/etc/default/rrdcached`
- `librenms/mariadb-tuning.cnf` — a MariaDB tuning konfig
- `librenms/librenms-config-baseline.sh` — az alkalmazott `lnms config:set` parancsok egyben
- `librenms/dashboard-recommendations.md` — dashboard és alert best-practice javaslatok
