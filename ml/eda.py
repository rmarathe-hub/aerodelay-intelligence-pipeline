from __future__ import annotations

import argparse
import json
from pathlib import Path

import pandas as pd

from ml.config_loader import load_config
from ml.features import add_derived_features
from ml.paths import ARTIFACTS_DIR, DATA_DIR, ensure_dirs


def load_train_test(data_dir: Path) -> tuple[pd.DataFrame, pd.DataFrame]:
    train = pd.read_parquet(data_dir / "train_2023_2024.parquet")
    test = pd.read_parquet(data_dir / "test_2025.parquet")
    return add_derived_features(train), add_derived_features(test)


def summarize(df: pd.DataFrame, label: str) -> dict:
    return {
        "split": label,
        "rows": int(len(df)),
        "positive_rate": round(float(df["target"].mean()), 4),
        "months": int(df["year_month"].nunique()),
        "origins": int(df["origin"].nunique()),
        "airlines": int(df["reporting_airline"].nunique()),
        "missing_wind_pct": round(float(df["wind_speed_knots"].isna().mean()), 4),
        "missing_precip_pct": round(float(df["precip_1hr_inches"].isna().mean()), 4),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="EDA summary for ML extracts.")
    parser.add_argument("--data-dir", type=Path, default=DATA_DIR)
    parser.add_argument(
        "--output",
        type=Path,
        default=ARTIFACTS_DIR / "eda_summary.json",
    )
    args = parser.parse_args()
    ensure_dirs()
    cfg = load_config()
    target = cfg["target"]

    train, test = load_train_test(args.data_dir)
    summaries = [summarize(train, "train_2023_2024"), summarize(test, "test_2025")]

    by_year = (
        train.assign(year=train["year_month"].str.slice(0, 4))
        .groupby("year", as_index=False)
        .agg(rows=("target", "size"), positive_rate=("target", "mean"))
        .assign(positive_rate=lambda d: d["positive_rate"].round(4))
    )

    payload = {
        "summaries": summaries,
        "train_by_year": by_year.to_dict(orient="records"),
        "target_column": target,
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)
        handle.write("\n")

    print(json.dumps(payload, indent=2))


if __name__ == "__main__":
    main()
