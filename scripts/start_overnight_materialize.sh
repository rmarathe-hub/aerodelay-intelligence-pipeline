#!/usr/bin/env bash
# Start overnight full 2023-2025 monthly materialization (run in tmux or dedicated terminal).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

RESUME_FROM="${1:-}"
LOG="${ROOT_DIR}/logs/full_materialize_2023_2025.log"
mkdir -p "${ROOT_DIR}/logs"

echo "=== AeroDelay overnight materialize ==="
echo "workspace: ${ROOT_DIR}"
echo "log: ${LOG}"

# Prevent Mac sleep until this terminal session ends (or caffeinate is killed)
if ! pgrep -f "caffeinate -dims" >/dev/null 2>&1; then
  caffeinate -dims &
  echo "caffeinate started (PID $!) — Mac will stay awake"
else
  echo "caffeinate already running"
fi

# Docker memory check
if command -v docker >/dev/null 2>&1; then
  DOCKER_MEM="$(docker info 2>/dev/null | awk -F': ' '/Total Memory/{print $2}' || true)"
  echo "Docker VM memory: ${DOCKER_MEM:-unknown}"
  if [[ "${DOCKER_MEM}" == *GiB ]]; then
  MEM_GB="${DOCKER_MEM%GiB}"
    if awk "BEGIN{exit !(${MEM_GB} < 8)}" 2>/dev/null; then
      echo "WARN: Docker memory < 8 GiB — bump in Docker Desktop → Settings → Resources → Memory (8–12 GB)"
    fi
  fi
fi

echo "Stopping Airflow (Postgres only needed)..."
docker compose stop airflow-webserver airflow-scheduler 2>/dev/null || true
docker compose ps postgres

INT_ROWS="$(docker compose exec -T postgres psql -U aerodelay -d aerodelay -At -c \
  "SELECT count(*) FROM intermediate.int_flights__weather_at_departure;" 2>/dev/null || echo 0)"
MONTHS="$(docker compose exec -T postgres psql -U aerodelay -d aerodelay -At -c \
  "SELECT count(DISTINCT year_month) FROM intermediate.int_flights__weather_at_departure;" 2>/dev/null || echo 0)"
echo "Current int rows: ${INT_ROWS} across ${MONTHS} month(s)"

MAT_ARGS=(--start 2023-01 --end 2025-12)
if [[ -n "${RESUME_FROM}" ]]; then
  MAT_ARGS+=(--resume-from "${RESUME_FROM}")
  echo "Resuming from: ${RESUME_FROM}"
elif [[ "${MONTHS}" -gt 0 ]]; then
  LAST_MONTH="$(docker compose exec -T postgres psql -U aerodelay -d aerodelay -At -c \
    "SELECT max(year_month) FROM intermediate.int_flights__weather_at_departure;")"
  echo "Data exists through ${LAST_MONTH} — pass resume YYYY-MM to continue, or --fresh via materialize_monthly.sh"
fi

echo ""
echo "Starting monthly run (foreground — use tmux)..."
echo "  tail -f ${LOG}   # in another terminal"
echo ""

{
  echo "=== started $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  bash scripts/materialize_monthly.sh "${MAT_ARGS[@]}"
  echo "=== monthly done $(date -u +%Y-%m-%dT%H:%M:%SZ) — running downstream ==="
  bash scripts/materialize_downstream.sh
  bash scripts/validate_full_materialization.sh
  echo "=== complete $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
} 2>&1 | tee -a "${LOG}"
