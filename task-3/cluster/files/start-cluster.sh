#!/usr/bin/env bash
set -euo pipefail

# Add a deterministic header so Jenkins can identify the active node by response header.
cat >/etc/apache2/conf-available/node-id.conf <<EOF
<IfModule mod_headers.c>
  Header set X-Active-Node "$(hostname)"
</IfModule>
EOF

a2enconf node-id >/dev/null

# Apache must be controlled only by Pacemaker.
apachectl -k stop >/dev/null 2>&1 || true

mkdir -p /var/log/pacemaker

corosync -f &
sleep 3
pacemakerd -f &

wait -n
