# Week 3 Day 16 — Join tests + scoped match coverage

## Files created / updated

| Path | Purpose |
|------|---------|
| `dbt/tests/assert_weather_join_row_count.sql` | Row count = departure context |
| `dbt/tests/assert_weather_join_window.sql` | Matched rows within ±2h window |
| `dbt/tests/assert_weather_join_coverage_loaded_months.sql` | ≥90% match on loaded station-months |
| `docs/DAY16_CHECKLIST.md` | This checklist |

## Coverage rule (important)

**Match rate ≥90% on loaded weather station-months only:**

| Airport | Month |
|---------|-------|
| ATL | 2025-01 |
| ORD | 2025-01 |
| LAX | 2025-01 |
| DEN | 2025-02 |

**Do not require ≥90% across all flights until full weather backfill is complete.**

## Your manual steps

### 1. Run join tests

```bash
bash scripts/dbt_run.sh test --select int_flights__weather_at_departure assert_weather_join_row_count assert_weather_join_window assert_weather_join_coverage_loaded_months
```

### 2. Document global match rate (not gated)

```bash
docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT weather_match_status, COUNT(*),
          ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
   FROM intermediate.int_flights__weather_at_departure GROUP BY 1;"
```

## Day 16 exit criteria

- [x] All join grain/window/row-count tests pass (**8/8**)
- [x] Match rate ≥90% on **each** loaded station-month (see below)
- [x] Global all-flight match rate documented but **not** gated until backfill

### Loaded station-month match rates (gated)

| Airport | Month | Flights | Matched | Match % |
|---------|-------|---------|---------|---------|
| ATL | 2025-01 | 23,881 | 22,924 | **95.99%** |
| ORD | 2025-01 | 21,643 | 20,822 | **96.21%** |
| LAX | 2025-01 | 15,157 | 14,520 | **95.80%** |
| DEN | 2025-02 | 22,816 | 21,727 | **95.23%** |

### Global match rate (documented only — not gated)

| Status | Count | % |
|--------|-------|---|
| matched | 80,335 | 4.76% |
| no_obs_in_window | 1,606,043 | 95.24% |

Low global rate is expected until full 45×36-month weather backfill.

## Commit (you only — after tests pass)

```bash
git add dbt/tests/assert_weather_join_row_count.sql \
        dbt/tests/assert_weather_join_window.sql \
        dbt/tests/assert_weather_join_coverage_loaded_months.sql \
        docs/DAY16_CHECKLIST.md
git commit -m "Add weather join tests with coverage scoped to loaded station-months"
git push
```

## Day 17 preview

Validation analyses: lag distribution, coverage by date/hour, unmatched diagnostics.
