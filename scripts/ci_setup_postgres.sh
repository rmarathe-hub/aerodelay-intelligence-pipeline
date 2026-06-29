#!/usr/bin/env bash
# Apply Postgres init DDL for CI (GitHub Actions service container or local).
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

PGHOST="${POSTGRES_HOST_LOCAL:-${POSTGRES_HOST:-localhost}}"
PGPORT="${POSTGRES_PORT:-5432}"
PGUSER="${POSTGRES_USER:-aerodelay}"
PGDATABASE="${POSTGRES_DB:-aerodelay}"
export PGPASSWORD="${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"

echo "Waiting for Postgres at ${PGHOST}:${PGPORT}..."
for _ in $(seq 1 30); do
  if pg_isready -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
pg_isready -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}"

echo "Applying init SQL..."
for sql_file in "${ROOT_DIR}"/docker/postgres/init/*.sql; do
  echo "  -> $(basename "${sql_file}")"
  psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}" -v ON_ERROR_STOP=1 -f "${sql_file}"
done

echo "Postgres CI setup complete."
