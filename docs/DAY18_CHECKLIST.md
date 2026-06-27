# Week 3 Day 18 — Marts scaffold + base fact table

## Files created / updated

| Path | Purpose |
|------|---------|
| `docker/postgres/init/04_marts_schema.sql` | `marts` schema (new installs) |
| `dbt/dbt_project.yml` | `marts:` config block |
| `dbt/models/marts/fct_flights.sql` | One row per flight — core columns |
| `dbt/models/marts/_marts.yml` | Model docs + grain tests |
| `dbt/tests/assert_fct_flights_row_count.sql` | Row count = weather join model |
| `docs/DAY18_CHECKLIST.md` | This checklist |

## Existing database: create marts schema once

If Postgres was started before Day 18 init SQL existed:

```bash
docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "CREATE SCHEMA IF NOT EXISTS marts;"
```

## Your manual steps

### 1. Build and test

```bash
bash scripts/dbt_run.sh run --select fct_flights
bash scripts/dbt_run.sh test --select fct_flights assert_fct_flights_row_count
```

### 2. Spot-check

```bash
docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT COUNT(*) FROM marts.fct_flights;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT weather_match_status, COUNT(*) FROM marts.fct_flights GROUP BY 1;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT flight_id, origin, dep_time_utc, weather_match_status, temperature_f
   FROM marts.fct_flights
   WHERE origin = 'ATL' AND weather_match_status = 'matched'
   LIMIT 3;"
```

## Day 18 exit criteria

- [x] `marts` schema exists in Postgres
- [x] `fct_flights` builds (1,686,378 rows)
- [x] `flight_id` unique; row count matches join model
- [x] dbt marts tests pass (**14/14**)

## Commit (you only — after tests pass)

```bash
git add docker/postgres/init/04_marts_schema.sql \
        dbt/dbt_project.yml \
        dbt/models/marts/fct_flights.sql \
        dbt/models/marts/_marts.yml \
        dbt/tests/assert_fct_flights_row_count.sql \
        docs/DAY18_CHECKLIST.md
git commit -m "Add marts schema and base fct_flights fact table"
git push
```

## Day 19 preview

Time features, extended weather columns, `is_analysis_eligible`, `has_departure_weather`.
