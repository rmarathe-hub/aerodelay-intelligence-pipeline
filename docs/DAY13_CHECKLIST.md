# Week 2 Day 13 — Join feasibility validation

## Goal

Prove flights and weather **can** join on `(origin airport, UTC time)` using loaded dev data — **without** building the nearest-observation join yet.

**Loaded station-months analyzed:** ATL Jan 2025, ORD Jan 2025, LAX Jan 2025, DEN Feb 2025.

**Match rule:** A flight is a **candidate match** if ≥1 weather observation exists at the same airport within **±2 hours** of `dep_time_utc`.

---

## Files created

| Path | Purpose |
|------|---------|
| `dbt/analyses/join_feasibility_atl.sql` | ATL Jan 2025 summary |
| `dbt/analyses/join_feasibility_den.sql` | DEN Feb 2025 summary |
| `dbt/analyses/join_feasibility_coverage.sql` | All 4 airports — by airport, date, hour |
| `dbt/analyses/dep_time_distribution.sql` | UTC hour distribution + sanity outliers |
| `docs/DAY13_CHECKLIST.md` | This checklist |

---

## How to run

```bash
bash scripts/dbt_run.sh compile

# Airport summaries
docker compose exec -T postgres psql -U aerodelay -d aerodelay \
  -f dbt/target/compiled/aerodelay/analyses/join_feasibility_atl.sql

docker compose exec -T postgres psql -U aerodelay -d aerodelay \
  -f dbt/target/compiled/aerodelay/analyses/join_feasibility_den.sql

# Full coverage (airport + date + hour grains — ~30–60s)
docker compose exec -T postgres psql -U aerodelay -d aerodelay \
  -f dbt/target/compiled/aerodelay/analyses/join_feasibility_coverage.sql

# Hour distribution + timezone sanity
docker compose exec -T postgres psql -U aerodelay -d aerodelay \
  -f dbt/target/compiled/aerodelay/analyses/dep_time_distribution.sql
```

Filter coverage output in psql:

```sql
-- airport summary only
WHERE grain = 'airport';

-- worst days
WHERE grain = 'date' ORDER BY match_pct;

-- worst UTC hours
WHERE grain = 'hour' AND airport_code = 'ORD' ORDER BY match_pct;
```

---

## Results (verified 2026-06-27)

### Airport-level candidate match coverage

| Airport | Month | Flights | Matched | Match % | Weather obs | Weather UTC range |
|---------|-------|---------|---------|---------|-------------|-------------------|
| ATL | 2025-01 | 23,881 | 22,924 | **95.99%** | 9,415 | Jan 1 00:00 → Jan 30 23:55 |
| ORD | 2025-01 | 21,643 | 20,822 | **96.21%** | 895 | Jan 1 00:51 → Jan 30 23:51 |
| LAX | 2025-01 | 15,157 | 14,520 | **95.80%** | 794 | Jan 1 00:00 → Jan 30 23:53 |
| DEN | 2025-02 | 22,816 | 21,727 | **95.23%** | 8,496 | Feb 1 00:00 → Feb 27 23:55 |

All four station-months exceed the **≥90%** exit threshold.

### Coverage gaps (by date)

Low match rates cluster on **calendar days after weather data ends** (partial-month downloads, not timezone bugs):

| Airport | Date | Flights | Match % | Cause |
|---------|------|---------|---------|-------|
| ATL | 2025-01-31 | 837 | 0.00% | No weather after Jan 30 23:55 UTC |
| ATL | 2025-01-30 | 834 | 85.61% | Partial last weather day |
| LAX | 2025-01-31 | 506 | 0.00% | Same tail gap |
| LAX | 2025-01-30 | 509 | 74.26% | Partial last weather day |
| DEN | 2025-02-28 | 884 | 0.00% | No weather after Feb 27 23:55 UTC |
| DEN | 2025-02-27 | 882 | 76.76% | Partial last weather day |

Most other dates show **100%** candidate match coverage.

### Coverage by UTC hour

Hour-level match rates stay **≥93%** even for sparse ORD/LAX samples (895 / 794 obs). Lowest ORD hours (~93%) still pass the 90% bar. Full hour breakdown: run `join_feasibility_coverage.sql` with `grain = 'hour'`.

`dep_time_distribution.sql` shows expected departure volume peaks (ATL afternoon/evening UTC = morning/midday Eastern local).

### Timezone sanity

| Airport | Flights | Before 1970 | After 2030 | Null dep_time_utc |
|---------|---------|-------------|------------|-------------------|
| ATL | 23,881 | 0 | 0 | 0 |
| ORD | 21,643 | 0 | 0 | 0 |
| LAX | 15,157 | 0 | 0 | 0 |
| DEN | 22,816 | 0 | 0 | 0 |

No systematic timezone offset detected.

---

## Findings

1. **Join is feasible** on the dev subset — all four loaded station-months exceed 95% candidate match at airport level.
2. **ORD/LAX sparse samples** (~900 obs vs ~9K for ATL/DEN) still achieve ~96% because the ±2h window is wide relative to obs spacing.
3. **Unmatched flights** are mostly on the **last 1–2 calendar days** of each month where weather files end early (Jan 30–31, Feb 27–28). Fix: complete station-month weather backfill, not join logic.
4. **UTC conversion looks correct** — no outlier timestamps; hour distributions align with expected US hub departure patterns.

---

## Day 13 exit criteria

- [x] ≥90% of ATL Jan flights have weather obs within ±2h (**95.99%**)
- [x] DEN Feb spot-check passes (**95.23%**)
- [x] ORD Jan and LAX Jan analyzed (**96.21%**, **95.80%**)
- [x] Coverage reported by airport, date, and hour (`join_feasibility_coverage.sql`)
- [x] No systematic timezone bugs
- [x] Findings documented in analysis comments and this checklist

---

## Commit (you only — after review)

```bash
git add dbt/analyses/join_feasibility_atl.sql \
        dbt/analyses/join_feasibility_den.sql \
        dbt/analyses/join_feasibility_coverage.sql \
        dbt/analyses/dep_time_distribution.sql \
        docs/DAY13_CHECKLIST.md
git commit -m "Add join feasibility analyses for loaded flight-weather station-months"
git push
```

## Day 14 preview

Week 2 wrap-up: full intermediate run, `weather_join_methodology.md` draft, `DAY14_CHECKLIST.md`.
