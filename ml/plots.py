from __future__ import annotations

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from sklearn.calibration import calibration_curve
from sklearn.metrics import auc, precision_recall_curve


def save_calibration_curve(
    y_true: np.ndarray,
    y_score: np.ndarray,
    path,
    title: str = "Calibration curve (2025 holdout)",
) -> None:
    prob_true, prob_pred = calibration_curve(y_true, y_score, n_bins=10, strategy="quantile")
    fig, ax = plt.subplots(figsize=(6, 4))
    ax.plot([0, 1], [0, 1], linestyle="--", color="gray", label="Perfect calibration")
    ax.plot(prob_pred, prob_true, marker="o", label="Model")
    ax.set_xlabel("Mean predicted probability")
    ax.set_ylabel("Fraction of positives")
    ax.set_title(title)
    ax.legend()
    fig.tight_layout()
    fig.savefig(path, dpi=120)
    plt.close(fig)


def save_pr_curve(
    y_true: np.ndarray,
    y_score: np.ndarray,
    baseline_rate: float,
    path,
    title: str = "Precision–Recall (2025 holdout)",
) -> float:
    precision, recall, _ = precision_recall_curve(y_true, y_score)
    pr_auc = auc(recall, precision)
    fig, ax = plt.subplots(figsize=(6, 4))
    ax.plot(recall, precision, label=f"Model (AP={pr_auc:.3f})")
    ax.hlines(
        baseline_rate,
        0,
        1,
        colors="gray",
        linestyles="--",
        label=f"Baseline rate ({baseline_rate:.3f})",
    )
    ax.set_xlabel("Recall")
    ax.set_ylabel("Precision")
    ax.set_title(title)
    ax.legend()
    fig.tight_layout()
    fig.savefig(path, dpi=120)
    plt.close(fig)
    return float(pr_auc)


def weather_buckets(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    wind = out["wind_speed_knots"]
    precip = out["precip_1hr_inches"].fillna(0)
    out["wind_bucket"] = np.select(
        [
            wind.isna(),
            wind <= 5,
            wind <= 15,
            wind <= 25,
        ],
        ["unknown", "calm", "light", "moderate"],
        default="strong",
    )
    out["precip_bucket"] = np.select(
        [precip == 0, precip <= 0.1, precip <= 0.3],
        ["none", "light", "moderate"],
        default="heavy",
    )
    return out
