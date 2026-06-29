# Week 5 Day 28 — Carrier route charts

## Files created / updated

| Path | Purpose |
|------|---------|
| `dashboard/pages/3_Carrier_Routes.py` | Volume vs delay scatter, route rankings |
| `dashboard/carrier_route_views.py` | Filters, leaderboards, route labels |

## Run

```bash
make dashboard
```

Open **Carrier Routes** in the sidebar.

## Verify Day 4

- [ ] **Carriers** multiselect (empty = all)
- [ ] **Origin** / **Destination** dropdowns
- [ ] **Min flights** slider filters thin routes
- [ ] **Volume vs delay** scatter plot with carrier colors
- [ ] **Top routes by volume** bar chart
- [ ] **Top routes by delay rate** bar chart
- [ ] **Carrier delay leaderboard**
- [ ] Raw data expander

## Expected highlights (Jan 2025)

- Top volume: **HA HNL→OGG** (~634 flights, ~8% delayed)
- High delay (≥50 flights): **F9 ATL→PHL** (~55% delayed)
- HA inter-island routes dominate volume; legacy carriers show higher delay on select routes

## Next (Day 29)

- Polish home overview page
- Export agg marts to parquet for Streamlit Cloud deploy

**Done** — see `docs/DAY29_CHECKLIST.md`
