# Week 4 Day 28 — Exit review (Phase C bulletproof)

## Goal

Confirm Week 4 deliverables are complete: aggregation marts, analyses, bulletproof validation on Jan 2025 sample.

---

## Week 4 deliverables

| Phase | Deliverable | Status |
|-------|-------------|--------|
| A | `agg_delay_by_airport_hour` + tests | ✅ |
| A | `agg_delay_by_weather_bucket` + tests | ✅ |
| A | `agg_delay_by_carrier_route` + tests | ✅ |
| A | `dev_year_month` filter + Plan B materialize | ✅ |
| B | 4 delay/coverage analyses | ✅ |
| B | Headline findings (`DAY24_CHECKLIST.md`) | ✅ |
| C | `assert_weather_join_coverage_jan2025` test | ✅ |
| C | `scripts/bulletproof_jan2025.sh` | ✅ |
| C | `docs/DATA_COVERAGE.md` updated | ✅ |

---

## Bulletproof pass

```bash
bash scripts/bulletproof_jan2025.sh
```

**Last verified:** 2026-06-29

| Check | Result |
|-------|--------|
| Critical dbt tests | **33/33 PASS** (~6s) |
| Join row parity | PASS |
| Join window | PASS |
| Jan 2025 coverage (excl. HNL) | PASS (≥90% all airports) |
| All 3 agg marts | PASS (24 tests) |
| Coverage analysis | Overall **95.0%** match; HNL **0%** (known) |

Log: `logs/bulletproof_jan2025.log`

---

## Week 4 models

| Layer | Model |
|-------|-------|
| Intermediate (table) | `int_flights__weather_at_departure` |
| Marts (table) | `fct_flights` |
| Marts (views) | `agg_delay_by_airport_hour`, `agg_delay_by_weather_bucket`, `agg_delay_by_carrier_route` |

---

## Known gaps (documented, not blocking)

| Gap | Notes |
|-----|-------|
| HNL weather | Station map uses `HNL`; IEM ASOS is `PHNL` — fix in Week 5+ |
| Full 16M materialize | Deferred; raw backfill complete, dbt uses Jan 2025 sample |
| Full 71 dbt tests | Deferred to CI on sample (Week 6) |
| Legacy coverage test | `assert_weather_join_coverage_loaded_months` still checks 4 old months; superseded by `assert_weather_join_coverage_jan2025` on sample |

---

## Portfolio headline stats (Jan 2025)

- **95.0%** weather join match (excl. HNL issue)
- **FLL** highest airport delay rate: **24.7%**
- **Precip** strong signal: none **18.4%** → heavy **68.2%** delay rate
- **DEN 18:00 UTC** busiest hour: 2,474 flights, **21.6%** delayed

See `docs/DAY24_CHECKLIST.md` for full analysis output.

---

## Exit criteria

- [x] 3 aggregation marts built and tested
- [x] Analysis SQL + documented insights
- [x] Bulletproof pass on Jan 2025 sample (33 critical tests)
- [x] `DATA_COVERAGE.md` reflects full raw backfill + sample dbt workflow
- [ ] Optional: README portfolio section
- [ ] Optional: fix HNL → PHNL mapping

---

## Next: Week 5

- Streamlit dashboard on agg marts (Jan 2025 sample)
- Optional HNL station fix + re-run bulletproof
- README polish

---

## Commit (when ready)

```bash
git add dbt/models/marts/ dbt/tests/ dbt/analyses/ dbt/macros/ \
  dbt/dbt_project.yml docs/DATA_COVERAGE.md docs/DAY24_CHECKLIST.md \
  docs/DAY28_CHECKLIST.md scripts/bulletproof_jan2025.sh
git commit -m "Complete Week 4 delay marts, analyses, and bulletproof validation"
```

Do **not** commit `.env`, `data/`, `dbt/target/`, or logs.
