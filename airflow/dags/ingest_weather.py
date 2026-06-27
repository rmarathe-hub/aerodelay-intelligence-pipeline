"""
Ingest Iowa Mesonet ASOS/METAR weather into raw.weather_observations.

Trigger manually from Airflow UI with params:
  year    — e.g. 2025
  month   — e.g. 1
  station — optional single station (e.g. ATL); omit for all 45 stations
"""

from __future__ import annotations

from datetime import datetime

from airflow.models.param import Param
from airflow.operators.bash import BashOperator
from airflow import DAG

with DAG(
    dag_id="ingest_weather",
    description="Download and load ASOS/METAR weather into raw.weather_observations",
    start_date=datetime(2023, 1, 1),
    schedule=None,
    catchup=False,
    max_active_runs=1,
    tags=["aerodelay", "ingest", "weather"],
    params={
        "year": Param(2025, type="integer", description="Weather file year"),
        "month": Param(1, type="integer", description="Weather file month (1-12)"),
        "station": Param(
            "",
            type="string",
            description="Optional single station ID (empty = all 45 stations)",
        ),
    },
) as dag:
    ingest_weather_month = BashOperator(
        task_id="ingest_weather_month",
        bash_command="""
set -euo pipefail
export PYTHONPATH=/opt/airflow
cd /opt/airflow
STATION="{{ params.station }}"
CMD="python -m ingestion.weather.load --year {{ params.year }} --month {{ params.month }} --download"
if [[ -n "${STATION}" ]]; then
  CMD="${CMD} --station ${STATION}"
fi
eval "${CMD}"
""",
        retries=2,
    )
