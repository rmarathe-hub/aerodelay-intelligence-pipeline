#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

echo "=== Airflow DAGs ==="
docker compose exec -T airflow-webserver airflow dags list 2>/dev/null | grep -E "ingest_weather|dag_id" || true

echo ""
echo "=== DAG import errors ==="
docker compose exec -T airflow-webserver airflow dags list-import-errors 2>/dev/null || true

echo ""
echo "=== ingest_weather task ==="
docker compose exec -T airflow-webserver airflow tasks list ingest_weather 2>/dev/null || true
