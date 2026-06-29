# Data Coverage — Current Local State

Verified warehouse and on-disk coverage for this development environment.

Last verified: 2026-06-29

---

## Summary

| Layer | Production target | Raw Postgres (full backfill) | Full marts (local) | dbt dev sample (Jan 2025) |
|-------|-------------------|------------------------------|--------------------|---------------------------|
| **BTS flights** | 45 origins, 2023–2025 | **15.9M rows**, 36 months | — | **409K rows** (`2025-01`) |
| **Weather obs** | 45 stations, 36 months | **14.4M rows** | — | **403K rows** (`2025-01`) |
| **Join + fct table** | Full history | — | **15,752,377 rows** | **409K rows** |
| **Agg marts** | Full or sample | Built on full `fct` | Tables on disk | **1K / 634 / 6.3K rows** |

**Raw ingest is complete.** **Full 2023–2025 marts materialized locally** (2026-06-29). CI and fast iteration still use **`dev_year_month: "2025-01"`** (~3 min join, tests in seconds).

Guide: [`LOCAL_FULL_MATERIALIZATION.md`](LOCAL_FULL_MATERIALIZATION.md)

---

## BTS — `raw.bts_flights`

| Metric | Value |
|--------|-------|
| Total rows | **15,866,662** |
| Months | **2023-01 → 2025-12** (36) |
| Origins | 45 airports |

Backfill script: `bash scripts/backfill_bts.sh`

---

## Weather — `raw.weather_observations`

| Metric | Value |
|--------|-------|
| Total rows | **14,353,070** |
| Station-months | **36 × 45 = 1,620** |
| Index | `idx_weather_obs_station_valid` on `(station, valid)` |

Backfill script: `bash scripts/backfill_weather.sh`

**Known issue:** HNL maps to IEM station `HNL` but ASOS data uses **`PHNL`** — 0% weather match for HNL until `airport_station_map.csv` is updated.

---

## dbt dev sample (Jan 2025)

Materialized with:

```bash
bash scripts/dbt_run.sh run \
  --select +int_flights__weather_at_departure fct_flights \
  --full-refresh --vars '{dev_year_month: "2025-01"}' --threads 1
```

| Object | Type | Rows | Size |
|--------|------|------|------|
| `staging.stg_bts__flights` | view (filtered) | 408,974 | — |
| `staging.stg_weather__observations` | view (filtered) | 402,697 | — |
| `intermediate.int_flights__weather_at_departure` | **table** | 408,974 | 243 MB |
| `marts.fct_flights` | **table** | 408,974 | 81 MB |

### Weather join (Jan 2025)

| Metric | Value |
|--------|-------|
| Total flights | 408,974 |
| Matched | 388,542 (**95.0%**) |
| Unmatched | 20,432 (5.0%) |
| HNL only | 5,164 flights, **0%** matched (station mapping) |
| All other airports | **≥95.7%** matched |

### Modeling grain (`marts.fct_flights`, Jan 2025)

| is_analysis_eligible | has_departure_weather | Rows |
|----------------------|-----------------------|------|
| false | false | 316 |
| false | true | 12,611 |
| true | false | 20,116 |
| true | true | **375,931** |

---

## Week 4 aggregation marts

| Model | Grain | Rows (Jan 2025) |
|-------|-------|-----------------|
| `agg_delay_by_airport_hour` | origin + dep_hour_utc | 1,000 |
| `agg_delay_by_weather_bucket` | origin + wind/precip/visibility bins | 634 |
| `agg_delay_by_carrier_route` | airline + origin + dest | 6,273 |

Analyses: `dbt/analyses/delay_by_*`, `weather_join_coverage_jan2025.sql`  
Findings: `docs/DAY24_CHECKLIST.md`

---

## Bulletproof validation (Jan 2025 sample)

One-time critical test pass (not full 71 tests):

```bash
bash scripts/bulletproof_jan2025.sh
```

**Last run:** 2026-06-29 — **33/33 PASS** in ~6s (join integrity, fct consistency, all agg tests, Jan 2025 coverage gate excluding HNL).

Log: `logs/bulletproof_jan2025.log`

---

## Local dev workflow

| Task | Command |
|------|---------|
| Rebuild sample tables | `bash scripts/dbt_run.sh run --select +int_flights__weather_at_departure fct_flights --full-refresh --vars '{dev_year_month: "2025-01"}' --threads 1` |
| Run new agg | `bash scripts/dbt_run.sh run --select agg_delay_by_airport_hour agg_delay_by_weather_bucket agg_delay_by_carrier_route` |
| Test aggs only | `bash scripts/dbt_run.sh test --select agg_delay_by_airport_hour agg_delay_by_weather_bucket agg_delay_by_carrier_route --threads 1` |
| Bulletproof pass | `bash scripts/bulletproof_jan2025.sh` |

**Do not** run `make dbt-test` (71 tests) on 16M rows locally.

---

## Full materialization (2023–2025) — verified 2026-06-29

Built via monthly incremental dbt (`scripts/materialize_monthly.sh` → `materialize_downstream.sh`).

| Object | Rows |
|--------|------|
| `intermediate.int_flights__weather_at_departure` | **15,752,377** |
| `marts.fct_flights` | **15,752,377** |
| int ↔ fct delta | **0** |
| Duplicate `flight_id` | **0** |

### Weather join (full history)

| Metric | Value |
|--------|-------|
| Months | **36** (2023-01 → 2025-12) |
| Match rate | **~96%** every month (95.75%–96.69%) |
| HNL unmatched | **179,195** flights (**100%** unmatched — `HNL` vs `PHNL` station map) |
| Other top origins | ~1–3% unmatched (ATL, DFW, DEN, ORD, etc.) |

### Spot dbt tests (full history)

`bash scripts/materialize_downstream.sh` — **7/7 PASS** (agg rate tests, fct consistency, weather join window).

### Reproduce

```bash
make check-materialization-ready-monthly
make materialize-full-local    # ~3–8 hr overnight
make validate-full-materialization
```

Resume after failure:

```bash
bash scripts/materialize_monthly.sh --resume-from YYYY-MM
bash scripts/materialize_downstream.sh
```

Analyses: `dbt/analyses/materialization_*.sql`

---

## Data folder structure

```
data/
├── samples/          # Manual dev samples (gitignored)
└── raw/
    ├── bts/          # BTS ZIP downloads (gitignored)
    └── weather/      # IEM CSV downloads (gitignored)
```

All of `data/` is gitignored.

---

## Ingest logs

- `meta.bts_ingest_log` — 36 months loaded (2023–2025)
- `meta.weather_ingest_log` — 1,620 station-months loaded
- `docs/ingest_issues.md` — check for HNL / download failures
