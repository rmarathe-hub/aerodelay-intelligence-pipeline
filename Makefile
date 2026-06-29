.PHONY: up down logs ps check shell-postgres fernet env ingest-deps load-bts-sample test-bts-idempotency backfill-bts verify-ingest-bts-dag load-weather-sample test-weather-idempotency verify-ingest-weather-dag backfill-weather inventory-mac-data check-materialization-ready materialize-monthly materialize-downstream validate-full-materialization materialize-full-local materialize-2025-local materialize-q1-2025-local dbt-deps dbt-seed dbt-run dbt-run-intermediate dbt-run-marts dbt-test dbt-bulletproof-jan2025 dbt-docs dashboard-deps dashboard export-dashboard-demo verify-dashboard-cloud ci-setup-postgres ci-load-jan2025 ci-dbt-test-jan2025 ml-deps ml-extract ml-eda ml-cv ml-tune ml-ablation train-delay-model-day1 ml-train-final ml-evaluate export-ml-demo train-delay-model-day2

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

inventory-mac-data:
	bash scripts/inventory_mac_data.sh

check-materialization-ready:
	bash scripts/check_full_materialization_ready.sh

check-materialization-ready-monthly:
	bash scripts/check_full_materialization_ready.sh --mode monthly --allow-local --stage full

materialize-monthly:
	bash scripts/materialize_monthly.sh

materialize-downstream:
	bash scripts/materialize_downstream.sh

validate-full-materialization:
	bash scripts/validate_full_materialization.sh

materialize-full-local:
	bash scripts/check_full_materialization_ready.sh --mode monthly --allow-local --stage full
	bash scripts/materialize_monthly.sh
	bash scripts/materialize_downstream.sh
	bash scripts/validate_full_materialization.sh

materialize-2025-local:
	bash scripts/materialize_monthly.sh --start 2025-01 --end 2025-12 --fresh
	bash scripts/materialize_downstream.sh
	bash scripts/validate_full_materialization.sh

materialize-q1-2025-local:
	bash scripts/materialize_monthly.sh --start 2025-01 --end 2025-03 --fresh
	bash scripts/materialize_downstream.sh
	bash scripts/validate_full_materialization.sh

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

dbt-docs:
	bash scripts/dbt_docs_generate.sh

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

ml-deps:
	@if [[ ! -x .venv-ml/bin/python ]]; then \
		python3 -m venv .venv-ml && \
		.venv-ml/bin/pip install -q --upgrade pip && \
		.venv-ml/bin/pip install -q -r ml/requirements.txt; \
	fi
	@echo "ML venv ready: .venv-ml"

ml-extract: ml-deps
	PYTHONPATH=. .venv-ml/bin/python ml/extract.py

ml-eda: ml-deps
	PYTHONPATH=. .venv-ml/bin/python ml/eda.py

ml-cv: ml-deps
	PYTHONPATH=. .venv-ml/bin/python ml/cv.py

ml-tune: ml-deps
	PYTHONPATH=. .venv-ml/bin/python ml/tune.py

ml-ablation: ml-deps
	PYTHONPATH=. .venv-ml/bin/python ml/ablation.py

train-delay-model-day1: ml-deps
	bash scripts/train_delay_model_day1.sh

ml-train-final: ml-deps
	PYTHONPATH=. .venv-ml/bin/python ml/train.py

ml-evaluate: ml-deps
	PYTHONPATH=. .venv-ml/bin/python ml/evaluate.py

export-ml-demo:
	bash scripts/export_ml_demo.sh

train-delay-model-day2: ml-deps
	bash scripts/train_delay_model_day2.sh
