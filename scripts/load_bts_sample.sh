#!/usr/bin/env bash
# Load BTS sample ZIP (January 2025) into raw.bts_flights
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

SAMPLE_ZIP="data/samples/On_Time_Reporting_Carrier_On_Time_Performance_1987_present_2025_1 (2).zip"
if [[ ! -f "${SAMPLE_ZIP}" ]]; then
  SAMPLE_ZIP="data/samples/On_Time_Reporting_Carrier_On_Time_Performance_1987_present_2025_1.zip"
fi

if [[ ! -f "${SAMPLE_ZIP}" ]]; then
  echo "Sample ZIP not found under data/samples/. Download or place January 2025 BTS ZIP there."
  exit 1
fi

python -m ingestion.bts.load --year 2025 --month 1 --zip-path "${SAMPLE_ZIP}"

echo ""
echo "Verify:"
echo "  docker compose exec postgres psql -U aerodelay -d aerodelay -c \"SELECT year_month, COUNT(*) FROM raw.bts_flights GROUP BY 1;\""
echo "  docker compose exec postgres psql -U aerodelay -d aerodelay -c \"SELECT \\\"Origin\\\", COUNT(*) FROM raw.bts_flights GROUP BY 1 ORDER BY 2 DESC LIMIT 10;\""
