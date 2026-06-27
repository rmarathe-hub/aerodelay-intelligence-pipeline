"""Load Iowa Mesonet ASOS CSV into raw.weather_observations with idempotent reload."""

from __future__ import annotations

import argparse
import csv
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

from psycopg2.extras import execute_values

from ingestion.weather.config import WEATHER_RAW_DIR, WeatherStationMonth, load_weather_stations
from ingestion.weather.download import download_station_month
from ingestion.weather.logging import ensure_meta_tables, finish_run, start_run
from ingestion.common.db import get_connection

RAW_TABLE = "raw.weather_observations"
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


def read_csv_header(csv_path: Path) -> list[str]:
    with csv_path.open(newline="", encoding="utf-8", errors="replace") as handle:
        reader = csv.reader(handle)
        for row in reader:
            if not row or not any(cell.strip() for cell in row):
                continue
            if row[0].startswith("#"):
                continue
            return sanitize_headers(row)
    raise ValueError(f"No CSV header found in {csv_path}")


def ensure_weather_table(source_columns: list[str]) -> None:
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
    CREATE INDEX IF NOT EXISTS idx_weather_obs_year_month
        ON {RAW_TABLE} (year_month);
    CREATE INDEX IF NOT EXISTS idx_weather_obs_station
        ON {RAW_TABLE} ("station");
    CREATE INDEX IF NOT EXISTS idx_weather_obs_station_year_month
        ON {RAW_TABLE} ("station", year_month);
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(ddl)


def delete_station_month(station: str, year_month: str) -> int:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f'DELETE FROM {RAW_TABLE} WHERE "station" = %s AND year_month = %s',
                (station, year_month),
            )
            deleted = cur.rowcount
    return deleted


def iter_rows(csv_path: Path, source_columns: list[str]) -> Iterable[tuple[str, ...]]:
    with csv_path.open(newline="", encoding="utf-8", errors="replace") as handle:
        reader = csv.reader(handle)
        raw_header: list[str] | None = None
        keep_indices: list[int] = []

        for row in reader:
            if not row or not any(cell.strip() for cell in row):
                continue
            if row[0].startswith("#"):
                continue
            if raw_header is None:
                raw_header = row
                keep_indices = [i for i, header in enumerate(raw_header) if (header or "").strip()]
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


def load_station_month(
    station: str,
    year: int,
    month: int,
    *,
    csv_path: Path | None = None,
    download: bool = False,
) -> dict:
    station = station.strip().upper()
    station_month = WeatherStationMonth(station=station, year=year, month=month)
    ensure_meta_tables()

    if csv_path is None:
        csv_path = station_month.csv_path
    if download or not csv_path.exists():
        csv_path = download_station_month(station, year, month)

    if not csv_path.exists():
        raise FileNotFoundError(f"Weather CSV not found: {csv_path}")

    source_columns = read_csv_header(csv_path)
    if "station" not in source_columns:
        raise ValueError(f"CSV missing 'station' column: {csv_path}")
    if "valid" not in source_columns:
        raise ValueError(f"CSV missing 'valid' column: {csv_path}")

    ensure_weather_table(source_columns)

    run_id = start_run(station, station_month.year_month, csv_path.name)
    loaded_at = datetime.now(timezone.utc)
    rows_loaded = 0

    try:
        rows_deleted = delete_station_month(station, station_month.year_month)
        print(
            f"Deleted {rows_deleted:,} existing rows for "
            f"{station} {station_month.year_month}"
        )

        chunk: list[tuple] = []
        for row in iter_rows(csv_path, source_columns):
            chunk.append(row)
            if len(chunk) >= CHUNK_SIZE:
                insert_chunk(
                    source_columns,
                    chunk,
                    run_id=run_id,
                    source_file=csv_path.name,
                    year_month=station_month.year_month,
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
                source_file=csv_path.name,
                year_month=station_month.year_month,
                loaded_at=loaded_at,
            )
            rows_loaded += len(chunk)

        finish_run(
            run_id,
            status="success",
            rows_loaded=rows_loaded,
            rows_deleted=rows_deleted,
        )
        print(
            f"\nLoaded {rows_loaded:,} rows into {RAW_TABLE} for "
            f"{station} {station_month.year_month}"
        )
        return {
            "station": station,
            "year_month": station_month.year_month,
            "rows_loaded": rows_loaded,
            "rows_deleted": rows_deleted,
            "run_id": str(run_id),
            "source_file": csv_path.name,
        }
    except Exception as exc:
        finish_run(run_id, status="failed", error_message=str(exc))
        raise


def load_month(
    year: int,
    month: int,
    *,
    stations: list[str] | None = None,
    download: bool = False,
) -> list[dict]:
    target_stations = stations or load_weather_stations()
    results: list[dict] = []
    failures: list[str] = []

    for station in target_stations:
        try:
            outcome = load_station_month(
                station,
                year,
                month,
                download=download,
            )
            results.append(outcome)
        except Exception as exc:  # noqa: BLE001 - continue other stations
            failures.append(f"{station}: {exc}")
            print(f"FAIL {station} {year}-{month:02d}: {exc}", file=sys.stderr)

    if failures and not results:
        raise RuntimeError("All station loads failed:\n" + "\n".join(failures))
    if failures:
        print("Partial failures:", file=sys.stderr)
        for msg in failures:
            print(f"  - {msg}", file=sys.stderr)

    return results


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Load IEM ASOS CSV into raw.weather_observations"
    )
    parser.add_argument("--year", type=int, required=True)
    parser.add_argument("--month", type=int, required=True)
    parser.add_argument(
        "--station",
        default=None,
        help="Single station ID (default: all 45 mapped stations)",
    )
    parser.add_argument(
        "--csv-path",
        type=Path,
        default=None,
        help="Use existing CSV instead of data/raw/weather/",
    )
    parser.add_argument("--download", action="store_true", help="Download CSV before loading")
    args = parser.parse_args()

    if args.station:
        result = load_station_month(
            args.station,
            args.year,
            args.month,
            csv_path=args.csv_path,
            download=args.download,
        )
        print(result)
    else:
        results = load_month(args.year, args.month, download=args.download)
        total_rows = sum(r["rows_loaded"] for r in results)
        print(f"Loaded {total_rows:,} rows across {len(results)} stations")


if __name__ == "__main__":
    main()
