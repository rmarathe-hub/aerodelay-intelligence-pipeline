# Data Coverage — Current Local State

Verified warehouse and on-disk coverage for this development environment.

Last verified: 2026-06-29

---

## Summary

| Layer | Production target | Raw Postgres (full backfill) | dbt dev sample (Jan 2025) |
|-------|-------------------|------------------------------|---------------------------|
| **BTS flights** | 45 origins, 2023–2025 | **15.9M rows**, 36 months | **409K rows** (`2025-01`) |
| **Weather obs** | 45 stations, 36 months | **14.4M rows** | **403K rows** (`2025-01`) |
| **Join + fct table** | Full history | Not materialized locally | **409K rows** (tables on disk) |
| **Agg marts** | Full or sample | Views over sample tables | **1K / 634 / 6.3K rows** |

**Raw ingest is complete.** Local dbt iteration uses **`dev_year_month: "2025-01"`** (Plan B) for fast builds (~3 min join, tests in seconds).

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

## Full materialization (optional, deferred)

Full 2023–2025 table materialize on Docker Mac takes **hours** (16M-row weather join). Options:

- Overnight local run with index + RAM bump
- Paid cloud VM with 8+ GB RAM
- Keep portfolio on Jan 2025 sample (recommended)

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
