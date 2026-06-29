"""Helpers for airport × hour dashboard views."""

from __future__ import annotations

import pandas as pd


def prepare_airport_hour(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    out["dep_hour_utc"] = out["dep_hour_utc"].astype(int)
    out["hour_label"] = out["dep_hour_utc"].map(lambda h: f"{h:02d}:00")
    return out


def filter_airport_hour(
    df: pd.DataFrame,
    airport: str,
    min_flights: int,
) -> pd.DataFrame:
    subset = df[df["origin"] == airport].copy()
    subset = subset[subset["flight_count"] >= min_flights]
    return subset.sort_values("dep_hour_utc")


def airport_summary(df: pd.DataFrame, airport: str) -> dict[str, float | int]:
    subset = df[df["origin"] == airport]
    flights = int(subset["flight_count"].sum())
    delayed = int(subset["delayed_count"].sum())
    rate = delayed / flights if flights else 0.0
    avg_delay = (
        (subset["avg_dep_delay_minutes"] * subset["flight_count"]).sum() / flights
        if flights
        else 0.0
    )
    return {
        "flight_count": flights,
        "delayed_count": delayed,
        "delay_rate_15": rate,
        "avg_dep_delay_minutes": avg_delay,
    }


def top_delay_hours(
    df: pd.DataFrame,
    airport: str,
    min_flights: int,
    limit: int = 5,
) -> pd.DataFrame:
    subset = filter_airport_hour(df, airport, min_flights)
    return subset.sort_values(
        ["delay_rate_15", "flight_count"],
        ascending=[False, False],
    ).head(limit)


def top_airports_by_delay(
    df: pd.DataFrame,
    min_airport_flights: int = 500,
    limit: int = 10,
) -> pd.DataFrame:
    airport_totals = (
        df.groupby("origin", as_index=False)
        .agg(
            flight_count=("flight_count", "sum"),
            delayed_count=("delayed_count", "sum"),
        )
        .assign(
            delay_rate_15=lambda d: d["delayed_count"] / d["flight_count"].clip(lower=1)
        )
    )
    return (
        airport_totals[airport_totals["flight_count"] >= min_airport_flights]
        .sort_values("delay_rate_15", ascending=False)
        .head(limit)
    )
