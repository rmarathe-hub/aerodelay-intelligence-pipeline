"""Backfill BTS monthly data: download + load over a date range."""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from datetime import datetime, timezone

from ingestion.bts.load import load_month
from ingestion.common.paths import PROJECT_ROOT

INGEST_ISSUES_PATH = PROJECT_ROOT / "docs" / "ingest_issues.md"


@dataclass
class BackfillResult:
    year: int
    month: int
    status: str
    rows_loaded: int = 0
    error: str | None = None


def iter_year_months(start_year: int, start_month: int, end_year: int, end_month: int):
    year, month = start_year, start_month
    while (year, month) <= (end_year, end_month):
        yield year, month
        month += 1
        if month > 12:
            month = 1
            year += 1


def append_issue(message: str) -> None:
    INGEST_ISSUES_PATH.parent.mkdir(parents=True, exist_ok=True)
    if not INGEST_ISSUES_PATH.exists():
        INGEST_ISSUES_PATH.write_text("# BTS / Weather ingest issues log\n\n")
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    with INGEST_ISSUES_PATH.open("a", encoding="utf-8") as handle:
        handle.write(f"- **{timestamp}** — {message}\n")


def backfill_range(
    start_year: int,
    start_month: int,
    end_year: int,
    end_month: int,
    *,
    download: bool = True,
    stop_on_error: bool = False,
) -> list[BackfillResult]:
    results: list[BackfillResult] = []
    for year, month in iter_year_months(start_year, start_month, end_year, end_month):
        label = f"{year}-{month:02d}"
        print(f"\n=== BTS backfill {label} ===")
        try:
            outcome = load_month(year, month, download=download)
            result = BackfillResult(
                year=year,
                month=month,
                status="success",
                rows_loaded=outcome["rows_loaded"],
            )
            print(f"OK {label}: {result.rows_loaded:,} rows")
        except Exception as exc:  # noqa: BLE001 - collect per-month failures
            result = BackfillResult(
                year=year,
                month=month,
                status="failed",
                error=str(exc),
            )
            msg = f"BTS `{label}` failed: {exc}"
            print(f"FAIL {label}: {exc}", file=sys.stderr)
            append_issue(msg)
            if stop_on_error:
                results.append(result)
                break
        results.append(result)
    return results


def print_summary(results: list[BackfillResult]) -> None:
    success = [r for r in results if r.status == "success"]
    failed = [r for r in results if r.status == "failed"]
    total_rows = sum(r.rows_loaded for r in success)
    print("\n=== Backfill summary ===")
    print(f"Months attempted: {len(results)}")
    print(f"Success: {len(success)}")
    print(f"Failed:  {len(failed)}")
    print(f"Total rows loaded: {total_rows:,}")
    if failed:
        print("Failed months:")
        for r in failed:
            print(f"  - {r.year}-{r.month:02d}: {r.error}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Backfill BTS OTP data for a month range")
    parser.add_argument("--start-year", type=int, default=2023)
    parser.add_argument("--start-month", type=int, default=1)
    parser.add_argument("--end-year", type=int, default=2025)
    parser.add_argument("--end-month", type=int, default=12)
    parser.add_argument(
        "--no-download",
        action="store_true",
        help="Load existing ZIPs only (skip TranStats download)",
    )
    parser.add_argument(
        "--stop-on-error",
        action="store_true",
        help="Stop backfill after first failed month",
    )
    args = parser.parse_args()

    results = backfill_range(
        args.start_year,
        args.start_month,
        args.end_year,
        args.end_month,
        download=not args.no_download,
        stop_on_error=args.stop_on_error,
    )
    print_summary(results)
    if any(r.status == "failed" for r in results):
        sys.exit(1)


if __name__ == "__main__":
    main()
