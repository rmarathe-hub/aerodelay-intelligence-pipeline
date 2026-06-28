# Week 3 Day 19 — Features, delay labels, and modeling grain

## Files updated

| Path | Purpose |
|------|---------|
| `dbt/models/marts/fct_flights.sql` | Time features, extended weather, modeling flags |
| `dbt/models/marts/_marts.yml` | Column docs + tests |
| `dbt/tests/assert_fct_cancelled_not_analysis_eligible.sql` | Cancelled/diverted not eligible |
| `dbt/tests/assert_fct_has_departure_weather_consistent.sql` | Weather flag matches status |
| `dbt/tests/assert_fct_cancelled_null_dep_delay.sql` | Cancelled keep null delays |
| `docs/DAY19_CHECKLIST.md` | This checklist |

## Modeling grain

| Flag | Rule | Use |
|------|------|-----|
| `is_analysis_eligible` | `not is_cancelled and not is_diverted` | Primary modeling / delay-rate grain |
| `has_departure_weather` | `weather_match_status = 'matched'` | Weather-conditioned analysis |

All flights remain in the table; filter by flags instead of dropping rows.

## Time features

| Column | Definition |
|--------|------------|
| `dep_hour_utc` | Hour 0–23 from `dep_time_utc` |
| `dep_dow` | ISO day of week: 1=Monday … 7=Sunday |
| `dep_month` | Month 1–12 from `dep_time_utc` |

## Your manual steps

```bash
bash scripts/dbt_run.sh run --select fct_flights
bash scripts/dbt_run.sh test --select fct_flights assert_fct_cancelled_not_analysis_eligible assert_fct_has_departure_weather_consistent assert_fct_cancelled_null_dep_delay assert_fct_flights_row_count

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT is_analysis_eligible, has_departure_weather, COUNT(*)
   FROM marts.fct_flights GROUP BY 1, 2 ORDER BY 1, 2;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT dep_hour_utc, ROUND(AVG(is_dep_delay_15_plus::int)::numeric, 3) AS delay_rate
   FROM marts.fct_flights
   WHERE origin = 'ATL' AND year_month = '2025-01' AND is_analysis_eligible
   GROUP BY 1 ORDER BY 1 LIMIT 5;"
```

## Day 19 exit criteria

- [x] Time features populated for all rows with `dep_time_utc` (dep_hour_utc, dep_dow, dep_month not null)
- [x] `is_analysis_eligible` and `has_departure_weather` documented in `_marts.yml`
- [x] Cancelled/diverted flights excluded from analysis grain by flag (25,191 cancelled + 1,930 diverted ineligible rows retained)
- [x] dbt tests pass (**23/23**)

### Modeling grain counts

| is_analysis_eligible | has_departure_weather | Count |
|----------------------|-----------------------|-------|
| false | false | 26,973 |
| false | true | 2,148 |
| true | false | 1,579,070 |
| true | true | 78,187 |

## Commit (you only — after tests pass)

```bash
git add dbt/models/marts/fct_flights.sql \
        dbt/models/marts/_marts.yml \
        dbt/tests/assert_fct_cancelled_not_analysis_eligible.sql \
        dbt/tests/assert_fct_has_departure_weather_consistent.sql \
        dbt/tests/assert_fct_cancelled_null_dep_delay.sql \
        docs/DAY19_CHECKLIST.md
git commit -m "Add delay labels, time features, and modeling flags to fct_flights"
git push
```

## Day 20 preview

Full pipeline run, `DATA_COVERAGE.md`, finalize methodology, `dbt-run-marts` Makefile target.
