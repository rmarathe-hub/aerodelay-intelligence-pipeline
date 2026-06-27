"""Load BTS monthly CSV into raw.bts_flights with idempotent month reload."""

from __future__ import annotations

import argparse
import csv
import sys
import uuid
import zipfile
from datetime import datetime, timezone
from io import TextIOWrapper
from pathlib import Path
from typing import Iterable

from psycopg2.extras import execute_values

from ingestion.bts.config import BTS_RAW_DIR, BtsMonth, load_origin_airports
from ingestion.bts.download import download_month
from ingestion.bts.logging import ensure_meta_tables, finish_run, start_run
from ingestion.common.db import get_connection

RAW_TABLE = "raw.bts_flights"
METADATA_COLUMNS = ("run_id", "source_file", "loaded_at", "year_month")
CHUNK_SIZE = 5_000


def quote_ident(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


def sanitize_headers(headers: list[str]) -> list[str]:
    cleaned: list[str] = []
    seen: dict[str, int] = {}
    for header in headers:
        name = (header or "").strip()
        if not name:
            continue
        if name in seen:
            seen[name] += 1
            name = f"{name}_{seen[name]}"
        else:
            seen[name] = 0
        cleaned.append(name)
    return cleaned


def extract_csv_name(zip_path: Path) -> str:
    with zipfile.ZipFile(zip_path) as zf:
        csv_names = [info.filename for info in zf.infolist() if info.filename.lower().endswith(".csv")]
        if not csv_names:
            raise FileNotFoundError(f"No CSV found inside {zip_path}")
        return csv_names[0]


def read_csv_header(zip_path: Path) -> list[str]:
    with zipfile.ZipFile(zip_path) as zf:
        csv_name = extract_csv_name(zip_path)
        with zf.open(csv_name) as raw_handle:
            reader = csv.reader(TextIOWrapper(raw_handle, encoding="utf-8", errors="replace"))
            return sanitize_headers(next(reader))


def ensure_bts_table(source_columns: list[str]) -> None:
    column_defs = ",\n    ".join(f"{quote_ident(col)} TEXT" for col in source_columns)
    metadata_defs = """
    run_id UUID NOT NULL,
    source_file TEXT NOT NULL,
    loaded_at TIMESTAMPTZ NOT NULL,
    year_month TEXT NOT NULL
    """
    ddl = f"""
    CREATE TABLE IF NOT EXISTS {RAW_TABLE} (
        {column_defs},
        {metadata_defs}
    );
    CREATE INDEX IF NOT EXISTS idx_bts_flights_year_month
        ON {RAW_TABLE} (year_month);
    CREATE INDEX IF NOT EXISTS idx_bts_flights_origin
        ON {RAW_TABLE} ("Origin");
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(ddl)


def delete_month(year_month: str) -> int:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(f"DELETE FROM {RAW_TABLE} WHERE year_month = %s", (year_month,))
            deleted = cur.rowcount
    return deleted


def iter_filtered_rows(
    zip_path: Path,
    source_columns: list[str],
    origin_airports: set[str],
) -> Iterable[tuple[str, ...]]:
    origin_pos = source_columns.index("Origin")
    with zipfile.ZipFile(zip_path) as zf:
        csv_name = extract_csv_name(zip_path)
        with zf.open(csv_name) as raw_handle:
            reader = csv.reader(TextIOWrapper(raw_handle, encoding="utf-8", errors="replace"))
            raw_header = next(reader)
            keep_indices = [i for i, header in enumerate(raw_header) if (header or "").strip()]
            for row in reader:
                origin = row[keep_indices[origin_pos]].strip().upper() if keep_indices[origin_pos] < len(row) else ""
                if origin not in origin_airports:
                    continue
                yield tuple(
                    row[idx].strip() if idx < len(row) and row[idx] is not None else ""
                    for idx in keep_indices
                )


def insert_chunk(
    source_columns: list[str],
    rows: list[tuple],
    *,
    run_id: uuid.UUID,
    source_file: str,
    year_month: str,
    loaded_at: datetime,
) -> None:
    all_columns = list(source_columns) + list(METADATA_COLUMNS)
    quoted_cols = ", ".join(quote_ident(c) for c in source_columns)
    quoted_cols += ", run_id, source_file, loaded_at, year_month"
    sql = f"INSERT INTO {RAW_TABLE} ({quoted_cols}) VALUES %s"

    payload = [
        row + (str(run_id), source_file, loaded_at, year_month)
        for row in rows
    ]
    with get_connection() as conn:
        with conn.cursor() as cur:
            execute_values(cur, sql, payload, page_size=len(payload))


def load_month(
    year: int,
    month: int,
    *,
    zip_path: Path | None = None,
    download: bool = False,
) -> dict:
    bts_month = BtsMonth(year=year, month=month)
    ensure_meta_tables()

    if zip_path is None:
        zip_path = bts_month.zip_path
    if download or not zip_path.exists():
        zip_path = download_month(year, month)

    if not zip_path.exists():
        raise FileNotFoundError(f"BTS ZIP not found: {zip_path}")

    source_columns = read_csv_header(zip_path)
    ensure_bts_table(source_columns)
    origin_airports = load_origin_airports()

    run_id = start_run(bts_month.year_month, zip_path.name)
    loaded_at = datetime.now(timezone.utc)
    rows_loaded = 0

    try:
        rows_deleted = delete_month(bts_month.year_month)
        print(f"Deleted {rows_deleted:,} existing rows for {bts_month.year_month}")

        chunk: list[tuple] = []
        for row in iter_filtered_rows(zip_path, source_columns, origin_airports):
            chunk.append(row)
            if len(chunk) >= CHUNK_SIZE:
                insert_chunk(
                    source_columns,
                    chunk,
                    run_id=run_id,
                    source_file=zip_path.name,
                    year_month=bts_month.year_month,
                    loaded_at=loaded_at,
                )
                rows_loaded += len(chunk)
                print(f"Loaded {rows_loaded:,} rows...", end="\r")
                chunk = []

        if chunk:
            insert_chunk(
                source_columns,
                chunk,
                run_id=run_id,
                source_file=zip_path.name,
                year_month=bts_month.year_month,
                loaded_at=loaded_at,
            )
            rows_loaded += len(chunk)

        finish_run(
            run_id,
            status="success",
            rows_loaded=rows_loaded,
            rows_deleted=rows_deleted,
        )
        print(f"\nLoaded {rows_loaded:,} rows into {RAW_TABLE} for {bts_month.year_month}")
        return {
            "year_month": bts_month.year_month,
            "rows_loaded": rows_loaded,
            "rows_deleted": rows_deleted,
            "run_id": str(run_id),
            "source_file": zip_path.name,
        }
    except Exception as exc:
        finish_run(run_id, status="failed", error_message=str(exc))
        raise


def main() -> None:
    parser = argparse.ArgumentParser(description="Load BTS monthly ZIP into raw.bts_flights")
    parser.add_argument("--year", type=int, required=True)
    parser.add_argument("--month", type=int, required=True)
    parser.add_argument("--zip-path", type=Path, default=None, help="Use existing ZIP instead of data/raw/bts/")
    parser.add_argument("--download", action="store_true", help="Download ZIP before loading")
    args = parser.parse_args()

    result = load_month(
        args.year,
        args.month,
        zip_path=args.zip_path,
        download=args.download,
    )
    print(result)


if __name__ == "__main__":
    main()
