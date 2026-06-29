# Week 6 Day 32 — GitHub Actions CI

## Deliverables

| Path | Purpose |
|------|---------|
| `.github/workflows/dbt-ci.yml` | CI on push/PR to `main` |
| `scripts/ci_setup_postgres.sh` | Apply init DDL to Postgres service |
| `scripts/ci_load_jan2025_sample.sh` | Download + load Jan 2025 BTS + weather |
| `scripts/ci_dbt_test_jan2025.sh` | dbt run + 13 critical tests |
| `README.md` | CI badge + local repro commands |

## What CI runs

| Step | Duration (approx) |
|------|-------------------|
| Postgres init | ~10s |
| BTS Jan 2025 download + load | ~2–5 min |
| Weather 45× Jan 2025 | ~5–15 min |
| dbt run (409K join) | ~5–10 min |
| dbt test (13 tests) | ~10s |

**Total:** ~15–30 min · timeout 45 min

## Verify Day 2

- [ ] Push branch → GitHub Actions workflow starts
- [ ] Badge in README shows passing (after merge to `main`)
- [ ] Local repro works with Docker Postgres up:
  ```bash
  make ci-setup-postgres && make ci-load-jan2025 && make ci-dbt-test-jan2025
  ```

## Notes

- CI does **not** use Docker Compose — only Postgres service container
- Same test selection as `scripts/bulletproof_jan2025.sh` (minus docker row-count echo)
- Full 71-test suite still **not** run in CI (by design)

## Next (Day 33)

- Portfolio polish — dashboard screenshot, repo topics
- Paste live Streamlit URL into README
