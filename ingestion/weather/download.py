"""Download Iowa Mesonet ASOS/METAR CSV for one station-month."""

from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

import requests

from ingestion.weather.config import WEATHER_RAW_DIR, WeatherStationMonth


def download_station_month(
    station: str,
    year: int,
    month: int,
    dest_dir: Path | None = None,
    retries: int = 3,
    min_bytes: int = 100,
    timeout: int = 120,
) -> Path:
    """Download one station-month CSV from IEM. Returns path to saved file."""
    station_month = WeatherStationMonth(
        station=station.strip().upper(),
        year=year,
        month=month,
    )
    dest = dest_dir or WEATHER_RAW_DIR
    dest.mkdir(parents=True, exist_ok=True)
    target = dest / station_month.csv_filename

    last_error: Exception | None = None
    for attempt in range(1, retries + 1):
        try:
            print(
                f"Downloading {station_month.station} {year}-{month:02d} "
                f"(attempt {attempt}/{retries})"
            )
            response = requests.get(
                "https://mesonet.agron.iastate.edu/cgi-bin/request/asos.py",
                params=station_month.iem_params,
                timeout=timeout,
            )
            response.raise_for_status()
            content = response.content
            if len(content) < min_bytes:
                raise ValueError(
                    f"Downloaded file too small ({len(content)} bytes) — likely bad response"
                )

            tmp_path = target.with_suffix(".csv.part")
            tmp_path.write_bytes(content)
            tmp_path.replace(target)
            print(f"Saved {target} ({len(content):,} bytes)")
            return target
        except Exception as exc:  # noqa: BLE001 - retry wrapper
            last_error = exc
            print(f"Download failed: {exc}", file=sys.stderr)
            if attempt < retries:
                sleep_seconds = attempt * 2
                print(f"Retrying in {sleep_seconds}s...")
                time.sleep(sleep_seconds)

    raise RuntimeError(
        f"Failed to download weather {station_month.station} {year}-{month:02d}"
    ) from last_error


def main() -> None:
    parser = argparse.ArgumentParser(description="Download IEM ASOS CSV for one station-month")
    parser.add_argument("--station", required=True, help="Weather station ID (e.g. ATL)")
    parser.add_argument("--year", type=int, required=True)
    parser.add_argument("--month", type=int, required=True)
    parser.add_argument("--dest", type=Path, default=WEATHER_RAW_DIR)
    args = parser.parse_args()
    download_station_month(args.station, args.year, args.month, dest_dir=args.dest)


if __name__ == "__main__":
    main()
