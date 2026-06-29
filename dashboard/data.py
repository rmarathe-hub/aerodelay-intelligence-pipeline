"""Load aggregation marts for the Streamlit dashboard."""

from __future__ import annotations

from pathlib import Path

import pandas as pd
import psycopg2
import streamlit as st

from dashboard.config import DEMO_DATA_DIR, Settings, get_settings

AGG_TABLES = {
    "airport_hour": "marts.agg_delay_by_airport_hour",
    "weather_bucket": "marts.agg_delay_by_weather_bucket",
    "carrier_route": "marts.agg_delay_by_carrier_route",
}

PARQUET_FILES = {
    "airport_hour": DEMO_DATA_DIR / "agg_delay_by_airport_hour.parquet",
    "weather_bucket": DEMO_DATA_DIR / "agg_delay_by_weather_bucket.parquet",
    "carrier_route": DEMO_DATA_DIR / "agg_delay_by_carrier_route.parquet",
}


def using_demo_parquet() -> bool:
    return all(path.is_file() for path in PARQUET_FILES.values())


def data_source_label(table_key: str) -> str:
    return "parquet" if PARQUET_FILES[table_key].is_file() else "postgres"


def check_postgres_connection(settings: Settings | None = None) -> tuple[bool, str]:
    settings = settings or get_settings()
    if not settings.postgres_password:
        return False, "POSTGRES_PASSWORD is not set in .env"
    try:
        with psycopg2.connect(settings.dsn()) as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
        return True, f"Connected to {settings.postgres_db} @ {settings.postgres_host}"
    except psycopg2.Error as exc:
        return False, str(exc).strip()


@st.cache_data(ttl=300, show_spinner=False)
def load_agg_table(table_key: str, _dsn: str) -> pd.DataFrame:
    """Load one agg mart from parquet (deploy) or Postgres (local dev)."""
    parquet_path: Path = PARQUET_FILES[table_key]
    if parquet_path.is_file():
        return pd.read_parquet(parquet_path)

    relation = AGG_TABLES[table_key]
    query = f"SELECT * FROM {relation}"
    with psycopg2.connect(_dsn) as conn:
        return pd.read_sql_query(query, conn)


def load_all_aggs(settings: Settings | None = None) -> dict[str, pd.DataFrame]:
    settings = settings or get_settings()
    return {
        key: load_agg_table(key, settings.dsn())
        for key in AGG_TABLES
    }


def overview_metrics(
    airport_hour: pd.DataFrame,
    weather_bucket: pd.DataFrame,
    carrier_route: pd.DataFrame,
) -> dict[str, object]:
    top_airport = airport_hour.loc[airport_hour["flight_count"] >= 500].sort_values(
        "delay_rate_15", ascending=False
    )
    top_precip = (
        weather_bucket.groupby("precip_bucket", as_index=False)
        .agg(flight_count=("flight_count", "sum"), delayed_count=("delayed_count", "sum"))
        .assign(
            delay_rate_15=lambda df: df["delayed_count"] / df["flight_count"].clip(lower=1)
        )
        .sort_values("precip_bucket")
    )

    return {
        "airport_hour_rows": len(airport_hour),
        "weather_bucket_rows": len(weather_bucket),
        "carrier_route_rows": len(carrier_route),
        "top_airport": (
            top_airport.iloc[0]["origin"] if not top_airport.empty else None
        ),
        "top_airport_delay_rate": (
            float(top_airport.iloc[0]["delay_rate_15"]) if not top_airport.empty else None
        ),
        "busiest_hour": (
            airport_hour.sort_values("flight_count", ascending=False).iloc[0]
            if not airport_hour.empty
            else None
        ),
        "precip_rates": top_precip,
        "top_route": (
            carrier_route.sort_values("flight_count", ascending=False).iloc[0]
            if not carrier_route.empty
            else None
        ),
    }
