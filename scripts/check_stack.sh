#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

source .env 2>/dev/null || true
PGUSER="${POSTGRES_USER:-aerodelay}"
PGDB="${POSTGRES_DB:-aerodelay}"

echo "=== Docker services ==="
docker compose ps

echo ""
echo "=== Postgres schemas (raw, meta) ==="
docker compose exec -T postgres psql -U "${PGUSER}" -d "${PGDB}" -c "\dn"

echo ""
echo "=== Airflow webserver health ==="
if curl -sf http://localhost:8080/health >/dev/null 2>&1; then
  echo "OK — http://localhost:8080 (login: admin / admin)"
else
  echo "Not ready yet — wait 1–2 min after first start, then retry"
fi

echo ""
echo "=== Connect from host ==="
echo "  psql postgresql://${PGUSER}:<password>@localhost:5432/${PGDB}"
echo "  Or: docker compose exec postgres psql -U ${PGUSER} -d ${PGDB}"
