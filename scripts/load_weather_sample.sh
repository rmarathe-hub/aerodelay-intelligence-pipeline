#!/usr/bin/env bash
# Load January 2025 weather samples (ATL, ORD, LAX) into raw.weather_observations
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

load_sample() {
  local station="$1"
  local csv_path="$2"
  if [[ ! -f "${csv_path}" ]]; then
    echo "Sample CSV not found: ${csv_path}"
    exit 1
  fi
  echo "Loading ${station} from ${csv_path}..."
  python -m ingestion.weather.load \
    --year 2025 \
    --month 1 \
    --station "${station}" \
    --csv-path "${csv_path}"
}

load_sample "ATL" "data/samples/weather_ATL_2025_jan.csv"
load_sample "ORD" "data/samples/weather_ORD_2025_jan.csv"
load_sample "LAX" "data/samples/weather_asos_LAX_jan2025.csv"

echo ""
echo "Verify:"
echo "  docker compose exec postgres psql -U aerodelay -d aerodelay -c \\"
echo "    \"SELECT station, year_month, COUNT(*) FROM raw.weather_observations GROUP BY 1, 2 ORDER BY 1;\""
