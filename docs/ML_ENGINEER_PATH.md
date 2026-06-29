# ML engineer / researcher path (1–2 days)

Rigorous modeling track on top of dbt `fct_flights` — **expanding-window CV**, **hyperparameter tuning**, **ablations**, **calibration**, and **segmented evaluation**. Use this if you want an **ML-engineer-grade** story, not just a portfolio add-on.

**Prerequisite:** Full marts materialized (`fct_flights` ~15.7M rows).  
**Companion doc:** [`ML.md`](ML.md) (problem definition, features, leakage rules).

**Status:** Plan only — not yet implemented.

---

## What “standout” means here

| Hybrid path (4–6 hr) | ML engineer path (1–2 days) |
|----------------------|-----------------------------|
| One holdout: train 23–24 → test 25 | **3 expanding-window CV folds** + final test 25 |
| Default hyperparameters | **Optuna** search on validation folds only |
| One model + baseline | **Logistic + HGB + optional LightGBM** |
| Global PR-AUC | **PR-AUC + calibration + segments + ablations** |
| Feature importance | **Permutation importance + SHAP (sampled)** |

**Interview line:**

> “Expanding-window temporal CV on 15M joined flights; tuned HistGradientBoosting with Optuna on validation years only; final 2025 holdout scored once; weather ablation shows +X PR-AUC over schedule-only features.”

---

## Day-by-day schedule

### Day 1 — Data, CV, tuning (~6–8 hr)

| Block | Task | Output |
|-------|------|--------|
| **1** (1 hr) | Extract parquet splits + EDA | `ml/data/{train,val_folds,test}.parquet`, EDA notebook or `ml/eda.py` summary |
| **2** (1.5 hr) | Expanding-window CV harness | `ml/cv.py` — 3 folds, unified metrics |
| **3** (2 hr) | Baselines + logistic + HGB (default params) | Fold metrics table |
| **4** (2 hr) | Optuna on HGB (50–100 trials) | `ml/artifacts/best_params.json` |
| **5** (30 min) | Ablation runs (3 feature sets) | `ml/artifacts/ablation.csv` |

### Day 2 — Final model, analysis, ship (~6–8 hr)

| Block | Task | Output |
|-------|------|--------|
| **1** (1.5 hr) | Retrain best model on **all 2023–2024** | `ml/models/final_hgb.joblib` |
| **2** (1 hr) | **Single** evaluation on **all 2025** (never tuned on this) | `metrics_2025_holdout.json` |
| **3** (1.5 hr) | Calibration + PR/ROC curves + lift@k | PNGs in `ml/artifacts/` |
| **4** (1 hr) | Segmented metrics (origin, month, weather bins) | `segment_metrics.csv` |
| **5** (1 hr) | SHAP + permutation importance (50k sample) | importance CSV + plot |
| **6** (1 hr) | Streamlit page + README + update `ML.md` results | `dashboard/pages/4_Delay_Risk_Model.py` |

---

## Data protocol

### Grain (unchanged)

```sql
FROM marts.fct_flights
WHERE is_analysis_eligible
  AND has_departure_weather
  AND origin != 'HNL'   -- recommended until PHNL fix
```

### Splits

```
┌─────────────────────────────────────────────────────────────┐
│  CV / tuning (never touch 2025 until the very end)          │
├─────────────────────────────────────────────────────────────┤
│  Fold 1:  train 2023        →  validate 2024                │
│  Fold 2:  train 2023–2024 H1  →  validate 2024 H2           │
│  Fold 3:  train 2023–2024     →  validate 2024-10..12     │
├─────────────────────────────────────────────────────────────┤
│  Final:   train ALL 2023–2024  →  TEST ALL 2025 (once)     │
└─────────────────────────────────────────────────────────────┘
```

**Fold 3** uses Q4 2024 as validation — closest regime to 2025.

### Extract strategy (Mac-friendly)

| File | SQL filter | Approx rows | Notes |
|------|------------|-------------|-------|
| `train_2023_2024.parquet` | `year_month < '2025-01'` | ~10M | Subsample to **2M** for tuning trials |
| `val_2024.parquet` | `year_month between '2024-01' and '2024-12'` | ~5M | Use subsets per fold |
| `test_2025.parquet` | `year_month >= '2025-01'` | ~5M | **Never** used in Optuna |

**Tuning subsample:** `train.sample(2_000_000, random_state=42)` stratified on target.  
**Final fit:** Use full 2023–2024 (or 3M stratified if RAM-bound — document honestly).

```bash
# Extract via ml/extract.py (recommended)
python ml/extract.py --split cv
```

---

## Features

### Full feature set (`full`)

| Group | Columns |
|-------|---------|
| Schedule | `reporting_airline`, `origin`, `dest`, `dep_hour_utc`, `dep_dow`, `dep_month`, `dep_time_source` |
| Weather | `wind_speed_knots`, `wind_gust_knots`, `precip_1hr_inches`, `visibility_miles`, `temperature_f`, `relative_humidity_pct`, `weather_obs_lag_minutes` |
| Derived | `is_precip`, `sin_hour`, `cos_hour` (compute in Python) |

Add `distance_miles` from int layer if extract joins it.

### Ablation sets (required for ML-engineer story)

| Name | Features | Hypothesis |
|------|----------|------------|
| `schedule_only` | airline, origin, dest, hour, dow, month | Operational baseline |
| `weather_only` | weather cols + origin (hub fixed effect) | Join value isolated |
| `full` | schedule + weather | Production candidate |

Report **Δ PR-AUC** of `full` vs `schedule_only` on each CV fold and 2025 test.

---

## Models

| Model | Role | Tuning |
|-------|------|--------|
| **Global rate baseline** | Predict train positive rate | None |
| **Logistic regression** | Interpretable linear baseline | `C` in `[0.01, 0.1, 1, 10]` |
| **HistGradientBoosting** | Primary production candidate | Optuna (below) |
| **LightGBM** (optional) | If install is painless on Mac | Same search space |

Skip neural nets — not worth setup for tabular data at this scale.

---

## Expanding-window CV (`ml/cv.py`)

```python
FOLDS = [
    {"train_end": "2023-12", "val_start": "2024-01", "val_end": "2024-12"},
    {"train_end": "2024-06", "val_start": "2024-07", "val_end": "2024-12"},
    {"train_end": "2024-09", "val_start": "2024-10", "val_end": "2024-12"},
]
```

For each fold, compute on validation slice:

- `pr_auc`, `roc_auc`, `brier_score`
- `precision_at_recall_50` (threshold where recall ≈ 0.5)
- `lift_at_top_decile` — capture rate in top 10% predicted risk vs base rate

Report: **mean ± std** across folds for CV; **single number** for 2025 test.

---

## Hyperparameter tuning (Optuna)

**Rule:** Optuna objective = **mean PR-AUC across CV folds**. **2025 is never seen.**

### Search space (HistGradientBoosting)

```python
{
    "max_depth": [4, 6, 8, 10, 12],
    "learning_rate": loguniform(0.01, 0.2),
    "max_iter": [100, 200, 300],
    "min_samples_leaf": [20, 50, 100, 200],
    "l2_regularization": loguniform(1e-4, 10),
    "max_bins": [128, 255],
}
```

### Optuna config

- **Trials:** 75–100 (Day 1 afternoon)
- **Sampler:** `TPESampler(seed=42)`
- **Pruner:** `MedianPruner` on fold 1 metric (optional)
- **Study name:** `hgb_delay_pr_auc`
- Save: `ml/artifacts/optuna_study.pkl` + `best_params.json`

```bash
python ml/tune.py --trials 100 --train-subsample 2000000
```

### After tuning

1. Lock `best_params`
2. Retrain on **full 2023–2024**
3. Score **2025 once** → write final metrics
4. **Do not** re-run Optuna after seeing 2025

---

## Evaluation suite (`ml/evaluate.py`)

### Global metrics (2025 holdout)

| Metric | Why |
|--------|-----|
| **PR-AUC** | Primary (imbalanced) |
| **ROC-AUC** | Secondary |
| **Brier score** | Calibration quality |
| **Log loss** | Probabilistic scoring |
| **ECE** (expected calibration error) | ML-engineer signal |

### Calibration

- Reliability diagram (10 bins) → `calibration_curve.png`
- Optional: `CalibratedClassifierCV` (isotonic) on 2024 only — compare Brier before/after

### Lift / operations

| Metric | Definition |
|--------|------------|
| **Lift @ top 10%** | `(delay rate in top decile) / (base rate)` |
| **Capture @ 20% alert rate** | % of all delays found by flagging top 20% scores |

These read well for “ops” interviews.

### Segmented evaluation (`ml/artifacts/segment_metrics.csv`)

Compute PR-AUC on 2025 test for:

- **Top 10 origins** (ATL, ORD, DFW, DEN, LAX, …)
- **Calendar month** (2025-01 … 2025-12)
- **Weather bins** (reuse agg bucket logic: calm vs strong wind, dry vs precip)
- **dep_time_source** (`scheduled` vs `actual`)

Flag segments where model **underperforms** baseline — honest discussion point.

---

## Explainability

### Permutation importance

- Sample **100k** from 2025 test
- `sklearn.inspection.permutation_importance` on fitted pipeline
- Save top 20 → `permutation_importance.csv`

### SHAP (sampled)

```bash
pip install shap
```

- **50k** train sample, **10k** explain
- `shap.TreeExplainer` on HGB
- Beeswarm plot for top 10 features → `shap_summary.png`
- **Do not** SHAP 15M rows

**Standout tie-in:** SHAP top features should align with `agg_delay_by_weather_bucket` (precip, wind, hour).

---

## Repo layout (ML engineer track)

```
ml/
  requirements.txt       # + optuna, shap
  config.yaml            # splits, features, seeds, paths
  extract.py
  eda.py                 # class balance, missingness, by-year stats
  cv.py                  # fold definitions + runner
  train.py               # fit single model from config
  tune.py                # Optuna study
  evaluate.py            # holdout + segments + plots
  ablation.py            # schedule vs weather vs full
  data/                  # gitignored parquet
  models/                # gitignored joblib
  artifacts/             # committed: JSON, CSV, PNG (< 5 MB total)
    cv_fold_metrics.csv
    best_params.json
    ablation.csv
    metrics_2025_holdout.json
    segment_metrics.csv
    pr_curve.png
    calibration_curve.png
    shap_summary.png
scripts/train_delay_model_full.sh
dashboard/pages/4_Delay_Risk_Model.py
dashboard/demo_data/ml_metrics_2025_holdout.json
```

### `ml/requirements.txt`

```
scikit-learn>=1.4,<2
pandas>=2.0,<3
pyarrow>=16,<17
joblib>=1.3,<2
matplotlib>=3.8,<4
optuna>=3.5,<4
shap>=0.45,<1
psycopg2-binary>=2.9,<3
python-dotenv>=1.0,<2
pyyaml>=6,<7
```

Optional: `lightgbm>=4,<5` if `brew`/wheel installs cleanly.

### `.gitignore` additions

```
ml/data/
ml/models/
ml/artifacts/optuna_study.pkl
.venv-ml/
```

Commit **small** artifacts: JSON, CSV, PNG only.

---

## Streamlit page (ML engineer version)

`dashboard/pages/4_Delay_Risk_Model.py` sections:

1. **Protocol** — expanding CV, 2025 scored once, no test leakage
2. **Metrics cards** — baseline vs logistic vs HGB (PR-AUC, lift)
3. **CV stability** — fold metrics table (mean ± std)
4. **Ablation bar chart** — schedule vs weather vs full
5. **Calibration plot** (static image)
6. **Top features** — permutation + SHAP thumbnail
7. **Segment table** — PR-AUC by hub (top 10)

Caption: *Precomputed locally; full training data not shipped.*

---

## Makefile targets

```makefile
ml-extract:
	python ml/extract.py --split cv

ml-tune:
	python ml/tune.py --trials 100

ml-train-final:
	python ml/train.py --config ml/artifacts/best_params.json --train-through 2024-12

ml-evaluate:
	python ml/evaluate.py --test-year 2025

ml-ablation:
	python ml/ablation.py

train-delay-model-full:
	bash scripts/train_delay_model_full.sh
```

`scripts/train_delay_model_full.sh` chains: extract → tune → train-final → evaluate → ablation → copy artifacts to `dashboard/demo_data/`.

---

## Expected outcomes (honest ranges)

Delay prediction is noisy. These are **plausible**, not guarantees:

| Metric | Baseline | After tuning |
|--------|----------|--------------|
| PR-AUC (2025) | 0.16–0.20 | 0.22–0.30 |
| Lift vs baseline | 0 | +0.04–0.10 absolute PR-AUC |
| Weather ablation lift | — | +0.02–0.06 over schedule-only |
| CV fold std | — | ±0.01–0.03 PR-AUC |

**A +0.06 PR-AUC lift on 5M test rows with documented protocol is strong** for this problem.

---

## README / resume bullets (after completion)

**README:**

> **ML (departure delay risk):** Expanding-window CV on 2023–2024; Optuna-tuned HistGradientBoosting; **2025 holdout PR-AUC X.XX** (+Y.Y vs baseline). Weather features add +Z PR-AUC over schedule-only ablation.

**Resume:**

> Built temporal CV and Optuna tuning pipeline on 15M-row dbt feature store; final 2025 holdout PR-AUC 0.XX (+33% vs naive baseline); SHAP/permutation importance confirms weather join signal aligns with SQL agg marts.

---

## Interview prep (ML engineer questions)

| Question | Your answer |
|----------|-------------|
| Why not random split? | Delays cluster in time; random split leaks future patterns. |
| Why expanding window? | Simulates production — always train on past, validate on future. |
| Why score 2025 only once? | Prevent test-set overfitting from hyperparameter search. |
| Why PR-AUC not accuracy? | ~85% on-time → accuracy misleading; care about ranking delayed flights. |
| How do you know weather join helps? | `weather_only` and `full` ablations vs `schedule_only`. |
| Calibration? | Reliability diagram + Brier; optional isotonic on 2024. |
| Production next steps? | Batch scoring job, model registry, monitor drift on delay rate + PR-AUC. |

---

## What to skip (even on ML engineer path)

- Deep learning / transformers
- Real-time inference API
- Full 15M SHAP
- 500+ Optuna trials
- MLflow / Kubeflow (mention as “next step” verbally unless you want +3 hr)

---

## Results template (fill after Day 2)

### CV folds (tuned HGB)

| Fold | Train period | Val period | PR-AUC | ROC-AUC |
|------|--------------|------------|--------|---------|
| 1 | 2023 | 2024 | — | — |
| 2 | 2023–2024 H1 | 2024 H2 | — | — |
| 3 | 2023–2024 Q1–Q3 | 2024 Q4 | — | — |
| **Mean ± std** | | | — ± — | — ± — |

### 2025 holdout (scored once)

| Model | PR-AUC | ROC-AUC | Brier | Δ vs baseline |
|-------|--------|---------|-------|---------------|
| Global rate | — | — | — | — |
| Logistic | — | — | — | — |
| HGB (tuned) | — | — | — | — |

### Ablation (2025 holdout)

| Feature set | PR-AUC | Δ vs schedule_only |
|-------------|--------|-------------------|
| schedule_only | — | — |
| weather_only | — | — |
| full | — | — |

---

## Suggested commits

```bash
# Commit 1 — ML package + scripts
git add ml/ scripts/train_delay_model_full.sh Makefile .gitignore
git commit -m "Add ML engineer track: CV, Optuna tuning, evaluation suite."

# Commit 2 — artifacts + dashboard + docs
git add ml/artifacts/ dashboard/demo_data/ dashboard/pages/4_Delay_Risk_Model.py docs/ML.md docs/ML_ENGINEER_PATH.md README.md
git commit -m "Add 2025 holdout results, SHAP/ablation artifacts, and Streamlit ML page."
```

---

## Quick start (when implemented)

```bash
cd /Users/rohitmarathe/AeroDelay_Intel_Pipeline
make up
python -m venv .venv-ml && source .venv-ml/bin/activate
pip install -r ml/requirements.txt

# Day 1
make ml-extract
python ml/eda.py
make ml-tune
make ml-ablation

# Day 2
make ml-train-final
make ml-evaluate
cp ml/artifacts/metrics_2025_holdout.json dashboard/demo_data/
make dashboard
```
