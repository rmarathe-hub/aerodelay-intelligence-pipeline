# Week 1 Day 1 — completion checklist

## Files created today

| Path | Purpose |
|------|---------|
| `.gitignore` | Python, Docker, dbt, data, secrets |
| `.env.example` | Postgres + Airflow placeholders |
| `docker-compose.yml` | Postgres 15, Airflow init/webserver/scheduler |
| `docker/postgres/init/01_schemas.sql` | `raw`, `meta` schemas |
| `docker/airflow/Dockerfile` | Custom Airflow image |
| `docker/airflow/requirements.txt` | Postgres provider, pandas, requests |
| `airflow/dags/day1_healthcheck.py` | Proves DAG folder is mounted |
| `scripts/dev_up.sh` | Start stack |
| `scripts/check_stack.sh` | Verify Postgres + Airflow |
| `scripts/generate_fernet_key.sh` | Fernet key → `.env` |
| `Makefile` | `make up`, `make check`, etc. |

## Your manual steps

1. `cp .env.example .env` and set `POSTGRES_PASSWORD`
2. Install `cryptography` if Fernet script fails: `pip install cryptography`
3. Run `bash scripts/dev_up.sh` (pulls images — needs network)
4. Open http://localhost:8080 — login `admin` / `admin`
5. Confirm DAG `aerodelay_day1_healthcheck` appears
6. Run `bash scripts/check_stack.sh` — `raw` and `meta` schemas listed

## Success criteria

- Docker stack up without errors
- Postgres: schemas `raw`, `meta` exist
- Airflow UI reachable
- Healthcheck DAG visible (no need to run it yet)

## Optional commit (you only)

After checklist passes:

```
chore: scaffold project skeleton and Docker stack
```

Do **not** commit `.env`.

## Day 2 preview

- `docs/airports_45.csv`
- `docs/airport_station_map.csv`
- BTS + weather sample downloads (manual browser if needed)
