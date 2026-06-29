# Flagship Day 2 — dbt docs on GitHub Pages

## Deliverables

| Path | Purpose |
|------|---------|
| `scripts/dbt_docs_generate.sh` | Build Jan 2025 marts + `dbt docs generate --static` |
| `.github/workflows/dbt-docs.yml` | CI deploy to GitHub Pages |
| `README.md` | Link to public docs site |

## Public URL

**https://rmarathe-hub.github.io/aerodelay-intelligence-pipeline/**

(Catalog reflects **Jan 2025** sample — same scope as CI.)

## One-time GitHub setup

1. Repo **Settings → Pages**
2. **Build and deployment → Source:** **GitHub Actions**
3. Push to `main` or run workflow **Deploy dbt docs** manually

## Local generate (Docker Postgres up)

```bash
make up
make dbt-docs
open dbt/target/index.html
```

Or full CI-like path without Docker (needs local Postgres on 5432):

```bash
make ci-setup-postgres && make ci-load-jan2025 && make dbt-docs
```

## Verify Day 2

- [ ] Workflow **Deploy dbt docs** succeeds on GitHub Actions
- [ ] Pages URL loads lineage graph
- [ ] README links to dbt docs
- [ ] `fct_flights` and agg models visible in catalog

## Next (Day 3)

- Streamlit screenshots in README
- See `docs/FLAGSHIP_PLAN.md`
