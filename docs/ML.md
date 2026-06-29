# ML layer — departure delay risk (Day 14)

Lightweight **classification** layer on top of dbt `fct_flights`. Goal: DE + ML hybrid portfolio story without turning the repo into a Kaggle notebook.

**Status:** Day 1 complete (extract, CV, Optuna, ablation). Day 2: final train + 2025 holdout + Streamlit.

---

## Problem statement

**Predict:** Will this flight have a **15+ minute departure delay**?

| Item | Choice |
|------|--------|
| **Target** | `is_dep_delay_15_plus` (already in `fct_flights`; matches agg marts) |
| **Unit of analysis** | One flight at origin departure |
| **Positive class rate** | ~15–20% typical on Jan 2025 sample (verify at train time) |
| **Use case** | Operational risk scoring *before* pushback — weather + schedule context only |

This complements the existing **descriptive** dashboard (delay rates by airport/hour/weather bucket) with a **predictive** baseline.

---

## Modeling grain (match dbt docs)

```sql
SELECT *
FROM marts.fct_flights
WHERE is_analysis_eligible = true
  AND has_departure_weather = true
```

- Exclude cancelled / diverted (`is_analysis_eligible`)
- Exclude rows without nearest METAR (`has_departure_weather`)
- Exclude **HNL** until `PHNL` station map fix (optional: `AND origin != 'HNL'`)

Expected rows:

| Dataset | Approx rows |
|---------|-------------|
| Jan 2025 sample | ~376K |
| Full 2023–2025 | ~15.1M (after filters; ~96% of 15.75M) |

**Two tracks:**

| Track | Time | Doc |
|-------|------|-----|
| **Hybrid (portfolio)** | 4–6 hr | This file — train 2023–24, test 2025, baseline + HGB |
| **ML engineer / researcher** | 1–2 days | [`ML_ENGINEER_PATH.md`](ML_ENGINEER_PATH.md) — expanding-window CV, Optuna, ablations, SHAP, calibration |

**Recommended default:** Hybrid track first to validate the pipeline; upgrade to ML engineer track if targeting ML-heavy roles.

---

## Features (no leakage)

### Use ✅

| Feature | Source | Notes |
|---------|--------|-------|
| `origin`, `dest` | fct | Categorical — target-encode or one-hot top-N |
| `reporting_airline` | fct | Categorical |
| `dep_hour_utc`, `dep_dow`, `dep_month` | fct | Calendar / circadian |
| `dep_time_source` | fct | `scheduled` vs `actual` anchor — OK as model input; document interpretation |
| `wind_speed_knots`, `wind_gust_knots` | fct | |
| `precip_1hr_inches`, `visibility_miles` | fct | |
| `temperature_f`, `relative_humidity_pct` | fct | |
| `weather_obs_lag_minutes` | fct | Join quality signal |
| `distance_miles` | **int layer** | Join `int_flights__weather_at_departure` or extend export SQL |

Optional derived (compute in Python):

- `is_precip` = `precip_1hr_inches > 0`
- `wind_speed_bucket` / `visibility_bucket` — reuse bins from `agg_delay_by_weather_bucket`
- Cyclical encoding: `sin/cos` for `dep_hour_utc`

### Do NOT use ❌ (leakage or post-outcome)

| Column | Why |
|--------|-----|
| `dep_delay_minutes`, `is_dep_delay_15_plus` | Target |
| `arr_delay_*`, `taxi_out_minutes`, `taxi_in_minutes`, `air_time_minutes` | Observed after / during operation |
| `carrier_delay_minutes`, `weather_delay_minutes`, `nas_delay_minutes`, etc. | BTS **arrival** delay attribution — not known pre-departure |
| `flight_id`, `flight_date`, `dep_time_utc`, `year_month` | IDs / raw timestamps — use calendar features instead |

---

## Train / validation / test split

**Never random-split flight rows** — delays are autocorrelated in time.

### Option A — Portfolio default (fast)

| Split | `year_month` | Purpose |
|-------|--------------|---------|
| Train | `2025-01` days 1–21 | Fit |
| Validation | `2025-01` days 22–28 | Threshold / early stopping |
| Test | `2025-01` days 29–31 | Report metrics once |

~70% / 15% / 15% by `flight_date` within January.

### Option B — Stronger generalization story

| Split | Period |
|-------|--------|
| Train | 2023-01 → 2024-12 |
| Test | 2025-01 → 2025-12 |

Train on laptop: **subsample** train to 1–2M rows (`TABLESAMPLE` or `WHERE random() < 0.1`) for speed; keep full 2025 as test.

### Option C — Full history (optional, slow)

Same as B but no subsample — only if you want maximum rigor and have RAM/time.

---

## Models (keep it to two)

| Model | Role | Why |
|-------|------|-----|
| **Logistic regression** | Interpretable baseline | Coefficients align with weather-bucket dashboard story |
| **HistGradientBoosting** (sklearn) | Main model | No LightGBM compile issues; handles mixed types with preprocessing |

Skip deep learning — not worth it here.

**Class imbalance:** `class_weight='balanced'` (logistic) or `scale_pos_weight` equivalent; report **PR-AUC** (not accuracy alone).

---

## Metrics to report

| Metric | Notes |
|--------|-------|
| **PR-AUC** | Primary — imbalanced target |
| **ROC-AUC** | Secondary |
| **Brier score** | Calibration |
| **Precision @ recall 0.5** | Operational cut |
| **Baseline** | Predict global train delay rate for every row |
| **Lift vs baseline** | “Model captures X% more delay cases at same alert rate” |

Segmented evaluation (write in `docs/ML.md` results section):

- By `origin` (top 5 hubs)
- By `wind_speed_bucket` — model should beat baseline most on bad-weather bins

---

## Repo layout (proposed)

```
ml/
  requirements.txt          # scikit-learn, joblib, pandas, pyarrow
  config.py                 # paths, split dates, feature lists
  extract.py                # SQL → parquet (from Postgres)
  train.py                  # fit baseline + HGB, save joblib
  evaluate.py               # metrics JSON + plots (PNG)
  artifacts/
    metrics_jan2025.json      # committed — small
    feature_importance.csv  # committed
    roc_pr_jan2025.png        # committed (optional)
  models/                   # gitignored — joblib binaries
scripts/train_delay_model.sh
dashboard/pages/4_Delay_Risk_Model.py   # reads artifacts only
dashboard/demo_data/ml_metrics_jan2025.json  # for Streamlit Cloud
```

---

## Implementation steps (~4–6 hours)

### Step 1 — Extract training frame (30 min)

```bash
# Example: Jan 2025 eligible + weather
docker compose exec postgres psql -U aerodelay -d aerodelay -c "\copy (
  SELECT
    flight_id, flight_date, year_month,
    reporting_airline, origin, dest,
    dep_hour_utc, dep_dow, dep_month, dep_time_source,
    wind_speed_knots, wind_gust_knots, precip_1hr_inches,
    visibility_miles, temperature_f, relative_humidity_pct,
    weather_obs_lag_minutes, is_dep_delay_15_plus
  FROM marts.fct_flights
  WHERE is_analysis_eligible AND has_departure_weather
    AND year_month = '2025-01'
) TO STDOUT WITH CSV HEADER" > ml/data/fct_jan2025_train.csv
```

Or `ml/extract.py` using `psycopg2` + `.env` credentials.

### Step 2 — Train script (1–2 hr)

- `ColumnTransformer`: numeric passthrough + `OneHotEncoder` for airline/origin/dest (limit categories: top 20 airlines, all 45 origins)
- Pipeline: preprocess → model
- Save `ml/models/hgb_jan2025.joblib` + `metrics_jan2025.json`

### Step 3 — Evaluate + document (30 min)

- Print metrics table to terminal
- Write results into **Results** section below
- Compare to dashboard weather-bucket lift (qualitative consistency check)

### Step 4 — Streamlit page (1–2 hr)

`dashboard/pages/4_Delay_Risk_Model.py`:

- Load `demo_data/ml_metrics_jan2025.json` (parquet mode) or artifacts from disk (local)
- Show: baseline vs model PR-AUC, feature importance bar chart, short methodology sidebar
- **Do not train on Streamlit Cloud** — precompute only

### Step 5 — Makefile + README (30 min)

```makefile
train-delay-model:
	bash scripts/train_delay_model.sh
```

README bullet: “Optional ML: departure delay classifier (logistic + HGB) on Jan 2025 holdout.”

---

## `ml/requirements.txt` (pin lightly)

```
scikit-learn>=1.4,<2
pandas>=2.0,<3
pyarrow>=16,<17
joblib>=1.3,<2
matplotlib>=3.8,<4
```

Install: `pip install -r ml/requirements.txt` (separate from dashboard venv is fine).

---

## Streamlit Cloud constraints

- Commit only **JSON metrics + CSV importance** (< 1 MB total)
- Page works in **demo parquet mode** without Postgres
- Caption: “Model trained locally on Jan 2025; metrics precomputed”

---

## Interview talking points

1. **Same grain as dbt** — `is_analysis_eligible` + `has_departure_weather`; tests already guard fct consistency.
2. **Time-based split** — no random leakage across days/months.
3. **Leakage discipline** — no post-hoc BTS delay attribution features.
4. **Baseline first** — logistic regression before boosting; PR-AUC on imbalanced target.
5. **DE → ML handoff** — features come from the weather-at-departure join you built; model validates that join has predictive signal beyond marginals.

**Sample outcome hypothesis** (fill after train):

> HistGradientBoosting beats global-rate baseline by ~0.05–0.15 PR-AUC on Jan 2025 holdout; `precip_1hr_inches`, `wind_speed_knots`, and `dep_hour_utc` top importance — consistent with `agg_delay_by_weather_bucket`.

---

**Status:** Day 2 complete — final model trained on 9.96M rows; 2025 holdout scored once.

---

## Results (2025 holdout — 4,967,395 flights)

| Model | PR-AUC | ROC-AUC | Lift @ top 10% |
|-------|--------|---------|----------------|
| Global rate baseline | **0.225** | 0.50 | 1.0× |
| HGB (Optuna-tuned) | **0.470** | 0.73 | **2.49×** |

**Lift vs baseline:** +0.245 PR-AUC (+109% relative)

**Day 1 CV (subsampled folds):** baseline 0.198 · logistic 0.320 · HGB 0.403 ± 0.066

**Ablation (HGB CV):** schedule_only 0.397 · weather_only 0.363 · full 0.403

Artifacts: `ml/artifacts/` · Streamlit: `dashboard/pages/4_Delay_Risk_Model.py`

---

## Out of scope (hybrid track only)

- Real-time inference API
- Cancellation prediction (different problem; censored outcomes)
- Neural nets / transformers

For **Optuna, expanding-window CV, SHAP, ablations** → see [`ML_ENGINEER_PATH.md`](ML_ENGINEER_PATH.md).

---

## Suggested commit message (when implemented)

```
Add departure delay classifier (baseline + HGB) and Streamlit ML page.

Time-based Jan 2025 holdout on fct_flights modeling grain; precomputed metrics for Cloud demo.
```
