"""Carrier route delay aggregates."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import bootstrap  # noqa: F401

import altair as alt
import streamlit as st

from dashboard.carrier_route_views import (
    carrier_leaderboard,
    filter_carrier_routes,
    prepare_carrier_routes,
    route_summary,
    top_routes_by_delay,
    top_routes_by_volume,
)
from dashboard.config import get_settings
from dashboard.data import load_agg_table

st.set_page_config(page_title="Carrier Routes", layout="wide")
st.title("Delay by carrier route")
st.caption("Reporting airline × origin × destination (Jan 2025 sample)")

settings = get_settings()
df = prepare_carrier_routes(load_agg_table("carrier_route", settings.dsn()))

carriers = sorted(df["reporting_airline"].unique())
origins = sorted(df["origin"].unique())
dests = sorted(df["dest"].unique())

with st.sidebar:
    st.subheader("Filters")
    selected_carriers = st.multiselect(
        "Carriers",
        carriers,
        default=[],
        help="Leave empty to include all carriers.",
    )
    origin = st.selectbox("Origin", ["All"] + origins, index=0)
    dest = st.selectbox("Destination", ["All"] + dests, index=0)
    min_flights = st.slider(
        "Min flights per route",
        min_value=25,
        max_value=200,
        value=50,
        step=25,
    )

filtered = filter_carrier_routes(
    df,
    carriers=selected_carriers or None,
    origin=None if origin == "All" else origin,
    dest=None if dest == "All" else dest,
    min_flights=min_flights,
)
summary = route_summary(filtered)

m1, m2, m3, m4 = st.columns(4)
m1.metric("Routes in view", f"{summary['route_count']:,}")
m2.metric("Total flights", f"{summary['flight_count']:,}")
m3.metric("Delayed (15+ min)", f"{summary['delayed_count']:,}")
m4.metric("Overall delay rate", f"{summary['delay_rate_15']:.1%}")

if filtered.empty:
    st.warning("No routes match the current filters.")
    st.stop()

st.subheader("Volume vs delay rate")
scatter = (
    alt.Chart(filtered)
    .mark_circle(opacity=0.75)
    .encode(
        x=alt.X("flight_count:Q", title="Flights on route"),
        y=alt.Y("delay_rate_pct:Q", title="Delay rate (%)"),
        size=alt.Size("flight_count:Q", legend=None, scale=alt.Scale(range=[40, 400])),
        color=alt.Color("reporting_airline:N", title="Carrier"),
        tooltip=[
            "reporting_airline",
            "route_label",
            alt.Tooltip("flight_count", title="Flights", format=","),
            alt.Tooltip("delay_rate_pct", title="Delay rate (%)"),
            alt.Tooltip("avg_dep_delay_minutes", title="Avg delay (min)", format=".1f"),
        ],
    )
    .properties(height=380)
)
st.altair_chart(scatter, use_container_width=True)
st.caption(
    "Top-right = high volume **and** high delay (operational pain points). "
    "Bottom-right = busy but relatively on-time."
)

left, right = st.columns(2)

with left:
    st.subheader("Top routes by volume")
    volume = top_routes_by_volume(filtered, limit=10)
    volume_chart = (
        alt.Chart(volume)
        .mark_bar(color="#5a9bd5")
        .encode(
            x=alt.X("flight_count:Q", title="Flights"),
            y=alt.Y("label:N", sort="-x", title="Route"),
            tooltip=["label", "flight_count", "delay_rate_pct"],
        )
        .properties(height=360)
    )
    st.altair_chart(volume_chart, use_container_width=True)

with right:
    st.subheader("Top routes by delay rate")
    delayed = top_routes_by_delay(filtered, min_flights=min_flights, limit=10)
    if delayed.empty:
        st.caption("No routes meet the flight minimum.")
    else:
        delay_chart = (
            alt.Chart(delayed)
            .mark_bar(color="#c44e52")
            .encode(
                x=alt.X("delay_rate_pct:Q", title="Delay rate (%)"),
                y=alt.Y("label:N", sort="-x", title="Route"),
                tooltip=["label", "flight_count", "delay_rate_pct"],
            )
            .properties(height=360)
        )
        st.altair_chart(delay_chart, use_container_width=True)

st.subheader("Carrier delay leaderboard")
carriers_ranked = carrier_leaderboard(filtered, min_flights=max(min_flights * 2, 200))
if carriers_ranked.empty:
    st.caption("No carriers meet the volume threshold for this view.")
else:
    carrier_chart = (
        alt.Chart(carriers_ranked)
        .mark_bar(color="#1f4e79")
        .encode(
            x=alt.X("delay_rate_pct:Q", title="Delay rate (%)"),
            y=alt.Y("reporting_airline:N", sort="-x", title="Carrier"),
            tooltip=[
                "reporting_airline",
                alt.Tooltip("flight_count", title="Flights", format=","),
                "delay_rate_pct",
            ],
        )
        .properties(height=max(280, 28 * len(carriers_ranked)))
    )
    st.altair_chart(carrier_chart, use_container_width=True)

with st.expander("Raw route data"):
    st.dataframe(
        filtered.sort_values("flight_count", ascending=False),
        hide_index=True,
        use_container_width=True,
    )
