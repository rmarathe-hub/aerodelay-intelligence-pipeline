#!/usr/bin/env bash
# Download and load Jan 2025 BTS + weather (45 stations) for CI / local repro.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

export PYTHONPATH="${ROOT_DIR}${PYTHONPATH:+:${PYTHONPATH}}"

echo "=== BTS Jan 2025 ==="
python -m ingestion.bts.load --year 2025 --month 1 --download

echo ""
echo "=== Weather Jan 2025 (45 stations) ==="
python -m ingestion.weather.backfill \
  --start-year 2025 \
  --start-month 1 \
  --end-year 2025 \
  --end-month 1

echo ""
echo "=== Raw row counts ==="
PGHOST="${POSTGRES_HOST_LOCAL:-${POSTGRES_HOST:-localhost}}"
PGPORT="${POSTGRES_PORT:-5432}"
PGUSER="${POSTGRES_USER:-aerodelay}"
PGDATABASE="${POSTGRES_DB:-aerodelay}"
export PGPASSWORD="${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"

psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}" -c "
  SELECT 'raw.bts_flights' AS src, count(*) FROM raw.bts_flights
  UNION ALL SELECT 'raw.weather_observations', count(*) FROM raw.weather_observations;
"

echo "CI sample load complete."
