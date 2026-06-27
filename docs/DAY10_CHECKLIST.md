# Week 2 Day 10 — Scheduled departure UTC

## Files created / updated

| Path | Purpose |
|------|---------|
| `dbt/models/intermediate/int_flights__departure_context.sql` | Scheduled dep local + UTC (part 1) |
| `dbt/models/intermediate/_intermediate.yml` | Model tests |
| `dbt/tests/assert_int_flights_row_count_matches_staging.sql` | Row count parity test |

## Model logic

```
stg_bts__flights
  → join dim_airports on origin
  → crs_dep_time_hhmm (raw BTS HHMM string)
  → crs_dep_time_local (parsed local timestamp)
  → crs_dep_time_utc   (UTC timestamptz via origin IANA timezone)
```

Day 11 adds actual departure fallback and `dep_time_utc` for weather joins.

## Your manual steps

### 1. Build intermediate flight model

```bash
bash scripts/dbt_run.sh run --select int_flights__departure_context
bash scripts/dbt_run.sh test --select int_flights__departure_context assert_int_flights_row_count_matches_staging
```

Or:

```bash
make dbt-run
make dbt-test
```

### 2. Spot-check row counts and ATL sample

```bash
docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT COUNT(*) FROM intermediate.int_flights__departure_context;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT COUNT(*) FROM intermediate.int_flights__departure_context WHERE crs_dep_time_utc IS NULL AND NOT is_cancelled;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT origin, crs_dep_time_hhmm, crs_dep_time_local, crs_dep_time_utc, origin_timezone
   FROM intermediate.int_flights__departure_context
   WHERE origin = 'ATL' AND flight_date = '2025-01-15'
   ORDER BY crs_dep_time_local LIMIT 10;"
```

Expected: ~1.69M rows; ATL Jan 2025 flights show EST offset (~5 hours to UTC).

## Day 10 exit criteria

- [ ] Model builds on ~1.69M rows without error
- [ ] Row count matches `stg_bts__flights`
- [ ] `crs_dep_time_utc` populated for non-cancelled flights with valid scheduled dep
- [ ] ATL sample shows correct local → UTC conversion
- [ ] dbt tests pass

## Commit (you only — after tests pass)

```bash
git add dbt/models/intermediate/int_flights__departure_context.sql \
        dbt/models/intermediate/_intermediate.yml \
        dbt/tests/assert_int_flights_row_count_matches_staging.sql \
        docs/DAY10_CHECKLIST.md
git commit -m "Add int_flights__departure_context with scheduled departure UTC"
git push
```

## Day 11 preview

Add actual departure fallback, `dep_time_utc`, and `dep_time_source` for weather joins.
