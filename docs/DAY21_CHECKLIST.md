# Week 3 Day 21 — Exit review

## Goal

Confirm Week 3 deliverables are complete and the project is ready for Week 4 aggregations / analysis.

---

## Week 3 deliverables

| Day | Deliverable |
|-----|-------------|
| 15 | `int_flights__weather_at_departure` (nearest-obs join) |
| 16 | Join tests + scoped coverage (loaded station-months only) |
| 17 | Validation analyses (coverage, lag, unmatched) |
| 18 | `marts` schema + base `fct_flights` |
| 19 | Time features, extended weather, modeling flags |
| 20 | Full integration, `weather_join_methodology.md`, `DATA_COVERAGE.md` |
| 21 | This exit checklist |

### Models

| Layer | Model |
|-------|-------|
| Intermediate | `int_flights__weather_at_departure` |
| Marts | `fct_flights` |

### Tests

- Join grain, window, row count
- Scoped coverage (≥90% on loaded station-months only)
- Fact table grain + modeling flag consistency

### Analyses

- `dbt/analyses/weather_join_coverage.sql`
- `dbt/analyses/weather_obs_lag_distribution.sql`
- `dbt/analyses/weather_join_unmatched.sql`

### Docs

- `docs/weather_join_methodology.md` (implemented)
- `docs/DATA_COVERAGE.md` (join + marts counts)
- `docs/DAY15_CHECKLIST.md` through `docs/DAY21_CHECKLIST.md`

---

## Final verification

```bash
make dbt-run
make dbt-test
```

Layer targets:

```bash
make dbt-run-intermediate
make dbt-run-marts
```

---

## Week 3 exit criteria

- [x] `int_flights__weather_at_departure` — 1,686,378 rows, one per flight
- [x] Match rate ≥90% on **loaded weather station-months only** (all four ≥95%)
- [x] Global all-flight match rate documented (4.76%); **not** gated until full weather backfill
- [x] `marts.fct_flights` — 1,686,378 rows with weather, delay, and feature columns
- [x] All dbt tests pass (**71/71** — staging + intermediate + marts)
- [x] Join lag/coverage documented in analyses + `DATA_COVERAGE.md`
- [x] `weather_join_methodology.md` finalized (implemented)

---

## Verified results

### Pipeline

| Check | Result |
|-------|--------|
| dbt models | 7 (2 staging, 4 intermediate, 1 marts) — **PASS** |
| dbt tests | **71/71 PASS** (verified 2026-06-28) |

### Join model

| Metric | Value |
|--------|-------|
| `int_flights__weather_at_departure` rows | 1,686,378 |
| Global matched | 80,335 (4.76%) |
| Global unmatched | 1,606,043 (95.24%) |

### Loaded station-month match rates (gated)

| Origin | Month | Match % |
|--------|-------|---------|
| ATL | 2025-01 | 95.99% |
| ORD | 2025-01 | 96.21% |
| LAX | 2025-01 | 95.80% |
| DEN | 2025-02 | 95.23% |

Nearest-obs equals Day 13 feasibility (0% delta). See `docs/DAY17_CHECKLIST.md`.

### Marts (`fct_flights`)

| Metric | Value |
|--------|-------|
| Total rows | 1,686,378 |
| `is_analysis_eligible` + `has_departure_weather` | 78,187 |

Modeling grain: filter `is_analysis_eligible = true` for delay analysis; add `has_departure_weather = true` for weather-conditioned work.

---

## Commit (you only — Week 3 wrap-up)

If not already committed per-day, one Week 3 commit:

```bash
git add dbt/models/intermediate/int_flights__weather_at_departure.sql \
        dbt/models/marts/ \
        dbt/tests/assert_weather_join_*.sql \
        dbt/tests/assert_fct_*.sql \
        dbt/analyses/weather_join_*.sql \
        dbt/analyses/weather_obs_lag_distribution.sql \
        docker/postgres/init/04_marts_schema.sql \
        docs/weather_join_methodology.md \
        docs/DATA_COVERAGE.md \
        docs/DAY15_CHECKLIST.md \
        docs/DAY16_CHECKLIST.md \
        docs/DAY17_CHECKLIST.md \
        docs/DAY18_CHECKLIST.md \
        docs/DAY19_CHECKLIST.md \
        docs/DAY20_CHECKLIST.md \
        docs/DAY21_CHECKLIST.md \
        Makefile \
        dbt/dbt_project.yml \
        dbt/models/intermediate/_intermediate.yml

git commit -m "Complete flight-weather join and fct_flights marts layer"
git push
```

---

## Week 4 preview

1. **Weather backfill** — start with 2025 (45×12 station-months) overnight to raise `has_departure_weather` coverage
2. Delay risk aggregations by airport, route, carrier, weather bucket
3. Exploratory analysis / feature importance on `fct_flights`
4. **BTS backfill** (2023–2025) when historical scope needed
5. Streamlit dashboard (Week 6)
