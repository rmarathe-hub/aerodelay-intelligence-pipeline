# Local full materialization (monthly chunks)

Free fallback when OCI Always Free A1 capacity is unavailable. Builds full **2023–2025** history on local Docker Postgres in **36 monthly windows** instead of one 16M-row join.

## When to use

| Path | Use when |
|------|----------|
| **Monthly local (this doc)** | OCI out of capacity; Mac has raw data + Docker; OK with 3–8 hr overnight run |
| **OCI batch VM** | A1 capacity available; want fewer manual steps |
| **Jan 2025 sample** | CI, Streamlit demo, fast iteration (`dev_year_month`) |

Public **Streamlit Cloud** demo stays on committed **parquet** — full warehouse marts are local proof, not required for the live URL.

## Prerequisites

- Raw backfill complete (~15.9M BTS, ~14.4M weather)
- `make up` — Postgres healthy
- Docker Desktop memory **8–12 GB**
- `unset dev_year_month DBT_VARS start_date end_date`

## Preflight

```bash
bash scripts/check_full_materialization_ready.sh --mode monthly --allow-local --stage full
```

Expect **DATA GO**, **CONFIG GO**, **RESOURCES GO** with `--allow-local`.

## Overnight run (full 2023–2025)

```bash
# Optional: free RAM
docker compose stop airflow-webserver airflow-scheduler

# Prevent Mac sleep (separate terminal)
caffeinate -dims &

# tmux recommended
tmux new -s materialize
make materialize-full-local
# Ctrl+B, D to detach
```

Or log to file:

```bash
nohup make materialize-full-local > logs/full_materialize_$(date +%F).log 2>&1 &
tail -f logs/full_materialize_*.log
```

## What runs

1. **`materialize_monthly.sh`** — 36 months, `start_date`/`end_date` vars per month, incremental `int_flights__weather_at_departure` (`unique_key: flight_id`). First month uses `--full-refresh` when replacing Jan sample.
2. **`materialize_downstream.sh`** — `fct_flights` full-refresh + agg views + spot tests.
3. **`validate_full_materialization.sh`** — row counts, dupes, coverage by month.

## Scoped runs

```bash
# 2025 only
make materialize-2025-local

# Q1 2025 smoke
make materialize-q1-2025-local
```

## Resume after failure

If month `2024-06` fails:

```bash
bash scripts/materialize_monthly.sh --resume-from 2024-06
bash scripts/materialize_downstream.sh
bash scripts/validate_full_materialization.sh
```

Do **not** pass `--fresh` when resuming (drops accumulated months).

## Validation (morning)

```bash
bash scripts/validate_full_materialization.sh
```

Expect:

- `int_flights__weather_at_departure` ≈ **15.9M** rows
- `fct_flights` same count
- **0** duplicate `flight_id`
- ~**95%** weather match (HNL lower until PHNL mapping fix)

## Join semantics (unchanged)

- Origin airport ↔ weather station
- ±`weather_join_window_hours` (default 2) of `dep_time_utc`
- Nearest absolute lag; tie-break obs at/before departure, then `loaded_at`

## Runtime risk

| Phase | Estimate |
|-------|----------|
| 36 monthly int runs | 2–6 hours |
| fct + aggs + spot tests | 30–90 min |
| **Total** | **3–8 hours** |

OOM risk per month is similar to Jan 2025 sample (~3 min). Failure mode is usually Docker memory — bump to 12 GB.

## Interview wording (honest)

> Ingested 15.9M BTS flights and 14.4M METAR observations into Postgres. Materialized full 2023–2025 marts locally via monthly incremental dbt runs (~16M-row nearest-weather join). Public Streamlit demo uses a parquet bundle for reliable free hosting; CI reproduces Jan 2025 on every push.

Do **not** claim OCI if you used local monthly materialization.

## Related

- `docs/OCI_MATERIALIZATION.md` — optional cloud path when A1 available
- `docs/DATA_COVERAGE.md` — update row counts after success
- `scripts/check_full_materialization_ready.sh` — GO/NO-GO
