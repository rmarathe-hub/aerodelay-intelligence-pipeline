from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd

from ml.config_loader import load_config
from ml.cv import run_cv, summarize_cv
from ml.features import add_derived_features
from ml.paths import ARTIFACTS_DIR, DATA_DIR, ensure_dirs


def main() -> None:
    parser = argparse.ArgumentParser(description="Feature-set ablation across CV folds.")
    parser.add_argument("--data-dir", type=Path, default=DATA_DIR)
    parser.add_argument("--subsample", type=int, default=None)
    args = parser.parse_args()
    ensure_dirs()
    cfg = load_config()
    seed = int(cfg["seed"])
    target_col = cfg["target"]
    subsample = args.subsample if args.subsample is not None else cfg["cv"].get("subsample")
    val_subsample = cfg["cv"].get("val_subsample")

    train_df = add_derived_features(pd.read_parquet(args.data_dir / "train_2023_2024.parquet"))
    frames: list[pd.DataFrame] = []
    for feature_set in ("schedule_only", "weather_only", "full"):
        print(f"=== ablation: {feature_set} ===", flush=True)
        frames.append(
            run_cv(
                train_df,
                subsample=subsample,
                seed=seed,
                target_col=target_col,
                feature_set=feature_set,
                val_subsample=val_subsample,
            )
        )

    results = pd.concat(frames, ignore_index=True)
    hgb_only = results[results["model"] == "hgb_default"].copy()
    out_path = ARTIFACTS_DIR / "ablation.csv"
    hgb_only.to_csv(out_path, index=False)
    print(f"Wrote {out_path}")
    print(summarize_cv(hgb_only))


if __name__ == "__main__":
    main()
