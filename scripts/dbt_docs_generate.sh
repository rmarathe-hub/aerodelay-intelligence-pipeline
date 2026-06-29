#!/usr/bin/env bash
# Build Jan 2025 marts and generate dbt docs (local Docker Postgres or CI service).
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

DEV_VARS='{dev_year_month: "2025-01"}'
DBT_SELECT_BUILD="+int_flights__weather_at_departure fct_flights agg_delay_by_airport_hour agg_delay_by_weather_bucket agg_delay_by_carrier_route"

echo "=== dbt deps + seed ==="
bash scripts/dbt_run.sh deps
bash scripts/dbt_run.sh seed

echo ""
echo "=== dbt run (Jan 2025 sample — populates catalog) ==="
bash scripts/dbt_run.sh run \
  --select ${DBT_SELECT_BUILD} \
  --full-refresh \
  --vars "${DEV_VARS}" \
  --threads 1

echo ""
echo "=== dbt docs generate (static — GitHub Pages subpath) ==="
bash scripts/dbt_run.sh docs generate --static

echo ""
echo "Docs site files: ${ROOT_DIR}/dbt/target/"
echo "Open locally: open dbt/target/index.html"
echo "GitHub Pages: https://rmarathe-hub.github.io/aerodelay-intelligence-pipeline/"
