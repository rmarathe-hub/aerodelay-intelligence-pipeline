#!/usr/bin/env bash
# Validation queries after full local materialization.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

source .env 2>/dev/null || true
PGUSER="${POSTGRES_USER:-aerodelay}"
PGDB="${POSTGRES_DB:-aerodelay}"

psql_run() {
  if docker compose ps postgres --status running >/dev/null 2>&1; then
    docker compose exec -T postgres psql -U "${PGUSER}" -d "${PGDB}" -c "$1"
  else
    PGPASSWORD="${POSTGRES_PASSWORD:?}" psql -h "${POSTGRES_HOST_LOCAL:-localhost}" -p "${POSTGRES_PORT:-5432}" -U "${PGUSER}" -d "${PGDB}" -c "$1"
  fi
}

section() {
  echo ""
  echo "=== $1 ==="
}

section "Table row counts"
psql_run "
SELECT relname, n_live_tup::bigint AS est_rows
FROM pg_stat_user_tables
WHERE schemaname IN ('intermediate', 'marts')
  AND relname IN (
    'int_flights__weather_at_departure', 'fct_flights',
    'agg_delay_by_airport_hour', 'agg_delay_by_weather_bucket', 'agg_delay_by_carrier_route'
  )
ORDER BY relname;
"

section "Exact counts"
psql_run "
SELECT 'int' AS model, count(*) FROM intermediate.int_flights__weather_at_departure
UNION ALL SELECT 'fct', count(*) FROM marts.fct_flights;
"

section "Duplicate flight_id check (expect 0)"
psql_run "
SELECT count(*) - count(DISTINCT flight_id) AS duplicate_flight_keys
FROM intermediate.int_flights__weather_at_departure;
"

section "Coverage by month"
psql_run "
SELECT
    year_month,
    count(*) AS flights,
    count(*) FILTER (WHERE weather_match_status = 'matched') AS matched,
    round(100.0 * count(*) FILTER (WHERE weather_match_status = 'matched') / nullif(count(*), 0), 2) AS match_pct
FROM intermediate.int_flights__weather_at_departure
GROUP BY 1
ORDER BY 1;
"

section "Unmatched by origin (top 10)"
psql_run "
SELECT
    origin,
    count(*) FILTER (WHERE weather_match_status = 'no_obs_in_window') AS unmatched,
    count(*) AS total
FROM intermediate.int_flights__weather_at_departure
GROUP BY 1
HAVING count(*) FILTER (WHERE weather_match_status = 'no_obs_in_window') > 0
ORDER BY 2 DESC
LIMIT 10;
"

section "fct vs int row parity"
psql_run "
SELECT
    (SELECT count(*) FROM intermediate.int_flights__weather_at_departure) AS int_rows,
    (SELECT count(*) FROM marts.fct_flights) AS fct_rows,
    (SELECT count(*) FROM intermediate.int_flights__weather_at_departure)
      - (SELECT count(*) FROM marts.fct_flights) AS delta;
"

echo ""
echo "For compiled analysis SQL: bash scripts/dbt_run.sh compile && psql -f dbt/target/compiled/.../analyses/materialization_*.sql"
