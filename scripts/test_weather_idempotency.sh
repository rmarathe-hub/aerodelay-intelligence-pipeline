#!/usr/bin/env bash
# Verify weather load idempotency for ATL January 2025 sample
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

SAMPLE="data/samples/weather_ATL_2025_jan.csv"
if [[ ! -f "${SAMPLE}" ]]; then
  echo "Sample not found: ${SAMPLE}"
  exit 1
fi

count_rows() {
  docker compose exec -T postgres psql -U aerodelay -d aerodelay -t -A -c \
    "SELECT COUNT(*) FROM raw.weather_observations WHERE station = 'ATL' AND year_month = '2025-01';"
}

echo "Run 1..."
python -m ingestion.weather.load --year 2025 --month 1 --station ATL --csv-path "${SAMPLE}"
COUNT1="$(count_rows)"
echo "Rows after run 1: ${COUNT1}"

echo "Run 2 (idempotency check)..."
python -m ingestion.weather.load --year 2025 --month 1 --station ATL --csv-path "${SAMPLE}"
COUNT2="$(count_rows)"
echo "Rows after run 2: ${COUNT2}"

if [[ "${COUNT1}" == "${COUNT2}" ]]; then
  echo "PASS: row count unchanged (${COUNT1})"
else
  echo "FAIL: row count changed from ${COUNT1} to ${COUNT2}"
  exit 1
fi
