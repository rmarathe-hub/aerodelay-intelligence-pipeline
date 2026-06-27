# Week 1 Day 5 — Weather raw ingestion

## Files created / updated

| Path | Purpose |
|------|---------|
| `ingestion/weather/config.py` | IEM URL params, station list, paths |
| `ingestion/weather/download.py` | Download one station-month CSV from Iowa Mesonet |
| `ingestion/weather/load.py` | Load CSV → `raw.weather_observations` |
| `ingestion/weather/logging.py` | Run logs → `meta.weather_ingest_log` |
| `airflow/dags/ingest_weather.py` | Airflow DAG for one month (all stations or one) |
| `scripts/load_weather_sample.sh` | Load ATL/ORD/LAX January 2025 samples |
| `scripts/test_weather_idempotency.sh` | Verify rerun does not duplicate rows |
| `scripts/verify_ingest_weather_dag.sh` | Confirm DAG appears in Airflow |
| `ingestion/common/paths.py` | Added `WEATHER_RAW_DIR`, `STATION_MAP_CSV` |

## Your manual steps

### 1. Install ingestion dependencies (if not already)

```bash
cd /Users/rohitmarathe/AeroDelay_Intel_Pipeline
python -m pip install -r ingestion/requirements.txt
```

### 2. Ensure Docker/Postgres is running

```bash
docker compose ps
# or: bash scripts/dev_up.sh
```

### 3. Load January 2025 weather samples (ATL, ORD, LAX)

```bash
bash scripts/load_weather_sample.sh
```

Or one station:

```bash
python -m ingestion.weather.load \
  --year 2025 --month 1 --station ATL \
  --csv-path "data/samples/weather_ATL_2025_jan.csv"
```

### 4. Verify row counts

```bash
docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT station, year_month, COUNT(*) FROM raw.weather_observations GROUP BY 1, 2 ORDER BY 1;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT status, COUNT(*) FROM meta.weather_ingest_log GROUP BY 1;"
```

### 5. Test idempotency

```bash
bash scripts/test_weather_idempotency.sh
```

Expected: row count after run 2 equals run 1 (not doubled).

### 6. Verify Airflow DAG

```bash
make verify-ingest-weather-dag
```

### 7. Trigger one month from Airflow (optional — needs network)

1. Open http://localhost:8080
2. Unpause **`ingest_weather`**
3. Trigger with params: `{"year": 2025, "month": 1, "station": "ATL"}` (or omit `station` for all 45)

CLI:

```bash
docker compose exec airflow-webserver airflow dags trigger ingest_weather \
  --conf '{"year": 2025, "month": 1, "station": "ATL"}'
```

### 8. Optional — download from Iowa Mesonet (needs network)

```bash
python -m ingestion.weather.download --station ATL --year 2025 --month 1
python -m ingestion.weather.load --year 2025 --month 1 --station ATL
```

## Day 5 exit criteria

- [ ] `raw.weather_observations` table exists with Mesonet columns + metadata
- [ ] ATL, ORD, LAX January 2025 samples loaded
- [ ] `meta.weather_ingest_log` shows successful runs
- [ ] Rerun same station-month → no duplicate rows
- [ ] `ingest_weather` DAG visible in Airflow (no import errors)

## Current local coverage (verified)

Weather ingest tooling is implemented, but the local warehouse holds only **ATL/ORD/LAX Jan 2025 + DEN Feb 2025** (~19.7K rows). Full 45-station backfill is optional. See [`DATA_COVERAGE.md`](DATA_COVERAGE.md).

## Idempotency rule

Reload deletes all rows for `(station, year_month)` before insert:

```sql
DELETE FROM raw.weather_observations
WHERE station = 'ATL' AND year_month = '2025-01';
```

## Commit (you only — after tests pass)

```bash
git add ingestion/weather/ ingestion/common/paths.py \
        airflow/dags/ingest_weather.py scripts/load_weather_sample.sh \
        scripts/test_weather_idempotency.sh scripts/verify_ingest_weather_dag.sh \
        docs/DAY5_CHECKLIST.md Makefile
git commit -m "Add weather download and load pipeline for raw.weather_observations"
git push
```

Do **not** commit `.env` or `data/`.

## Day 6 preview

Weather backfill script + multi-station month loop (mirrors BTS `backfill.py`).
