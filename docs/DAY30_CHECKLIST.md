# Week 5 Day 30 — Deploy to Streamlit Community Cloud

## Goal

Live public URL: `https://<your-app>.streamlit.app` — no Postgres, parquet-only demo.

## Prerequisites

- [ ] Week 5 Days 1–5 complete (`docs/DAY25_CHECKLIST.md` … `DAY29_CHECKLIST.md`)
- [ ] `dashboard/demo_data/*.parquet` committed to Git
- [ ] Repo pushed to GitHub (public repo for free tier)

## Pre-deploy smoke test (local)

Simulates Streamlit Cloud (no `PYTHONPATH`):

```bash
make verify-dashboard-cloud
```

Expected: `cloud smoke OK: 1000 634 6273`

## Deploy steps

### 1. Commit and push

```bash
git add dashboard/ requirements.txt .streamlit/ scripts/ docs/DAY30_CHECKLIST.md Makefile .gitignore
git status   # confirm parquet files staged
git commit -m "Add Streamlit dashboard and demo parquet for cloud deploy"
git push origin main
```

### 2. Create app on Streamlit Community Cloud

1. Sign in at [share.streamlit.io](https://share.streamlit.io) (GitHub OAuth)
2. **Create app** → pick `rmarathe-hub/aerodelay-intelligence-pipeline`
3. **Branch:** `main`
4. **Main file path:** `dashboard/app.py`
5. **App URL (optional):** e.g. `aerodelay-intel`
6. **Advanced settings → Python version:** 3.12 (or 3.11+)
7. **Requirements file:** `requirements.txt` (repo root)
8. **Secrets:** leave empty (parquet mode needs no Postgres)
9. **Deploy**

First build takes ~2–3 minutes.

### 3. Verify live app

- [ ] Home page loads — executive snapshot + precip chart
- [ ] Sidebar: **Demo parquet bundle loaded**
- [ ] All three subpages load (Airport × Hour, Weather, Routes)
- [ ] No Postgres connection errors

### 4. Save live URL

Copy the deployed URL and add to README:

```markdown
## Live demo

**[AeroDelay Dashboard](https://YOUR-APP.streamlit.app)** — Jan 2025 sample (parquet demo mode)
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `ModuleNotFoundError: dashboard` | Ensure `dashboard/bootstrap.py` is committed; redeploy |
| `No module named 'pyarrow'` | Root `requirements.txt` must include `-r dashboard/requirements.txt` |
| Parquet not found | Commit `dashboard/demo_data/*.parquet`; paths are relative to repo root |
| Theme not applied | Root `.streamlit/config.toml` should be committed |
| Build fails on psycopg2 | Normal on Cloud — parquet mode never connects; dep still installs |

## Files for cloud deploy

| Path | Why |
|------|-----|
| `dashboard/app.py` | Main entry |
| `dashboard/pages/*.py` | Multipage routes |
| `dashboard/bootstrap.py` | `sys.path` fix for Cloud |
| `dashboard/demo_data/*.parquet` | Offline data |
| `requirements.txt` | Streamlit Cloud deps |
| `.streamlit/config.toml` | Theme (repo root) |

## Week 5 exit criteria

- [ ] Local dashboard: `make dashboard`
- [ ] Cloud smoke: `make verify-dashboard-cloud`
- [ ] Live URL on Streamlit Community Cloud
- [ ] README links to live demo

## Next (Week 6)

- Full README rewrite + architecture diagram
- GitHub Actions CI (`dbt test` on Jan 2025 sample)
- Update `docs/DATA_COVERAGE.md` with full backfill stats
