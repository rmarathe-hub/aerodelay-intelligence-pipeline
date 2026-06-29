# Flagship plan — day by day (from green CI)

**You are here:** CI green on `main` ✅ — core pipeline is proven in GitHub Actions.

**Goal:** Portfolio-ready in ~1 week; optional OCI full materialize in week 2–3 (~$0).

**Live demo:** https://aerodelay-intelligence-pipeline-882usdpsfau5g7ap6yzktj.streamlit.app/

---

## Already done ✅

- [x] End-to-end ELT (BTS + weather → Postgres → dbt → marts)
- [x] Raw backfill (~15.9M flights, ~14.4M weather)
- [x] Jan 2025 marts + bulletproof tests
- [x] Streamlit dashboard + Streamlit Cloud deploy
- [x] README + `docs/ARCHITECTURE.md`
- [x] GitHub Actions CI (Jan 2025 sample) — **green**

---

## Week A — Ship the portfolio (~4 days)

### Day 1 — GitHub hygiene *(today)*

- [x] CI green on `main`
- [ ] Confirm latest fixes are pushed (seed CSVs, agg dbt selector in `ci_dbt_test_jan2025.sh`)
- [ ] Add repo **topics** on GitHub: `data-engineering`, `dbt`, `airflow`, `postgresql`, `streamlit`, `elt`, `aviation`, `python`, `docker`

```bash
gh repo edit rmarathe-hub/aerodelay-intelligence-pipeline \
  --add-topic data-engineering,dbt,airflow,postgresql,streamlit,elt,aviation,python,docker
```

**Exit:** Pinned repo looks professional; CI badge green.

---

### Day 2 — dbt docs site

- [x] `scripts/dbt_docs_generate.sh` + `.github/workflows/dbt-docs.yml`
- [ ] Enable **Settings → Pages → GitHub Actions** (one-time)
- [ ] Push to `main` → verify https://rmarathe-hub.github.io/aerodelay-intelligence-pipeline/
- [x] README link to dbt docs

**Done** — see `docs/DAY34_CHECKLIST.md`

---

### Day 3 — Screenshots + README final pass

- [ ] Screenshot Streamlit home → `docs/images/dashboard_home.png`
- [ ] Screenshot one subpage (Airport × Hour or Weather)
- [ ] Embed images in README
- [ ] Skim README for stale wording (“partial load”, etc.)

**Exit:** README tells the story in 60 seconds with visuals.

---

### Day 4 — Resume + LinkedIn

- [ ] Pin repo on GitHub profile
- [ ] LinkedIn project post (repo + live dashboard + one metric: 15.9M raw / 95% weather match)
- [ ] Resume bullets (see below)

**Exit:** Project is **shareable** — **~8.5–9/10** portfolio without OCI.

**Resume bullets (copy/edit):**

> Built an end-to-end flight-delay ELT pipeline (Airflow, Postgres, dbt) ingesting 15.9M BTS flights and 14.4M METAR observations; implemented nearest-weather-at-departure join (95% match on Jan 2025 sample) with dbt tests and GitHub Actions CI.

> Deployed a public Streamlit analytics dashboard (airport×hour, weather buckets, carrier routes) on Streamlit Community Cloud with parquet demo bundle.

---

## Week B — OCI prep (~2 days, optional but recommended before VM)

### Day 5 — Mac data inventory

Choose how to get raw data onto OCI:

```bash
docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT count(*), count(DISTINCT year_month) FROM raw.bts_flights;"
docker compose exec postgres psql -U aerodelay -d aerodelay -c \
  "SELECT count(*), count(DISTINCT station || '-' || year_month) FROM raw.weather_observations;"
du -sh data/raw/bts data/raw/weather 2>/dev/null
ls data/raw/bts/*.zip 2>/dev/null | wc -l
```

| Result | Path |
|--------|------|
| 36 ZIPs + weather files on disk | **Option C** — `rsync data/raw/` to VM |
| Postgres complete only | **Option B** — `pg_dump -n raw -n meta` |
| Gaps | **Option A** — re-backfill on VM |

If Option B: `pg_dump -Fc` and note file size.

**Exit:** Transfer method chosen.

---

### Day 6 — Preflight script

- [ ] Add/run `scripts/check_full_materialization_ready.sh`
- [ ] Must print: disk, RAM, swap, raw counts, `dev_year_month` unset, planned dbt command
- [ ] Run locally against Docker Postgres — GO/NO-GO

**Exit:** Safe to start long OCI jobs without guessing.

---

## Week C — OCI batch materialize (~$0, optional level-up)

### Day 7 — Create disposable OCI VM

- [ ] Always Free `VM.Standard.A1.Flex`: **2 OCPU / 12 GB RAM**
- [ ] 50 GB boot + **~150 GB block volume** (home region, ≤200 GB total)
- [ ] Ubuntu 22.04, SSH, **16 GB swap**
- [ ] Install: git, python3, venv, postgresql-15, postgresql-client
- [ ] **No Airflow** on VM — Postgres + dbt only

**Exit:** SSH works.

---

### Day 8 — Load raw on VM

- [ ] Clone repo, `.env`, init schemas
- [ ] Load data (Option A/B/C from Day 5)
- [ ] **Staged start:** 2025 raw only first (recommended)
- [ ] Preflight → GO

**Exit:** Raw rows match target stage.

---

### Day 9 — dbt Stage 1 (2025 only)

```bash
tmux new -s dbt
bash scripts/check_full_materialization_ready.sh

bash scripts/dbt_run.sh run \
  --select +int_flights__weather_at_departure fct_flights \
    agg_delay_by_airport_hour agg_delay_by_weather_bucket agg_delay_by_carrier_route \
  --full-refresh \
  --threads 1
```

**No `--vars`** for full scope; for 2025-only raw, still no vars (all loaded raw is 2025).

- [ ] Verify `marts.fct_flights` row count (~4–6M for full 2025)
- [ ] Spot tests only

**Exit:** Stage 1 success (~2–6 hrs).

---

### Day 10 — Stage 2: 2024 + 2025 (optional)

- [ ] Load 2024 raw
- [ ] Same dbt command, full-refresh
- [ ] Verify ~10M rows

**Exit:** 2024–2025 materialized **or skip to Day 11 if Stage 1 enough**.

---

### Day 11 — Stage 3: full 2023–2025 (optional)

- [ ] Load 2023 raw if missing
- [ ] Preflight: 36 BTS months, ~1620 station-months
- [ ] Same dbt command overnight

**Exit:** ~15–16M rows in `fct_flights` **or** document partial success.

---

## Week D — Export + close (~2 days)

### Day 12 — Export artifacts

On VM:

```bash
make export-dashboard-demo
pg_dump -U aerodelay -d aerodelay -n marts -n intermediate -Fc -f marts_full.dump
```

On Mac:

```bash
scp .../dashboard/demo_data/*.parquet ./dashboard/demo_data/
scp .../marts_full.dump ~/Backups/aerodelay/   # never commit dump
```

- [ ] Commit parquet if Git-size-safe (<50 MB per file)
- [ ] Push → Streamlit redeploys

**Exit:** Proof artifacts saved.

---

### Day 13 — Document + terminate VM

- [ ] Write `docs/OCI_MATERIALIZATION.md` (shape, runtime, row counts, tests)
- [ ] Update `docs/DATA_COVERAGE.md` + README “Scale proof” paragraph
- [ ] **Terminate VM** in OCI console

**Exit:** $0 ongoing; honest flagship story **~9/10**.

---

### Day 14 — Optional ML layer

Only if Weeks A–D are done and you want AE/ML hybrid roles:

- [ ] Train logistic/LightGBM on `fct_flights` (Jan 2025 sample OK)
- [ ] Time-based train/test split
- [ ] `docs/ML.md` + optional Streamlit page

**Exit:** DE + light ML story.

---

## Short paths

| If you only have… | Do |
|-------------------|-----|
| **1 hour today** | Day 1 topics + pin repo |
| **This week** | Days 1–4 → **share on LinkedIn** |
| **Next weekend** | Days 5–9 → OCI 2025 proof |
| **Ambitious** | Days 10–13 → full 16M proof |

---

## Commands cheat sheet

**Jan 2025 local rebuild:**

```bash
bash scripts/dbt_run.sh run \
  --select +int_flights__weather_at_departure fct_flights \
    agg_delay_by_airport_hour agg_delay_by_weather_bucket agg_delay_by_carrier_route \
  --full-refresh --vars '{dev_year_month: "2025-01"}' --threads 1
```

**Full materialize (no month filter):**

```bash
bash scripts/dbt_run.sh run \
  --select +int_flights__weather_at_departure fct_flights \
    agg_delay_by_airport_hour agg_delay_by_weather_bucket agg_delay_by_carrier_route \
  --full-refresh --threads 1
```

**CI local repro:**

```bash
make ci-setup-postgres && make ci-load-jan2025 && make ci-dbt-test-jan2025
```

---

## Honest demo story (use in interviews)

> Public Streamlit demo runs from a lightweight parquet bundle for reliable free hosting. The warehouse ingests 15.9M flights and 14.4M weather observations; dbt builds tested marts with a documented nearest-METAR join. GitHub Actions CI reproduces the Jan 2025 pipeline on every push. Full historical marts can be materialized on a disposable OCI Always Free batch VM when local Docker runs out of memory.
