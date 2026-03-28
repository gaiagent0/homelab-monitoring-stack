# LibreNMS — Installation & SNMP Setup

## LXC creation (pve-01)

```bash
pct create 203 /var/lib/vz/template/cache/debian-12-standard_12.12-1_amd64.tar.zst \
  --hostname librenms --memory 1024 --swap 512 --cores 2 \
  --net0 name=eth0,bridge=vmbr0,ip=10.10.40.203/24,gw=10.10.40.1,tag=40 \
  --storage local-zfs --rootfs local-zfs:20 \
  --unprivileged 1 --features nesting=1 --start 1
pct enter 203
```

## Install (official script)

```bash
wget https://raw.githubusercontent.com/librenms/librenms-install/master/install.sh
bash install.sh
```

## Mass SNMP deployment

```bash
bash scripts/snmp-deploy.sh
```

## Add devices

```bash
pct enter 203
cd /opt/librenms
for IP in 10.10.40.11 10.10.40.12 10.10.40.13; do
  su -s /bin/bash librenms -c "lnms device:add $IP --v2c --community public"
done
```

## Known issues

- `snmpd` bound only to 127.0.0.1 → fix: `sed -i '/agentaddress.*127/Id' /etc/snmp/snmpd.conf; echo 'agentAddress udp:161' >> ...`
- LibreNMS polls by **hostname** (must resolve in DNS or be an IP) — use `display` column for friendly names
- `zfs-zed` crashloops inside LXC → disable: `systemctl disable --now zfs-zed` (inside PBS CT)

See [librenms-alerts.md](librenms-alerts.md) for Telegram spam fix and Blade template correction.
