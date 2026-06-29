from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd

from ml.config_loader import load_config
from ml.db import connect
from ml.paths import DATA_DIR, ensure_dirs

EXTRACT_SQL = """
SELECT
    flight_date,
    year_month,
    reporting_airline,
    origin,
    dest,
    dep_hour_utc,
    dep_dow,
    dep_month,
    dep_time_source,
    wind_speed_knots,
    wind_gust_knots,
    precip_1hr_inches,
    visibility_miles,
    temperature_f,
    relative_humidity_pct,
    weather_obs_lag_minutes,
    is_dep_delay_15_plus AS target
FROM marts.fct_flights
WHERE is_analysis_eligible
  AND has_departure_weather
  AND origin != %(exclude_origin)s
ORDER BY flight_date, origin, reporting_airline, dest
"""


def extract_to_parquet(
    output_dir: Path,
    exclude_origin: str,
    chunksize: int,
) -> dict[str, int]:
    ensure_dirs()
    train_path = output_dir / "train_2023_2024.parquet"
    test_path = output_dir / "test_2025.parquet"
    cfg = load_config()
    test_start = cfg["splits"]["test_year_month_start"]

    if train_path.exists() and test_path.exists():
        train_n = len(pd.read_parquet(train_path, columns=["target"]))
        test_n = len(pd.read_parquet(test_path, columns=["target"]))
        print(f"Parquet already exists: train={train_n:,} test={test_n:,}")
        return {"train": train_n, "test": test_n}

    train_chunks: list[pd.DataFrame] = []
    test_chunks: list[pd.DataFrame] = []

    with connect() as conn:
        reader = pd.read_sql_query(
            EXTRACT_SQL,
            conn,
            params={"exclude_origin": exclude_origin},
            chunksize=chunksize,
        )
        for i, chunk in enumerate(reader, start=1):
            train_part = chunk[chunk["year_month"] < test_start]
            test_part = chunk[chunk["year_month"] >= test_start]
            if not train_part.empty:
                train_chunks.append(train_part)
            if not test_part.empty:
                test_chunks.append(test_part)
            print(
                f"  chunk {i}: +{len(train_part):,} train, +{len(test_part):,} test",
                flush=True,
            )

    train_df = pd.concat(train_chunks, ignore_index=True)
    test_df = pd.concat(test_chunks, ignore_index=True)
    train_df.to_parquet(train_path, index=False)
    test_df.to_parquet(test_path, index=False)

    counts = {"train": len(train_df), "test": len(test_df)}
    print(f"Wrote {train_path} ({counts['train']:,} rows)")
    print(f"Wrote {test_path} ({counts['test']:,} rows)")
    return counts


def main() -> None:
    parser = argparse.ArgumentParser(description="Extract ML training data from Postgres.")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DATA_DIR,
        help="Directory for parquet outputs",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Re-extract even if parquet files exist",
    )
    args = parser.parse_args()
    cfg = load_config()
    if args.force:
        for name in ("train_2023_2024.parquet", "test_2025.parquet"):
            path = args.output_dir / name
            if path.exists():
                path.unlink()

    counts = extract_to_parquet(
        output_dir=args.output_dir,
        exclude_origin=cfg["exclude_origin"],
        chunksize=int(cfg["extract"]["chunksize"]),
    )
    print(f"Extract complete: train={counts['train']:,} test={counts['test']:,}")


if __name__ == "__main__":
    main()
