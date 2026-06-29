# Week 5 Day 27 — Weather bucket charts

## Files created / updated

| Path | Purpose |
|------|---------|
| `dashboard/pages/2_Weather_Buckets.py` | Pooled + per-airport weather charts |
| `dashboard/weather_bucket_views.py` | Bucket aggregation, ordering, worst combos |

## Run

```bash
make dashboard
```

Open **Weather Buckets** in the sidebar.

## Verify Day 3

- [ ] Scope toggle: **All airports (pooled)** vs **Single airport**
- [ ] Min flights slider filters thin weather combos
- [ ] Three bar charts: **precip**, **wind**, **visibility** delay rates
- [ ] Precip info banner shows heavy vs none lift
- [ ] **Worst weather combinations** horizontal bar chart
- [ ] Raw data expander at bottom

## Expected highlights (Jan 2025, pooled)

- Precip: **none ~18%** → **heavy ~68%** delay rate
- Visibility: **low** worse than **medium/high**
- Wind: **strong** higher than **calm** (small-n on strong bin)

## Next (Day 28)

- Carrier route volume vs delay on `3_Carrier_Routes`
- Carrier and route filters

**Done** — see `docs/DAY28_CHECKLIST.md`
