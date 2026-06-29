"""AeroDelay Intelligence — Streamlit dashboard (Week 5)."""

from __future__ import annotations

import bootstrap  # noqa: F401 — repo root on sys.path for Streamlit Cloud

import altair as alt
import streamlit as st

from dashboard.config import get_settings
from dashboard.data import (
    check_postgres_connection,
    data_source_label,
    load_all_aggs,
    overview_metrics,
    using_demo_parquet,
)

st.set_page_config(
    page_title="AeroDelay Intelligence",
    page_icon="✈️",
    layout="wide",
    initial_sidebar_state="expanded",
)

st.title("AeroDelay Intelligence")
st.caption(
    "Flight delay risk across 45 U.S. airports — BTS On-Time Performance + ASOS/METAR weather"
)

settings = get_settings()
demo_mode = using_demo_parquet()

with st.sidebar:
    st.header("Data")
    if demo_mode:
        st.success("Demo parquet bundle loaded")
        st.caption("Streamlit Cloud / offline mode — no Postgres required.")
    else:
        ok_pg, message = check_postgres_connection(settings)
        if ok_pg:
            st.success(message)
        else:
            st.error(message)
            st.info("Run `make up` or `make export-dashboard-demo` for parquet fallback.")

    st.divider()
    st.markdown(f"**Scope:** {settings.data_scope_label}")
    st.markdown("**Pipeline:** BTS + weather ingest → dbt marts → dashboard")
    st.page_link("pages/1_Airport_Hour.py", label="Airport × Hour", icon="🕐")
    st.page_link("pages/2_Weather_Buckets.py", label="Weather Buckets", icon="🌧️")
    st.page_link("pages/3_Carrier_Routes.py", label="Carrier Routes", icon="🛫")

if not demo_mode:
    ok_pg, _ = check_postgres_connection(settings)
    if not ok_pg:
        st.warning(
            "Postgres is not reachable. Start Docker (`make up`) or export demo parquet: "
            "`make export-dashboard-demo`."
        )
        st.stop()

try:
    aggs = load_all_aggs(settings)
except Exception as exc:  # noqa: BLE001 — show load errors in UI
    st.error(f"Failed to load aggregation marts: {exc}")
    st.stop()

metrics = overview_metrics(
    aggs["airport_hour"],
    aggs["weather_bucket"],
    aggs["carrier_route"],
)

source_cols = st.columns(3)
source_cols[0].caption(f"Airport-hour source: **{data_source_label('airport_hour')}**")
source_cols[1].caption(f"Weather source: **{data_source_label('weather_bucket')}**")
source_cols[2].caption(f"Routes source: **{data_source_label('carrier_route')}**")

st.subheader("Executive snapshot")
col1, col2, col3, col4 = st.columns(4)
col1.metric("Airport × hour buckets", f"{metrics['airport_hour_rows']:,}")
col2.metric("Weather bucket rows", f"{metrics['weather_bucket_rows']:,}")
col3.metric("Carrier routes", f"{metrics['carrier_route_rows']:,}")
if metrics["top_airport"] and metrics["top_airport_delay_rate"] is not None:
    col4.metric(
        "Highest airport delay rate",
        f"{metrics['top_airport_delay_rate']:.1%}",
        help=f"Airports with ≥500 flights; leader: {metrics['top_airport']}",
    )

st.divider()

insight1, insight2, insight3 = st.columns(3)

with insight1:
    st.markdown("#### Busiest departure hour")
    busiest = metrics["busiest_hour"]
    if busiest is not None:
        st.markdown(
            f"**{busiest['origin']}** · **{int(busiest['dep_hour_utc']):02d}:00 UTC**  \n"
            f"{int(busiest['flight_count']):,} flights · "
            f"{float(busiest['delay_rate_15']):.1%} delayed 15+ min"
        )
    else:
        st.caption("No airport-hour data.")

with insight2:
    st.markdown("#### Top route by volume")
    top_route = metrics["top_route"]
    if top_route is not None:
        st.markdown(
            f"**{top_route['reporting_airline']}** "
            f"{top_route['origin']} → {top_route['dest']}  \n"
            f"{int(top_route['flight_count']):,} flights · "
            f"{float(top_route['delay_rate_15']):.1%} delayed"
        )
    else:
        st.caption("No route data.")

with insight3:
    st.markdown("#### Precip signal (pooled)")
    precip = metrics["precip_rates"]
    if not precip.empty and "none" in set(precip["precip_bucket"]) and "heavy" in set(
        precip["precip_bucket"]
    ):
        none_rate = float(
            precip.loc[precip["precip_bucket"] == "none", "delay_rate_15"].iloc[0]
        )
        heavy_rate = float(
            precip.loc[precip["precip_bucket"] == "heavy", "delay_rate_15"].iloc[0]
        )
        st.markdown(
            f"**None:** {none_rate:.1%} delayed  \n"
            f"**Heavy:** {heavy_rate:.1%} delayed  \n"
            f"**Lift:** +{(heavy_rate - none_rate):.1%} pts"
        )
    else:
        st.caption("Insufficient precip buckets.")

st.subheader("Delay rate by precipitation")
precip = metrics["precip_rates"]
if not precip.empty:
    precip_chart_df = precip.assign(
        delay_rate_pct=(precip["delay_rate_15"] * 100).round(1),
    )
    precip_chart = (
        alt.Chart(precip_chart_df)
        .mark_bar(color="#1f4e79")
        .encode(
            x=alt.X("precip_bucket:N", sort=["none", "light", "moderate", "heavy"], title="Precip"),
            y=alt.Y("delay_rate_pct:Q", title="Delay rate (%)"),
            tooltip=[
                "precip_bucket",
                alt.Tooltip("flight_count", format=","),
                alt.Tooltip("delay_rate_pct", title="Delay rate (%)"),
            ],
        )
        .properties(height=280)
    )
    st.altair_chart(precip_chart, use_container_width=True)

st.subheader("Explore")
nav1, nav2, nav3 = st.columns(3)
with nav1:
    st.page_link(
        "pages/1_Airport_Hour.py",
        label="Airport × Hour delays",
        icon="🕐",
        help="Hourly delay curves and airport leaderboard",
    )
with nav2:
    st.page_link(
        "pages/2_Weather_Buckets.py",
        label="Weather bucket analysis",
        icon="🌧️",
        help="Wind, precip, visibility vs delay",
    )
with nav3:
    st.page_link(
        "pages/3_Carrier_Routes.py",
        label="Carrier route performance",
        icon="🛫",
        help="Volume vs delay scatter and route rankings",
    )

st.caption(
    "AeroDelay Intelligence Pipeline · Jan 2025 dev sample · "
    "Raw backfill: 15.9M flights / 14.4M weather obs (2023–2025)"
)
