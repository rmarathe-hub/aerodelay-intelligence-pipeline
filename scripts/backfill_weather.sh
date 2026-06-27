#!/usr/bin/env bash
# Backfill weather data for production scope (2023-01 through 2025-12, 45 stations)
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

START_YEAR="${1:-2023}"
START_MONTH="${2:-1}"
END_YEAR="${3:-2025}"
END_MONTH="${4:-12}"

echo "Backfilling weather ${START_YEAR}-${START_MONTH} through ${END_YEAR}-${END_MONTH}"
echo "All 45 mapped stations unless --station is passed to the Python module directly."
echo "This may take a long time and requires network access."
echo ""

python -m ingestion.weather.backfill \
  --start-year "${START_YEAR}" \
  --start-month "${START_MONTH}" \
  --end-year "${END_YEAR}" \
  --end-month "${END_MONTH}"

echo ""
echo "Spot-check row counts:"
docker compose exec -T postgres psql -U aerodelay -d aerodelay -c \
  "SELECT station, year_month, COUNT(*) AS rows FROM raw.weather_observations GROUP BY 1, 2 ORDER BY 1, 2;"

echo ""
echo "Ingest log summary:"
docker compose exec -T postgres psql -U aerodelay -d aerodelay -c \
  "SELECT status, COUNT(*) FROM meta.weather_ingest_log GROUP BY 1;"
