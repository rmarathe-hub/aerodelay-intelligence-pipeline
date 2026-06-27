.PHONY: up down logs ps check shell-postgres fernet env ingest-deps load-bts-sample test-bts-idempotency backfill-bts verify-ingest-bts-dag load-weather-sample test-weather-idempotency verify-ingest-weather-dag backfill-weather dbt-deps dbt-seed dbt-run dbt-test

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

dbt-test:
	bash scripts/dbt_run.sh test
