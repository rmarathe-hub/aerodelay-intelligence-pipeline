# Week 1 Day 4 — BTS backfill + Airflow DAG

## Files created / updated

| Path | Purpose |
|------|---------|
| `ingestion/bts/backfill.py` | Loop year-month range: download + load |
| `airflow/dags/ingest_bts.py` | Airflow DAG for one month ingest |
| `scripts/backfill_bts.sh` | Run full 2023–2025 backfill |
| `scripts/verify_ingest_bts_dag.sh` | Confirm DAG appears in Airflow |
| `docs/ingest_issues.md` | Log failed months / downloads |
| `ingestion/common/db.py` | Fixed Postgres host for Airflow vs laptop |

## Your manual steps

### 1. Verify Airflow picks up the new DAG

```bash
bash scripts/verify_ingest_bts_dag.sh
```

Expected: `ingest_bts` listed, no import errors.

### 2. Trigger one month from Airflow UI (optional)

1. Open http://localhost:8080
2. Unpause **`ingest_bts`**
3. Click **Trigger DAG w/ config**
4. Set params: `{"year": 2025, "month": 2}` (or use Trigger and edit params)
5. Watch task `ingest_bts_month` turn green

Or trigger from CLI:

```bash
docker compose exec airflow-webserver airflow dags trigger ingest_bts \
  --conf '{"year": 2025, "month": 2}'
```

### 3. Run multi-year backfill (long — needs network)

Default production scope **2023-01 → 2025-12**:

```bash
bash scripts/backfill_bts.sh
```

Custom range:

```bash
python -m ingestion.bts.backfill --start-year 2024 --start-month 1 --end-year 2024 --end-month 12
```

Load existing ZIPs only (no download):

```bash
python -m ingestion.bts.backfill --start-year 2023 --start-month 1 --end-year 2025 --end-month 12 --no-download
```

### 4. Spot-check counts

```bash
docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT year_month, COUNT(*) FROM raw.bts_flights GROUP BY 1 ORDER BY 1;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT status, COUNT(*) FROM meta.bts_ingest_log GROUP BY 1;"
```

### 5. Review failures

```bash
cat docs/ingest_issues.md
```

## Day 4 exit criteria

- [ ] `ingest_bts` DAG visible in Airflow (no import errors)
- [ ] Can trigger one month successfully (UI or CLI)
- [ ] Backfill script runs for at least one new month beyond Jan 2025 sample
- [ ] Row counts queryable by `year_month`
- [ ] Failures logged to `docs/ingest_issues.md`

## Idempotency

Same as Day 3: each month reload deletes `year_month` rows before insert.

## Commit (you only — after tests pass)

```bash
git add ingestion/bts/backfill.py ingestion/common/db.py \
        airflow/dags/ingest_bts.py scripts/backfill_bts.sh \
        scripts/verify_ingest_bts_dag.sh docs/ingest_issues.md docs/DAY4_CHECKLIST.md \
        Makefile
git commit -m "Add BTS backfill script and ingest_bts Airflow DAG"
git push
```

## Day 5 preview

Weather raw layer: `ingestion/weather/download.py`, `load.py`, `ingest_weather` DAG.
