#!/usr/bin/env bash
# Verify idempotency: load same month twice, row count should not double
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

SAMPLE_ZIP="data/samples/On_Time_Reporting_Carrier_On_Time_Performance_1987_present_2025_1 (2).zip"
if [[ ! -f "${SAMPLE_ZIP}" ]]; then
  SAMPLE_ZIP="data/samples/On_Time_Reporting_Carrier_On_Time_Performance_1987_present_2025_1.zip"
fi

echo "Run 1..."
python -m ingestion.bts.load --year 2025 --month 1 --zip-path "${SAMPLE_ZIP}"
COUNT1=$(docker compose exec -T postgres psql -U aerodelay -d aerodelay -t -c "SELECT COUNT(*) FROM raw.bts_flights WHERE year_month = '2025-01';" | tr -d ' ')

echo "Run 2 (same month)..."
python -m ingestion.bts.load --year 2025 --month 1 --zip-path "${SAMPLE_ZIP}"
COUNT2=$(docker compose exec -T postgres psql -U aerodelay -d aerodelay -t -c "SELECT COUNT(*) FROM raw.bts_flights WHERE year_month = '2025-01';" | tr -d ' ')

echo "Count after run 1: ${COUNT1}"
echo "Count after run 2: ${COUNT2}"

if [[ "${COUNT1}" == "${COUNT2}" && "${COUNT1}" != "0" ]]; then
  echo "PASS: idempotent reload (counts match)"
else
  echo "FAIL: counts differ or zero"
  exit 1
fi
