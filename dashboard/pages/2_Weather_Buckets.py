"""Weather bucket delay aggregates."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import bootstrap  # noqa: F401

import altair as alt
import streamlit as st

from dashboard.config import get_settings
from dashboard.data import load_agg_table
from dashboard.weather_bucket_views import (
    BUCKET_LABELS,
    aggregate_bucket_rates,
    precip_lift_vs_none,
    weather_summary,
    worst_weather_combos,
)

st.set_page_config(page_title="Weather Buckets", layout="wide")
st.title("Delay by weather bucket")
st.caption(
    "Departure delay vs wind, precipitation, and visibility at origin "
    "(analysis-eligible flights with matched weather only)"
)

settings = get_settings()
df = load_agg_table("weather_bucket", settings.dsn())
airports = sorted(df["origin"].unique())

with st.sidebar:
    st.subheader("Filters")
    scope = st.radio(
        "Scope",
        ["All airports (pooled)", "Single airport"],
        index=0,
    )
    airport: str | None = None
    if scope == "Single airport":
        default = "DFW" if "DFW" in airports else airports[0]
        airport = st.selectbox("Airport", airports, index=airports.index(default))
    min_combo_flights = st.slider(
        "Min flights per weather combo",
        min_value=0,
        max_value=100,
        value=50,
        step=10,
        help="Applied before pooling bins and when ranking worst combos.",
    )

summary = weather_summary(df, airport, min_combo_flights)
scope_label = airport if airport else "All airports"

m1, m2, m3, m4 = st.columns(4)
m1.metric("Scope", scope_label)
m2.metric("Flights (matched weather)", f"{summary['flight_count']:,}")
m3.metric("Delay rate (15+ min)", f"{summary['delay_rate_15']:.1%}")
m4.metric("Weather combos in view", f"{summary['combo_count']:,}")

pooled_precip = aggregate_bucket_rates(df, "precip_bucket", airport, min_combo_flights)
lift = precip_lift_vs_none(pooled_precip)
if lift is not None:
    st.info(
        f"**Precip signal:** heavy precip delay rate is **{lift:.1%} points** "
        f"higher than no precip in this view."
    )

bucket_specs = [
    ("precip_bucket", "#1f4e79"),
    ("wind_speed_bucket", "#5a9bd5"),
    ("visibility_bucket", "#7f7f7f"),
]


def bucket_chart(data: pd.DataFrame, bucket_col: str, color: str) -> alt.Chart:
    return (
        alt.Chart(data)
        .mark_bar(color=color)
        .encode(
            x=alt.X(
                f"{bucket_col}:N",
                sort=list(data[bucket_col].astype(str)),
                title=BUCKET_LABELS[bucket_col],
            ),
            y=alt.Y("delay_rate_pct:Q", title="Delay rate (%)"),
            tooltip=[
                alt.Tooltip(bucket_col, title=BUCKET_LABELS[bucket_col]),
                alt.Tooltip("flight_count", title="Flights", format=","),
                alt.Tooltip("delayed_count", title="Delayed", format=","),
                alt.Tooltip("delay_rate_pct", title="Delay rate (%)"),
            ],
        )
        .properties(height=300)
    )


st.subheader("Delay rate by weather dimension")
cols = st.columns(3)
for col, (bucket_col, color) in zip(cols, bucket_specs, strict=True):
    chart_df = aggregate_bucket_rates(df, bucket_col, airport, min_combo_flights)
    with col:
        st.markdown(f"**{BUCKET_LABELS[bucket_col]}**")
        if chart_df.empty:
            st.caption("No data for current filters.")
        else:
            st.altair_chart(bucket_chart(chart_df, bucket_col, color), use_container_width=True)

st.subheader("Worst weather combinations")
worst = worst_weather_combos(df, airport, min_combo_flights, limit=8)
if worst.empty:
    st.caption("No combos meet the minimum flight threshold.")
else:
    worst = worst.assign(
        delay_rate_pct=(worst["delay_rate_15"] * 100).round(1),
    )
    combo_chart = (
        alt.Chart(worst)
        .mark_bar(color="#c44e52")
        .encode(
            x=alt.X("delay_rate_pct:Q", title="Delay rate (%)"),
            y=alt.Y("combo_label:N", sort="-x", title="Weather combo"),
            tooltip=[
                "combo_label",
                alt.Tooltip("flight_count", title="Flights", format=","),
                alt.Tooltip("delay_rate_pct", title="Delay rate (%)"),
                alt.Tooltip("avg_dep_delay_minutes", title="Avg delay (min)"),
            ],
        )
        .properties(height=max(280, 40 * len(worst)))
    )
    st.altair_chart(combo_chart, use_container_width=True)

with st.expander("Raw weather-bucket data"):
    view = df if airport is None else df[df["origin"] == airport]
    if min_combo_flights > 0:
        view = view[view["flight_count"] >= min_combo_flights]
    st.dataframe(
        view.sort_values(["origin", "delay_rate_15"], ascending=[True, False]),
        hide_index=True,
        use_container_width=True,
    )
