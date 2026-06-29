#!/usr/bin/env bash
# Build Jan 2025 dbt sample and run critical tests (CI + local repro without Docker).
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

DEV_VARS='{dev_year_month: "2025-01"}'
DBT_SELECT_BUILD="+int_flights__weather_at_departure fct_flights agg_delay_by_*"
DBT_SELECT_TEST="assert_weather_join_row_count \
  assert_weather_join_window \
  assert_weather_join_coverage_jan2025 \
  assert_weather_join_coverage_loaded_months \
  assert_fct_flights_row_count \
  assert_fct_has_departure_weather_consistent \
  assert_fct_cancelled_null_dep_delay \
  assert_fct_cancelled_not_analysis_eligible \
  assert_dep_time_utc_coverage \
  agg_delay_by_airport_hour \
  agg_delay_by_weather_bucket \
  agg_delay_by_carrier_route"

echo "=== dbt deps + seed ==="
bash scripts/dbt_run.sh deps
bash scripts/dbt_run.sh seed

echo ""
echo "=== dbt run (Jan 2025 sample) ==="
bash scripts/dbt_run.sh run \
  --select ${DBT_SELECT_BUILD} \
  --full-refresh \
  --vars "${DEV_VARS}" \
  --threads 1

echo ""
echo "=== dbt test (critical Jan 2025 pass) ==="
bash scripts/dbt_run.sh test \
  --select ${DBT_SELECT_TEST} \
  --threads 1

echo ""
echo "CI dbt Jan 2025 tests passed."
