# Week 5 Day 25 — Streamlit dashboard skeleton

## Files created

| Path | Purpose |
|------|---------|
| `dashboard/app.py` | Home overview — KPIs, connection status, headline stats |
| `dashboard/config.py` | Load Postgres settings from `.env` |
| `dashboard/data.py` | Cached agg mart loaders (Postgres or parquet fallback) |
| `dashboard/pages/1_Airport_Hour.py` | Airport × hour table (Day 2 charts) |
| `dashboard/pages/2_Weather_Buckets.py` | Weather bucket table (Day 3 charts) |
| `dashboard/pages/3_Carrier_Routes.py` | Carrier route table (Day 4 charts) |
| `dashboard/requirements.txt` | streamlit, pandas, psycopg2-binary |
| `dashboard/.streamlit/config.toml` | Theme |
| `scripts/run_dashboard.sh` | Venv + `streamlit run` wrapper |

## Prerequisites

- Docker stack up: `make up`
- Jan 2025 agg marts built (from Week 4 Plan B):

```bash
bash scripts/dbt_run.sh run --select agg_delay_by_airport_hour agg_delay_by_weather_bucket agg_delay_by_carrier_route
```

## Run locally

```bash
make dashboard-deps   # first time only
make dashboard
```

Opens at http://localhost:8501

Or:

```bash
bash scripts/run_dashboard.sh
```

## Verify Day 1

- [ ] Sidebar shows **green** Postgres connection
- [ ] Overview metrics: ~1,000 airport-hour rows, ~634 weather rows, ~6,273 routes
- [ ] Busiest hour shows **DEN 18:00 UTC** (or similar)
- [ ] Precip table shows none → heavy delay gradient
- [ ] All three sidebar pages load without error

## Data layer behavior

| Source | When |
|--------|------|
| **Postgres** `marts.agg_*` | Default local dev (`POSTGRES_HOST_LOCAL=localhost`) |
| **Parquet** `data/demo/*.parquet` | Future Streamlit Cloud deploy (Day 5 export) |

Set optional scope label in `.env`:

```bash
DASHBOARD_DATA_SCOPE="Jan 2025 sample"
```

## Next (Day 26)

- Airport filter + bar chart on `1_Airport_Hour`
- Top delay hours highlight cards

**Done** — see `docs/DAY26_CHECKLIST.md`
