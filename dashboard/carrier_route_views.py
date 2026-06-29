"""Helpers for carrier-route dashboard views."""

from __future__ import annotations

import pandas as pd


def prepare_carrier_routes(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    out["route_label"] = out["origin"] + " → " + out["dest"]
    out["delay_rate_pct"] = (out["delay_rate_15"] * 100).round(1)
    return out


def filter_carrier_routes(
    df: pd.DataFrame,
    carriers: list[str] | None = None,
    origin: str | None = None,
    dest: str | None = None,
    min_flights: int = 0,
) -> pd.DataFrame:
    subset = df.copy()
    if carriers:
        subset = subset[subset["reporting_airline"].isin(carriers)]
    if origin:
        subset = subset[subset["origin"] == origin]
    if dest:
        subset = subset[subset["dest"] == dest]
    if min_flights > 0:
        subset = subset[subset["flight_count"] >= min_flights]
    return subset


def route_summary(df: pd.DataFrame) -> dict[str, float | int]:
    flights = int(df["flight_count"].sum())
    delayed = int(df["delayed_count"].sum())
    rate = delayed / flights if flights else 0.0
    return {
        "route_count": len(df),
        "flight_count": flights,
        "delayed_count": delayed,
        "delay_rate_15": rate,
    }


def top_routes_by_volume(df: pd.DataFrame, limit: int = 10) -> pd.DataFrame:
    label_col = "route_label" if "route_label" in df.columns else "origin"
    out = df.sort_values("flight_count", ascending=False).head(limit).copy()
    if "reporting_airline" in out.columns:
        out["label"] = out["reporting_airline"] + " " + out["route_label"]
    else:
        out["label"] = out[label_col]
    return out


def top_routes_by_delay(
    df: pd.DataFrame,
    min_flights: int = 50,
    limit: int = 10,
) -> pd.DataFrame:
    subset = df[df["flight_count"] >= min_flights].copy()
    subset = subset.sort_values(
        ["delay_rate_15", "flight_count"],
        ascending=[False, False],
    ).head(limit)
    subset["label"] = subset["reporting_airline"] + " " + subset["route_label"]
    return subset


def carrier_leaderboard(df: pd.DataFrame, min_flights: int = 200) -> pd.DataFrame:
    grouped = (
        df.groupby("reporting_airline", as_index=False)
        .agg(
            flight_count=("flight_count", "sum"),
            delayed_count=("delayed_count", "sum"),
        )
        .assign(
            delay_rate_15=lambda d: d["delayed_count"] / d["flight_count"].clip(lower=1),
            delay_rate_pct=lambda d: (
                d["delayed_count"] / d["flight_count"].clip(lower=1) * 100
            ).round(1),
        )
    )
    return (
        grouped[grouped["flight_count"] >= min_flights]
        .sort_values("delay_rate_15", ascending=False)
    )
