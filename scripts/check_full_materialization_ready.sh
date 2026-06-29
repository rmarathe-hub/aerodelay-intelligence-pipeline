#!/usr/bin/env bash
# Day 6 — GO/NO-GO preflight before full dbt materialization (local Docker or OCI VM).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

STAGE="full"
ALLOW_LOCAL=0
MODE="full"

usage() {
  cat <<'EOF'
Usage: check_full_materialization_ready.sh [options]

  --stage 2025|2024-2025|full   Raw coverage expectation (default: full)
  --mode full|monthly           full = single full-refresh; monthly = chunked local path
  --allow-local                 Allow macOS Docker for monthly chunked runs
  -h, --help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stage)
      STAGE="${2:?--stage requires a value}"
      shift 2
      ;;
    --allow-local)
      ALLOW_LOCAL=1
      shift
      ;;
    --mode)
      MODE="${2:?--mode requires a value}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "${STAGE}" in
  2025) MIN_BTS_MONTHS=12; MIN_WX_STATION_MONTHS=528; STAGE_LABEL="2025 only (12 months)" ;;
  2024-2025) MIN_BTS_MONTHS=24; MIN_WX_STATION_MONTHS=1056; STAGE_LABEL="2024–2025 (24 months)" ;;
  full) MIN_BTS_MONTHS=36; MIN_WX_STATION_MONTHS=1584; STAGE_LABEL="full 2023–2025 (36 months)" ;;
  *)
    echo "Invalid --stage: ${STAGE} (use 2025, 2024-2025, or full)" >&2
    exit 2
    ;;
esac

source .env 2>/dev/null || true
PGUSER="${POSTGRES_USER:-aerodelay}"
PGDB="${POSTGRES_DB:-aerodelay}"
PGHOST="${POSTGRES_HOST_LOCAL:-localhost}"
PGPORT="${POSTGRES_PORT:-5432}"

PLANNED_DBT_CMD='bash scripts/dbt_run.sh run \
  --select +int_flights__weather_at_departure fct_flights \
    agg_delay_by_airport_hour agg_delay_by_weather_bucket agg_delay_by_carrier_route \
  --full-refresh \
  --threads 1'

DATA_GO=1
RESOURCE_GO=1
CONFIG_GO=1
ISSUES=()

section() {
  echo ""
  echo "=== $1 ==="
}

note_issue() {
  local bucket="$1"
  local msg="$2"
  ISSUES+=("[${bucket}] ${msg}")
  case "${bucket}" in
    DATA) DATA_GO=0 ;;
    RESOURCE) RESOURCE_GO=0 ;;
    CONFIG) CONFIG_GO=0 ;;
  esac
}

USE_DOCKER=0
if docker compose ps postgres --status running >/dev/null 2>&1; then
  USE_DOCKER=1
fi

psql_query() {
  if [[ "${USE_DOCKER}" -eq 1 ]]; then
    docker compose exec -T postgres psql -U "${PGUSER}" -d "${PGDB}" -At -c "$1"
  else
    PGPASSWORD="${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD in .env}" \
      psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDB}" -At -c "$1"
  fi
}

section "Environment"
if [[ "${USE_DOCKER}" -eq 1 ]]; then
  echo "host:     docker compose postgres"
else
  echo "host:     ${PGHOST}:${PGPORT}"
fi
echo "database: ${PGDB}"
echo "stage:    ${STAGE_LABEL}"
echo "mode:     ${MODE}"
echo "workspace: ${ROOT_DIR}"

section "Host resources"
OS_NAME="$(uname -s)"
echo "OS: ${OS_NAME} $(uname -m)"

if [[ "${OS_NAME}" == "Darwin" ]]; then
  RAM_BYTES="$(sysctl -n hw.memsize)"
  RAM_GB=$((RAM_BYTES / 1024 / 1024 / 1024))
  SWAP_TOTAL_MB="$(sysctl -n vm.swapusage 2>/dev/null | awk '{gsub(/M/, "", $3); print int($3 + 0.5)}')"
  SWAP_GB=$(( (SWAP_TOTAL_MB + 512) / 1024 ))
else
  RAM_GB="$(free -g | awk '/^Mem:/{print $2}')"
  SWAP_GB="$(free -g | awk '/^Swap:/{print $2}')"
fi

echo "RAM:  ${RAM_GB} GB"
echo "swap: ${SWAP_GB} GB"

df -h "${ROOT_DIR}" | tail -1 | awk '{printf "disk (workspace): %s total, %s avail (%s used) on %s\n", $2, $4, $5, $1}'

MIN_RAM_GB=10
MIN_SWAP_GB=8
MIN_DISK_AVAIL_GB=40

DISK_AVAIL_KB="$(df -k "${ROOT_DIR}" | tail -1 | awk '{print $4}')"
DISK_AVAIL_GB=$((DISK_AVAIL_KB / 1024 / 1024))

if [[ "${RAM_GB}" -lt "${MIN_RAM_GB}" ]]; then
  note_issue RESOURCE "RAM ${RAM_GB} GB < recommended ${MIN_RAM_GB} GB for full materialize"
fi
if [[ "${SWAP_GB}" -lt "${MIN_SWAP_GB}" ]]; then
  note_issue RESOURCE "swap ${SWAP_GB} GB < recommended ${MIN_SWAP_GB} GB"
fi
if [[ "${DISK_AVAIL_GB}" -lt "${MIN_DISK_AVAIL_GB}" ]]; then
  note_issue RESOURCE "disk avail ${DISK_AVAIL_GB} GB < recommended ${MIN_DISK_AVAIL_GB} GB"
fi
if [[ "${OS_NAME}" == "Darwin" && "${ALLOW_LOCAL}" -eq 0 && "${MODE}" == "full" ]]; then
  note_issue RESOURCE "macOS Docker host — use monthly mode (--mode monthly --allow-local) or OCI VM"
fi
if [[ "${OS_NAME}" == "Darwin" && "${MODE}" == "monthly" && "${ALLOW_LOCAL}" -eq 0 ]]; then
  note_issue RESOURCE "monthly local runs need --allow-local on macOS Docker"
fi

section "Postgres connectivity + size"
if [[ "${USE_DOCKER}" -eq 0 ]]; then
  if ! command -v psql >/dev/null 2>&1; then
    note_issue DATA "psql not found and Docker Postgres is not running"
  fi
fi

DB_SIZE="$(psql_query "SELECT pg_size_pretty(pg_database_size(current_database()));" 2>/dev/null || echo "unknown")"
echo "database size: ${DB_SIZE}"

SCHEMAS="$(psql_query "SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('raw','meta','staging','intermediate','marts') ORDER BY 1;" 2>/dev/null | paste -sd, - || true)"
echo "schemas: ${SCHEMAS:-missing}"
if [[ "${SCHEMAS}" != *raw* ]]; then
  note_issue DATA "raw schema missing — run init / load raw first"
fi

section "Raw row counts"
IFS='|' read -r BTS_ROWS BTS_MONTHS BTS_MIN BTS_MAX <<<"$(
  psql_query "SELECT count(*), count(DISTINCT year_month), coalesce(min(year_month),''), coalesce(max(year_month),'') FROM raw.bts_flights;"
)"
IFS='|' read -r WX_ROWS WX_STATION_MONTHS WX_STATIONS WX_MIN WX_MAX <<<"$(
  psql_query "SELECT count(*), count(DISTINCT station || '-' || year_month), count(DISTINCT station), coalesce(min(year_month),''), coalesce(max(year_month),'') FROM raw.weather_observations;"
)"

echo "raw.bts_flights:          rows=${BTS_ROWS}  months=${BTS_MONTHS}  range=${BTS_MIN}..${BTS_MAX}"
echo "raw.weather_observations: rows=${WX_ROWS}  station_months=${WX_STATION_MONTHS}  stations=${WX_STATIONS}  range=${WX_MIN}..${WX_MAX}"

if [[ "${BTS_ROWS}" -eq 0 ]]; then
  note_issue DATA "raw.bts_flights is empty"
fi
if [[ "${WX_ROWS}" -eq 0 ]]; then
  note_issue DATA "raw.weather_observations is empty"
fi
if [[ "${BTS_MONTHS}" -lt "${MIN_BTS_MONTHS}" ]]; then
  note_issue DATA "BTS months ${BTS_MONTHS} < ${MIN_BTS_MONTHS} required for stage ${STAGE}"
fi
if [[ "${WX_STATION_MONTHS}" -lt "${MIN_WX_STATION_MONTHS}" ]]; then
  note_issue DATA "weather station-months ${WX_STATION_MONTHS} < ${MIN_WX_STATION_MONTHS} required for stage ${STAGE}"
fi
if [[ -n "${BTS_MIN}" && -n "${WX_MIN}" && "${BTS_MIN}" != "${WX_MIN}" ]]; then
  echo "WARN: BTS min month (${BTS_MIN}) != weather min month (${WX_MIN})"
fi
if [[ -n "${BTS_MAX}" && -n "${WX_MAX}" && "${BTS_MAX}" != "${WX_MAX}" ]]; then
  echo "WARN: BTS max month (${BTS_MAX}) != weather max month (${WX_MAX})"
fi

section "dbt config (filters must be unset for full materialize)"
DEV_VAR="${dev_year_month:-}"
DBT_VARS_ENV="${DBT_VARS:-}"
START_DATE_VAR="${start_date:-}"
END_DATE_VAR="${end_date:-}"

if [[ -n "${DEV_VAR}" ]]; then
  note_issue CONFIG "env dev_year_month=${DEV_VAR} — unset before full materialize"
fi
if [[ "${DBT_VARS_ENV}" == *dev_year_month* ]]; then
  note_issue CONFIG "DBT_VARS contains dev_year_month: ${DBT_VARS_ENV}"
fi
if [[ -n "${START_DATE_VAR}" || -n "${END_DATE_VAR}" ]]; then
  note_issue CONFIG "env start_date/end_date set — unset for orchestrated monthly script"
fi
if [[ -z "${DEV_VAR}" && "${DBT_VARS_ENV}" != *dev_year_month* && -z "${START_DATE_VAR}" && -z "${END_DATE_VAR}" ]]; then
  echo "dev_year_month / start_date / end_date: unset in shell (OK)"
else
  echo "date filters: check shell env before starting"
fi

echo "dbt profile: ${DBT_PROFILE:-aerodelay}  target: ${DBT_TARGET:-dev}"

if [[ -x "${ROOT_DIR}/.venv-dbt/bin/dbt" ]]; then
  echo "dbt venv: ${ROOT_DIR}/.venv-dbt (ready)"
else
  echo "dbt venv: will be created on first scripts/dbt_run.sh (OK)"
fi

if [[ ! -f "${ROOT_DIR}/dbt/seeds/airport_station_map.csv" ]]; then
  note_issue CONFIG "missing dbt/seeds/airport_station_map.csv — run make dbt-seed first"
fi

section "Materialized table sizes (if any)"
INT_ROWS="$(psql_query "SELECT count(*) FROM intermediate.int_flights__weather_at_departure;" 2>/dev/null || echo "n/a")"
FCT_ROWS="$(psql_query "SELECT count(*) FROM marts.fct_flights;" 2>/dev/null || echo "n/a")"
INT_SIZE="$(psql_query "SELECT pg_size_pretty(pg_total_relation_size('intermediate.int_flights__weather_at_departure'));" 2>/dev/null || echo "n/a")"
FCT_SIZE="$(psql_query "SELECT pg_size_pretty(pg_total_relation_size('marts.fct_flights'));" 2>/dev/null || echo "n/a")"
echo "intermediate.int_flights__weather_at_departure: ${INT_ROWS} rows (${INT_SIZE})"
echo "marts.fct_flights:                              ${FCT_ROWS} rows (${FCT_SIZE})"

section "Planned commands"
if [[ "${MODE}" == "monthly" ]]; then
  echo "bash scripts/materialize_monthly.sh --start ${BTS_MIN:-2023-01} --end ${BTS_MAX:-2025-12}"
  echo "bash scripts/materialize_downstream.sh"
else
  echo "${PLANNED_DBT_CMD}"
  echo ""
  echo "Prefer monthly on Mac: bash scripts/materialize_monthly.sh"
fi
echo ""
echo "Do NOT pass: --vars '{dev_year_month: \"2025-01\"}' for full history"

section "Verdict"
if [[ "${#ISSUES[@]}" -gt 0 ]]; then
  echo "Issues:"
  for issue in "${ISSUES[@]}"; do
    echo "  - ${issue}"
  done
  echo ""
fi

echo "DATA:      $([[ "${DATA_GO}" -eq 1 ]] && echo GO || echo NO-GO)"
echo "RESOURCES: $([[ "${RESOURCE_GO}" -eq 1 ]] && echo GO || echo NO-GO)"
echo "CONFIG:    $([[ "${CONFIG_GO}" -eq 1 ]] && echo GO || echo NO-GO)"

OVERALL_GO=1
if [[ "${DATA_GO}" -eq 0 || "${RESOURCE_GO}" -eq 0 || "${CONFIG_GO}" -eq 0 ]]; then
  OVERALL_GO=0
fi

echo ""
if [[ "${OVERALL_GO}" -eq 1 ]]; then
  echo "OVERALL: GO — safe to start full materialize for stage ${STAGE}"
  exit 0
fi

echo "OVERALL: NO-GO — fix issues above before starting long dbt job"
if [[ "${DATA_GO}" -eq 1 && "${CONFIG_GO}" -eq 1 && "${RESOURCE_GO}" -eq 0 && "${OS_NAME}" == "Darwin" && "${MODE}" == "monthly" ]]; then
  echo "Hint: pass --allow-local for monthly chunked runs on Mac Docker"
fi
exit 1
