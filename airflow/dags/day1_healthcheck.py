"""
Placeholder DAG — proves Airflow picks up the dags/ folder.
Replaced in Week 1 Day 4+ with ingest_bts / ingest_weather.
"""

from datetime import datetime

from airflow import DAG
from airflow.operators.empty import EmptyOperator

with DAG(
    dag_id="aerodelay_day1_healthcheck",
    description="Day 1 stack health check — delete after real ingest DAGs exist",
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    tags=["aerodelay", "healthcheck"],
) as dag:
    EmptyOperator(task_id="stack_ok")
