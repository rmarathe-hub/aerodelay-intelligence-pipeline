# OCI materialization (optional)

Disposable **Oracle Cloud Always Free A1** VM for full-history dbt materialization in fewer steps than local monthly chunks.

## Status

OCI **VM.Standard.A1.Flex** capacity is often unavailable (e.g. Ashburn AD-1/2/3 out of capacity). When blocked, use **`docs/LOCAL_FULL_MATERIALIZATION.md`** instead — same scale proof, $0, no cloud dependency.

## When OCI helps

- A1 instance available in your home region
- Want Postgres + dbt on native Linux (12 GB RAM + 16 GB swap) without Docker Desktop limits
- Prefer rsync `data/raw/` + staged load over 36 local monthly dbt runs

## When local monthly is better

- A1 out of capacity (current situation)
- Raw data already on Mac
- OK with 3–8 hour overnight chunked run

## OCI steps (when capacity returns)

See `docs/DAY37_CHECKLIST.md`:

1. A1 Flex 2 OCPU / 12 GB + 150 GB block volume
2. `scripts/oci_vm_bootstrap.sh` on VM
3. rsync raw (Option C from Day 5)
4. `check_full_materialization_ready.sh --stage 2025` on VM
5. Either single full-refresh **or** `materialize_monthly.sh` on VM
6. Export parquet + terminate VM

## Honest portfolio story

| What you did | What to say |
|--------------|-------------|
| Local monthly materialization | Full marts built locally in monthly incremental batches |
| OCI batch VM | Full marts built on disposable Always Free A1 |
| Neither (Jan sample only) | Raw at scale; marts proven on Jan 2025 sample + CI |

Do not claim OCI unless you actually ran materialization there.

## Artifacts after either path

- `intermediate.int_flights__weather_at_departure` ~15–16M rows
- `marts.fct_flights` ~15–16M rows
- Update `docs/DATA_COVERAGE.md` with verified counts
- Optional: `make export-dashboard-demo` for richer parquet (keep Git size <50 MB per file)
