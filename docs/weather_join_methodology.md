# Weather Join Methodology

**Status:** Implemented (Week 3)  
**Last updated:** 2026-06-28

This document defines how flight records are joined to ASOS/METAR weather observations at departure. Implemented in `intermediate.int_flights__weather_at_departure` and exposed via `marts.fct_flights`.

---

## Inputs

| Model | Grain | Key columns |
|-------|-------|-------------|
| `intermediate.int_flights__departure_context` | One row per flight | `origin`, `dep_time_utc`, `dep_time_source` |
| `intermediate.int_weather__observations_enriched` | One row per `(airport_code, valid_utc)` | `airport_code`, `valid_utc`, weather metrics |

Both sides use **UTC timestamps**. Flight departure time for the join is `dep_time_utc` (actual departure when available and not cancelled; otherwise scheduled).

---

## Join keys

```
flight.origin = weather.airport_code
```

Time alignment is **not** an equality join — we select the **nearest** observation to `dep_time_utc` within a configurable window.

---

## Nearest-observation selection

For each flight `f`, consider all weather rows `w` where:

1. `w.airport_code = f.origin`
2. `w.valid_utc` is within the search window of `f.dep_time_utc` (see below)

From candidates, pick **one** row using this priority:

| Priority | Rule |
|----------|------|
| 1 | Minimum absolute time delta: `abs(w.valid_utc - f.dep_time_utc)` |
| 2 | **Tie-break:** prefer observation **at or before** departure (`w.valid_utc <= f.dep_time_utc`) over one after |
| 3 | **Further tie-break:** most recent `loaded_at` / latest ingest (dedupe safety) |

If no candidate exists within the window, the flight gets **no weather match** (`weather_valid_utc = NULL`, weather metrics null, `weather_match_status = 'no_obs_in_window'`).

---

## Search window

| Parameter | Default | Config |
|-----------|---------|--------|
| `weather_join_window_hours` | **2** | dbt var in `dbt/dbt_project.yml` |

Window is symmetric:  
`w.valid_utc between dep_time_utc - interval 'N hours' and dep_time_utc + interval 'N hours'`

---

## Implementation

**Model:** `dbt/models/intermediate/int_flights__weather_at_departure.sql`

```sql
-- Candidate join on origin + window
-- row_number() over (partition by flight_id order by
--   obs_delta_seconds asc,
--   obs_after_dep_rank asc,   -- prefer obs at/before dep
--   weather_loaded_at desc)
-- Left join best match back to all flights
```

**Mart:** `dbt/models/marts/fct_flights.sql` selects core flight, delay, weather, time features, and modeling flags.

**Tests:**
- One row per `flight_id`; row count = departure context
- Matched rows within window (`assert_weather_join_window`)
- Match rate ≥90% on **loaded station-months only** (`assert_weather_join_coverage_loaded_months`)

Global all-flight match rate is **not** gated until full weather backfill.

---

## Output columns

On `int_flights__weather_at_departure` / `marts.fct_flights`:

| Column | Description |
|--------|-------------|
| `flight_id` | PK |
| `dep_time_utc` | Join anchor time |
| `weather_valid_utc` | Selected observation timestamp |
| `weather_obs_lag_minutes` | `(dep_time_utc - weather_valid_utc)` in minutes; negative = obs after dep |
| `weather_match_status` | `matched` / `no_obs_in_window` |
| `has_departure_weather` | Boolean flag on `fct_flights` |
| Weather metrics | temp, precip, wind, visibility, pressure, etc. |

---

## Modeling grain (`fct_flights`)

| Flag | Rule |
|------|------|
| `is_analysis_eligible` | `not is_cancelled and not is_diverted` |
| `has_departure_weather` | `weather_match_status = 'matched'` |

Use both flags for weather-conditioned delay analysis. All flights remain in the table.

---

## Edge cases

| Case | Handling |
|------|----------|
| Cancelled flight | Join proceeds; excluded from analysis via `is_analysis_eligible` |
| Missing `dep_time_utc` | Zero rows in current data (intermediate tests enforce) |
| Sparse weather months (ORD/LAX samples) | Join succeeds when obs in window; wider lag distribution |
| Month-end weather gaps | No match — data coverage issue, not join bug |
| Duplicate obs same timestamp | Staging dedupes on `(station, valid_utc)` |

---

## Validation results

### Day 13 feasibility (candidate obs within ±2h)

| Airport | Month | Match % |
|---------|-------|---------|
| ATL | 2025-01 | 95.99% |
| ORD | 2025-01 | 96.21% |
| LAX | 2025-01 | 95.80% |
| DEN | 2025-02 | 95.23% |

### Day 17 nearest-obs join (identical to feasibility)

Nearest-obs match rates equal Day 13 exactly — every candidate flight gets a nearest match.

**Lag distribution (matched flights):** ATL/DEN median 0 min; ORD/LAX wider p90 (~23 min) due to sparse hourly samples. No ±300 min timezone offset.

**Unmatched flights:** Cluster on month-end days (Jan 30–31, Feb 27–28) when weather files end early.

See `dbt/analyses/weather_join_*.sql` and `docs/DAY17_CHECKLIST.md`.

---

## References

- `intermediate.int_flights__departure_context` — departure time logic
- `intermediate.int_weather__observations_enriched` — airport-mapped weather
- `marts.fct_flights` — consumption layer
- `docs/DATA_COVERAGE.md` — local row counts
- `docs/DAY13_CHECKLIST.md` — feasibility baseline
- `docs/DAY17_CHECKLIST.md` — join validation
