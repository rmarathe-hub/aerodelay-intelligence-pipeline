from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.inspection import permutation_importance

from ml.config_loader import load_config
from ml.features import split_xy
from ml.io_utils import load_model, load_train_test, write_run_metadata
from ml.metrics import baseline_scores, compute_metrics, save_json
from ml.paths import ARTIFACTS_DIR, DATA_DIR, ensure_dirs
from ml.plots import save_calibration_curve, save_pr_curve, weather_buckets


def segment_metrics(
    df: pd.DataFrame,
    y_score: np.ndarray,
    segment_col: str,
    baseline_rate: float,
    min_rows: int = 5000,
) -> pd.DataFrame:
    rows: list[dict] = []
    work = df.copy()
    work["y_score"] = y_score
    for segment, part in work.groupby(segment_col):
        if len(part) < min_rows:
            continue
        y_true = part["target"].astype(int)
        scores = part["y_score"].to_numpy()
        base = np.full(len(part), baseline_rate)
        model_m = compute_metrics(y_true, scores)
        base_m = compute_metrics(y_true, base)
        rows.append(
            {
                "segment_type": segment_col,
                "segment": str(segment),
                "n_rows": int(len(part)),
                "positive_rate": round(float(y_true.mean()), 4),
                "pr_auc_model": round(model_m["pr_auc"], 4),
                "pr_auc_baseline": round(base_m["pr_auc"], 4),
                "pr_auc_lift": round(model_m["pr_auc"] - base_m["pr_auc"], 4),
            }
        )
    return pd.DataFrame(rows).sort_values("n_rows", ascending=False)


def permutation_importance_frame(
    model,
    x: pd.DataFrame,
    y: pd.Series,
    sample_n: int,
    seed: int,
) -> pd.DataFrame:
    if len(x) > sample_n:
        idx = x.sample(n=sample_n, random_state=seed).index
        x = x.loc[idx]
        y = y.loc[idx]
    result = permutation_importance(
        model,
        x,
        y,
        n_repeats=3,
        random_state=seed,
        n_jobs=1,
    )
    return (
        pd.DataFrame(
            {
                "feature": x.columns,
                "importance_mean": result.importances_mean,
                "importance_std": result.importances_std,
            }
        )
        .sort_values("importance_mean", ascending=False)
        .reset_index(drop=True)
    )


def try_shap_summary(model, x: pd.DataFrame, sample_n: int, seed: int, path: Path) -> bool:
    try:
        import shap  # noqa: WPS433
    except ImportError:
        print("shap not installed — skipping SHAP plot")
        return False

    prep = model.named_steps["prep"]
    clf = model.named_steps["clf"]
    if len(x) > sample_n:
        x = x.sample(n=sample_n, random_state=seed)

    x_transformed = prep.transform(x)
    feature_names = prep.get_feature_names_out()
    explainer = shap.TreeExplainer(clf)
    shap_values = explainer.shap_values(x_transformed)
    import matplotlib.pyplot as plt

    shap.summary_plot(
        shap_values,
        x_transformed,
        feature_names=feature_names,
        show=False,
        max_display=15,
    )
    plt.tight_layout()
    plt.savefig(path, dpi=120, bbox_inches="tight")
    plt.close()
    return True


def main() -> None:
    parser = argparse.ArgumentParser(description="Evaluate 2025 holdout (score once).")
    parser.add_argument("--data-dir", type=Path, default=DATA_DIR)
    parser.add_argument("--skip-shap", action="store_true")
    args = parser.parse_args()
    ensure_dirs()
    cfg = load_config()
    target_col = cfg["target"]
    seed = int(cfg["seed"])
    final_cfg = cfg.get("final", {})

    train_df, test_df = load_train_test(args.data_dir)
    model = load_model()
    baseline_rate = float(train_df[target_col].mean())

    x_test, y_test = split_xy(test_df, "full", target_col)
    print(f"Scoring 2025 holdout: {len(x_test):,} rows", flush=True)
    scores = model.predict_proba(x_test)[:, 1]
    base_scores = baseline_scores(train_df[target_col], len(y_test))

    holdout = {
        "split": "train 2023-2024, test 2025 (single holdout)",
        "train_rows": len(train_df),
        "test_rows": len(test_df),
        "baseline_positive_rate": round(baseline_rate, 4),
        "baseline": compute_metrics(y_test, base_scores),
        "hgb_tuned": compute_metrics(y_test, scores),
    }
    holdout["lift"] = {
        "pr_auc_absolute": round(
            holdout["hgb_tuned"]["pr_auc"] - holdout["baseline"]["pr_auc"],
            4,
        ),
        "pr_auc_relative_pct": round(
            100
            * (holdout["hgb_tuned"]["pr_auc"] - holdout["baseline"]["pr_auc"])
            / max(holdout["baseline"]["pr_auc"], 1e-9),
            1,
        ),
    }
    metrics_path = ARTIFACTS_DIR / "metrics_2025_holdout.json"
    save_json(metrics_path, holdout)
    print(json.dumps(holdout, indent=2))

    y_np = y_test.to_numpy()
    save_calibration_curve(y_np, scores, ARTIFACTS_DIR / "calibration_curve.png")
    save_pr_curve(
        y_np,
        scores,
        baseline_rate,
        ARTIFACTS_DIR / "pr_curve.png",
    )

    scored = test_df.copy()
    scored["y_score"] = scores
    scored = weather_buckets(scored)

    segments = pd.concat(
        [
            segment_metrics(scored, scores, "origin", baseline_rate, min_rows=10000),
            segment_metrics(scored, scores, "year_month", baseline_rate, min_rows=10000),
            segment_metrics(scored, scores, "wind_bucket", baseline_rate, min_rows=5000),
            segment_metrics(scored, scores, "precip_bucket", baseline_rate, min_rows=5000),
        ],
        ignore_index=True,
    )
    segments.to_csv(ARTIFACTS_DIR / "segment_metrics.csv", index=False)

    perm_n = int(final_cfg.get("perm_importance_sample", 100_000))
    perm = permutation_importance_frame(model, x_test, y_test, sample_n=perm_n, seed=seed)
    perm.to_csv(ARTIFACTS_DIR / "permutation_importance.csv", index=False)

    if not args.skip_shap:
        shap_n = int(final_cfg.get("shap_sample", 50_000))
        try_shap_summary(
            model,
            x_test,
            sample_n=shap_n,
            seed=seed,
            path=ARTIFACTS_DIR / "shap_summary.png",
        )

    write_run_metadata(
        {"metrics_path": str(metrics_path), "segments": len(segments)},
        "evaluate_metadata.json",
    )
    print(f"Wrote {metrics_path}")


if __name__ == "__main__":
    main()
