# Weather Join Methodology (Draft)

**Status:** Draft for Week 3 implementation  
**Last updated:** 2026-06-27

This document defines how flight records will be joined to ASOS/METAR weather observations at departure. Week 2 built the **join-ready inputs**; Week 3 implements the actual join model (`int_flights__weather_at_departure`).

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

If no candidate exists within the window, the flight gets **no weather match** (`weather_valid_utc = NULL`, weather metrics null).

---

## Search window

| Parameter | Proposed default | Rationale |
|-----------|------------------|-----------|
| `weather_join_window_hours` | **2** | Day 13 feasibility used ±2h; ASOS reports every ~5–20 min when fully loaded |
| Pre-departure only variant | Optional flag | Some models prefer `w.valid_utc <= dep_time_utc` only (no future obs) — defer to Week 3 eval |

Window is symmetric by default:  
`w.valid_utc between dep_time_utc - interval '2 hours' and dep_time_utc + interval '2 hours'`

---

## Output columns (planned)

Minimum columns on `int_flights__weather_at_departure`:

| Column | Description |
|--------|-------------|
| `flight_id` | From flights (PK) |
| `dep_time_utc` | Join anchor time |
| `weather_valid_utc` | Selected observation timestamp |
| `weather_obs_lag_minutes` | `(dep_time_utc - weather_valid_utc)` in minutes; negative = obs after dep |
| `weather_match_status` | `matched` / `no_obs_in_window` |
| Weather metrics | Pass-through from enriched weather (temp, precip, wind, visibility, etc.) |

---

## Edge cases

| Case | Handling |
|------|----------|
| Cancelled flight | Still has `dep_time_utc` from scheduled time; join proceeds unless excluded in mart logic |
| Missing `dep_time_utc` | Exclude from join (<1% today; should be zero after intermediate tests) |
| Sparse weather months (ORD/LAX samples) | Join succeeds when any obs in window; coverage improves with full backfill |
| Month-end weather gaps | Flights on days after last obs have no match — data coverage issue, not join bug |
| Duplicate obs same timestamp | Staging dedupes on `(station, valid_utc)`; enriched model inherits 1:1 grain |

---

## Validation (Week 2 completed)

Day 13 analyses confirmed **≥95% candidate coverage** (obs exists within ±2h) for loaded station-months:

- ATL Jan 2025: 95.99%
- ORD Jan 2025: 96.21%
- LAX Jan 2025: 95.80%
- DEN Feb 2025: 95.23%

Unmatched flights cluster on calendar days after weather files end (partial month downloads). Full weather backfill is expected to close those gaps.

See `dbt/analyses/join_feasibility_*.sql` and `docs/DAY13_CHECKLIST.md`.

---

## Week 3 implementation notes

1. Implement as dbt model using window functions (`row_number()` over partition by `flight_id` ordered by delta, tie-break rules).
2. Add tests: at most one weather row per flight; `weather_valid_utc` within window when matched.
3. Re-run join feasibility on matched vs candidate rates after nearest-obs logic ships.
4. Consider dbt var for window hours to support sensitivity analysis.

---

## References

- `intermediate.int_flights__departure_context` — departure time logic
- `intermediate.int_weather__observations_enriched` — airport-mapped weather
- `docs/DAY13_CHECKLIST.md` — feasibility results
- `docs/DATA_COVERAGE.md` — local row counts and partial load truth
