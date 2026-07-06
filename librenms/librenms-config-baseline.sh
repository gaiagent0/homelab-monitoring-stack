#!/usr/bin/env bash
#
# LibreNMS config baseline - CT203, 2026-07-06 óta alkalmazva.
# Idempotens: bármikor újra futtatható, csak beállítja ugyanazokat az
# értékeket. Futtasd root-ként, librenms user alatt (su - librenms).
#
# FONTOS TANULSÁG: a kulcsnevek 26.x-ben ALÁHÚZÁSOS formátumúak
# (eventlog_purge, syslog_purge), NEM pontozott namespace formátumúak.
# A snmp.*, discovery.threads, poller.threads viszont pontozott és érvényes.
# Ha bizonytalan vagy egy kulcsban, ellenőrizd:
#   lnms config:get <kulcs>
# vagy nézd meg a config.php.dist / config_definitions.json fájlt.

set -euo pipefail
cd /opt/librenms || exit 1

echo "--- Retention / cleanup ---"
lnms config:set eventlog_purge 30
lnms config:set syslog_purge 14
lnms config:set alert_log_purge 90
lnms config:set authlog_purge 30
lnms config:set ports_fdb_purge 10
lnms config:set ports_nac_purge 10
lnms config:set ports_purge true
lnms config:set networks_purge true

echo "--- SNMP timeout/retries ---"
lnms config:set snmp.timeout 1
lnms config:set snmp.retries 5

echo "--- Discovery / polling teljesítmény (2 CPU cores) ---"
lnms config:set discovery.threads 4
lnms config:set poller.threads 4

echo "--- rrdcached bekötése ---"
lnms config:set rrdcached "unix:/var/run/rrdcached.sock"

echo "Kész. Ellenőrzés:"
for key in eventlog_purge syslog_purge alert_log_purge snmp.timeout snmp.retries discovery.threads poller.threads rrdcached; do
  printf "%-20s = " "$key"
  lnms config:get "$key"
done
