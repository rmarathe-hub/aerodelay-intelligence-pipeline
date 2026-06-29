#!/usr/bin/env bash
# Build fct_flights + agg marts and run spot tests after monthly int materialization.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

THREADS="${THREADS:-1}"

echo "=== Build fct_flights + aggregation marts ==="
bash scripts/dbt_run.sh run \
  --select fct_flights agg_delay_by_airport_hour agg_delay_by_weather_bucket agg_delay_by_carrier_route \
  --full-refresh \
  --threads "${THREADS}"

source .env 2>/dev/null || true
PGUSER="${POSTGRES_USER:-aerodelay}"
PGDB="${POSTGRES_DB:-aerodelay}"

row_query() {
  if docker compose ps postgres --status running >/dev/null 2>&1; then
    docker compose exec -T postgres psql -U "${PGUSER}" -d "${PGDB}" -At -c "$1"
  else
    PGPASSWORD="${POSTGRES_PASSWORD:?}" psql -h "${POSTGRES_HOST_LOCAL:-localhost}" -p "${POSTGRES_PORT:-5432}" -U "${PGUSER}" -d "${PGDB}" -At -c "$1"
  fi
}

echo ""
echo "=== Row counts ==="
row_query "
  SELECT 'int_flights__weather_at_departure', count(*) FROM intermediate.int_flights__weather_at_departure
  UNION ALL SELECT 'fct_flights', count(*) FROM marts.fct_flights
  UNION ALL SELECT 'agg_delay_by_airport_hour', count(*) FROM marts.agg_delay_by_airport_hour
  UNION ALL SELECT 'agg_delay_by_weather_bucket', count(*) FROM marts.agg_delay_by_weather_bucket
  UNION ALL SELECT 'agg_delay_by_carrier_route', count(*) FROM marts.agg_delay_by_carrier_route;
"

echo ""
echo "=== Spot dbt tests (safe for full history; skip Jan-only row-count tests) ==="
bash scripts/dbt_run.sh test \
  --select assert_weather_join_window \
    assert_fct_has_departure_weather_consistent \
    assert_fct_cancelled_null_dep_delay \
    assert_fct_cancelled_not_analysis_eligible \
    assert_agg_delay_by_airport_hour_rates_valid \
    assert_agg_delay_by_weather_bucket_rates_valid \
    assert_agg_delay_by_carrier_route_rates_valid \
  --threads 1

echo ""
echo "Downstream build complete. Run: bash scripts/validate_full_materialization.sh"
