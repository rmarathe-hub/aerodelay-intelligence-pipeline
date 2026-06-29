from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone

import pandas as pd

from ml.config_loader import load_config
from ml.cv import maybe_subsample
from ml.features import build_hgb_pipeline, split_xy
from ml.io_utils import load_best_params, load_train_test, save_model, write_run_metadata
from ml.paths import ARTIFACTS_DIR, ensure_dirs


def main() -> None:
    parser = argparse.ArgumentParser(description="Train final HGB on 2023-2024.")
    parser.add_argument("--subsample", type=int, default=None)
    args = parser.parse_args()
    ensure_dirs()
    cfg = load_config()
    target_col = cfg["target"]
    seed = int(cfg["seed"])
    final_cfg = cfg.get("final", {})
    subsample = args.subsample if args.subsample is not None else final_cfg.get("train_subsample")

    train_df, test_df = load_train_test()
    if subsample:
        train_df = maybe_subsample(train_df, int(subsample), seed, target_col)
    print(f"Training rows: {len(train_df):,}", flush=True)

    params = load_best_params()
    x_train, y_train = split_xy(train_df, "full", target_col)
    model = build_hgb_pipeline("full", params=params)
    model.fit(x_train, y_train)

    model_path = save_model(model)
    metadata = {
        "trained_at_utc": datetime.now(timezone.utc).isoformat(),
        "train_rows": len(train_df),
        "test_rows_held_out": len(test_df),
        "train_positive_rate": round(float(y_train.mean()), 4),
        "feature_set": "full",
        "best_params": params,
        "model_path": str(model_path),
        "train_subsample": subsample,
    }
    meta_path = write_run_metadata(metadata, "train_metadata.json")
    print(json.dumps(metadata, indent=2))
    print(f"Saved model → {model_path}")
    print(f"Saved metadata → {meta_path}")


if __name__ == "__main__":
    main()
