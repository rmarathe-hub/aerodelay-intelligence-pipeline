from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any

import pandas as pd

from ml.config_loader import load_config
from ml.features import (
    FeatureSetName,
    add_derived_features,
    build_hgb_pipeline,
    build_logistic_pipeline,
    split_xy,
)
from ml.metrics import baseline_scores, compute_metrics, metrics_to_frame, save_json
from ml.paths import ARTIFACTS_DIR, DATA_DIR, ensure_dirs


def filter_fold(
    df: pd.DataFrame,
    train_end: str,
    val_start: str,
    val_end: str,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    train = df[df["year_month"] <= train_end]
    val = df[(df["year_month"] >= val_start) & (df["year_month"] <= val_end)]
    return train, val


def maybe_subsample(
    df: pd.DataFrame,
    n: int | None,
    seed: int,
    target_col: str,
) -> pd.DataFrame:
    del target_col
    if n is None or len(df) <= n:
        return df
    return df.sample(n=n, random_state=seed)


def evaluate_fold(
    train_df: pd.DataFrame,
    val_df: pd.DataFrame,
    fold_name: str,
    feature_set: FeatureSetName,
    target_col: str,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    x_train, y_train = split_xy(train_df, feature_set, target_col)
    x_val, y_val = split_xy(val_df, feature_set, target_col)

    base_scores = baseline_scores(y_train, len(y_val))
    base_metrics = compute_metrics(y_val, base_scores)
    rows.append(
        {
            "fold": fold_name,
            "model": "baseline_global_rate",
            "feature_set": feature_set,
            **base_metrics,
        }
    )

    logit = build_logistic_pipeline(feature_set)
    logit.fit(x_train, y_train)
    logit_metrics = compute_metrics(y_val, logit.predict_proba(x_val)[:, 1])
    rows.append(
        {
            "fold": fold_name,
            "model": "logistic_regression",
            "feature_set": feature_set,
            **logit_metrics,
        }
    )

    hgb = build_hgb_pipeline(feature_set)
    hgb.fit(x_train, y_train)
    hgb_metrics = compute_metrics(y_val, hgb.predict_proba(x_val)[:, 1])
    rows.append(
        {
            "fold": fold_name,
            "model": "hgb_default",
            "feature_set": feature_set,
            **hgb_metrics,
        }
    )
    return rows


def run_cv(
    train_df: pd.DataFrame,
    subsample: int | None,
    seed: int,
    target_col: str,
    feature_set: FeatureSetName = "full",
    val_subsample: int | None = None,
) -> pd.DataFrame:
    cfg = load_config()
    rows: list[dict[str, Any]] = []
    for fold in cfg["cv"]["folds"]:
        fold_train, fold_val = filter_fold(
            train_df,
            train_end=fold["train_end"],
            val_start=fold["val_start"],
            val_end=fold["val_end"],
        )
        if subsample:
            fold_train = maybe_subsample(fold_train, subsample, seed, target_col)
        if val_subsample:
            fold_val = maybe_subsample(fold_val, val_subsample, seed + 1, target_col)
        print(
            f"{fold['name']}: train={len(fold_train):,} val={len(fold_val):,}",
            flush=True,
        )
        rows.extend(
            evaluate_fold(
                fold_train,
                fold_val,
                fold_name=fold["name"],
                feature_set=feature_set,
                target_col=target_col,
            )
        )
    return metrics_to_frame(rows)


def summarize_cv(df: pd.DataFrame) -> pd.DataFrame:
    numeric = ["pr_auc", "roc_auc", "brier", "lift_at_top_decile"]
    return (
        df.groupby(["model", "feature_set"], as_index=False)[numeric]
        .agg(["mean", "std"])
        .round(4)
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Expanding-window CV for delay models.")
    parser.add_argument("--data-dir", type=Path, default=DATA_DIR)
    parser.add_argument(
        "--feature-set",
        default="full",
        choices=["schedule_only", "weather_only", "full"],
    )
    parser.add_argument("--subsample", type=int, default=None)
    args = parser.parse_args()
    ensure_dirs()
    cfg = load_config()
    seed = int(cfg["seed"])
    target_col = cfg["target"]
    subsample = args.subsample if args.subsample is not None else cfg["cv"].get("subsample")
    val_subsample = cfg["cv"].get("val_subsample")

    train_df = add_derived_features(pd.read_parquet(args.data_dir / "train_2023_2024.parquet"))
    results = run_cv(
        train_df,
        subsample=subsample,
        seed=seed,
        target_col=target_col,
        feature_set=args.feature_set,
        val_subsample=val_subsample,
    )
    out_path = ARTIFACTS_DIR / "cv_fold_metrics.csv"
    results.to_csv(out_path, index=False)
    print(f"Wrote {out_path}")
    print(summarize_cv(results))

    summary = (
        results.groupby(["model", "feature_set"])["pr_auc"]
        .agg(["mean", "std"])
        .round(4)
        .reset_index()
    )
    save_json(
        ARTIFACTS_DIR / "cv_summary.json",
        {
            "feature_set": args.feature_set,
            "subsample": subsample,
            "pr_auc_summary": summary.to_dict(orient="records"),
        },
    )


if __name__ == "__main__":
    main()
