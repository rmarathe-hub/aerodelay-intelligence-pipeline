# Week 2 Day 12 — Weather enriched with airport codes

## Files created / updated

| Path | Purpose |
|------|---------|
| `dbt/models/intermediate/int_weather__observations_enriched.sql` | Weather + airport mapping |
| `dbt/models/intermediate/_intermediate.yml` | Model docs + uniqueness tests |
| `dbt/tests/assert_int_weather_row_count_matches_staging.sql` | No fan-out from station join |

## Logic

```sql
stg_weather__observations
  → inner join dim_airports on station = weather_station_id
  → add airport_code, airport_name, airport_timezone
  → valid_utc unchanged (already UTC in staging)
```

## Your manual steps

### 1. Build model and test

```bash
bash scripts/dbt_run.sh run --select int_weather__observations_enriched
bash scripts/dbt_run.sh test --select int_weather__observations_enriched assert_int_weather_row_count_matches_staging assert_all_weather_stations_in_dim_airports
```

### 2. Spot-check

```bash
docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT airport_code, COUNT(*) FROM intermediate.int_weather__observations_enriched GROUP BY 1 ORDER BY 1;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT COUNT(*) AS total FROM intermediate.int_weather__observations_enriched;"

docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT airport_code, valid_utc, temperature_f, precip_1hr_inches
   FROM intermediate.int_weather__observations_enriched
   WHERE airport_code = 'ATL'
   ORDER BY valid_utc
   LIMIT 5;"
```

## Day 12 exit criteria

- [x] All loaded stations (ATL, ORD, LAX, DEN) map to airport codes
- [x] Row count matches `stg_weather__observations` (19,600 — no fan-out)
- [x] `(airport_code, valid_utc)` unique
- [x] Precip/temp fields flow through unchanged
- [x] dbt tests pass (7/7)

## Commit (you only — after tests pass)

```bash
git add dbt/models/intermediate/int_weather__observations_enriched.sql \
        dbt/models/intermediate/_intermediate.yml \
        dbt/tests/assert_int_weather_row_count_matches_staging.sql \
        docs/DAY12_CHECKLIST.md
git commit -m "Add int_weather__observations_enriched with airport mapping"
git push
```

## Day 13 preview

Join feasibility analyses — ATL Jan and DEN Feb flights vs weather overlap within ±2h of `dep_time_utc`.
