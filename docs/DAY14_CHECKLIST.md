# Week 2 Day 14 — Integration, documentation, Week 2 exit

## Goal

Run the full intermediate layer, document join rules for Week 3, and confirm the pipeline is ready to proceed.

---

## Files created / updated

| Path | Purpose |
|------|---------|
| `docs/weather_join_methodology.md` | Draft nearest-obs join rules, tie-breaks, time window |
| `docs/DAY14_CHECKLIST.md` | Week 2 exit checklist (this file) |
| `docs/DATA_COVERAGE.md` | Intermediate model row counts added |
| `Makefile` | `dbt-run-intermediate` target |

---

## Your manual steps

### 1. Full intermediate run + tests

```bash
make dbt-run-intermediate
make dbt-test
```

Or rebuild everything including seeds:

```bash
make dbt-seed
make dbt-run
make dbt-test
```

### 2. Spot-checks

```bash
docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT COUNT(*) FROM intermediate.int_flights__departure_context;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT dep_time_source, COUNT(*) FROM intermediate.int_flights__departure_context GROUP BY 1;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT airport_code, COUNT(*) FROM intermediate.int_weather__observations_enriched GROUP BY 1 ORDER BY 1;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT COUNT(*) FROM intermediate.dim_airports;"
```

### 3. Review methodology doc

Read `docs/weather_join_methodology.md` — confirms Week 3 join approach (nearest obs within ±2h, prefer obs at/before departure).

---

## Week 2 exit criteria

- [x] `int_flights__departure_context` — 1,686,378 rows, `dep_time_utc` 100% populated
- [x] `int_weather__observations_enriched` — 19,600 rows, airport codes present
- [x] `dim_airports` — 45 rows with IANA timezones
- [x] All dbt tests pass (**40/40**)
- [x] Join feasibility analyses confirm data overlap on dev subset (Day 13, ≥95% per airport)
- [x] `weather_join_methodology.md` draft exists for Week 3

---

## Week 2 deliverables summary

| Layer | Models |
|-------|--------|
| Seeds | `airports_45`, `airport_timezones`, `airport_station_map` |
| Intermediate | `dim_airports`, `int_flights__departure_context`, `int_weather__observations_enriched` |
| Macros | BTS HHMM → local/UTC timestamps |
| Analyses | Join feasibility (ATL/DEN + all-station coverage + dep time distribution) |
| Docs | `weather_join_methodology.md`, `DATA_COVERAGE.md`, Day 8–14 checklists |

---

## Commit (you only — after review)

```bash
git add docs/weather_join_methodology.md \
        docs/DAY14_CHECKLIST.md \
        docs/DATA_COVERAGE.md \
        Makefile

git commit -m "Document weather join methodology and complete Week 2 intermediate layer"
git push
```

If Day 14 is bundled with the earlier uncommitted Week 2 work, use the combined commit from `docs/DAY13_CHECKLIST.md` instead.

---

## Week 3 preview

- `int_flights__weather_at_departure` — nearest ASOS observation join per `weather_join_methodology.md`
- Tie-break: prefer observation at or before departure
- Begin marts / fact table layer
