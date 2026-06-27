"""Ingestion run logging to meta.weather_ingest_log."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from ingestion.common.db import get_connection


def ensure_meta_tables() -> None:
    ddl = """
    CREATE TABLE IF NOT EXISTS meta.weather_ingest_log (
        run_id UUID PRIMARY KEY,
        station TEXT NOT NULL,
        year_month TEXT NOT NULL,
        source_file TEXT,
        rows_deleted INTEGER DEFAULT 0,
        rows_loaded INTEGER DEFAULT 0,
        started_at TIMESTAMPTZ NOT NULL,
        completed_at TIMESTAMPTZ,
        status TEXT NOT NULL,
        error_message TEXT
    );
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(ddl)


def start_run(station: str, year_month: str, source_file: str) -> uuid.UUID:
    run_id = uuid.uuid4()
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO meta.weather_ingest_log (
                    run_id, station, year_month, source_file, started_at, status
                ) VALUES (%s, %s, %s, %s, %s, 'running')
                """,
                (str(run_id), station, year_month, source_file, datetime.now(timezone.utc)),
            )
    return run_id


def finish_run(
    run_id: uuid.UUID,
    *,
    status: str,
    rows_loaded: int = 0,
    rows_deleted: int = 0,
    error_message: str | None = None,
) -> None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE meta.weather_ingest_log
                SET completed_at = %s,
                    status = %s,
                    rows_loaded = %s,
                    rows_deleted = %s,
                    error_message = %s
                WHERE run_id = %s
                """,
                (
                    datetime.now(timezone.utc),
                    status,
                    rows_loaded,
                    rows_deleted,
                    error_message,
                    str(run_id),
                ),
            )
