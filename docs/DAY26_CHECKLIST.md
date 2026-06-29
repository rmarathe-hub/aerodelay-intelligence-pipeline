# Week 5 Day 26 — Airport × hour charts

## Files created / updated

| Path | Purpose |
|------|---------|
| `dashboard/pages/1_Airport_Hour.py` | Airport filter, Altair bar charts, top-hour cards |
| `dashboard/airport_hour_views.py` | Pure pandas helpers for filtering and rankings |
| `dashboard/requirements.txt` | Added `altair` |

## Run

```bash
make dashboard
```

Open **Airport Hour** in the sidebar (refresh if already running).

## Verify Day 2

- [ ] Airport dropdown lists all origins (default **DEN**)
- [ ] **Min flights** slider hides thin hour buckets
- [ ] Four KPI metrics update when airport changes
- [ ] **Delay rate by hour** bar chart renders for selected airport
- [ ] **Flight volume by hour** bar chart renders alongside
- [ ] **Top delay hours** — up to 5 metric cards for worst UTC hours
- [ ] **Highest-delay airports** horizontal bar chart (≥500 flights per airport)
- [ ] Raw data available in expander at bottom

## Expected highlights (Jan 2025)

- **DEN 18:00 UTC** — among busiest hours
- **FLL** — often top airport delay rate at ≥500 flights

## Next (Day 27)

- Weather bucket pooled charts on `2_Weather_Buckets`
- Precip / wind / visibility comparison

**Done** — see `docs/DAY27_CHECKLIST.md`
