from __future__ import annotations

import os
from pathlib import Path

import psycopg2
from dotenv import load_dotenv

PROJECT_ROOT = Path(__file__).resolve().parents[1]
load_dotenv(PROJECT_ROOT / ".env")


def postgres_dsn() -> str:
    host = os.getenv("POSTGRES_HOST_LOCAL", "localhost")
    port = int(os.getenv("POSTGRES_PORT", "5432"))
    user = os.getenv("POSTGRES_USER", "aerodelay")
    password = os.getenv("POSTGRES_PASSWORD", "")
    dbname = os.getenv("POSTGRES_DB", "aerodelay")
    return (
        f"host={host} port={port} dbname={dbname} "
        f"user={user} password={password}"
    )


def connect():
    return psycopg2.connect(postgres_dsn())
