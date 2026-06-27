"""Download BTS On-Time Performance monthly ZIP files from TranStats."""

from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

import requests

from ingestion.bts.config import BTS_RAW_DIR, BtsMonth


def download_month(
    year: int,
    month: int,
    dest_dir: Path | None = None,
    retries: int = 3,
    min_bytes: int = 100_000,
    timeout: int = 120,
) -> Path:
    """Download one monthly BTS ZIP. Returns path to saved file."""
    bts_month = BtsMonth(year=year, month=month)
    dest = dest_dir or BTS_RAW_DIR
    dest.mkdir(parents=True, exist_ok=True)
    target = dest / bts_month.zip_filename

    last_error: Exception | None = None
    for attempt in range(1, retries + 1):
        try:
            print(f"Downloading {bts_month.url} (attempt {attempt}/{retries})")
            response = requests.get(bts_month.url, timeout=timeout, stream=True)
            response.raise_for_status()

            tmp_path = target.with_suffix(".zip.part")
            total = 0
            with tmp_path.open("wb") as handle:
                for chunk in response.iter_content(chunk_size=1024 * 1024):
                    if chunk:
                        handle.write(chunk)
                        total += len(chunk)

            if total < min_bytes:
                tmp_path.unlink(missing_ok=True)
                raise ValueError(f"Downloaded file too small ({total} bytes) — likely bad response")

            tmp_path.replace(target)
            print(f"Saved {target} ({total:,} bytes)")
            return target
        except Exception as exc:  # noqa: BLE001 - retry wrapper
            last_error = exc
            print(f"Download failed: {exc}", file=sys.stderr)
            if attempt < retries:
                sleep_seconds = attempt * 2
                print(f"Retrying in {sleep_seconds}s...")
                time.sleep(sleep_seconds)

    raise RuntimeError(f"Failed to download BTS {year}-{month:02d}") from last_error


def main() -> None:
    parser = argparse.ArgumentParser(description="Download BTS monthly OTP ZIP")
    parser.add_argument("--year", type=int, required=True)
    parser.add_argument("--month", type=int, required=True)
    parser.add_argument("--dest", type=Path, default=BTS_RAW_DIR)
    args = parser.parse_args()
    download_month(args.year, args.month, dest_dir=args.dest)


if __name__ == "__main__":
    main()
