#!/usr/bin/env bash
# One-time bulletproof validation on Jan 2025 dev sample (materialized tables).
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"
LOG="${ROOT_DIR}/logs/bulletproof_jan2025.log"
mkdir -p "${ROOT_DIR}/logs"

{
  echo "=== $(date -u +%Y-%m-%dT%H:%M:%SZ) Bulletproof pass (Jan 2025 sample) ==="

  echo "--- Row counts ---"
  docker compose exec -T postgres psql -U aerodelay -d aerodelay -c "
    SELECT 'raw.bts_flights' AS src, count(*) FROM raw.bts_flights
    UNION ALL SELECT 'raw.weather_observations', count(*) FROM raw.weather_observations
    UNION ALL SELECT 'staging.stg_bts__flights', count(*) FROM staging.stg_bts__flights
    UNION ALL SELECT 'intermediate.int_flights__weather_at_departure', count(*) FROM intermediate.int_flights__weather_at_departure
    UNION ALL SELECT 'marts.fct_flights', count(*) FROM marts.fct_flights;
  "

  echo "--- Critical dbt tests ---"
  bash scripts/dbt_run.sh test --select \
    assert_weather_join_row_count \
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
    agg_delay_by_carrier_route \
    --threads 1

  echo "--- Coverage analysis ---"
  bash scripts/dbt_run.sh compile
  docker compose exec -T postgres psql -U aerodelay -d aerodelay -f - \
    < dbt/target/compiled/aerodelay/analyses/weather_join_coverage_jan2025.sql \
    | head -20

  echo "=== DONE exit=0 $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
} 2>&1 | tee "${LOG}"
