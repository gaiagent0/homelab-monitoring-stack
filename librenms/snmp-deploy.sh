#!/bin/bash
# Mass SNMP deployment across all Proxmox LXC containers
# Run on each Proxmox node as root
# Source: https://github.com/gaiagent0/homelab-monitoring-stack
set -euo pipefail

source "$(dirname "$0")/../configs/env" 2>/dev/null || true
COMMUNITY=${SNMP_COMMUNITY:-public}

deploy_snmp() {
    local CT_ID=$1
    echo "[CT$CT_ID] Installing snmpd..."
    pct exec "$CT_ID" -- bash -c "
        apt-get install -y snmpd -qq 2>/dev/null
        # Remove any existing agentaddress lines (might be 127.0.0.1 only)
        sed -i '/agentaddress/Id' /etc/snmp/snmpd.conf
        sed -i '/agentAddress udp:161/Id' /etc/snmp/snmpd.conf
        # Listen on all interfaces
        echo 'agentAddress udp:161' >> /etc/snmp/snmpd.conf
        echo 'rocommunity ${COMMUNITY}' >> /etc/snmp/snmpd.conf
        systemctl enable snmpd --quiet
        systemctl restart snmpd
        echo OK
    "
}

# pve-01 CTs
for CT in ${PVE01_CT_IDS:-101 105 106 107 203}; do deploy_snmp $CT; done

# pve-02 CTs
PVE02_SSH="ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@${PVE02_IP:-10.10.40.12}"
for CT in ${PVE02_CT_IDS:-201 204 208}; do
    echo "[CT$CT on pve-02] Installing snmpd..."
    $PVE02_SSH "pct exec $CT -- bash -c 'apt-get install -y snmpd -qq; sed -i \"/agentaddress/Id\" /etc/snmp/snmpd.conf; echo \"agentAddress udp:161\" >> /etc/snmp/snmpd.conf; systemctl restart snmpd; echo OK'"
done

# pve-03 CTs
PVE03_SSH="ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@${PVE03_IP:-10.10.40.13}"
for CT in ${PVE03_CT_IDS:-302 303}; do
    echo "[CT$CT on pve-03] Installing snmpd..."
    $PVE03_SSH "pct exec $CT -- bash -c 'apt-get install -y snmpd -qq; sed -i \"/agentaddress/Id\" /etc/snmp/snmpd.conf; echo \"agentAddress udp:161\" >> /etc/snmp/snmpd.conf; systemctl restart snmpd; echo OK'"
done

echo ""
echo "SNMP deployment complete. Verify from LibreNMS CT (203):"
echo "  for IP in 10.10.40.11 10.10.40.12 10.10.40.13; do snmpwalk -v2c -c ${COMMUNITY} \$IP sysDescr.0; done"
