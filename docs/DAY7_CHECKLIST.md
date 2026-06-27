# Week 1 Day 7 — dbt staging models

## Files created / updated

| Path | Purpose |
|------|---------|
| `dbt/dbt_project.yml` | dbt project config |
| `dbt/profiles.yml` | Postgres connection (reads `.env`) |
| `dbt/packages.yml` | `dbt_utils` for composite uniqueness tests |
| `dbt/models/staging/stg_bts__flights.sql` | Typed BTS flights + `flight_id` |
| `dbt/models/staging/stg_weather__observations.sql` | Typed weather + dedupe on `(station, valid_utc)` |
| `dbt/models/staging/_sources.yml` | `raw.*` source definitions |
| `dbt/models/staging/_staging.yml` | Column tests |
| `dbt/macros/clean_raw_values.sql` | Handle `M` / `T` missing values |
| `dbt/requirements.txt` | `dbt-postgres` |
| `scripts/dbt_run.sh` | Wrapper loading `.env` |
| `docker/postgres/init/02_staging_schema.sql` | `staging` schema (new installs) |

## Your manual steps

### 1. Install dbt (one time)

```bash
cd /Users/rohitmarathe/AeroDelay_Intel_Pipeline
python -m pip install -r dbt/requirements.txt
```

### 2. Ensure `staging` schema exists (existing Postgres volumes)

```bash
docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "CREATE SCHEMA IF NOT EXISTS staging;"
```

### 3. Install dbt packages and build staging views

```bash
bash scripts/dbt_run.sh deps
bash scripts/dbt_run.sh run
bash scripts/dbt_run.sh test
```

Or with Make:

```bash
make dbt-deps
make dbt-run
make dbt-test
```

### 4. Spot-check staging output

```bash
docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT COUNT(*) FROM staging.stg_bts__flights;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT COUNT(*) FROM staging.stg_weather__observations;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT station, COUNT(*) FROM staging.stg_weather__observations GROUP BY 1 ORDER BY 2 DESC LIMIT 5;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT is_cancelled, COUNT(*) FROM staging.stg_bts__flights GROUP BY 1;"
```

## Day 7 exit criteria

- [ ] `dbt deps` and `dbt run` succeed
- [ ] `staging.stg_bts__flights` view exists with typed columns
- [ ] `staging.stg_weather__observations` view exists with `valid_utc` timestamptz
- [ ] `dbt test` passes (unique `flight_id`, unique `station`+`valid_utc`)
- [ ] Cancelled flights have null delay fields in staging

## Current local coverage (verified)

dbt staging runs against **partial dev data**:

| Model | Expected local scale |
|-------|---------------------|
| `staging.stg_bts__flights` | ~1.69M rows (2025-01 → 2025-04) |
| `staging.stg_weather__observations` | ~19.6K rows (4 station-months) |

Full 2023–2025 backfills are **not required** before intermediate models. See [`DATA_COVERAGE.md`](DATA_COVERAGE.md).

## Staging rules implemented

**Flights (`stg_bts__flights`):**
- Cast raw TEXT → proper types
- `is_cancelled`, `is_diverted` boolean flags
- Delay fields nulled when cancelled
- `flight_id` = MD5 of airline + flight number + origin + date + scheduled dep

**Weather (`stg_weather__observations`):**
- `valid` → `valid_utc` timestamptz
- `M` → NULL, `T` → 0 for precipitation
- Dedupe: latest `loaded_at` wins per `(station, valid_utc)`

## Commit (you only — after tests pass)

```bash
git add dbt/ scripts/dbt_run.sh docker/postgres/init/02_staging_schema.sql \
        docs/DAY7_CHECKLIST.md Makefile
git commit -m "Add dbt staging models for BTS flights and weather observations"
git push
```

## Week 2 preview

Intermediate models: flight departure context (UTC times) and weather join prep.  
Partial local data (documented in [`DATA_COVERAGE.md`](DATA_COVERAGE.md)) is sufficient to begin.
