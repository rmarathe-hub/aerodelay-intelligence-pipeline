#!/usr/bin/env bash
# Monthly chunked materialization for int_flights__weather_at_departure (local or OCI).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

START_YM="2023-01"
END_YM="2025-12"
RESUME_FROM=""
THREADS=1
FRESH=0
LOG_DIR="${ROOT_DIR}/logs"

usage() {
  cat <<'EOF'
Usage: materialize_monthly.sh [options]

  --start YYYY-MM     First month (default: 2023-01)
  --end YYYY-MM       Last month inclusive (default: 2025-12)
  --resume-from YYYY-MM  Skip months before this (re-run this month onward)
  --fresh             Drop and rebuild int table on first processed month
  --threads N         dbt threads (default: 1)
  -h, --help

Example — full 2023-2025 overnight:
  bash scripts/materialize_monthly.sh

Example — resume after failure in 2024-06:
  bash scripts/materialize_monthly.sh --resume-from 2024-06
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --start) START_YM="${2:?}"; shift 2 ;;
    --end) END_YM="${2:?}"; shift 2 ;;
    --resume-from) RESUME_FROM="${2:?}"; shift 2 ;;
    --fresh) FRESH=1; shift ;;
    --threads) THREADS="${2:?}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

ym_to_int() {
  local ym="$1"
  echo $((10#${ym%%-*} * 12 + 10#${ym##*-}))
}

int_to_start_date() {
  local y=$(( $1 / 12 ))
  local m=$(( $1 % 12 ))
  if [[ "${m}" -eq 0 ]]; then
    y=$((y - 1))
    m=12
  fi
  printf '%04d-%02d-01' "${y}" "${m}"
}

int_to_end_date() {
  local y=$(( $1 / 12 ))
  local m=$(( $1 % 12 ))
  if [[ "${m}" -eq 0 ]]; then
    y=$((y - 1))
    m=12
  fi
  m=$((m + 1))
  if [[ "${m}" -gt 12 ]]; then
    m=1
    y=$((y + 1))
  fi
  printf '%04d-%02d-01' "${y}" "${m}"
}

START_INT="$(ym_to_int "${START_YM}")"
END_INT="$(ym_to_int "${END_YM}")"
RESUME_INT=0
if [[ -n "${RESUME_FROM}" ]]; then
  RESUME_INT="$(ym_to_int "${RESUME_FROM}")"
fi

if [[ "${START_INT}" -gt "${END_INT}" ]]; then
  echo "Invalid range: ${START_YM} > ${END_YM}" >&2
  exit 2
fi

mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/materialize_monthly_$(date +%Y%m%d_%H%M%S).log"

source .env 2>/dev/null || true
PGUSER="${POSTGRES_USER:-aerodelay}"
PGDB="${POSTGRES_DB:-aerodelay}"

psql_count() {
  if docker compose ps postgres --status running >/dev/null 2>&1; then
    docker compose exec -T postgres psql -U "${PGUSER}" -d "${PGDB}" -At -c "$1"
  else
    PGPASSWORD="${POSTGRES_PASSWORD:?}" psql -h "${POSTGRES_HOST_LOCAL:-localhost}" -p "${POSTGRES_PORT:-5432}" -U "${PGUSER}" -d "${PGDB}" -At -c "$1"
  fi
}

log() {
  echo "$*" | tee -a "${LOG_FILE}"
}

log "=== AeroDelay monthly materialization ==="
log "range: ${START_YM} .. ${END_YM}"
log "resume-from: ${RESUME_FROM:-none}"
log "threads: ${THREADS}"
log "fresh: ${FRESH}"
log "log: ${LOG_FILE}"
log ""

TABLE_EXISTS="$(psql_count "SELECT CASE WHEN to_regclass('intermediate.int_flights__weather_at_departure') IS NOT NULL THEN 1 ELSE 0 END;" 2>/dev/null || echo 0)"

if [[ "${START_YM}" == "2023-01" && "${RESUME_INT}" -eq 0 && "${FRESH}" -eq 0 && "${TABLE_EXISTS}" -eq 1 ]]; then
  FRESH=1
  log "Auto --fresh: replacing existing int table for full 2023-2025 build"
fi

FIRST_RUN=1
for (( ym_int=START_INT; ym_int<=END_INT; ym_int++ )); do
  if [[ "${RESUME_INT}" -gt 0 && "${ym_int}" -lt "${RESUME_INT}" ]]; then
    continue
  fi

  start_date="$(int_to_start_date "${ym_int}")"
  end_date="$(int_to_end_date "${ym_int}")"
  label="${start_date:0:7}"

  refresh_flag=""
  if [[ "${FIRST_RUN}" -eq 1 ]]; then
    if [[ "${FRESH}" -eq 1 || "${TABLE_EXISTS}" -eq 0 ]]; then
      refresh_flag="--full-refresh"
    fi
    FIRST_RUN=0
  fi

  vars_json="{\"start_date\": \"${start_date}\", \"end_date\": \"${end_date}\"}"
  cmd=(bash scripts/dbt_run.sh run
    --select +int_flights__weather_at_departure
    --vars "${vars_json}"
    --threads "${THREADS}"
  )
  if [[ -n "${refresh_flag}" ]]; then
    cmd+=("${refresh_flag}")
  fi

  log "=== ${label}  [${start_date} .. ${end_date}) ==="
  log "command: ${cmd[*]}"
  month_start_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  if ! "${cmd[@]}" 2>&1 | tee -a "${LOG_FILE}"; then
    log "FAILED month ${label} at ${month_start_ts}"
    exit 1
  fi

  int_rows="$(psql_count "SELECT count(*) FROM intermediate.int_flights__weather_at_departure;" 2>/dev/null || echo "?")"
  month_rows="$(psql_count "SELECT count(*) FROM intermediate.int_flights__weather_at_departure WHERE year_month = '${label}';" 2>/dev/null || echo "?")"
  month_end_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  log "OK ${label}  month_rows=${month_rows}  int_total=${int_rows}  (${month_start_ts} -> ${month_end_ts})"
  log ""
done

log "=== Monthly materialization complete ==="
int_rows="$(psql_count "SELECT count(*) FROM intermediate.int_flights__weather_at_departure;")"
log "intermediate.int_flights__weather_at_departure total rows: ${int_rows}"
log "Next: bash scripts/materialize_downstream.sh  (or make materialize-full-local downstream only)"
