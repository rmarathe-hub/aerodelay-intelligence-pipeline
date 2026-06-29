# Week 5 Day 29 — Polish + Streamlit Cloud prep

## Files created / updated

| Path | Purpose |
|------|---------|
| `dashboard/app.py` | Polished home — insights, charts, page links, parquet mode |
| `dashboard/data.py` | `using_demo_parquet()` + source labels |
| `dashboard/config.py` | Demo data dir → `dashboard/demo_data/` |
| `dashboard/demo_data/*.parquet` | Committed agg snapshots for cloud deploy |
| `scripts/export_dashboard_demo.sh` | Export marts from Postgres to parquet |
| `requirements.txt` | Root pointer for Streamlit Cloud |
| `Makefile` | `export-dashboard-demo` target |

## Export demo data (from local Postgres)

```bash
make export-dashboard-demo
```

Writes:

- `dashboard/demo_data/agg_delay_by_airport_hour.parquet`
- `dashboard/demo_data/agg_delay_by_weather_bucket.parquet`
- `dashboard/demo_data/agg_delay_by_carrier_route.parquet`

Commit these files to Git for Streamlit Cloud (small, ~few MB total).

## Run locally

**Postgres mode** (default when parquet absent or alongside):

```bash
make up
make dashboard
```

**Parquet-only mode** (simulates cloud — rename or remove parquet to test postgres again):

Dashboard auto-detects parquet in `dashboard/demo_data/` and skips Postgres.

## Verify Day 5

- [ ] Home page shows **executive snapshot** + 3 insight cards
- [ ] Precip bar chart on home page
- [ ] **Explore** page links to all three subpages
- [ ] Sidebar shows **Demo parquet bundle loaded** when parquets exist
- [ ] `make export-dashboard-demo` succeeds
- [ ] Dashboard works after `docker compose stop` (parquet fallback)

## Deploy to Streamlit Community Cloud (free)

1. Push repo to GitHub (include `dashboard/demo_data/*.parquet`)
2. Go to [share.streamlit.io](https://share.streamlit.io)
3. **New app** → select repo
4. **Main file path:** `dashboard/app.py`
5. **Requirements:** `requirements.txt` (repo root)
6. Deploy → copy live URL into README (Week 6)

No Postgres secrets needed when parquet bundle is committed.

**Done** — see `docs/DAY30_CHECKLIST.md` for deploy steps.

## Next (Day 30 / Week 6)

- Deploy to Streamlit Community Cloud → live URL
- README rewrite + architecture diagram
- GitHub Actions CI on Jan 2025 sample
