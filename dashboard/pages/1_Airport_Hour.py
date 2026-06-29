"""Airport × UTC hour delay aggregates."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import bootstrap  # noqa: F401

import altair as alt
import streamlit as st

from dashboard.airport_hour_views import (
    airport_summary,
    filter_airport_hour,
    prepare_airport_hour,
    top_airports_by_delay,
    top_delay_hours,
)
from dashboard.config import get_settings
from dashboard.data import load_agg_table

st.set_page_config(page_title="Airport × Hour", layout="wide")
st.title("Delay by airport & hour")
st.caption("Departure delay rates by origin airport and UTC hour (Jan 2025 sample)")

settings = get_settings()
df = prepare_airport_hour(load_agg_table("airport_hour", settings.dsn()))
airports = sorted(df["origin"].unique())
default_airport = "DEN" if "DEN" in airports else airports[0]

with st.sidebar:
    st.subheader("Filters")
    airport = st.selectbox(
        "Airport",
        airports,
        index=airports.index(default_airport),
    )
    min_flights = st.slider(
        "Min flights per hour bucket",
        min_value=25,
        max_value=300,
        value=100,
        step=25,
        help="Hide thin hours with too few flights for stable delay rates.",
    )

summary = airport_summary(df, airport)
filtered = filter_airport_hour(df, airport, min_flights)

m1, m2, m3, m4 = st.columns(4)
m1.metric("Total flights", f"{summary['flight_count']:,}")
m2.metric("Delayed (15+ min)", f"{summary['delayed_count']:,}")
m3.metric("Overall delay rate", f"{summary['delay_rate_15']:.1%}")
m4.metric("Avg dep delay", f"{summary['avg_dep_delay_minutes']:.1f} min")

st.subheader(f"{airport} — hourly profile")
if filtered.empty:
    st.warning("No hour buckets match the current filters. Lower the minimum flight threshold.")
else:
    chart_df = filtered.assign(
        delay_rate_pct=lambda d: (d["delay_rate_15"] * 100).round(1),
    )

    rate_chart = (
        alt.Chart(chart_df)
        .mark_bar(color="#1f4e79")
        .encode(
            x=alt.X("hour_label:N", sort=None, title="Departure hour (UTC)"),
            y=alt.Y("delay_rate_pct:Q", title="Delay rate (%)"),
            tooltip=[
                alt.Tooltip("hour_label", title="Hour (UTC)"),
                alt.Tooltip("flight_count", title="Flights", format=","),
                alt.Tooltip("delayed_count", title="Delayed", format=","),
                alt.Tooltip("delay_rate_pct", title="Delay rate (%)"),
                alt.Tooltip("avg_dep_delay_minutes", title="Avg delay (min)", format=".1f"),
            ],
        )
        .properties(height=320)
    )

    volume_chart = (
        alt.Chart(chart_df)
        .mark_bar(color="#5a9bd5")
        .encode(
            x=alt.X("hour_label:N", sort=None, title="Departure hour (UTC)"),
            y=alt.Y("flight_count:Q", title="Flight count"),
            tooltip=["hour_label", "flight_count", "delayed_count"],
        )
        .properties(height=320)
    )

    left, right = st.columns(2)
    with left:
        st.markdown("**Delay rate by hour**")
        st.altair_chart(rate_chart, use_container_width=True)
    with right:
        st.markdown("**Flight volume by hour**")
        st.altair_chart(volume_chart, use_container_width=True)

st.subheader(f"Top delay hours — {airport}")
highlights = top_delay_hours(df, airport, min_flights, limit=5)
if highlights.empty:
    st.caption("No hours qualify at this flight minimum.")
else:
    cols = st.columns(min(len(highlights), 5))
    for col, (_, row) in zip(cols, highlights.iterrows(), strict=False):
        col.metric(
            label=f"{row['hour_label']} UTC",
            value=f"{row['delay_rate_15']:.1%}",
            delta=f"{int(row['flight_count']):,} flights",
            delta_color="off",
        )

st.subheader("Highest-delay airports")
top_airports = top_airports_by_delay(df, min_airport_flights=500, limit=10)
top_airports = top_airports.assign(
    delay_rate_pct=lambda d: (d["delay_rate_15"] * 100).round(1),
)
leaderboard = (
    alt.Chart(top_airports)
    .mark_bar(color="#c44e52")
    .encode(
        x=alt.X("delay_rate_pct:Q", title="Delay rate (%)"),
        y=alt.Y("origin:N", sort="-x", title="Airport"),
        tooltip=[
            alt.Tooltip("origin", title="Airport"),
            alt.Tooltip("flight_count", title="Flights", format=","),
            alt.Tooltip("delay_rate_pct", title="Delay rate (%)"),
        ],
    )
    .properties(height=360)
)
st.altair_chart(leaderboard, use_container_width=True)

with st.expander("Raw hourly data"):
    st.dataframe(
        filtered.sort_values("dep_hour_utc"),
        hide_index=True,
        use_container_width=True,
    )
