#!/usr/bin/env bash
# Enable the PostGIS extension. Terraform's Google provider cannot run CREATE EXTENSION,
# so run this once after the first apply.
# Usage: PROJECT_ID=... [INSTANCE=postgis-db] [DATABASE=app] ./enable-postgis.sh
set -euo pipefail

PROJECT_ID="${PROJECT_ID:?set PROJECT_ID}"
INSTANCE="${INSTANCE:-postgis-db}"
DATABASE="${DATABASE:-app}"
DB_USER="${DB_USER:-app}"
SECRET="${SECRET:-${INSTANCE}-${DB_USER}-password}"

export PGPASSWORD="$(gcloud secrets versions access latest --secret="$SECRET" --project="$PROJECT_ID")"

gcloud sql connect "$INSTANCE" --project="$PROJECT_ID" --user="$DB_USER" --database="$DATABASE" <<'SQL'
CREATE EXTENSION IF NOT EXISTS postgis;
SELECT postgis_full_version();
SQL
