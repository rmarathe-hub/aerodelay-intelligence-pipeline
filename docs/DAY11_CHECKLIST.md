# Week 2 Day 11 — Actual departure fallback + flight tests

## Files created / updated

| Path | Purpose |
|------|---------|
| `dbt/models/intermediate/int_flights__departure_context.sql` | Actual dep + `dep_time_utc` / `dep_time_source` |
| `dbt/models/intermediate/_intermediate.yml` | `dep_time_source` accepted_values test |
| `dbt/tests/assert_dep_time_utc_coverage.sql` | ≥99% `dep_time_utc` populated |
| `dbt/tests/assert_cancelled_flights_null_dep_delay.sql` | Cancelled flights keep null delays |

## Departure time logic (weather join)

| Condition | `dep_time_utc` | `dep_time_source` |
|-----------|----------------|-------------------|
| Not cancelled + actual dep parses | actual dep UTC | `actual` |
| Otherwise (incl. cancelled) | scheduled dep UTC | `scheduled` |

Also added: `dep_time_local`, `actual_dep_time_utc`, arrival local/UTC fields (`crs_arr_*`, `arr_*`) using dest timezone.

## Your manual steps

### 1. Rebuild model and test

```bash
bash scripts/dbt_run.sh run --select int_flights__departure_context
bash scripts/dbt_run.sh test --select int_flights__departure_context assert_dep_time_utc_coverage assert_cancelled_flights_null_dep_delay assert_int_flights_row_count_matches_staging
```

### 2. Spot-check

```bash
docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT dep_time_source, COUNT(*) FROM intermediate.int_flights__departure_context GROUP BY 1;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT COUNT(*) AS total,
          COUNT(*) FILTER (WHERE dep_time_utc IS NULL) AS null_dep_time_utc
   FROM intermediate.int_flights__departure_context;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT is_cancelled, dep_time_source, COUNT(*)
   FROM intermediate.int_flights__departure_context
   GROUP BY 1, 2 ORDER BY 1, 2;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT origin, dep_time_hhmm, dep_time_local, dep_time_utc, dep_time_source, crs_dep_time_utc
   FROM intermediate.int_flights__departure_context
   WHERE origin = 'ATL' AND NOT is_cancelled AND dep_time_source = 'actual'
   LIMIT 5;"
```

## Day 11 exit criteria

- [x] `dep_time_utc` populated for ≥99% of rows (100% — 1,686,378 / 1,686,378)
- [x] `dep_time_source` is `actual` or `scheduled` only
- [x] Cancelled flights: delays null, `dep_time_source` = `scheduled` (25,191 cancelled → all `scheduled`)
- [x] Row count matches staging (~1.69M)
- [x] dbt tests pass (10/10)

## Commit (you only — after tests pass)

```bash
git add dbt/models/intermediate/int_flights__departure_context.sql \
        dbt/models/intermediate/_intermediate.yml \
        dbt/tests/assert_dep_time_utc_coverage.sql \
        dbt/tests/assert_cancelled_flights_null_dep_delay.sql \
        docs/DAY11_CHECKLIST.md
git commit -m "Complete departure context with actual/scheduled dep_time_utc fallback"
git push
```

## Day 12 preview

`int_weather__observations_enriched` — weather observations with airport codes.
