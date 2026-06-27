# Week 3 Day 15 — Nearest-observation join model

## Files created / updated

| Path | Purpose |
|------|---------|
| `dbt/models/intermediate/int_flights__weather_at_departure.sql` | Nearest-obs weather join |
| `dbt/models/intermediate/_intermediate.yml` | Model docs + basic tests |
| `dbt/dbt_project.yml` | `weather_join_window_hours` var (default 2) |
| `docs/DAY15_CHECKLIST.md` | This checklist |

## Join logic

```
flight.origin = weather.airport_code
window: valid_utc within ±weather_join_window_hours of dep_time_utc
pick: min abs(valid_utc - dep_time_utc)
tie-break: prefer obs at/before departure, then latest loaded_at
```

## Your manual steps

### 1. Build model

```bash
bash scripts/dbt_run.sh run --select int_flights__weather_at_departure
bash scripts/dbt_run.sh test --select int_flights__weather_at_departure
```

### 2. Spot-check

```bash
docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT weather_match_status, COUNT(*) FROM intermediate.int_flights__weather_at_departure GROUP BY 1;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT origin, weather_match_status, COUNT(*)
   FROM intermediate.int_flights__weather_at_departure
   WHERE origin = 'ATL' AND year_month = '2025-01'
   GROUP BY 1, 2;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT flight_id, dep_time_utc, weather_valid_utc, weather_obs_lag_minutes, weather_match_status, temperature_f
   FROM intermediate.int_flights__weather_at_departure
   WHERE origin = 'ATL' AND year_month = '2025-01' AND weather_match_status = 'matched'
   ORDER BY abs(weather_obs_lag_minutes)
   LIMIT 5;"
```

## Day 15 exit criteria

- [x] Model builds on ~1.69M flights (1,686,378)
- [x] One row per `flight_id` (same grain as departure context)
- [x] Tie-break rules match `docs/weather_join_methodology.md`
- [x] ATL Jan matched flights: median lag **0 min**, avg **0.27 min**
- [x] Basic dbt tests pass (5/5)

### Match rates on loaded station-months (nearest-obs)

| Airport | Month | Matched | Total | Match % |
|---------|-------|---------|-------|---------|
| ATL | 2025-01 | 22,924 | 23,881 | 95.99% |
| ORD | 2025-01 | 20,822 | 21,643 | 96.21% |
| LAX | 2025-01 | 14,520 | 15,157 | 95.80% |
| DEN | 2025-02 | 21,727 | 22,816 | 95.23% |

Global: 80,335 matched / 1,686,378 total (4.76%) — expected until full weather backfill.

## Commit (you only — after tests pass)

```bash
git add dbt/models/intermediate/int_flights__weather_at_departure.sql \
        dbt/models/intermediate/_intermediate.yml \
        dbt/dbt_project.yml \
        docs/DAY15_CHECKLIST.md
git commit -m "Add int_flights__weather_at_departure nearest-observation join"
git push
```

## Day 16 preview

Join tests + match coverage scoped to loaded station-months only (ATL/ORD/LAX Jan, DEN Feb).
