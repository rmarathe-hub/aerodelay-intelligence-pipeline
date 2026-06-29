# Flagship Day 5 — Mac data inventory (OCI transfer path)

Choose how raw data gets onto the disposable OCI VM before full dbt materialization.

## Deliverables

| Path | Purpose |
|------|---------|
| `scripts/inventory_mac_data.sh` | Postgres + disk inventory + transfer recommendation |
| `docs/DAY35_CHECKLIST.md` | This checklist with recorded results |

## Run inventory

```bash
make up
make inventory-mac-data
```

Optional pg_dump size estimate (~1–3 min):

```bash
bash scripts/inventory_mac_data.sh --with-pgdump-estimate
```

## Recorded results (2026-06-29, this Mac)

### Postgres raw

| Source | Rows | Coverage |
|--------|------|----------|
| `raw.bts_flights` | **15,866,662** | 36 months (`2023-01` … `2025-12`) |
| `raw.weather_observations` | **14,353,070** | 1,584 station-months, **44 stations** |

### On-disk raw

| Path | Size | Files |
|------|------|-------|
| `data/raw/bts/` | **1.0 GB** | **36** ZIPs (2023–2025) |
| `data/raw/weather/` | **2.4 GB** | **1,620** CSVs (45 stations × 36 months) |

### 2025-only staging subset (Day 8 first load)

| Path | Size | Files |
|------|------|-------|
| `data/raw/bts/*_2025_*.zip` | ~**345 MB** | 12 |
| `data/raw/weather/weather_*_2025_*.csv` | ~**804 MB** | 540 |

### pg_dump reference (Option B)

`pg_dump -Fc -n raw -n meta` ≈ **305 MB** (faster upload, skips file-based load path).

### Known gap

- **HNL** weather CSVs exist on disk (36 files) but are **not loaded** in local Postgres (44 vs 45 stations). Intentional — HNL→PHNL mapping deferred. OCI load can skip HNL or fix mapping later.

### dbt local state

| Model | Rows | Notes |
|-------|------|-------|
| `marts.fct_flights` | 408,974 | Jan 2025 dev sample only |
| `intermediate.int_flights__weather_at_departure` | 408,974 | same scope |

Full materialize (no `dev_year_month`) is planned on OCI Days 9–11.

## Decision

| Option | When | This Mac |
|--------|------|----------|
| **C — rsync `data/raw/`** | ZIPs + CSVs complete on disk | **Chosen** |
| B — `pg_dump -n raw -n meta` | Postgres complete, disk gaps | Not needed (~305 MB if bandwidth-limited) |
| A — re-backfill on VM | Gaps in both | Not needed |

**Transfer method: Option C (rsync)**

Rationale:

1. All 36 BTS ZIPs and 1,620 weather CSVs are on disk — reproducible VM load via `--no-download` backfill.
2. Staged OCI load is easy: rsync **2025-only** first (~1.1 GB), validate, then add 2024 and 2023.
3. pg_dump is smaller (~305 MB) but bypasses the same ingestion path you use locally and in CI.

## Verify Day 5

- [x] `make inventory-mac-data` runs against Docker Postgres
- [x] BTS: 36 months in Postgres, 36 ZIPs on disk
- [x] Weather: 1,584 station-months in Postgres, 1,620 CSVs on disk (HNL on disk only)
- [x] Transfer path documented: **Option C — rsync**
- [x] 2025 staging subset sizes noted for Day 8

## Next (Day 6)

- `make check-materialization-ready` — see `docs/DAY36_CHECKLIST.md`
