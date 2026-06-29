from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import joblib
import pandas as pd
import yaml
from sklearn.pipeline import Pipeline

from ml.config_loader import load_config
from ml.features import add_derived_features
from ml.paths import ARTIFACTS_DIR, CONFIG_PATH, DATA_DIR, MODELS_DIR, ensure_dirs


def load_best_params(path: Path | None = None) -> dict[str, Any]:
    params_path = path or ARTIFACTS_DIR / "best_params.json"
    with params_path.open(encoding="utf-8") as handle:
        payload = json.load(handle)
    params = dict(payload["best_params"])
    params.setdefault("random_state", int(load_config()["seed"]))
    return params


def load_train_test(
    data_dir: Path | None = None,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    data_dir = data_dir or DATA_DIR
    train = add_derived_features(pd.read_parquet(data_dir / "train_2023_2024.parquet"))
    test = add_derived_features(pd.read_parquet(data_dir / "test_2025.parquet"))
    return train, test


def save_model(model: Pipeline, name: str = "final_hgb") -> Path:
    ensure_dirs()
    path = MODELS_DIR / f"{name}.joblib"
    joblib.dump(model, path)
    return path


def load_model(name: str = "final_hgb") -> Pipeline:
    path = MODELS_DIR / f"{name}.joblib"
    return joblib.load(path)


def write_run_metadata(payload: dict[str, Any], filename: str) -> Path:
    path = ARTIFACTS_DIR / filename
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)
        handle.write("\n")
    return path


def read_final_config() -> dict[str, Any]:
    with CONFIG_PATH.open(encoding="utf-8") as handle:
        cfg = yaml.safe_load(handle)
    return cfg.get("final", {})
