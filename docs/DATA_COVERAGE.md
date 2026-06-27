# Data Coverage — Current Local State

Verified warehouse and on-disk coverage for this development environment.  
**Production target scope** (2023–2025, 45 airports/stations) is implemented by backfill scripts but **not fully loaded locally**.

Last verified: 2026-06-27

---

## Summary

| Layer | BTS flights | Weather observations |
|-------|-------------|----------------------|
| **Production target** | 45 origins, 2023–2025 | 45 stations, 2023–2025 (36 months × 45 stations) |
| **Backfill scripts** | Implemented (`scripts/backfill_bts.sh`) | Implemented (`scripts/backfill_weather.sh`) |
| **Local backfill status** | **Not complete** | **Not complete** |
| **Currently loaded in Postgres** | **2025-01 → 2025-04 only** (~1.69M rows) | **4 station-months** (~19.7K rows) |
| **Safe for next dev phase?** | Yes — partial dev data is sufficient for intermediate/dbt work | Yes |

---

## BTS — `raw.bts_flights`

### Loaded in Postgres

| year_month | Approx. rows |
|------------|--------------|
| 2025-01 | 408,974 |
| 2025-02 | 381,883 |
| 2025-03 | 453,255 |
| 2025-04 | 442,266 |
| **Total** | **~1,686,378** |

No 2023 or 2024 months are loaded locally.

### On disk (`data/raw/bts/`)

Only automated downloads for **2025-02, 2025-03, 2025-04** are present.  
January 2025 was loaded from `data/samples/` (manual sample ZIP).

### Staging

`staging.stg_bts__flights` mirrors raw row count (~1.69M). dbt tests pass.

---

## Weather — `raw.weather_observations`

### Loaded in Postgres

| Station | year_month | Rows | Source |
|---------|------------|------|--------|
| ATL | 2025-01 | 9,448 | IEM download (`data/raw/weather/weather_ATL_2025_01.csv`; overwrote 817-row sample) |
| ORD | 2025-01 | 895 | Manual sample |
| LAX | 2025-01 | 794 | Manual sample |
| DEN | 2025-02 | 8,530 | Day 6 backfill verification download |
| **Total** | | **~19,667** | |

Full production backfill (1,620 station-months) has **not** been run locally.

### On disk

| Path | Origin |
|------|--------|
| `data/samples/weather_*` | Manual Day 2 samples (ATL, ORD, LAX Jan 2025) |
| `data/raw/weather/weather_ATL_2025_01.csv` | Automated IEM download (Airflow / ingest test) |
| `data/raw/weather/weather_DEN_2025_02.csv` | Automated IEM download (backfill verification) |

### Staging

`staging.stg_weather__observations` — ~19,600 rows after dedupe. dbt tests pass.

---

## Intermediate (dbt)

Last verified: 2026-06-27

| Model | Rows | Notes |
|-------|------|-------|
| `intermediate.dim_airports` | 45 | All origins with IANA timezone + weather station |
| `intermediate.int_flights__departure_context` | 1,686,378 | Matches staging; `dep_time_utc` 100% populated |
| `intermediate.int_weather__observations_enriched` | 19,600 | Matches staging; ATL/ORD/LAX/DEN mapped |

### Flight departure time split

| dep_time_source | Rows |
|-----------------|------|
| actual | 1,661,187 |
| scheduled | 25,191 (cancelled flights) |

### Enriched weather by airport

| airport_code | Rows |
|--------------|------|
| ATL | 9,415 |
| DEN | 8,496 |
| ORD | 895 |
| LAX | 794 |

All dbt intermediate tests pass. Join feasibility analyses (Day 13) confirm ≥95% candidate match within ±2h on loaded station-months. See `docs/weather_join_methodology.md`.

---

## Data folder structure (correct)

```
data/
├── samples/          # Manual dev samples (gitignored)
└── raw/
    ├── bts/          # Automated BTS ZIP downloads (gitignored)
    └── weather/      # Automated IEM CSV downloads (gitignored)
```

All of `data/` is gitignored. No raw or sample files are tracked by Git.

---

## Ingest logs

- `meta.bts_ingest_log` — 8 successful runs (2025-01 through 2025-04; some months rerun for idempotency/DAG tests)
- `meta.weather_ingest_log` — 16 successful runs (samples, Airflow trigger, backfill/idempotency tests)
- `docs/ingest_issues.md` — no failures logged

---

## What to run for full production load (optional, long)

```bash
# BTS — 2023-01 through 2025-12 (needs network, hours)
bash scripts/backfill_bts.sh

# Weather — 36 months × 45 stations (needs network, very long)
bash scripts/backfill_weather.sh
```

Batch by year if preferred (see `docs/DAY6_CHECKLIST.md`).

---

## Proceeding to intermediate models

Partial dev coverage is **intentional and sufficient** for:

- dbt intermediate models (UTC departure context)
- Weather join prep and prototyping on ATL/ORD/LAX/DEN subsets

Full backfill can run in parallel or overnight without blocking Week 2 work.
