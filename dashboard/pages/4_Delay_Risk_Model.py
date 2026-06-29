"""Departure delay risk model — 2025 holdout results."""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import bootstrap  # noqa: F401

import altair as alt
import pandas as pd
import streamlit as st

from dashboard.config import DEMO_DATA_DIR, PROJECT_ROOT

st.set_page_config(page_title="Delay Risk Model", layout="wide")
st.title("Departure delay risk model")
st.caption(
    "HistGradientBoosting on dbt `fct_flights` · train 2023–2024 · **2025 holdout scored once**"
)

ML_DEMO = DEMO_DATA_DIR
ML_ARTIFACTS = PROJECT_ROOT / "ml" / "artifacts"


def load_json(name: str) -> dict | None:
    for base in (ML_DEMO, ML_ARTIFACTS):
        path = base / name
        if path.is_file():
            with path.open(encoding="utf-8") as handle:
                return json.load(handle)
    return None


def load_csv(name: str) -> pd.DataFrame | None:
    for base in (ML_DEMO, ML_ARTIFACTS):
        path = base / name
        if path.is_file():
            return pd.read_csv(path)
    return None


def load_csv_first(*names: str) -> pd.DataFrame | None:
    """Try CSV names in order without boolean checks on DataFrames."""
    for name in names:
        df = load_csv(name)
        if df is not None:
            return df
    return None


def importance_ready(df: pd.DataFrame | None) -> bool:
    required = {"feature", "importance_mean", "importance_std"}
    return df is not None and not df.empty and required.issubset(df.columns)


def segments_ready(df: pd.DataFrame | None) -> bool:
    required = {
        "segment_type",
        "segment",
        "n_rows",
        "positive_rate",
        "pr_auc_model",
        "pr_auc_baseline",
        "pr_auc_lift",
    }
    return df is not None and not df.empty and required.issubset(df.columns)


def image_path(name: str) -> Path | None:
    for base in (ML_DEMO, ML_ARTIFACTS):
        path = base / name
        if path.is_file():
            return path
    return None


holdout = load_json("ml_metrics_2025_holdout.json")
cv_summary = load_json("ml_cv_summary.json")
best_params = load_json("ml_best_params.json")

if holdout is None:
    st.warning(
        "ML holdout metrics not found. Run Day 2 locally: `make train-delay-model-day2` "
        "then refresh."
    )
    st.stop()

with st.sidebar:
    st.subheader("Protocol")
    st.markdown(
        "- Grain: `is_analysis_eligible` + `has_departure_weather`\n"
        "- CV: 3 expanding-window folds (Day 1)\n"
        "- Tuning: Optuna on CV only\n"
        "- **Test: all of 2025, one shot**"
    )
    if best_params:
        st.json(best_params.get("best_params", best_params))

baseline = holdout["baseline"]
model = holdout["hgb_tuned"]
lift = holdout.get("lift", {})

c1, c2, c3, c4 = st.columns(4)
c1.metric("2025 test rows", f"{holdout['test_rows']:,}")
c2.metric("PR-AUC (model)", f"{model['pr_auc']:.3f}")
c3.metric("PR-AUC (baseline)", f"{baseline['pr_auc']:.3f}")
c4.metric(
    "Lift vs baseline",
    f"+{lift.get('pr_auc_absolute', 0):.3f}",
    delta=f"{lift.get('pr_auc_relative_pct', 0):.0f}% rel.",
)

c5, c6, c7 = st.columns(3)
c5.metric("ROC-AUC", f"{model['roc_auc']:.3f}")
c6.metric("Brier score", f"{model['brier']:.3f}")
c7.metric("Lift @ top decile", f"{model['lift_at_top_decile']:.2f}×")

st.divider()

left, right = st.columns(2)
pr_img = image_path("ml_pr_curve.png") or image_path("pr_curve.png")
cal_img = image_path("ml_calibration_curve.png") or image_path("calibration_curve.png")
with left:
    st.subheader("Precision–recall")
    if pr_img:
        st.image(str(pr_img), use_container_width=True)
    else:
        st.info("PR curve image not bundled.")
with right:
    st.subheader("Calibration")
    if cal_img:
        st.image(str(cal_img), use_container_width=True)
    else:
        st.info("Calibration plot not bundled.")

st.subheader("Cross-validation stability (Day 1)")
if cv_summary and "pr_auc_summary" in cv_summary:
    cv_df = pd.DataFrame(cv_summary["pr_auc_summary"])
    cv_df["label"] = cv_df["model"] + " (" + cv_df["mean"].map("{:.3f}".format) + " ± " + cv_df["std"].map("{:.3f}".format) + ")"
    chart = (
        alt.Chart(cv_df)
        .mark_bar()
        .encode(
            x=alt.X("mean:Q", title="Mean PR-AUC"),
            xError=alt.XError("std:Q"),
            y=alt.Y("model:N", sort="-x", title=""),
            color=alt.Color("model:N", legend=None),
            tooltip=["model", "mean", "std"],
        )
        .properties(height=180)
    )
    st.altair_chart(chart, use_container_width=True)
else:
    st.caption("CV summary not found in demo bundle.")

st.subheader("Feature importance (permutation, holdout sample)")
importance = load_csv_first("ml_permutation_importance.csv", "permutation_importance.csv")
if importance_ready(importance):
    top = importance.head(12)
    imp_chart = (
        alt.Chart(top)
        .mark_bar()
        .encode(
            x=alt.X("importance_mean:Q", title="Mean importance"),
            y=alt.Y("feature:N", sort="-x", title=""),
            tooltip=["feature", "importance_mean", "importance_std"],
        )
        .properties(height=360)
    )
    st.altair_chart(imp_chart, use_container_width=True)
else:
    st.info("Permutation importance data is not available in the demo bundle.")

st.subheader("Segments (2025 holdout)")
segments = load_csv_first("ml_segment_metrics.csv", "segment_metrics.csv")
if segments_ready(segments):
    seg_type = st.selectbox(
        "Segment by",
        sorted(segments["segment_type"].unique()),
        index=0,
    )
    view = segments[segments["segment_type"] == seg_type].head(15)
    st.dataframe(
        view[
            [
                "segment",
                "n_rows",
                "positive_rate",
                "pr_auc_model",
                "pr_auc_baseline",
                "pr_auc_lift",
            ]
        ],
        use_container_width=True,
        hide_index=True,
    )
else:
    st.info("Segment metrics are not available in the demo bundle.")

shap_img = image_path("ml_shap_summary.png") or image_path("shap_summary.png")
if shap_img:
    st.subheader("SHAP summary (sample)")
    st.image(str(shap_img), use_container_width=True)
