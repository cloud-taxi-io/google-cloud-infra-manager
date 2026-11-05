#!/usr/bin/env bash
# Open PostgreSQL on the VM to the Cloud Run Direct VPC egress subnet, with an `app` user.
# Run ON THE VM as root. The password is read on stdin (never as an argument):
#
#   gcloud compute scp scripts/configure-db-network.sh timescaledb:/tmp/ --zone us-central1-a --tunnel-through-iap
#   gcloud compute ssh timescaledb --zone us-central1-a --tunnel-through-iap \
#     --command "sudo bash /tmp/configure-db-network.sh; rm -f /tmp/configure-db-network.sh" < password-file
set -euo pipefail

PG_VERSION="${PG_VERSION:-18}"
INTERNAL_IP="${INTERNAL_IP:-$(hostname -I | awk '{print $1}')}"
CLOUD_RUN_SUBNET="${CLOUD_RUN_SUBNET:-10.128.0.0/20}"   # default subnet of us-central1

read -r PW; export PW
sudo --preserve-env=PW -u postgres psql -v ON_ERROR_STOP=1 -d app -q <<SQL
\getenv pw PW
SELECT 'CREATE ROLE app LOGIN' WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app') \gexec
ALTER ROLE app WITH LOGIN PASSWORD :'pw';
ALTER DATABASE app OWNER TO app;
ALTER SCHEMA public OWNER TO app;
ALTER SYSTEM SET listen_addresses = 'localhost,${INTERNAL_IP}';
SQL

HBA="/etc/postgresql/${PG_VERSION}/main/pg_hba.conf"
LINE="host    app    app    ${CLOUD_RUN_SUBNET}    scram-sha-256"
grep -qF "$LINE" "$HBA" || echo "$LINE   # Cloud Run Direct VPC egress" >> "$HBA"
systemctl restart postgresql
sleep 2
PGPASSWORD="$PW" psql -h "$INTERNAL_IP" -U app -d app -tAc "select 'app can connect on ' || inet_server_addr()"
