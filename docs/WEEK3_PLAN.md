# Week 3 Plan — Flight ↔ Weather Join + Marts (Days 15–21)

**Theme:** Implement the **nearest-observation weather join** and build the **mart layer** for delay-risk analysis.

**Prerequisite:** Week 2 complete (join-ready intermediate models, feasibility validated). See [`weather_join_methodology.md`](weather_join_methodology.md) and [`DATA_COVERAGE.md`](DATA_COVERAGE.md).

**Not in Week 3:** Streamlit dashboard (Week 6), ML modeling, full production backfill (optional in parallel).

---

## Overview

| Day | Focus | Main deliverable |
|-----|--------|------------------|
| 15 | Nearest-obs join model | `int_flights__weather_at_departure` |
| 16 | Join tests + scoped coverage | dbt tests on loaded station-months only |
| 17 | Join validation analyses | Coverage, lag, unmatched diagnostics |
| 18 | Marts scaffold + base fact | `marts` schema, `fct_flights` (core columns) |
| 19 | Features + delay labels | Weather features, time features, modeling flags |
| 20 | Integration + documentation | Full run, `DATA_COVERAGE.md`, methodology final |
| 21 | Week 3 exit review | `DAY21_CHECKLIST.md`, confirm ready for Week 4 |

---

## Day 15 — Nearest-observation join model

### Goal
Implement `int_flights__weather_at_departure` — the analytic core join from [`weather_join_methodology.md`](weather_join_methodology.md).

### Files to create / update

| Path | Purpose |
|------|---------|
| `dbt/models/intermediate/int_flights__weather_at_departure.sql` | Nearest-obs weather join |
| `dbt/models/intermediate/_intermediate.yml` | Model docs + basic tests |
| `dbt/dbt_project.yml` | Add `weather_join_window_hours` var (default `2`) |
| `docs/DAY15_CHECKLIST.md` | Day checklist |

### Inputs

| Model | Grain | Key columns |
|-------|-------|-------------|
| `int_flights__departure_context` | One row per flight | `flight_id`, `origin`, `dep_time_utc`, delay fields |
| `int_weather__observations_enriched` | One row per `(airport_code, valid_utc)` | `airport_code`, `valid_utc`, weather metrics |

### Join logic

```sql
-- For each flight f, candidates w where:
w.airport_code = f.origin
and w.valid_utc between f.dep_time_utc - interval '{{ var("weather_join_window_hours") }} hours'
                    and f.dep_time_utc + interval '{{ var("weather_join_window_hours") }} hours'

-- Pick one row per flight_id:
-- 1. min abs(w.valid_utc - f.dep_time_utc)
-- 2. tie-break: prefer w.valid_utc <= f.dep_time_utc
-- 3. tie-break: latest loaded_at
```

Implement with `row_number() over (partition by flight_id order by ...)`.

### Output columns (minimum)

| Column | Description |
|--------|-------------|
| `flight_id` | PK |
| `dep_time_utc` | Join anchor |
| `weather_valid_utc` | Selected observation time |
| `weather_obs_lag_minutes` | Minutes from obs to dep (negative = obs after dep) |
| `weather_match_status` | `matched` / `no_obs_in_window` |
| Weather metrics | Pass-through: `temperature_f`, `precip_1hr_inches`, `wind_speed_knots`, `visibility_miles`, etc. |

### Tasks
1. Build candidate join (flight × weather in window).
2. Rank candidates per flight; keep `row_num = 1`.
3. Left join back to all flights so unmatched flights remain one row with null weather.
4. Compute `weather_obs_lag_minutes` and `weather_match_status`.
5. Spot-check ATL Jan matched flights: lag should be small (minutes, not hours).

### Spot-check

```bash
bash scripts/dbt_run.sh run --select int_flights__weather_at_departure

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT weather_match_status, COUNT(*) FROM intermediate.int_flights__weather_at_departure GROUP BY 1;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT origin, weather_match_status, COUNT(*)
   FROM intermediate.int_flights__weather_at_departure f
   JOIN intermediate.int_flights__departure_context d USING (flight_id)
   WHERE origin = 'ATL' AND year_month = '2025-01'
   GROUP BY 1, 2;"
```

### Exit criteria
- [ ] Model builds on ~1.69M flights
- [ ] One row per `flight_id` (same grain as departure context)
- [ ] Tie-break rules match methodology doc
- [ ] ATL Jan sample rows show sensible `weather_obs_lag_minutes`

### Day 16 preview
Add dbt tests; coverage gate scoped to loaded station-months only.

---

## Day 16 — Join tests + scoped match coverage

### Goal
Prove join correctness with dbt tests. Measure match rate on **loaded weather station-months only** — not all flights.

### Files to create / update

| Path | Purpose |
|------|---------|
| `dbt/tests/assert_weather_join_row_count.sql` | Row count = departure context |
| `dbt/tests/assert_weather_join_window.sql` | Matched rows within ±2h window |
| `dbt/tests/assert_weather_join_coverage_loaded_months.sql` | ≥90% match on loaded months |
| `dbt/models/intermediate/_intermediate.yml` | `flight_id` unique, `weather_match_status` accepted_values |
| `docs/DAY16_CHECKLIST.md` | Day checklist |

### Tests

| Test | Rule |
|------|------|
| Grain | `flight_id` unique |
| Row count | Equals `int_flights__departure_context` |
| Window | When `weather_match_status = 'matched'`, `weather_valid_utc` within ±2h of `dep_time_utc` |
| Accepted values | `weather_match_status` in (`matched`, `no_obs_in_window`) |
| **Coverage** | **Match rate ≥90% on loaded weather station-months only** |

### Coverage scope (important)

Evaluate match rate **only** on these origin + month subsets:

| Airport | Loaded month | Approx. flights |
|---------|--------------|-----------------|
| ATL | 2025-01 | ~23,881 |
| ORD | 2025-01 | ~21,643 |
| LAX | 2025-01 | ~15,157 |
| DEN | 2025-02 | ~22,816 |

**Do not require ≥90% across all flights until full weather backfill is complete.**  
Flights at airports/months with no weather load will show `no_obs_in_window` — expected, not a join failure.

Day 13 feasibility baseline (candidate obs within ±2h): ATL 95.99%, ORD 96.21%, LAX 95.80%, DEN 95.23%. Nearest-obs match rate should be close (may be slightly lower).

### Coverage test pattern

```sql
-- Fail only if any loaded station-month is below 90%
select airport_code, year_month, match_pct
from (... per station-month aggregation ...)
where match_pct < 90
```

Document global all-flight match rate in checklist; do **not** gate on it.

### Tasks
1. Add grain, row count, window, and accepted_values tests.
2. Build coverage test filtered to the four loaded station-months.
3. Run full test suite on join model.
4. Record global match rate for reference (expect low until backfill).

### Spot-check

```bash
bash scripts/dbt_run.sh test --select int_flights__weather_at_departure assert_weather_join_coverage_loaded_months
```

### Exit criteria
- [ ] All join grain/window/row-count tests pass
- [ ] Match rate ≥90% on **each** loaded station-month
- [ ] Global all-flight match rate documented but **not** gated until backfill

### Day 17 preview
Validation analyses: lag distribution, coverage by date/hour, unmatched diagnostics.

---

## Day 17 — Join validation analyses

### Goal
Analyze join quality on the dev subset. Compare nearest-obs match rates to Day 13 feasibility.

### Files to create / update

| Path | Purpose |
|------|---------|
| `dbt/analyses/weather_join_coverage.sql` | Match rate by airport, date, hour (loaded months only) |
| `dbt/analyses/weather_obs_lag_distribution.sql` | Distribution of `weather_obs_lag_minutes` |
| `dbt/analyses/weather_join_unmatched.sql` | Sample unmatched flights + root cause |
| `docs/DAY17_CHECKLIST.md` | Day checklist |

### Validation queries

1. **Airport summary** — match % per loaded station-month (compare to Day 13).
2. **By date** — identify low-match days (expect month-end weather gaps).
3. **By hour** — UTC departure hour vs match rate.
4. **Lag distribution** — histogram of `weather_obs_lag_minutes` for matched flights; most should be near 0, bias toward negative (obs before dep).
5. **Unmatched sample** — flights with `no_obs_in_window` on loaded months; confirm month-end or sparse-sample causes.

### Tasks
1. Port Day 13 `join_feasibility_coverage.sql` pattern to use `int_flights__weather_at_departure`.
2. Filter all analyses to loaded station-months only.
3. Add lag percentiles (p50, p90, p99).
4. Document findings in analysis comments.

### Spot-check

```bash
bash scripts/dbt_run.sh compile
docker compose exec -T postgres psql -U aerodelay -d aerodelay \
  -f dbt/target/compiled/aerodelay/analyses/weather_join_coverage.sql
```

### Exit criteria
- [ ] Loaded station-month match rates align with Day 13 feasibility (within a few %)
- [ ] Unmatched flights on loaded months explained by month-end gaps or sparse ORD/LAX samples
- [ ] Lag distribution sane (median near 0; prefer-before-dep tie-break visible)
- [ ] No systematic timezone offset (e.g. all lags ≈ ±300 min)

### Day 18 preview
Marts schema and base `fct_flights`.

---

## Day 18 — Marts scaffold + base fact table

### Goal
Create the `marts` layer and a base `fct_flights` table sourced from the weather join model.

### Files to create / update

| Path | Purpose |
|------|---------|
| `docker/postgres/init/04_marts_schema.sql` | `marts` schema (new installs) |
| `dbt/dbt_project.yml` | `marts:` config block (`+schema: marts`) |
| `dbt/macros/generate_schema_name.sql` | Confirm marts schema naming (if needed) |
| `dbt/models/marts/fct_flights.sql` | One row per flight — core columns |
| `dbt/models/marts/_marts.yml` | Model docs + grain tests |
| `docs/DAY18_CHECKLIST.md` | Day checklist |

### `fct_flights` columns (Day 18 minimum)

**Flight identity & route:**
- `flight_id`, `reporting_airline`, `flight_number`, `origin`, `dest`, `flight_date`

**Departure context:**
- `dep_time_utc`, `dep_time_source`, `origin_timezone`

**Delay outcome (from intermediate):**
- `dep_delay_minutes`, `is_dep_delay_15_plus`, `is_cancelled`, `is_diverted`

**Weather join metadata:**
- `weather_match_status`, `weather_valid_utc`, `weather_obs_lag_minutes`

**Core weather at departure (pass-through):**
- `temperature_f`, `precip_1hr_inches`, `wind_speed_knots`, `visibility_miles`

### Logic

```sql
int_flights__weather_at_departure
  → select core flight, delay, weather columns
  → one row per flight_id
```

Time features and modeling flags come on Day 19.

### Tasks
1. Add `marts` schema init SQL.
2. Configure dbt marts materialization (view or table — match project convention).
3. Build slim `fct_flights` from join model.
4. Test: `flight_id` unique, row count = join model.

### Spot-check

```bash
bash scripts/dbt_run.sh run --select fct_flights
bash scripts/dbt_run.sh test --select fct_flights

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT COUNT(*) FROM marts.fct_flights;"
```

### Exit criteria
- [ ] `marts` schema exists in Postgres
- [ ] `fct_flights` builds (~1.69M rows)
- [ ] `flight_id` unique; row count matches join model
- [ ] dbt marts tests pass

### Day 19 preview
Add time features, extended weather columns, and modeling grain flags.

---

## Day 19 — Features, delay labels, and modeling grain

### Goal
Extend `fct_flights` with features for delay-risk analysis and explicit modeling grain.

### Files to create / update

| Path | Purpose |
|------|---------|
| `dbt/models/marts/fct_flights.sql` | Add features + flags |
| `dbt/models/marts/_marts.yml` | Column docs + not_null on target where applicable |
| `docs/DAY19_CHECKLIST.md` | Day checklist |

### Columns to add

**Target (delay label):**
- `is_dep_delay_15_plus` — primary binary target (already sourced; document as target)

**Time features (from `dep_time_utc`):**
- `dep_hour_utc` — hour 0–23
- `dep_dow` — day of week (1=Mon or 0=Sun — document choice)
- `dep_month` — month 1–12

**Extended weather features:**
- `dewpoint_f`, `relative_humidity_pct`, `wind_direction_deg`, `wind_gust_knots`
- `sea_level_pressure_hpa`, `altimeter_inhg`, `weather_codes`

**Modeling grain flags:**
- `is_analysis_eligible` — `not is_cancelled` (and optionally `not is_diverted`)
- `has_departure_weather` — `weather_match_status = 'matched'`

### Tasks
1. Add derived time columns from `dep_time_utc`.
2. Pass through remaining weather metrics from join model.
3. Add `is_analysis_eligible` and `has_departure_weather` flags.
4. Document which grain to use for modeling vs exploratory analysis.
5. Test: cancelled flights have null delay metrics; flags consistent.

### Spot-check

```bash
bash scripts/dbt_run.sh run --select fct_flights
bash scripts/dbt_run.sh test --select fct_flights

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT is_analysis_eligible, has_departure_weather, COUNT(*)
   FROM marts.fct_flights GROUP BY 1, 2 ORDER BY 1, 2;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT dep_hour_utc, AVG(is_dep_delay_15_plus::int) AS delay_rate
   FROM marts.fct_flights
   WHERE origin = 'ATL' AND year_month = '2025-01' AND is_analysis_eligible
   GROUP BY 1 ORDER BY 1 LIMIT 5;"
```

### Exit criteria
- [ ] Time features populated for all rows with `dep_time_utc`
- [ ] `is_analysis_eligible` and `has_departure_weather` documented in `_marts.yml`
- [ ] Cancelled flights excluded from analysis grain by flag (not dropped from table)
- [ ] dbt tests pass

### Day 20 preview
Full pipeline run, doc updates, Makefile target.

---

## Day 20 — Integration + documentation

### Goal
Run the full dbt pipeline (staging → intermediate → marts), update coverage docs, finalize join methodology.

### Files to create / update

| Path | Purpose |
|------|---------|
| `docs/weather_join_methodology.md` | Status: Draft → Implemented |
| `docs/DATA_COVERAGE.md` | Join model + marts row counts, match rates on loaded months |
| `Makefile` | `dbt-run-marts` target |
| `docs/DAY20_CHECKLIST.md` | Day checklist |

### Full run

```bash
make dbt-seed          # if seeds changed
make dbt-run           # full project
make dbt-test          # all tests
```

Or layer by layer:

```bash
make dbt-run-intermediate
make dbt-run-marts     # new target: run --select marts+
make dbt-test
```

### Spot-checks

```bash
docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT COUNT(*) FROM intermediate.int_flights__weather_at_departure;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT weather_match_status, COUNT(*) FROM intermediate.int_flights__weather_at_departure GROUP BY 1;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT COUNT(*) FROM marts.fct_flights;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT origin, year_month,
          COUNT(*) AS flights,
          COUNT(*) FILTER (WHERE has_departure_weather) AS matched
   FROM marts.fct_flights
   WHERE (origin IN ('ATL','ORD','LAX') AND year_month = '2025-01')
      OR (origin = 'DEN' AND year_month = '2025-02')
   GROUP BY 1, 2 ORDER BY 1, 2;"
```

### Tasks
1. Run full dbt build + test (40+ tests including new join/marts tests).
2. Update `DATA_COVERAGE.md` with join and marts row counts.
3. Update methodology doc with implementation notes (window var, tie-break SQL).
4. Add `dbt-run-marts` Makefile target.
5. Record global vs loaded-month match rates side by side.

### Exit criteria
- [ ] Full `make dbt-run` + `make dbt-test` pass
- [ ] `DATA_COVERAGE.md` reflects join + marts state
- [ ] `weather_join_methodology.md` marked implemented
- [ ] Match rates on loaded months documented in coverage doc

### Day 21 preview
Week 3 exit review and handoff to Week 4.

---

## Day 21 — Week 3 exit review

### Goal
Confirm Week 3 deliverables are complete and the project is ready for Week 4 aggregations / analysis.

### Files to create / update

| Path | Purpose |
|------|---------|
| `docs/DAY21_CHECKLIST.md` | Week 3 exit checklist |

### Week 3 exit criteria

- [ ] `int_flights__weather_at_departure` — ~1.69M rows, one per flight
- [ ] Match rate ≥90% on **loaded weather station-months only** (ATL/ORD/LAX Jan, DEN Feb)
- [ ] Global all-flight match rate documented; **not** required to pass 90% until full weather backfill
- [ ] `marts.fct_flights` — ~1.69M rows with weather, delay, and feature columns
- [ ] All dbt tests pass (staging + intermediate + marts)
- [ ] Join lag/coverage documented in analyses + `DATA_COVERAGE.md`
- [ ] `weather_join_methodology.md` finalized

### Deliverables summary

| Layer | Models |
|-------|--------|
| Intermediate | `int_flights__weather_at_departure` |
| Marts | `fct_flights` |
| Tests | Join grain, window, row count, scoped coverage |
| Analyses | `weather_join_coverage`, `weather_obs_lag_distribution`, `weather_join_unmatched` |
| Docs | `weather_join_methodology.md`, `DATA_COVERAGE.md`, Day 15–21 checklists |

### Final verification

```bash
make dbt-run
make dbt-test
bash scripts/dbt_run.sh compile
# Re-run Day 17 analyses if needed
```

### Week 4 preview

- Delay risk aggregations by airport, route, carrier, weather bucket
- Optional: full BTS/weather backfill → re-evaluate global match rate
- Begin exploratory analysis or feature importance on `fct_flights`
- Streamlit dashboard (Week 6)

---

## Dependencies between days

```
Day 15  int_flights__weather_at_departure
          ↓
Day 16  join tests (coverage on loaded months only)
          ↓
Day 17  validation analyses
          ↓
Day 18  marts schema + fct_flights (core)
          ↓
Day 19  fct_flights features + modeling flags
          ↓
Day 20  integration + docs
          ↓
Day 21  exit review
```

---

## Data requirements

Partial local data is **sufficient** (see [`DATA_COVERAGE.md`](DATA_COVERAGE.md)):

| Model / test | Needs |
|--------------|-------|
| `int_flights__weather_at_departure` | BTS 2025-01→04 (~1.69M rows) ✅ |
| Join coverage tests | ATL/ORD/LAX Jan + DEN Feb flights + weather ✅ |
| Global match rate gate | Full 45×36-month weather backfill ❌ not required for Week 3 |

---

## Commit guidance (after each day)

```
Day 15: Add int_flights__weather_at_departure nearest-observation join
Day 16: Add weather join tests with coverage scoped to loaded station-months
Day 17: Add weather join validation and lag distribution analyses
Day 18: Add marts schema and base fct_flights fact table
Day 19: Add delay labels, time features, and modeling flags to fct_flights
Day 20: Finalize weather join methodology and update data coverage docs
Day 21: Complete Week 3 flight-weather join and marts layer
```

Do **not** commit `.env`, `data/`, or `dbt/target/`.
