# Week 2 Day 9 — BTS HHMM time parsing macros

## Files created / updated

| Path | Purpose |
|------|---------|
| `dbt/macros/bts_time_to_timestamp.sql` | `FlightDate` + HHMM → local timestamp |
| `dbt/analyses/validate_bts_time_parsing.sql` | Spot-check ATL/DEN/LAX/ORD sample times |
| `docs/DAY9_CHECKLIST.md` | This checklist |

## Parsing rules (documented in macro)

| Input | Result |
|-------|--------|
| `800` | 08:00 on `flight_date` |
| `1530` | 15:30 on `flight_date` |
| `1` | 00:01 on `flight_date` |
| `2400` | 00:00 on `flight_date + 1 day` |
| NULL / empty | NULL |
| Invalid HHMM | NULL |

UTC conversion: local timestamp `AT TIME ZONE` IANA timezone → `timestamptz`.

## Your manual steps

### 1. Compile and run validation analysis

```bash
bash scripts/dbt_run.sh compile
```

Inspect compiled analysis:

```bash
grep -l validate_bts_time_parsing dbt/target/compiled/aerodelay/analyses/*.sql
```

Run compiled SQL in Postgres (path varies after compile):

```bash
docker compose exec -T postgres psql -U aerodelay -d aerodelay \
  -f dbt/target/compiled/aerodelay/analyses/validate_bts_time_parsing.sql
```

### 2. Quick inline spot-check

```bash
docker compose exec -T postgres psql -U aerodelay -d aerodelay -c "
SELECT
  (date '2025-01-15' + make_interval(hours => 8))::timestamp AT TIME ZONE 'America/New_York' AS atl_800_utc,
  (date '2025-01-15' + make_interval(hours => 15, mins => 30))::timestamp AT TIME ZONE 'America/New_York' AS atl_1530_utc;
"
```

Expected: ATL 08:00 EST → 13:00 UTC; 15:30 EST → 20:30 UTC (January = EST, UTC-5).

### 3. Confirm existing tests still pass

```bash
make dbt-test
```

## Day 9 exit criteria

- [ ] Macros handle `800`, `1530`, `1`, `2400`, NULL
- [ ] Analysis shows sane UTC for ATL, DEN, LAX, ORD samples
- [ ] Edge cases documented in macro comments
- [ ] dbt tests still pass

## Commit (you only — after verification)

```bash
git add dbt/macros/bts_time_to_timestamp.sql dbt/analyses/validate_bts_time_parsing.sql docs/DAY9_CHECKLIST.md
git commit -m "Add BTS HHMM time parsing macros for UTC conversion"
git push
```

## Day 10 preview

Build `int_flights__departure_context` with scheduled departure UTC using these macros.
