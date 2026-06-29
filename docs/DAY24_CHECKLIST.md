# Week 4 Phase B — Delay risk analyses (Day 24)

## Files created

| Path | Purpose |
|------|---------|
| `dbt/analyses/delay_by_airport_hour_top.sql` | Top delay hours, airports, busiest UTC hours |
| `dbt/analyses/delay_by_weather_bucket.sql` | Pooled weather-bin delay rates + worst combos |
| `dbt/analyses/delay_carrier_route_top.sql` | Top routes by volume and delay rate |
| `dbt/analyses/weather_join_coverage_jan2025.sql` | Join match % for all airports, Jan 2025 |

**Scope:** Jan 2025 sample (`fct_flights` / join table materialized with `dev_year_month: "2025-01"`).

---

## Run analyses

```bash
bash scripts/dbt_run.sh compile --select path:analyses

docker compose exec postgres psql -U aerodelay -d aerodelay \
  -f dbt/target/compiled/aerodelay/analyses/delay_by_airport_hour_top.sql

docker compose exec postgres psql -U aerodelay -d aerodelay \
  -f dbt/target/compiled/aerodelay/analyses/delay_by_weather_bucket.sql

docker compose exec postgres psql -U aerodelay -d aerodelay \
  -f dbt/target/compiled/aerodelay/analyses/delay_carrier_route_top.sql

docker compose exec postgres psql -U aerodelay -d aerodelay \
  -f dbt/target/compiled/aerodelay/analyses/weather_join_coverage_jan2025.sql
```

---

## Headline findings (Jan 2025, verified)

### Airport × hour

- **Busiest hour:** DEN 18:00 UTC — 2,474 flights; **21.6%** delayed 15+ min
- **Highest airport delay rate (≥500 flights):** FLL **24.7%**, then DFW **23.4%**, DEN **23.4%**
- **Worst hour by avg delay (≥100 flights):** DFW 05:00 UTC — **96.6%** delayed, avg **94.8** min (small-n caveat: 206 flights)

### Weather buckets (matched weather only)

- **Precip:** none **18.4%** → light **26.7%** → moderate **52.4%** → heavy **68.2%** delay rate
- **Visibility:** high/medium ~**18%** vs low visibility **25.6%**
- **Wind:** calm **17.0%** vs strong **27.8%** (strong bin small: 216 flights)
- **Worst combo (≥50 flights):** DFW calm + moderate precip + medium visibility — **94.1%** delayed

### Carrier routes

- **Highest volume:** HA HNL→OGG (634 flights), delay rate **8.0%**
- **Highest delay rate (≥50 flights):** F9 ATL→PHL **54.9%** (51 flights)

### Weather join coverage (Jan 2025)

Run `weather_join_coverage_jan2025.sql` for per-airport match %. Any airport below 90% is flagged as `low_match_airport` (check HNL / station mapping).

---

## Exit criteria

- [x] 4 analysis SQL files compile and run
- [x] Headline insights documented above
- [ ] Optional: paste top rows into README portfolio section (Phase C / polish)

---

## Next: Phase C — Bulletproof pass

- Critical ~8–10 tests on Jan 2025 sample
- Update `docs/DATA_COVERAGE.md`
- Week 4 exit checklist

**Done** — see `docs/DAY28_CHECKLIST.md` and `make dbt-bulletproof-jan2025`
