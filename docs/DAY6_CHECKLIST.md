# Week 1 Day 6 — Weather backfill

## Files created / updated

| Path | Purpose |
|------|---------|
| `ingestion/weather/backfill.py` | Loop year-month × station: download + load |
| `scripts/backfill_weather.sh` | Run full 2023–2025 backfill (45 stations) |
| `docs/DAY6_CHECKLIST.md` | This checklist |

## Your manual steps

### 1. Quick test — one station, one month (needs network)

```bash
cd /Users/rohitmarathe/AeroDelay_Intel_Pipeline
python -m ingestion.weather.backfill \
  --start-year 2025 --start-month 2 --end-year 2025 --end-month 2 \
  --station DEN
```

### 2. Load existing CSVs only (no download)

If you already have files under `data/raw/weather/`:

```bash
python -m ingestion.weather.backfill \
  --start-year 2025 --start-month 1 --end-year 2025 --end-month 1 \
  --station ATL --no-download
```

### 3. Full production backfill (long — needs network)

Default **2023-01 → 2025-12**, all **45 stations**:

```bash
bash scripts/backfill_weather.sh
```

Custom range:

```bash
python -m ingestion.weather.backfill \
  --start-year 2024 --start-month 1 --end-year 2024 --end-month 12
```

Multiple stations only:

```bash
python -m ingestion.weather.backfill \
  --start-year 2025 --start-month 1 --end-year 2025 --end-month 1 \
  --station ATL --station ORD --station LAX
```

### 4. Spot-check counts

```bash
docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT station, year_month, COUNT(*) FROM raw.weather_observations GROUP BY 1, 2 ORDER BY 1, 2;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT status, COUNT(*) FROM meta.weather_ingest_log GROUP BY 1;"
```

### 5. Review failures

```bash
cat docs/ingest_issues.md
```

### 6. Optional — trigger one month in Airflow

All 45 stations for one month:

```bash
docker compose exec airflow-webserver airflow dags trigger ingest_weather \
  --conf '{"year": 2025, "month": 2}'
```

## Day 6 exit criteria

- [ ] Backfill script runs for at least one new station-month beyond Jan 2025 samples
- [ ] Row counts queryable by `station` + `year_month`
- [ ] Failures logged to `docs/ingest_issues.md`
- [ ] Idempotent rerun of same station-month does not duplicate rows

## Idempotency

Same as Day 5 — each station-month reload deletes existing rows first:

```sql
DELETE FROM raw.weather_observations
WHERE station = 'DEN' AND year_month = '2025-02';
```

## Scale note

Full backfill = **36 months × 45 stations = 1,620 station-month downloads**. Run overnight or in batches by year:

```bash
python -m ingestion.weather.backfill --start-year 2023 --start-month 1 --end-year 2023 --end-month 12
python -m ingestion.weather.backfill --start-year 2024 --start-month 1 --end-year 2024 --end-month 12
python -m ingestion.weather.backfill --start-year 2025 --start-month 1 --end-year 2025 --end-month 12
```

## Commit (you only — after tests pass)

```bash
git add ingestion/weather/backfill.py scripts/backfill_weather.sh \
        docs/DAY6_CHECKLIST.md Makefile
git commit -m "Add weather backfill script for multi-station ASOS ingest"
git push
```

## Day 7 preview

dbt project: staging models for `raw.bts_flights` and `raw.weather_observations`.
