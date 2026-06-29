.PHONY: up down logs ps check shell-postgres fernet env ingest-deps load-bts-sample test-bts-idempotency backfill-bts verify-ingest-bts-dag load-weather-sample test-weather-idempotency verify-ingest-weather-dag backfill-weather dbt-deps dbt-seed dbt-run dbt-run-intermediate dbt-run-marts dbt-test dbt-bulletproof-jan2025 dashboard-deps dashboard export-dashboard-demo verify-dashboard-cloud ci-setup-postgres ci-load-jan2025 ci-dbt-test-jan2025

up:
	bash scripts/dev_up.sh

down:
	docker compose down

logs:
	docker compose logs -f

ps:
	docker compose ps

check:
	bash scripts/check_stack.sh

shell-postgres:
	docker compose exec postgres psql -U $$(grep POSTGRES_USER .env | cut -d= -f2) -d $$(grep POSTGRES_DB .env | cut -d= -f2)

fernet:
	bash scripts/generate_fernet_key.sh

env:
	cp -n .env.example .env || true
	@echo "Edit .env — set POSTGRES_PASSWORD, then run: make fernet"

ingest-deps:
	python -m pip install -r ingestion/requirements.txt

load-bts-sample:
	bash scripts/load_bts_sample.sh

test-bts-idempotency:
	bash scripts/test_bts_idempotency.sh

backfill-bts:
	bash scripts/backfill_bts.sh

verify-ingest-bts-dag:
	bash scripts/verify_ingest_bts_dag.sh

load-weather-sample:
	bash scripts/load_weather_sample.sh

test-weather-idempotency:
	bash scripts/test_weather_idempotency.sh

verify-ingest-weather-dag:
	bash scripts/verify_ingest_weather_dag.sh

backfill-weather:
	bash scripts/backfill_weather.sh

dbt-deps:
	bash scripts/dbt_run.sh deps

dbt-seed:
	bash scripts/dbt_run.sh seed

dbt-run:
	bash scripts/dbt_run.sh run

dbt-run-intermediate:
	bash scripts/dbt_run.sh run --select intermediate+

dbt-run-marts:
	bash scripts/dbt_run.sh run --select marts+

dbt-test:
	bash scripts/dbt_run.sh test

dbt-bulletproof-jan2025:
	bash scripts/bulletproof_jan2025.sh

dashboard-deps:
	@if [[ ! -x .venv-dashboard/bin/streamlit ]]; then \
		python3 -m venv .venv-dashboard && \
		.venv-dashboard/bin/pip install -q --upgrade pip && \
		.venv-dashboard/bin/pip install -q -r dashboard/requirements.txt; \
	fi
	@echo "Dashboard venv ready: .venv-dashboard"

dashboard:
	bash scripts/run_dashboard.sh

export-dashboard-demo:
	bash scripts/export_dashboard_demo.sh

verify-dashboard-cloud:
	bash scripts/verify_dashboard_cloud.sh

ci-setup-postgres:
	bash scripts/ci_setup_postgres.sh

ci-load-jan2025:
	bash scripts/ci_load_jan2025_sample.sh

ci-dbt-test-jan2025:
	bash scripts/ci_dbt_test_jan2025.sh
