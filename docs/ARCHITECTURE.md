# Architecture — AeroDelay Intelligence Pipeline

Last updated: 2026-06-29 (Week 6)

---

## System overview

AeroDelay is a **local-first ELT stack** that ingests public aviation and weather data, transforms it with **dbt** in **Postgres**, and serves insights through a **Streamlit** dashboard. Airflow orchestrates repeatable ingest; the dashboard can run against Postgres locally or bundled **parquet** on Streamlit Community Cloud.

```mermaid
flowchart TB
  subgraph ext["Data sources"]
    direction LR
    BTS["BTS TranStats<br/>monthly ZIP/CSV"]
    IEM["IEM Mesonet<br/>ASOS/METAR CSV"]
  end

  subgraph docker["Docker Compose"]
    direction TB
    PG[("Postgres 15<br/>raw · meta · staging<br/>intermediate · marts")]
    AF_WEB["Airflow webserver<br/>:8080"]
    AF_SCH["Airflow scheduler"]
    AF_WEB --- AF_SCH
    AF_SCH --> PG
  end

  subgraph py["Python ingest (Airflow tasks)"]
    DL_BTS["download_bts_month"]
    LD_BTS["load_bts → raw.bts_flights"]
    DL_WX["download_weather_month"]
    LD_WX["load_weather → raw.weather_observations"]
    LOG["meta.bts_ingest_log<br/>meta.weather_ingest_log"]
  end

  subgraph dbt_layer["dbt (profiles → Postgres)"]
    direction TB
    SEED["seeds: airports, station map"]
    STG["staging views<br/>stg_bts__flights<br/>stg_weather__observations"]
    INT["intermediate<br/>departure context<br/>weather enriched<br/>flight ⨝ weather join"]
    MART["marts<br/>fct_flights<br/>agg_delay_by_*"]
    TEST["tests + analyses"]
    SEED --> STG --> INT --> MART
    MART --> TEST
  end

  subgraph ui["Presentation"]
    ST_LOCAL["Streamlit local<br/>Postgres or parquet"]
    ST_CLOUD["Streamlit Cloud<br/>parquet demo_data/"]
  end

  BTS --> DL_BTS --> LD_BTS --> PG
  IEM --> DL_WX --> LD_WX --> PG
  LD_BTS --> LOG
  LD_WX --> LOG
  PG --> dbt_layer
  MART --> ST_LOCAL
  MART --> ST_CLOUD
```

---

## Component responsibilities

| Component | Role |
|-----------|------|
| **Airflow** | Schedule/trigger ingest DAGs; retry failed months; pause-at-creation for safety |
| **ingestion/** | Download from BTS/IEM, parse CSV, bulk load to Postgres, write audit rows |
| **Postgres** | Single warehouse; schemas separate concerns (raw → marts) |
| **dbt** | SQL transforms, documentation, data tests, ad-hoc analyses |
| **Streamlit** | Multipage dashboard over agg marts; parquet fallback for cloud |
| **scripts/** | Thin wrappers for dev ergonomics (`dbt_run.sh`, `bulletproof_jan2025.sh`) |

---

## Postgres schemas

| Schema | Owner | Contents |
|--------|-------|----------|
| `raw` | Ingest | `bts_flights`, `weather_observations` — append/upsert by ingest |
| `meta` | Ingest | `bts_ingest_log`, `weather_ingest_log` — idempotency & audit |
| `staging` | dbt | Typed views on raw; optional `dev_year_month` filter |
| `intermediate` | dbt | Join prep, weather enrichment, flight–weather join (table on sample) |
| `marts` | dbt | `fct_flights` fact + `agg_delay_by_*` aggregation views/tables |

Init SQL: `docker/postgres/init/`

---

## Ingest flow

### BTS (`airflow/dags/ingest_bts.py`)

1. Download monthly ZIP from TranStats (or read local cache under `data/raw/bts/`)
2. Extract CSV, filter to 45 origin airports
3. Load to `raw.bts_flights` with `(year_month, origin)` dedupe semantics
4. Record row counts in `meta.bts_ingest_log`

Backfill: `make backfill-bts` (36 months, 2023–2025)

### Weather (`airflow/dags/ingest_weather.py`)

1. Map airport → IEM station via `docs/airport_station_map.csv`
2. Download hourly ASOS/METAR CSV per station-month
3. Load to `raw.weather_observations`
4. Index `(station, valid)` for join performance
5. Audit in `meta.weather_ingest_log`

Backfill: `make backfill-weather` (45 stations × 36 months)

---

## dbt model graph (simplified)

```mermaid
flowchart LR
  RAW_BTS[(raw.bts_flights)]
  RAW_WX[(raw.weather_observations)]
  SEED_APT[dim_airports seed]

  STG_BTS[stg_bts__flights]
  STG_WX[stg_weather__observations]
  INT_DEP[int_flights__departure_context]
  INT_WX[int_weather__observations_enriched]
  INT_JOIN[int_flights__weather_at_departure]
  FCT[fct_flights]
  AGG1[agg_delay_by_airport_hour]
  AGG2[agg_delay_by_weather_bucket]
  AGG3[agg_delay_by_carrier_route]

  RAW_BTS --> STG_BTS
  RAW_WX --> STG_WX
  SEED_APT --> INT_DEP
  STG_BTS --> INT_DEP
  STG_WX --> INT_WX
  INT_DEP --> INT_JOIN
  INT_WX --> INT_JOIN
  INT_JOIN --> FCT
  FCT --> AGG1
  FCT --> AGG2
  FCT --> AGG3
```

### Dev sample filter

Macro `dev_year_month_filter` limits staging (and downstream) to one month for fast iteration:

```bash
--vars '{dev_year_month: "2025-01"}'
```

Always select **parents** (`+model`) so filtered staging propagates.

---

## Weather join (core logic)

Implemented in `intermediate.int_flights__weather_at_departure`:

1. Match `flight.origin` to `weather.airport_code`
2. Find observations within ± window of `dep_time_utc`
3. Pick **nearest** observation (tie-break: before departure preferred)
4. Expose match flags and lag minutes on `marts.fct_flights`

Full spec: [`weather_join_methodology.md`](weather_join_methodology.md)

---

## Dashboard architecture

| Mode | Data path | When |
|------|-----------|------|
| **Local Postgres** | `load_agg_table()` → `marts.agg_*` | Docker up, no parquet |
| **Parquet demo** | `dashboard/demo_data/*.parquet` | Streamlit Cloud, offline |
| **Hybrid** | Parquet preferred if files exist | Default after `make export-dashboard-demo` |

Entry: `dashboard/app.py` · pages: `dashboard/pages/` · bootstrap: `dashboard/bootstrap.py` (Cloud `sys.path` fix)

Export: `make export-dashboard-demo`

---

## Validation strategy

| Scope | Command | Duration |
|-------|---------|----------|
| Jan 2025 bulletproof | `make dbt-bulletproof-jan2025` | ~6s |
| Agg tests only | `dbt test --select agg_delay_by_*` | seconds |
| Full test suite (71 tests) | `make dbt-test` | **avoid on 16M rows locally** |

CI (Week 6 Day 2): GitHub Actions — [`.github/workflows/dbt-ci.yml`](../.github/workflows/dbt-ci.yml) on Jan 2025 sample (~13 critical tests).

---

## Deployment topology

```mermaid
flowchart LR
  subgraph local["Developer machine"]
    DC["Docker Compose<br/>Postgres + Airflow"]
    DBT_L["dbt CLI"]
    ST_L["Streamlit :8501"]
    DC --> DBT_L
    DC --> ST_L
  end

  subgraph cloud["Streamlit Community Cloud"]
    GH["GitHub repo<br/>+ demo parquet"]
    ST_C["Streamlit app<br/>Python 3.11"]
    GH --> ST_C
  end

  subgraph future["Post–Week 6 optional"]
    OCI["OCI Always Free VM<br/>full 16M materialize"]
  end

  local -.->|"export parquet"| cloud
  local -.->|"future"| OCI
```

---

## Related docs

- [`DATA_COVERAGE.md`](DATA_COVERAGE.md) — row counts and dev commands
- [`data_dictionary.md`](data_dictionary.md) — column definitions
- [`ingest_issues.md`](ingest_issues.md) — HNL and download notes
