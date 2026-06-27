# AeroDelay Intelligence Pipeline

Production-style ELT pipeline analyzing flight delay risk across 45 major U.S. airports using BTS On-Time Performance data, ASOS/METAR weather, Airflow, dbt, Postgres, Docker, and Streamlit.

**Status:** Ingestion pipeline + dbt staging in place — **partial local data load** (see [`docs/DATA_COVERAGE.md`](docs/DATA_COVERAGE.md))

## Stack (local)

| Service | URL / access |
|---------|----------------|
| Postgres 15 | `localhost:5432` (db: `aerodelay`) |
| Airflow UI | http://localhost:8080 (`admin` / `admin`) |
| Schemas | `raw`, `meta`, `staging` |

## Current data coverage (local)

| Dataset | Loaded | Notes |
|---------|--------|-------|
| BTS flights | 2025-01 → 2025-04 (~1.69M rows) | Full 2023–2025 backfill script exists; **not run to completion** |
| Weather | ATL/ORD/LAX Jan 2025 + DEN Feb 2025 (~19.7K rows) | Full 45×36-month backfill script exists; **not run to completion** |

Details: [`docs/DATA_COVERAGE.md`](docs/DATA_COVERAGE.md)

## Quickstart (Day 1)

```bash
# 1. Environment
cp .env.example .env
# Edit .env — set POSTGRES_PASSWORD to something local-only

# 2. Fernet key + start stack
bash scripts/generate_fernet_key.sh   # needs: pip install cryptography (or use python3 -c with cryptography)
bash scripts/dev_up.sh

# 3. Verify
bash scripts/check_stack.sh
```

Or with Make:

```bash
make env
# edit .env
make fernet
make up
make check
```

## Day 1 completion checklist

- [ ] `.env` created from `.env.example` (password set, Fernet key set)
- [ ] `docker compose up -d --build` succeeds
- [ ] Postgres healthy; `\dn` shows `raw` and `meta`
- [ ] Airflow UI loads at http://localhost:8080
- [ ] DAG `aerodelay_day1_healthcheck` visible in Airflow
- [ ] `psql` or `docker compose exec postgres psql` connects

## Project layout

```
airflow/dags/          Airflow DAGs
dbt/                   dbt project (Week 1 Day 7)
ingestion/bts/         BTS download/load (Week 1 Day 3+)
ingestion/weather/       Weather download/load (Week 1 Day 5+)
dashboard/             Streamlit (Week 6)
docker/                Postgres init, Airflow image
docs/                  Data dictionary, architecture
scripts/               dev_up, health checks
```

## Data sources

- **BTS On-Time Performance** — monthly flight records (partial 2025 load locally; full 2023–2025 via backfill)
- **ASOS/METAR** — airport weather observations (sparse dev load; full backfill available)

Coverage details: [`docs/DATA_COVERAGE.md`](docs/DATA_COVERAGE.md)
