# Week 2 Plan — dbt Intermediate Layer (Days 8–14)

**Theme:** Make flights and weather **join-ready** — UTC departure times, airport timezones, weather enriched with airport codes.

**Prerequisite:** Week 1 complete (staging models, partial dev data). See [`DATA_COVERAGE.md`](DATA_COVERAGE.md).

**Not in Week 2:** The actual flight ↔ weather nearest-observation join (Week 3).

---

## Overview

| Day | Focus | Main deliverable |
|-----|--------|------------------|
| 8 | Intermediate layer scaffold + airport timezones | `seeds/airport_timezones.csv`, `dim_airports` |
| 9 | BTS HHMM → local timestamp macros | `macros/bts_time_to_timestamp.sql` |
| 10 | Scheduled departure UTC | `int_flights__departure_context` (scheduled times) |
| 11 | Actual departure fallback + tests | Complete `int_flights__departure_context` |
| 12 | Weather enriched with airport codes | `int_weather__observations_enriched` |
| 13 | Join-prep validation on dev subset | Analysis queries + spot-checks ATL/DEN |
| 14 | Integration, docs, Week 2 exit review | `weather_join_methodology.md` draft, `DAY14_CHECKLIST.md` |

---

## Day 8 — Intermediate scaffold + airport timezones

### Goal
Set up the dbt `intermediate` layer and a reliable airport → IANA timezone mapping for all 45 origins.

### Files to create / update

| Path | Purpose |
|------|---------|
| `docker/postgres/init/03_intermediate_schema.sql` | `intermediate` schema (new installs) |
| `dbt/seeds/airport_timezones.csv` | `airport_code`, `timezone` (IANA, e.g. `America/New_York`) |
| `dbt/models/intermediate/dim_airports.sql` | Join `airports_45` + timezones + station map |
| `dbt/models/intermediate/_intermediate.yml` | Model docs + tests |
| `dbt/dbt_project.yml` | Add `intermediate:` config block |
| `docs/DAY8_CHECKLIST.md` | Day checklist |

### Tasks
1. Create IANA timezone mapping for all 45 airports in `docs/airports_45.csv`.
2. Add dbt seed + `dbt seed` target.
3. Build `dim_airports` with: `airport_code`, `airport_name`, `state`, `region`, `timezone`, `weather_station_id`.
4. Test: every origin in `stg_bts__flights` has a timezone; every weather station maps to an airport.

### Exit criteria
- [ ] `intermediate` schema exists in Postgres
- [ ] `dbt seed` loads 45 airport timezone rows
- [ ] `dim_airports` has 45 rows, no null timezones
- [ ] All 4 loaded weather stations present in dim

### Day 9 preview
BTS HHMM parsing macros (handle `2400`, nulls, date rollover).

---

## Day 9 — BTS time parsing macros

### Goal
Reusable macros to convert BTS `FlightDate` + HHMM local time → `timestamptz` in airport local time, then UTC.

### Files to create / update

| Path | Purpose |
|------|---------|
| `dbt/macros/bts_time_to_timestamp.sql` | Parse HHMM string/int → local timestamp |
| `dbt/macros/bts_time_to_utc.sql` | Local timestamp + IANA tz → UTC |
| `dbt/analyses/validate_bts_time_parsing.sql` | Manual spot-check queries |
| `docs/DAY9_CHECKLIST.md` | Day checklist |

### Parsing rules
- BTS HHMM: `800` = 08:00, `1530` = 15:30, `2400` = midnight end-of-day (treat as 00:00 next day or 23:59 same day — document choice).
- Null/empty time → `NULL` timestamp.
- Times are **local to the airport** passed in (origin for dep, dest for arr).

### Exit criteria
- [ ] Macro handles sample values: `800`, `1530`, `1`, `2400`, `NULL`
- [ ] Analysis query shows sane UTC for ATL, DEN, LAX examples
- [ ] Document edge-case decisions in macro comments

### Day 10 preview
Apply macros to build scheduled departure UTC on flights.

---

## Day 10 — Scheduled departure UTC (`int_flights__departure_context` part 1)

### Goal
Build the intermediate flight model with **scheduled** departure times in local and UTC.

### Files to create / update

| Path | Purpose |
|------|---------|
| `dbt/models/intermediate/int_flights__departure_context.sql` | Core model (scheduled dep first) |
| `docs/DAY10_CHECKLIST.md` | Day checklist |

### Model columns (minimum)
- From staging: `flight_id`, `reporting_airline`, `flight_number`, `origin`, `dest`, `flight_date`, delay fields, flags
- New: `origin_timezone`, `crs_dep_time_local`, `crs_dep_time_utc`

### Logic
```sql
stg_bts__flights
  → join dim_airports on origin = airport_code
  → crs_dep_time_local = bts_time_to_timestamp(flight_date, crs_dep_time_local, origin_timezone)
  → crs_dep_time_utc   = bts_time_to_utc(crs_dep_time_local, origin_timezone)
```

### Exit criteria
- [ ] Model builds without error on ~1.69M rows
- [ ] `crs_dep_time_utc` not null for non-cancelled flights with valid scheduled dep
- [ ] Sample ATL flights: local vs UTC offset looks correct (EST/EDT)

### Day 11 preview
Add actual departure fallback and `dep_time_utc` for weather join.

---

## Day 11 — Actual departure fallback + flight tests

### Goal
Complete `int_flights__departure_context` with the **weather join departure time** and full test coverage.

### Files to create / update

| Path | Purpose |
|------|---------|
| `dbt/models/intermediate/int_flights__departure_context.sql` | Add actual dep + fallback logic |
| `dbt/models/intermediate/_intermediate.yml` | Tests: not_null, accepted_values |

### Departure time for weather join
| Condition | `dep_time_utc` source | `dep_time_source` |
|-----------|----------------------|-------------------|
| Not cancelled + actual dep present | actual dep UTC | `'actual'` |
| Otherwise | scheduled dep UTC | `'scheduled'` |
| Cancelled, no times | scheduled dep UTC if available | `'scheduled'` |

Also add: `dep_time_local`, `dep_time_utc`, `arr_*` local/UTC (optional but useful for Week 3+).

### Exit criteria
- [ ] `dep_time_utc` populated for ≥99% of rows (document exceptions)
- [ ] Cancelled flights: delays null (from staging), but `dep_time_utc` may still exist from scheduled
- [ ] dbt tests pass: `flight_id` unique, `dep_time_source` in (`actual`, `scheduled`)
- [ ] Row count matches `stg_bts__flights`

### Day 12 preview
Enrich weather observations with airport codes.

---

## Day 12 — Weather enriched with airport codes

### Goal
Bridge weather stations to airport codes so observations can join to flights on `(airport_code, timestamp)`.

### Files to create / update

| Path | Purpose |
|------|---------|
| `dbt/models/intermediate/int_weather__observations_enriched.sql` | Weather + airport mapping |
| `dbt/models/intermediate/_intermediate.yml` | Tests on enriched weather |

### Logic
```sql
stg_weather__observations
  → join dim_airports on station = weather_station_id
  → add airport_code, airport_name, timezone (already UTC in valid_utc)
```

### Exit criteria
- [ ] All loaded stations (ATL, ORD, LAX, DEN) map to airport codes
- [ ] Row count matches `stg_weather__observations` (no fan-out)
- [ ] `(airport_code, valid_utc)` unique
- [ ] Precip/temp fields flow through unchanged

### Day 13 preview
Validate join feasibility on dev subset.

---

## Day 13 — Join-prep validation (dev subset)

### Goal
Prove flights and weather **can** join on `(origin airport, UTC time)` using loaded dev data — without building the full nearest-obs join yet.

### Files to create / update

| Path | Purpose |
|------|---------|
| `dbt/analyses/join_feasibility_atl.sql` | ATL flights vs ATL weather overlap check |
| `dbt/analyses/join_feasibility_den.sql` | DEN Feb flights vs DEN weather |
| `dbt/analyses/dep_time_distribution.sql` | dep_time_utc hour distribution by airport |
| `docs/DAY13_CHECKLIST.md` | Day checklist |

### Validation queries
1. For ATL origin flights in Jan 2025: count how many have ≥1 weather obs within ±2 hours of `dep_time_utc`.
2. Same for DEN origin flights in Feb 2025.
3. Check for timezone outliers (dep_time_utc before 1970, after 2030, etc.).

### Exit criteria
- [ ] ≥90% of ATL Jan flights have weather obs within ±2h (expect high for loaded data)
- [ ] DEN Feb spot-check passes
- [ ] No systematic timezone bugs (e.g. all times off by 5 hours)
- [ ] Document findings in analysis comments

### Day 14 preview
Week 2 wrap-up + join methodology doc draft.

---

## Day 14 — Integration, documentation, Week 2 exit

### Goal
Run full intermediate layer, document join rules for Week 3, confirm ready to proceed.

### Files to create / update

| Path | Purpose |
|------|---------|
| `docs/weather_join_methodology.md` | Draft: nearest-obs join rules, tie-breaks, time window |
| `docs/DAY14_CHECKLIST.md` | Week 2 exit checklist |
| `docs/DATA_COVERAGE.md` | Add intermediate model row counts |
| `Makefile` | Optional: `dbt-run-intermediate` target |

### Full run
```bash
make dbt-run    # or: bash scripts/dbt_run.sh run --select intermediate+
make dbt-test
```

### Spot-checks
```bash
docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT COUNT(*) FROM intermediate.int_flights__departure_context;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT dep_time_source, COUNT(*) FROM intermediate.int_flights__departure_context GROUP BY 1;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT airport_code, COUNT(*) FROM intermediate.int_weather__observations_enriched GROUP BY 1;"
```

### Week 2 exit criteria
- [ ] `int_flights__departure_context` — ~1.69M rows, `dep_time_utc` populated
- [ ] `int_weather__observations_enriched` — ~19.6K rows, airport codes present
- [ ] `dim_airports` — 45 rows with IANA timezones
- [ ] All dbt intermediate tests pass
- [ ] Join feasibility analyses confirm data overlap on dev subset
- [ ] `weather_join_methodology.md` draft exists for Week 3

### Week 3 preview
- `int_flights__weather_at_departure` — nearest ASOS observation join
- Tie-break: prefer observation at or before departure
- dbt marts / fact table beginnings

---

## Dependencies between days

```
Day 8  dim_airports + timezones
         ↓
Day 9  time parsing macros
         ↓
Day 10 int_flights (scheduled UTC)
         ↓
Day 11 int_flights (actual fallback + tests)
         ↓
Day 12 int_weather enriched
         ↓
Day 13 join feasibility analyses
         ↓
Day 14 integration + methodology doc
         ↓
Week 3  nearest-observation join
```

---

## Data requirements

Partial local data is **sufficient** (see [`DATA_COVERAGE.md`](DATA_COVERAGE.md)):

| Model | Needs |
|-------|-------|
| `int_flights__departure_context` | BTS 2025-01→04 (~1.69M rows) ✅ |
| `int_weather__observations_enriched` | ATL/ORD/LAX Jan + DEN Feb ✅ |
| Join feasibility (Day 13) | ATL + DEN subsets ✅ |

Full 2023–2025 backfill optional — run in background if desired.

---

## Commit guidance (after each day)

Follow Week 1 pattern — one commit per day after tests pass:

```
Day 8:  Add airport timezone seed and dim_airports intermediate model
Day 9:  Add BTS HHMM time parsing macros for UTC conversion
Day 10: Add int_flights__departure_context with scheduled departure UTC
Day 11: Complete departure context with actual/scheduled fallback and tests
Day 12: Add int_weather__observations_enriched with airport mapping
Day 13: Add join feasibility analysis queries for dev subset
Day 14: Document weather join methodology and complete Week 2 intermediate layer
```

Do **not** commit `.env`, `data/`, or `dbt/target/`.
