# Week 6 Day 33 — Portfolio polish

## Deliverables

| Item | Status |
|------|--------|
| Live Streamlit URL in README | ✅ |
| Streamlit + tech badges in README | ✅ |
| Per-page dashboard links | ✅ |
| GitHub repo topics | Manual (see below) |

## Live app

**Base URL:** https://aerodelay-intelligence-pipeline-882usdpsfau5g7ap6yzktj.streamlit.app/

| Page | URL |
|------|-----|
| Home | `/` |
| Airport × Hour | `/Airport_Hour` |
| Weather Buckets | `/Weather_Buckets` |
| Carrier Routes | `/Carrier_Routes` |

Verified 2026-06-29: parquet mode, executive snapshot, precip chart, all pages load.

## GitHub repo topics (manual)

On GitHub → **Settings → General → Topics**, add:

```
data-engineering
dbt
airflow
postgresql
streamlit
elt
aviation
python
docker
```

Or via CLI:

```bash
gh repo edit rmarathe-hub/aerodelay-intelligence-pipeline \
  --add-topic data-engineering,dbt,airflow,postgresql,streamlit,elt,aviation,python,docker
```

## Optional screenshot

Add a dashboard capture for LinkedIn / resume:

1. Open [live home page](https://aerodelay-intelligence-pipeline-882usdpsfau5g7ap6yzktj.streamlit.app/)
2. Screenshot → save as `docs/images/dashboard_home.png`
3. Embed in README: `![Dashboard](docs/images/dashboard_home.png)`

## Week 6 exit criteria

- [x] README portfolio rewrite
- [x] Architecture doc + mermaid
- [x] GitHub Actions CI
- [x] Live Streamlit URL in README
- [ ] Repo topics set on GitHub
- [x] CI badge green on `main`

## What's next

See **`docs/FLAGSHIP_PLAN.md`** — day-by-day from green CI.
