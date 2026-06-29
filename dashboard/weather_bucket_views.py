"""Helpers for weather-bucket dashboard views."""

from __future__ import annotations

import pandas as pd

WIND_ORDER = [
    "calm_0_5kt",
    "light_6_15kt",
    "moderate_16_25kt",
    "strong_26plus_kt",
    "unknown",
]
PRECIP_ORDER = ["none", "light", "moderate", "heavy"]
VISIBILITY_ORDER = [
    "high_over_10mi",
    "medium_3_10mi",
    "low_under_3mi",
    "unknown",
]

BUCKET_ORDERS = {
    "wind_speed_bucket": WIND_ORDER,
    "precip_bucket": PRECIP_ORDER,
    "visibility_bucket": VISIBILITY_ORDER,
}

BUCKET_LABELS = {
    "wind_speed_bucket": "Wind speed",
    "precip_bucket": "Precipitation (1h)",
    "visibility_bucket": "Visibility",
}


def _ordered_categories(series: pd.Series, bucket_col: str) -> pd.Categorical:
    order = BUCKET_ORDERS[bucket_col]
    present = [value for value in order if value in set(series)]
    extras = sorted(set(series) - set(order))
    return pd.Categorical(series, categories=present + extras, ordered=True)


def aggregate_bucket_rates(
    df: pd.DataFrame,
    bucket_col: str,
    airport: str | None = None,
    min_combo_flights: int = 0,
) -> pd.DataFrame:
    subset = df if airport is None else df[df["origin"] == airport]
    if min_combo_flights > 0:
        subset = subset[subset["flight_count"] >= min_combo_flights]

    grouped = (
        subset.groupby(bucket_col, as_index=False)
        .agg(
            flight_count=("flight_count", "sum"),
            delayed_count=("delayed_count", "sum"),
        )
        .assign(
            delay_rate_15=lambda d: d["delayed_count"] / d["flight_count"].clip(lower=1),
            delay_rate_pct=lambda d: (d["delayed_count"] / d["flight_count"].clip(lower=1) * 100).round(1),
        )
    )
    grouped[bucket_col] = _ordered_categories(grouped[bucket_col], bucket_col)
    return grouped.sort_values(bucket_col)


def weather_summary(
    df: pd.DataFrame,
    airport: str | None = None,
    min_combo_flights: int = 0,
) -> dict[str, float | int]:
    subset = df if airport is None else df[df["origin"] == airport]
    if min_combo_flights > 0:
        subset = subset[subset["flight_count"] >= min_combo_flights]
    flights = int(subset["flight_count"].sum())
    delayed = int(subset["delayed_count"].sum())
    rate = delayed / flights if flights else 0.0
    return {
        "flight_count": flights,
        "delayed_count": delayed,
        "delay_rate_15": rate,
        "combo_count": len(subset),
    }


def worst_weather_combos(
    df: pd.DataFrame,
    airport: str | None = None,
    min_combo_flights: int = 50,
    limit: int = 5,
) -> pd.DataFrame:
    subset = df if airport is None else df[df["origin"] == airport]
    subset = subset[subset["flight_count"] >= min_combo_flights].copy()
    subset["combo_label"] = (
        subset["wind_speed_bucket"]
        + " · "
        + subset["precip_bucket"]
        + " · "
        + subset["visibility_bucket"]
    )
    if airport is None:
        subset["combo_label"] = subset["origin"] + " — " + subset["combo_label"]
    return subset.sort_values(
        ["delay_rate_15", "flight_count"],
        ascending=[False, False],
    ).head(limit)


def precip_lift_vs_none(pooled_precip: pd.DataFrame) -> float | None:
    rates = pooled_precip.set_index("precip_bucket")["delay_rate_15"]
    if "none" not in rates.index or "heavy" not in rates.index:
        return None
    return float(rates["heavy"] - rates["none"])
