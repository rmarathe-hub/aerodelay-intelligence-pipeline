from __future__ import annotations

import json
from typing import Any

import numpy as np
import pandas as pd
from sklearn.metrics import (
    average_precision_score,
    brier_score_loss,
    precision_recall_curve,
    roc_auc_score,
)


def predict_scores(model, x: pd.DataFrame) -> np.ndarray:
    if hasattr(model, "predict_proba"):
        return model.predict_proba(x)[:, 1]
    return np.asarray(model)


def compute_metrics(y_true: pd.Series, y_score: np.ndarray) -> dict[str, float]:
    y = y_true.astype(int).to_numpy()
    scores = np.clip(np.asarray(y_score, dtype=float), 0.0, 1.0)
    metrics: dict[str, float] = {
        "pr_auc": float(average_precision_score(y, scores)),
        "roc_auc": float(roc_auc_score(y, scores)),
        "brier": float(brier_score_loss(y, scores)),
        "positive_rate": float(y.mean()),
        "n_rows": float(len(y)),
    }
    precision, recall, _ = precision_recall_curve(y, scores)
    target_recall = 0.5
    idx = np.argmin(np.abs(recall - target_recall))
    metrics["precision_at_recall_50"] = float(precision[idx])
    metrics["lift_at_top_decile"] = float(lift_at_top_decile(y, scores))
    return metrics


def lift_at_top_decile(y_true: np.ndarray, y_score: np.ndarray) -> float:
    if len(y_true) == 0:
        return 0.0
    base_rate = y_true.mean()
    if base_rate == 0:
        return 0.0
    cutoff = np.quantile(y_score, 0.9)
    top_mask = y_score >= cutoff
    if not top_mask.any():
        return 0.0
    top_rate = y_true[top_mask].mean()
    return float(top_rate / base_rate)


def baseline_scores(y_train: pd.Series, length: int) -> np.ndarray:
    rate = float(y_train.mean())
    return np.full(length, rate)


def metrics_to_frame(rows: list[dict[str, Any]]) -> pd.DataFrame:
    return pd.DataFrame(rows)


def save_json(path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)
        handle.write("\n")
