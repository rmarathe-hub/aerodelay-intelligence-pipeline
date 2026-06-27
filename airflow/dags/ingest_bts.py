"""
Ingest one month of BTS On-Time Performance data into raw.bts_flights.

Trigger manually from Airflow UI with params:
  year  — e.g. 2025
  month — e.g. 1
"""

from __future__ import annotations

from datetime import datetime

from airflow.models.param import Param
from airflow.operators.bash import BashOperator
from airflow import DAG

with DAG(
    dag_id="ingest_bts",
    description="Download and load one month of BTS OTP data into raw.bts_flights",
    start_date=datetime(2023, 1, 1),
    schedule=None,
    catchup=False,
    max_active_runs=1,
    tags=["aerodelay", "ingest", "bts"],
    params={
        "year": Param(2025, type="integer", description="BTS file year"),
        "month": Param(1, type="integer", description="BTS file month (1-12)"),
    },
) as dag:
    ingest_bts_month = BashOperator(
        task_id="ingest_bts_month",
        bash_command="""
set -euo pipefail
export PYTHONPATH=/opt/airflow
cd /opt/airflow
python -m ingestion.bts.load \
  --year {{ params.year }} \
  --month {{ params.month }} \
  --download
""",
        retries=2,
    )
