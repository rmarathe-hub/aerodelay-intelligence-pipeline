# Week 1 Day 3 — BTS raw ingestion

## Files created

| Path | Purpose |
|------|---------|
| `ingestion/bts/download.py` | Download monthly BTS ZIP from TranStats |
| `ingestion/bts/load.py` | Load CSV → `raw.bts_flights` (45-airport filter) |
| `ingestion/bts/logging.py` | Run logs → `meta.bts_ingest_log` |
| `ingestion/bts/config.py` | URLs, paths, airport list loader |
| `ingestion/common/db.py` | Postgres connection from `.env` |
| `ingestion/requirements.txt` | `psycopg2-binary`, `requests` |
| `scripts/load_bts_sample.sh` | Load January 2025 sample ZIP |
| `scripts/test_bts_idempotency.sh` | Verify rerun does not duplicate rows |

## Your manual steps

### 1. Install ingestion dependencies (one time)

```bash
cd /Users/rohitmarathe/AeroDelay_Intel_Pipeline
python -m pip install -r ingestion/requirements.txt
```

### 2. Ensure Docker/Postgres is running

```bash
docker compose ps
# or: bash scripts/dev_up.sh
```

### 3. Load January 2025 sample (uses your existing ZIP)

```bash
bash scripts/load_bts_sample.sh
```

Or directly:

```bash
python -m ingestion.bts.load \
  --year 2025 \
  --month 1 \
  --zip-path "data/samples/On_Time_Reporting_Carrier_On_Time_Performance_1987_present_2025_1 (2).zip"
```

### 4. Verify row counts

```bash
docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT year_month, COUNT(*) FROM raw.bts_flights GROUP BY 1;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT \"Origin\", COUNT(*) FROM raw.bts_flights GROUP BY 1 ORDER BY 2 DESC LIMIT 10;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT * FROM meta.bts_ingest_log ORDER BY started_at DESC LIMIT 3;"
```

### 5. Test idempotency

```bash
bash scripts/test_bts_idempotency.sh
```

Expected: row count after run 2 equals run 1 (not doubled).

### 6. Optional — download from TranStats (needs network)

```bash
python -m ingestion.bts.download --year 2025 --month 1
python -m ingestion.bts.load --year 2025 --month 1
```

## Day 3 exit criteria

- [ ] `raw.bts_flights` table exists with BTS columns + metadata
- [ ] January 2025 sample loaded
- [ ] Only 45 origin airports present in loaded data
- [ ] `meta.bts_ingest_log` shows successful run
- [ ] Rerun same month → no duplicate rows

## Idempotency rule

Reload deletes all rows for `year_month` before insert:

```sql
DELETE FROM raw.bts_flights WHERE year_month = '2025-01';
```

## Commit (you only — after tests pass)

```bash
git add ingestion/ scripts/load_bts_sample.sh scripts/test_bts_idempotency.sh docs/DAY3_CHECKLIST.md Makefile
git commit -m "Add BTS download and load pipeline for raw.bts_flights"
git push
```

Do **not** commit `.env` or `data/`.
