#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ ! -f .env ]]; then
  echo "No .env found. Run: cp .env.example .env && bash scripts/generate_fernet_key.sh"
  exit 1
fi

# macOS/Linux: set AIRFLOW_UID to your user id if scheduler has permission errors
if ! grep -q "^AIRFLOW_UID=" .env || grep -q "^AIRFLOW_UID=50000" .env; then
  echo "Tip: if Airflow logs show permission errors, set AIRFLOW_UID=$(id -u) in .env"
fi

if grep -q "^AIRFLOW__CORE__FERNET_KEY=$" .env || ! grep -q "^AIRFLOW__CORE__FERNET_KEY=" .env; then
  echo "Generating Fernet key..."
  bash scripts/generate_fernet_key.sh
fi

mkdir -p airflow/logs data/samples

echo "Starting Docker stack (first run builds Airflow image — may take several minutes)..."
docker compose up -d --build

echo ""
echo "Waiting for Postgres..."
until docker compose exec -T postgres pg_isready -U "${POSTGRES_USER:-aerodelay}" -d "${POSTGRES_DB:-aerodelay}" >/dev/null 2>&1; do
  sleep 2
done
echo "Postgres is ready."

echo ""
echo "Stack started. Run: bash scripts/check_stack.sh"
