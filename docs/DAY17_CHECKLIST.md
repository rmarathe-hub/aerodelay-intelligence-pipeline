# Week 3 Day 17 — Join validation analyses

## Goal

Analyze nearest-obs join quality on the dev subset. Compare match rates to Day 13 feasibility and diagnose unmatched flights.

**Scope:** Loaded station-months only — ATL/ORD/LAX Jan 2025, DEN Feb 2025.

---

## Files created

| Path | Purpose |
|------|---------|
| `dbt/analyses/weather_join_coverage.sql` | Match rate by airport, date, hour |
| `dbt/analyses/weather_obs_lag_distribution.sql` | Lag percentiles, timing split, histogram |
| `dbt/analyses/weather_join_unmatched.sql` | Worst days + unmatched date samples |
| `docs/DAY17_CHECKLIST.md` | This checklist |

---

## How to run

```bash
bash scripts/dbt_run.sh compile

# Airport summary only (fast)
docker compose exec -T postgres psql -U aerodelay -d aerodelay -c "
$(grep -A999 '^with scope' dbt/target/compiled/aerodelay/analyses/weather_join_coverage.sql | sed '/^select grain/,$d')
select airport_code, year_month, flights, matched_flights, match_pct from airport_summary order by 1;
"

# Full analyses (~90s each)
docker compose exec -T postgres psql -U aerodelay -d aerodelay \
  -f dbt/target/compiled/aerodelay/analyses/weather_obs_lag_distribution.sql

docker compose exec -T postgres psql -U aerodelay -d aerodelay \
  -f dbt/target/compiled/aerodelay/analyses/weather_join_unmatched.sql
```

Filter coverage output in psql: `WHERE grain = 'airport'` / `'date'` / `'hour'`.

---

## Results (verified 2026-06-27)

### Nearest-obs vs Day 13 feasibility (airport summary)

| Airport | Month | Nearest-obs | Day 13 candidate | Delta |
|---------|-------|-------------|------------------|-------|
| ATL | 2025-01 | **95.99%** | 95.99% | 0.00 |
| ORD | 2025-01 | **96.21%** | 96.21% | 0.00 |
| LAX | 2025-01 | **95.80%** | 95.80% | 0.00 |
| DEN | 2025-02 | **95.23%** | 95.23% | 0.00 |

Nearest-obs match rate equals Day 13 feasibility exactly — every flight with a candidate obs in ±2h gets a nearest match.

### Lag distribution (matched flights)

| Airport | p50 | p90 | p99 | avg | min | max |
|---------|-----|-----|-----|-----|-----|-----|
| ATL | 0 min | 2 min | 2 min | 0.27 | -5 | 120 |
| ORD | 2 min | 23 min | 30 min | 1.32 | -29 | 119 |
| LAX | 0 min | 24 min | 30 min | 0.72 | -29 | 112 |
| DEN | 0 min | 2 min | 5 min | 0.29 | -29 | 119 |

- No systematic timezone offset (no cluster at ±300 min).
- ATL/DEN dense obs: median 0, p90 ≤ 2 min.
- ORD/LAX sparse samples: wider spread (p90 ~23–24 min) due to ~hourly obs gaps, still within window.

**Timing split (obs before / at / after dep):** ATL 8,569 / 5,835 / 8,520 — balanced around departure due to 5-min ASOS cadence and symmetric window.

### Unmatched flights (worst days)

All low-match days are **month-end weather coverage gaps** (partial downloads):

| Airport | Date | Match % | Cause |
|---------|------|---------|-------|
| ATL | 2025-01-31 | 0.00% | No weather after Jan 30 23:55 UTC |
| ATL | 2025-01-30 | 85.61% | Partial last weather day |
| LAX | 2025-01-31 | 0.00% | Same |
| LAX | 2025-01-30 | 74.26% | Partial last weather day |
| DEN | 2025-02-28 | 0.00% | No weather after Feb 27 |
| DEN | 2025-02-27 | 76.76% | Partial last weather day |
| ORD | 2025-01-31 | 0.00% | Same pattern |
| ORD | 2025-01-30 | 87.02% | Partial last weather day |

No unmatched flights on fully-covered dates suggest a join logic bug.

---

## Day 17 exit criteria

- [x] Loaded station-month match rates align with Day 13 feasibility (identical — 0% delta)
- [x] Unmatched flights on loaded months explained by month-end gaps / sparse ORD-LAX samples
- [x] Lag distribution sane (median 0–2 min; no ±300 min timezone bug)
- [x] Findings documented in analysis comments and this checklist

---

## Commit (you only — after review)

```bash
git add dbt/analyses/weather_join_coverage.sql \
        dbt/analyses/weather_obs_lag_distribution.sql \
        dbt/analyses/weather_join_unmatched.sql \
        docs/DAY17_CHECKLIST.md
git commit -m "Add weather join validation analyses for loaded station-months"
git push
```

## Day 18 preview

Marts schema + base `fct_flights` fact table.
