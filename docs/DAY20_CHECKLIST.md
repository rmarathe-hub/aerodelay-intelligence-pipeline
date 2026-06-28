# Week 3 Day 20 — Integration + documentation

## Files updated

| Path | Purpose |
|------|---------|
| `docs/weather_join_methodology.md` | Draft → Implemented |
| `docs/DATA_COVERAGE.md` | Join + marts row counts, match rates |
| `Makefile` | `dbt-run-marts` target |
| `docs/DAY20_CHECKLIST.md` | This checklist |

## Your manual steps

### 1. Full pipeline run

```bash
make dbt-run
make dbt-test
```

Or layer by layer:

```bash
make dbt-run-intermediate
make dbt-run-marts
make dbt-test
```

### 2. Spot-checks

```bash
docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT COUNT(*) FROM intermediate.int_flights__weather_at_departure;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT weather_match_status, COUNT(*) FROM intermediate.int_flights__weather_at_departure GROUP BY 1;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT COUNT(*) FROM marts.fct_flights;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT origin, year_month, COUNT(*) AS flights,
          COUNT(*) FILTER (WHERE has_departure_weather) AS matched
   FROM marts.fct_flights
   WHERE (origin IN ('ATL','ORD','LAX') AND year_month = '2025-01')
      OR (origin = 'DEN' AND year_month = '2025-02')
   GROUP BY 1, 2 ORDER BY 1, 2;"
```

## Day 20 exit criteria

- [x] Full `make dbt-run` + `make dbt-test` pass (**7 models, 71/71 tests**)
- [x] `DATA_COVERAGE.md` reflects join + marts state
- [x] `weather_join_methodology.md` marked implemented
- [x] Match rates on loaded months documented in coverage doc

## Commit (you only — after review)

```bash
git add docs/weather_join_methodology.md \
        docs/DATA_COVERAGE.md \
        Makefile \
        docs/DAY20_CHECKLIST.md
git commit -m "Finalize weather join methodology and update data coverage docs"
git push
```

## Day 21 preview

Week 3 exit review and handoff to Week 4.
