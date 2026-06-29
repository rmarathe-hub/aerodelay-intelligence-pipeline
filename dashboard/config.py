"""Dashboard configuration loaded from project .env."""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEMO_DATA_DIR = PROJECT_ROOT / "dashboard" / "demo_data"

load_dotenv(PROJECT_ROOT / ".env")


@dataclass(frozen=True)
class Settings:
    postgres_host: str
    postgres_port: int
    postgres_user: str
    postgres_password: str
    postgres_db: str
    data_scope_label: str

    @classmethod
    def from_env(cls) -> Settings:
        return cls(
            postgres_host=os.getenv("POSTGRES_HOST_LOCAL", "localhost"),
            postgres_port=int(os.getenv("POSTGRES_PORT", "5432")),
            postgres_user=os.getenv("POSTGRES_USER", "aerodelay"),
            postgres_password=os.getenv("POSTGRES_PASSWORD", ""),
            postgres_db=os.getenv("POSTGRES_DB", "aerodelay"),
            data_scope_label=os.getenv("DASHBOARD_DATA_SCOPE", "Jan 2025 sample"),
        )

    def dsn(self) -> str:
        return (
            f"host={self.postgres_host} port={self.postgres_port} "
            f"dbname={self.postgres_db} user={self.postgres_user} "
            f"password={self.postgres_password}"
        )


def get_settings() -> Settings:
    return Settings.from_env()
