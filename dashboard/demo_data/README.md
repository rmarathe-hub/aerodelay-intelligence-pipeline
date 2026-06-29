# Parquet snapshots of dbt agg marts for Streamlit Community Cloud deploy.

Generated from local Postgres (`marts.agg_*`) via:

```bash
make export-dashboard-demo
```

**Scope:** Jan 2025 sample (same data as local Plan B materialization).

Streamlit loads these files when present; otherwise it queries local Postgres.
