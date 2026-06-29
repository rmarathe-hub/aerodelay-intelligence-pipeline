# Flagship Day 6 — Full materialization preflight

GO/NO-GO check before starting long dbt jobs on OCI (or smoke test locally).

## Deliverables

| Path | Purpose |
|------|---------|
| `scripts/check_full_materialization_ready.sh` | Disk, RAM, swap, raw counts, dbt config, planned command |
| `docs/DAY36_CHECKLIST.md` | This checklist |

## Run preflight

**Local smoke test** (expect NO-GO on resources — Mac Docker is not the target host):

```bash
make up
make check-materialization-ready
```

**OCI VM** (after raw load, expect GO):

```bash
bash scripts/check_full_materialization_ready.sh --stage 2025
# later:
bash scripts/check_full_materialization_ready.sh --stage 2024-2025
bash scripts/check_full_materialization_ready.sh --stage full
```

## What the script checks

| Bucket | Checks |
|--------|--------|
| **Resources** | RAM ≥ 10 GB, swap ≥ 8 GB, workspace disk ≥ 40 GB free; blocks macOS Docker unless `--allow-local` |
| **Data** | `raw.bts_flights` / `raw.weather_observations` row counts vs `--stage` thresholds |
| **Config** | `dev_year_month` unset in env; seed file present; prints planned dbt command **without** `--vars` |

## Planned dbt command (printed by script)

```bash
bash scripts/dbt_run.sh run \
  --select +int_flights__weather_at_departure fct_flights \
    agg_delay_by_airport_hour agg_delay_by_weather_bucket agg_delay_by_carrier_route \
  --full-refresh \
  --threads 1
```

## Local run result (2026-06-29, this Mac)

With `--stage full` and Docker Postgres up:

| Bucket | Result | Reason |
|--------|--------|--------|
| DATA | **GO** | 15.9M BTS rows, 36 months; 14.4M weather rows, 1584 station-months |
| RESOURCES | **NO-GO** | macOS Docker host (use OCI VM) |
| CONFIG | **GO** | `dev_year_month` unset |
| **OVERALL** | **NO-GO** | Expected — data ready for OCI handoff, not local full join |

Re-run on OCI after Day 7–8 with `--stage 2025` for first materialize.

## Verify Day 6

- [x] `scripts/check_full_materialization_ready.sh` exists
- [x] Prints disk, RAM, swap, raw counts, `dev_year_month` status, planned dbt command
- [x] `make check-materialization-ready` runs against Docker Postgres
- [x] Local Mac returns NO-GO (resources) with DATA GO — safe to proceed to OCI Days 7–8

## Next (Day 7)

- OCI console + VM bootstrap — see `docs/DAY37_CHECKLIST.md`
