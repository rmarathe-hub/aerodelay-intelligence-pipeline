from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import optuna
import pandas as pd

from ml.config_loader import load_config
from ml.cv import filter_fold, maybe_subsample, run_cv
from ml.features import add_derived_features, build_hgb_pipeline, split_xy
from ml.metrics import compute_metrics
from ml.paths import ARTIFACTS_DIR, DATA_DIR, ensure_dirs


def objective_factory(
    train_df: pd.DataFrame,
    subsample: int,
    val_subsample: int | None,
    seed: int,
    target_col: str,
):
    cfg = load_config()

    def objective(trial: optuna.Trial) -> float:
        params = {
            "max_depth": trial.suggest_int("max_depth", 4, 12),
            "learning_rate": trial.suggest_float("learning_rate", 0.01, 0.2, log=True),
            "max_iter": trial.suggest_int("max_iter", 100, 300, step=50),
            "min_samples_leaf": trial.suggest_int("min_samples_leaf", 20, 200, step=10),
            "l2_regularization": trial.suggest_float("l2_regularization", 1e-4, 10.0, log=True),
            "random_state": seed,
        }
        fold_scores: list[float] = []
        for fold in cfg["cv"]["folds"]:
            fold_train, fold_val = filter_fold(
                train_df,
                train_end=fold["train_end"],
                val_start=fold["val_start"],
                val_end=fold["val_end"],
            )
            fold_train = maybe_subsample(fold_train, subsample, seed, target_col)
            if val_subsample:
                fold_val = maybe_subsample(fold_val, val_subsample, seed + 1, target_col)
            x_train, y_train = split_xy(fold_train, "full", target_col)
            x_val, y_val = split_xy(fold_val, "full", target_col)
            model = build_hgb_pipeline("full", params=params)
            model.fit(x_train, y_train)
            scores = model.predict_proba(x_val)[:, 1]
            fold_scores.append(compute_metrics(y_val, scores)["pr_auc"])
        return float(np.mean(fold_scores))

    return objective


def main() -> None:
    parser = argparse.ArgumentParser(description="Optuna tuning for HistGradientBoosting.")
    parser.add_argument("--data-dir", type=Path, default=DATA_DIR)
    parser.add_argument("--trials", type=int, default=None)
    parser.add_argument("--subsample", type=int, default=None)
    args = parser.parse_args()
    ensure_dirs()
    cfg = load_config()
    seed = int(cfg["seed"])
    target_col = cfg["target"]
    trials = args.trials if args.trials is not None else int(cfg["tune"]["trials"])
    subsample = (
        args.subsample if args.subsample is not None else int(cfg["tune"]["subsample"])
    )
    val_subsample = cfg["cv"].get("val_subsample")

    train_df = add_derived_features(pd.read_parquet(args.data_dir / "train_2023_2024.parquet"))
    study = optuna.create_study(
        direction="maximize",
        study_name="hgb_delay_pr_auc",
        sampler=optuna.samplers.TPESampler(seed=seed),
    )
    study.optimize(
        objective_factory(train_df, subsample, val_subsample, seed, target_col),
        n_trials=trials,
        show_progress_bar=True,
    )

    best = {
        "best_value": study.best_value,
        "best_params": study.best_params,
        "trials": trials,
        "subsample": subsample,
        "metric": "mean_cv_pr_auc",
    }
    out_path = ARTIFACTS_DIR / "best_params.json"
    with out_path.open("w", encoding="utf-8") as handle:
        json.dump(best, handle, indent=2)
        handle.write("\n")
    print(json.dumps(best, indent=2))
    print(f"Wrote {out_path}")


if __name__ == "__main__":
    main()
