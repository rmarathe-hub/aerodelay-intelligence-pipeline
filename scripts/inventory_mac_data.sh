#!/usr/bin/env bash
# Day 5 — Mac data inventory for OCI transfer path (rsync vs pg_dump vs re-backfill).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

WITH_PGDUMP_ESTIMATE=0
if [[ "${1:-}" == "--with-pgdump-estimate" ]]; then
  WITH_PGDUMP_ESTIMATE=1
fi

source .env 2>/dev/null || true
PGUSER="${POSTGRES_USER:-aerodelay}"
PGDB="${POSTGRES_DB:-aerodelay}"

section() {
  echo ""
  echo "=== $1 ==="
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

docker compose ps postgres --status running >/dev/null 2>&1 \
  || fail "Postgres is not running. Start with: make up"

psql_query() {
  docker compose exec -T postgres psql -U "${PGUSER}" -d "${PGDB}" -At -c "$1"
}

section "Postgres raw — BTS"
IFS='|' read -r BTS_ROWS BTS_MONTHS BTS_MIN BTS_MAX <<<"$(
  psql_query "SELECT count(*), count(DISTINCT year_month), min(year_month), max(year_month) FROM raw.bts_flights;"
)"
echo "rows=${BTS_ROWS}  months=${BTS_MONTHS}  range=${BTS_MIN}..${BTS_MAX}"

section "Postgres raw — weather"
IFS='|' read -r WX_ROWS WX_STATION_MONTHS WX_STATIONS <<<"$(
  psql_query "SELECT count(*), count(DISTINCT station || '-' || year_month), count(DISTINCT station) FROM raw.weather_observations;"
)"
echo "rows=${WX_ROWS}  station_months=${WX_STATION_MONTHS}  stations=${WX_STATIONS}"

section "On-disk raw files"
BTS_DIR="data/raw/bts"
WX_DIR="data/raw/weather"
BTS_ZIP_COUNT=0
WX_CSV_COUNT=0
BTS_DISK=""
WX_DISK=""

if [[ -d "${BTS_DIR}" ]]; then
  BTS_DISK="$(du -sh "${BTS_DIR}" 2>/dev/null | awk '{print $1}')"
  BTS_ZIP_COUNT="$(find "${BTS_DIR}" -maxdepth 1 -name '*.zip' 2>/dev/null | wc -l | tr -d ' ')"
fi
if [[ -d "${WX_DIR}" ]]; then
  WX_DISK="$(du -sh "${WX_DIR}" 2>/dev/null | awk '{print $1}')"
  WX_CSV_COUNT="$(find "${WX_DIR}" -maxdepth 1 -name 'weather_*.csv' 2>/dev/null | wc -l | tr -d ' ')"
fi

echo "BTS:  ${BTS_DISK:-missing}  (${BTS_ZIP_COUNT} ZIPs in ${BTS_DIR})"
echo "WX:   ${WX_DISK:-missing}  (${WX_CSV_COUNT} CSVs in ${WX_DIR})"

BTS_2025_ZIPS=0
WX_2025_CSVS=0
BTS_2025_DISK=""
WX_2025_DISK=""
if [[ -d "${BTS_DIR}" ]]; then
  BTS_2025_ZIPS="$(find "${BTS_DIR}" -maxdepth 1 -name '*_2025_*.zip' 2>/dev/null | wc -l | tr -d ' ')"
  BTS_2025_DISK="$(du -ch "${BTS_DIR}"/*_2025_*.zip 2>/dev/null | tail -1 | awk '{print $1}' || true)"
fi
if [[ -d "${WX_DIR}" ]]; then
  WX_2025_CSVS="$(find "${WX_DIR}" -maxdepth 1 -name 'weather_*_2025_*.csv' 2>/dev/null | wc -l | tr -d ' ')"
  WX_2025_DISK="$(du -ch "${WX_DIR}"/weather_*_2025_*.csv 2>/dev/null | tail -1 | awk '{print $1}' || true)"
fi

echo ""
echo "2025-only staging subset:"
echo "  BTS ZIPs: ${BTS_2025_ZIPS}  (~${BTS_2025_DISK:-?})"
echo "  WX CSVs:  ${WX_2025_CSVS}  (~${WX_2025_DISK:-?})"

section "Disk vs Postgres gaps"
DISK_STATIONS="$(find "${WX_DIR}" -maxdepth 1 -name 'weather_*.csv' -print0 2>/dev/null \
  | xargs -0 -n1 basename 2>/dev/null \
  | sed -E 's/^weather_([A-Z0-9]+)_[0-9]{4}_[0-9]{2}\.csv$/\1/' \
  | sort -u || true)"
DB_STATIONS="$(psql_query "SELECT station FROM (SELECT DISTINCT station FROM raw.weather_observations) s ORDER BY 1;")"

ONLY_ON_DISK=""
while IFS= read -r station; do
  [[ -z "${station}" ]] && continue
  if ! grep -qx "${station}" <<<"${DB_STATIONS}"; then
    ONLY_ON_DISK="${ONLY_ON_DISK} ${station}"
  fi
done <<<"${DISK_STATIONS}"

ONLY_ON_DISK="$(echo "${ONLY_ON_DISK}" | xargs || true)"
if [[ -n "${ONLY_ON_DISK}" ]]; then
  echo "Weather CSV on disk but not loaded in Postgres: ${ONLY_ON_DISK}"
else
  echo "No extra weather stations on disk beyond Postgres."
fi

section "dbt materialization (local)"
FCT_ROWS="$(psql_query "SELECT count(*) FROM marts.fct_flights;" 2>/dev/null || echo "0")"
INT_ROWS="$(psql_query "SELECT count(*) FROM intermediate.int_flights__weather_at_departure;" 2>/dev/null || echo "0")"
echo "marts.fct_flights:                      ${FCT_ROWS} rows"
echo "intermediate.int_flights__weather_at_departure: ${INT_ROWS} rows"
if [[ "${FCT_ROWS}" == "408974" ]]; then
  echo "(Jan 2025 dev sample only — full materialize happens on OCI)"
fi

if [[ "${WITH_PGDUMP_ESTIMATE}" -eq 1 ]]; then
  section "pg_dump size estimate (raw + meta, may take 1–3 min)"
  DUMP_PATH="/tmp/aerodelay_raw_meta_estimate.dump"
  docker compose exec -T postgres rm -f "${DUMP_PATH}" >/dev/null 2>&1 || true
  docker compose exec -T postgres pg_dump -U "${PGUSER}" -d "${PGDB}" -n raw -n meta -Fc -f "${DUMP_PATH}"
  docker compose exec -T postgres ls -lh "${DUMP_PATH}"
  docker compose exec -T postgres rm -f "${DUMP_PATH}" >/dev/null 2>&1 || true
else
  echo ""
  echo "(Skip pg_dump estimate by default. Re-run with --with-pgdump-estimate if needed.)"
fi

section "Transfer path recommendation"
RECOMMEND=""
REASON=""

if [[ "${BTS_ZIP_COUNT}" -ge 36 && "${WX_CSV_COUNT}" -ge 1584 ]]; then
  RECOMMEND="Option C — rsync data/raw/ to OCI VM"
  REASON="Complete BTS ZIPs (${BTS_ZIP_COUNT}) and weather CSVs (${WX_CSV_COUNT}) on disk. Staged Day-8 load: rsync 2025 subset (~${BTS_2025_DISK:-?} BTS + ~${WX_2025_DISK:-?} weather), then backfill --no-download on VM."
elif [[ "${BTS_MONTHS}" -ge 36 && "${WX_STATION_MONTHS}" -ge 1584 ]]; then
  RECOMMEND="Option B — pg_dump -n raw -n meta"
  REASON="Postgres raw is complete but on-disk files are incomplete. Dump is smaller than re-download but skips reproducible file-based load."
else
  RECOMMEND="Option A — re-backfill on VM"
  REASON="Gaps in both disk files and Postgres. Use ingestion backfill scripts on OCI with network download."
fi

echo "${RECOMMEND}"
echo ""
echo "${REASON}"
echo ""
echo "OCI staged rsync examples (Option C):"
echo "  rsync -avz --progress data/raw/bts/*_2025_*.zip user@vm:~/AeroDelay_Intel_Pipeline/data/raw/bts/"
echo "  rsync -avz --progress data/raw/weather/weather_*_2025_*.csv user@vm:~/AeroDelay_Intel_Pipeline/data/raw/weather/"
echo ""
echo "VM load (after rsync, no download):"
echo "  python -m ingestion.bts.backfill --start-year 2025 --end-year 2025 --end-month 12 --no-download"
echo "  python -m ingestion.weather.backfill --start-year 2025 --end-year 2025 --end-month 12 --no-download"
echo ""
echo "Exit: transfer method chosen → document in docs/DAY35_CHECKLIST.md"
