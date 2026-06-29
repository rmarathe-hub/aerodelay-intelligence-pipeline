#!/usr/bin/env bash
# Day 7 — Bootstrap Ubuntu 22.04 OCI A1 VM for AeroDelay materialization.
# Run ON the VM after first SSH login (not on Mac).
set -euo pipefail

SWAP_GB="${SWAP_GB:-16}"
DATA_MOUNT="${DATA_MOUNT:-/data}"
MOUNT_DEVICE="${MOUNT_DEVICE:-}"
REPO_URL="${REPO_URL:-https://github.com/rmarathe-hub/aerodelay-intelligence-pipeline.git}"
REPO_DIR="${REPO_DIR:-$HOME/aerodelay-intelligence-pipeline}"

usage() {
  cat <<'EOF'
Usage: oci_vm_bootstrap.sh [options]

  --mount-device /dev/sdb   Format (if needed) and mount block volume at /data
  --repo-dir PATH           Clone target (default: ~/aerodelay-intelligence-pipeline)
  --skip-clone              Only install OS packages, swap, Postgres
  -h, --help

Example (after attaching 150 GB volume as /dev/sdb):
  curl -fsSL https://raw.githubusercontent.com/rmarathe-hub/aerodelay-intelligence-pipeline/main/scripts/oci_vm_bootstrap.sh | bash -s -- --mount-device /dev/sdb

Or clone repo first, then:
  bash scripts/oci_vm_bootstrap.sh --mount-device /dev/sdb
EOF
}

SKIP_CLONE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mount-device)
      MOUNT_DEVICE="${2:?}"
      shift 2
      ;;
    --repo-dir)
      REPO_DIR="${2:?}"
      shift 2
      ;;
    --skip-clone)
      SKIP_CLONE=1
      shift
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

if [[ "$(id -u)" -ne 0 ]]; then
  SUDO="sudo"
else
  SUDO=""
fi

log() { echo "==> $*"; }

log "AeroDelay OCI VM bootstrap (Day 7)"

log "1/6 — 16 GB swap"
if ! swapon --show | grep -q '/swapfile'; then
  ${SUDO} fallocate -l "${SWAP_GB}G" /swapfile
  ${SUDO} chmod 600 /swapfile
  ${SUDO} mkswap /swapfile
  ${SUDO} swapon /swapfile
  if ! grep -q '/swapfile' /etc/fstab 2>/dev/null; then
    echo '/swapfile none swap sw 0 0' | ${SUDO} tee -a /etc/fstab >/dev/null
  fi
else
  echo "swapfile already active"
fi
free -h

log "2/6 — apt packages + PostgreSQL 15"
${SUDO} apt-get update -qq
${SUDO} apt-get install -y -qq \
  git curl ca-certificates \
  python3 python3-pip python3-venv \
  build-essential \
  rsync tmux

if ! command -v psql >/dev/null 2>&1 || ! psql --version | grep -q '15'; then
  if [[ ! -f /etc/apt/sources.list.d/pgdg.list ]]; then
    ${SUDO} sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | ${SUDO} gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
    ${SUDO} apt-get update -qq
  fi
  ${SUDO} apt-get install -y -qq postgresql-15 postgresql-client-15
fi

log "3/6 — optional data volume at ${DATA_MOUNT}"
if [[ -n "${MOUNT_DEVICE}" ]]; then
  if [[ ! -b "${MOUNT_DEVICE}" ]]; then
    echo "Block device not found: ${MOUNT_DEVICE}" >&2
    echo "Check: lsblk" >&2
    exit 1
  fi
  ${SUDO} mkdir -p "${DATA_MOUNT}"
  if ! blkid "${MOUNT_DEVICE}" >/dev/null 2>&1; then
    log "Formatting ${MOUNT_DEVICE} (ext4)..."
    ${SUDO} mkfs.ext4 -F "${MOUNT_DEVICE}"
  fi
  UUID="$(${SUDO} blkid -s UUID -o value "${MOUNT_DEVICE}")"
  if ! grep -q "${DATA_MOUNT}" /etc/fstab 2>/dev/null; then
    echo "UUID=${UUID} ${DATA_MOUNT} ext4 defaults,nofail 0 2" | ${SUDO} tee -a /etc/fstab >/dev/null
  fi
  ${SUDO} mount -a
  ${SUDO} chown "$(whoami):$(whoami)" "${DATA_MOUNT}"
  echo "Data volume mounted: $(df -h "${DATA_MOUNT}" | tail -1)"
fi

log "4/6 — Postgres role, database, schemas"
PG_CONF="/etc/postgresql/15/main/postgresql.conf"
PG_HBA="/etc/postgresql/15/main/pg_hba.conf"

# Tuning for 12 GB RAM A1 — join-heavy workload
if [[ -f "${PG_CONF}" ]]; then
  ${SUDO} sed -i "s/^#*shared_buffers = .*/shared_buffers = 2GB/" "${PG_CONF}" || true
  ${SUDO} sed -i "s/^#*maintenance_work_mem = .*/maintenance_work_mem = 1GB/" "${PG_CONF}" || true
  ${SUDO} sed -i "s/^#*work_mem = .*/work_mem = 128MB/" "${PG_CONF}" || true
  ${SUDO} sed -i "s/^#*effective_cache_size = .*/effective_cache_size = 8GB/" "${PG_CONF}" || true
fi

# Move data directory to /data if mounted (more room for 15M-row tables)
if [[ -d "${DATA_MOUNT}" ]] && mountpoint -q "${DATA_MOUNT}" 2>/dev/null; then
  PG_DATA="${DATA_MOUNT}/postgresql/15/main"
  if [[ ! -d "${PG_DATA}/base" ]]; then
    log "Moving Postgres data to ${PG_DATA}..."
    ${SUDO} systemctl stop postgresql
    ${SUDO} mkdir -p "$(dirname "${PG_DATA}")"
    ${SUDO} rsync -a /var/lib/postgresql/15/main/ "${PG_DATA}/"
    ${SUDO} chown -R postgres:postgres "${DATA_MOUNT}/postgresql"
    if ! grep -q "data_directory" "${PG_CONF}" 2>/dev/null; then
      echo "data_directory = '${PG_DATA}'" | ${SUDO} tee -a "${PG_CONF}" >/dev/null
    fi
  fi
fi

${SUDO} systemctl enable postgresql
${SUDO} systemctl restart postgresql

# Credentials — override before running or edit .env after clone
PGUSER="${POSTGRES_USER:-aerodelay}"
PGDB="${POSTGRES_DB:-aerodelay}"
PGPASS="${POSTGRES_PASSWORD:-aerodelay_oci_change_me}"

${SUDO} -u postgres psql -v ON_ERROR_STOP=1 <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${PGUSER}') THEN
    CREATE ROLE ${PGUSER} WITH LOGIN PASSWORD '${PGPASS}';
  ELSE
    ALTER ROLE ${PGUSER} WITH PASSWORD '${PGPASS}';
  END IF;
END
\$\$;
SELECT 'CREATE DATABASE ${PGDB} OWNER ${PGUSER}'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${PGDB}')\gexec
GRANT ALL PRIVILEGES ON DATABASE ${PGDB} TO ${PGUSER};
SQL

# Local trust for bootstrap
if [[ -f "${PG_HBA}" ]] && ! grep -q "host.*${PGDB}.*${PGUSER}.*127.0.0.1" "${PG_HBA}"; then
  echo "host    ${PGDB}    ${PGUSER}    127.0.0.1/32    scram-sha-256" | ${SUDO} tee -a "${PG_HBA}" >/dev/null
  echo "host    ${PGDB}    ${PGUSER}    ::1/128         scram-sha-256" | ${SUDO} tee -a "${PG_HBA}" >/dev/null
  ${SUDO} systemctl reload postgresql
fi

export PGPASSWORD="${PGPASS}"

log "5/6 — clone repo + init schemas"
if [[ "${SKIP_CLONE}" -eq 0 ]]; then
  if [[ ! -d "${REPO_DIR}/.git" ]]; then
    git clone "${REPO_URL}" "${REPO_DIR}"
  else
    echo "Repo already exists: ${REPO_DIR}"
  fi
fi

if [[ ! -d "${REPO_DIR}/docker/postgres/init" ]]; then
  echo "Repo not found at ${REPO_DIR} — clone first or omit --skip-clone" >&2
  exit 1
fi

cd "${REPO_DIR}"

for sql_file in docker/postgres/init/*.sql; do
  echo "  -> $(basename "${sql_file}")"
  psql -h localhost -U "${PGUSER}" -d "${PGDB}" -v ON_ERROR_STOP=1 -f "${sql_file}"
done

log "Python venv (ingestion)"
if [[ ! -x .venv-ingest/bin/python ]]; then
  python3 -m venv .venv-ingest
  .venv-ingest/bin/pip install -q --upgrade pip
  .venv-ingest/bin/pip install -q -r ingestion/requirements.txt
else
  echo ".venv-ingest already exists"
fi

if [[ ! -f .env ]]; then
  cp .env.example .env
  sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${PGPASS}/" .env
  sed -i 's/^POSTGRES_HOST=.*/POSTGRES_HOST=localhost/' .env
  sed -i 's/^POSTGRES_HOST_LOCAL=.*/POSTGRES_HOST_LOCAL=localhost/' .env
  echo ""
  echo "Created .env with POSTGRES_PASSWORD=${PGPASS}"
fi

log "6/6 — verify"
export PGPASSWORD="${PGPASS}"
pg_isready -h localhost -U "${PGUSER}" -d "${PGDB}"
psql -h localhost -U "${PGUSER}" -d "${PGDB}" -c '\dn'

cat <<EOF

Bootstrap complete.

Postgres: localhost:5432  user=${PGUSER}  db=${PGDB}
Repo:     ${REPO_DIR}

Next (Day 8):
  1. From Mac — rsync 2025 raw files (Option C):
     rsync -avz --progress data/raw/bts/*_2025_*.zip ubuntu@<VM_IP>:${REPO_DIR}/data/raw/bts/
     rsync -avz --progress data/raw/weather/weather_*_2025_*.csv ubuntu@<VM_IP>:${REPO_DIR}/data/raw/weather/
  2. On VM — load raw:
     cd ${REPO_DIR}
     .venv-ingest/bin/python -m ingestion.bts.backfill --start-year 2025 --end-year 2025 --end-month 12 --no-download
     .venv-ingest/bin/python -m ingestion.weather.backfill --start-year 2025 --end-year 2025 --end-month 12 --no-download
  3. Preflight:
     bash scripts/check_full_materialization_ready.sh --stage 2025

Terminate VM when done (Day 13) to avoid any charges.
EOF
