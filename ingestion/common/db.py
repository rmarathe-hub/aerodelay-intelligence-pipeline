"""Postgres connection helpers for local ingestion scripts."""

from __future__ import annotations

import os
from contextlib import contextmanager
from pathlib import Path

import psycopg2

from ingestion.common.paths import PROJECT_ROOT


def load_dotenv(path: Path | None = None) -> None:
    """Minimal .env loader (no external dependency)."""
    env_path = path or PROJECT_ROOT / ".env"
    if not env_path.exists():
        return
    for line in env_path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        os.environ.setdefault(key.strip(), value.strip())


def get_connection_params() -> dict:
    load_dotenv()
    # Airflow container: connect to postgres service. Host laptop: use POSTGRES_HOST_LOCAL.
    if os.environ.get("AIRFLOW_HOME"):
        host = os.environ.get("POSTGRES_HOST", "postgres")
    else:
        host = os.environ.get("POSTGRES_HOST_LOCAL") or os.environ.get("POSTGRES_HOST", "localhost")
    return {
        "host": host,
        "port": int(os.environ.get("POSTGRES_PORT", "5432")),
        "dbname": os.environ.get("POSTGRES_DB", "aerodelay"),
        "user": os.environ.get("POSTGRES_USER", "aerodelay"),
        "password": os.environ.get("POSTGRES_PASSWORD", ""),
    }


@contextmanager
def get_connection():
    conn = psycopg2.connect(**get_connection_params())
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
