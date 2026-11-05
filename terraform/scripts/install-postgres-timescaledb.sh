#!/usr/bin/env bash
# VM startup script: PostgreSQL 15 + PostGIS + TimescaleDB on Debian 12.
# Needs outbound internet (external IP). Idempotent: runs once.
set -euo pipefail

MARKER=/var/lib/postgis-timescaledb-installed
DB_NAME="app"
[ -f "$MARKER" ] && exit 0

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y gnupg lsb-release wget apt-transport-https ca-certificates

# TimescaleDB apt repository
echo "deb https://packagecloud.io/timescale/timescaledb/debian/ $(lsb_release -c -s) main" \
  > /etc/apt/sources.list.d/timescaledb.list
wget -qO- https://packagecloud.io/timescale/timescaledb/gpgkey | gpg --dearmor -o /etc/apt/trusted.gpg.d/timescaledb.gpg
apt-get update

apt-get install -y postgresql-15 postgresql-15-postgis-3 timescaledb-2-postgresql-15 timescaledb-tools

# Tune for a small VM and enable the library (adds shared_preload_libraries)
timescaledb-tune --quiet --yes
systemctl restart postgresql

# PostgreSQL listens on localhost only (default); no password or network exposure.
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1 \
  || sudo -u postgres createdb "${DB_NAME}"
sudo -u postgres psql -d "${DB_NAME}" -c "CREATE EXTENSION IF NOT EXISTS timescaledb;"
sudo -u postgres psql -d "${DB_NAME}" -c "CREATE EXTENSION IF NOT EXISTS postgis;"

touch "$MARKER"
echo "PostgreSQL + PostGIS + TimescaleDB installed"
