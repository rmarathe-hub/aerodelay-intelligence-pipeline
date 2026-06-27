# Week 2 Day 8 — Intermediate scaffold + airport timezones

## Files created / updated

| Path | Purpose |
|------|---------|
| `docker/postgres/init/03_intermediate_schema.sql` | `intermediate` schema (new installs) |
| `dbt/seeds/airport_timezones.csv` | IANA timezone per airport |
| `dbt/seeds/airports_45.csv` | dbt copy of `docs/airports_45.csv` |
| `dbt/seeds/airport_station_map.csv` | dbt copy of `docs/airport_station_map.csv` |
| `dbt/seeds/_seeds.yml` | Seed tests |
| `dbt/models/intermediate/dim_airports.sql` | Airport dimension with timezone + weather station |
| `dbt/models/intermediate/_intermediate.yml` | Model tests |
| `dbt/macros/generate_schema_name.sql` | Use `intermediate` schema without prefix |
| `dbt/tests/assert_all_flight_origins_in_dim_airports.sql` | Coverage test |
| `dbt/tests/assert_all_weather_stations_in_dim_airports.sql` | Coverage test |
| `dbt/dbt_project.yml` | Intermediate + seed schema config |

Canonical reference CSVs remain in `docs/`; dbt seeds are copies for warehouse loading.

## Your manual steps

### 1. Ensure `intermediate` schema exists (existing Postgres volumes)

```bash
docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "CREATE SCHEMA IF NOT EXISTS intermediate;"
```

### 2. Load seeds and build dim_airports

```bash
make dbt-seed
make dbt-run
make dbt-test
```

Or:

```bash
bash scripts/dbt_run.sh seed
bash scripts/dbt_run.sh run --select intermediate+
bash scripts/dbt_run.sh test
```

### 3. Spot-check

```bash
docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT COUNT(*) FROM intermediate.dim_airports;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT airport_code, timezone, weather_station_id FROM intermediate.dim_airports ORDER BY 1 LIMIT 10;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT airport_code, timezone FROM intermediate.dim_airports WHERE airport_code IN ('ATL','DEN','LAX','ORD');"
```

## Day 8 exit criteria

- [ ] `intermediate` schema exists in Postgres
- [ ] `dbt seed` loads 45 airport timezone rows
- [ ] `dim_airports` has 45 rows, no null timezones
- [ ] All loaded weather stations (ATL, ORD, LAX, DEN) present in dim
- [ ] All flight origins in staging map to dim_airports
- [ ] dbt tests pass

## Timezone notes

- BTS departure/arrival times are **local to the airport**; `timezone` is IANA (e.g. `America/New_York`).
- Arizona (PHX) uses `America/Phoenix` (no DST).
- Indianapolis (IND) uses `America/Indiana/Indianapolis`.
- Honolulu (HNL) uses `Pacific/Honolulu`.

## Commit (you only — after tests pass)

```bash
git add docker/postgres/init/03_intermediate_schema.sql dbt/ docs/DAY8_CHECKLIST.md Makefile
git commit -m "Add airport timezone seed and dim_airports intermediate model"
git push
```

## Day 9 preview

BTS HHMM parsing macros (`bts_time_to_timestamp`, `bts_time_to_utc`).
