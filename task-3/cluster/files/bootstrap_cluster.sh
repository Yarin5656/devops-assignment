#!/usr/bin/env bash
set -euo pipefail

VIP="172.28.0.100"

wait_for_cluster() {
  local retries=60
  until crm_mon -1 >/dev/null 2>&1; do
    retries=$((retries-1))
    if [ "$retries" -le 0 ]; then
      echo "Cluster services are not ready yet."
      exit 1
    fi
    sleep 2
  done
}

wait_for_cluster

crm configure property stonith-enabled=false
crm configure property no-quorum-policy=ignore
crm configure rsc_defaults resource-stickiness=1

crm configure delete prefer-web-stack >/dev/null 2>&1 || true
crm configure delete prefer-web-stack-001 >/dev/null 2>&1 || true
crm configure delete prefer-web-stack-002 >/dev/null 2>&1 || true
crm configure delete prefer-web-stack-003 >/dev/null 2>&1 || true
crm configure delete web-stack >/dev/null 2>&1 || true
crm configure delete apache-svc >/dev/null 2>&1 || true
crm configure delete vip >/dev/null 2>&1 || true

crm configure primitive vip ocf:heartbeat:IPaddr2 \
  params ip="$VIP" cidr_netmask="16" nic="eth0" \
  op monitor interval="10s" timeout="20s"

crm configure primitive apache-svc lsb:apache2 \
  op start interval="0" timeout="60s" \
  op stop interval="0" timeout="60s" \
  op monitor interval="20s" timeout="40s"

crm configure group web-stack vip apache-svc
crm configure location prefer-web-stack-001 web-stack 300: webz-001
crm configure location prefer-web-stack-002 web-stack 200: webz-002
crm configure location prefer-web-stack-003 web-stack 100: webz-003

crm resource cleanup web-stack
crm resource start web-stack
sleep 3
crm_mon -1
