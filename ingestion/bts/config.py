from __future__ import annotations

import csv
from dataclasses import dataclass

from ingestion.common.paths import AIRPORTS_CSV, BTS_RAW_DIR

BTS_URL_TEMPLATE = (
    "https://transtats.bts.gov/PREZIP/"
    "On_Time_Reporting_Carrier_On_Time_Performance_1987_present_{year}_{month}.zip"
)

BTS_ZIP_FILENAME_TEMPLATE = (
    "On_Time_Reporting_Carrier_On_Time_Performance_1987_present_{year}_{month}.zip"
)


@dataclass(frozen=True)
class BtsMonth:
    year: int
    month: int

    @property
    def year_month(self) -> str:
        return f"{self.year:04d}-{self.month:02d}"

    @property
    def url(self) -> str:
        return BTS_URL_TEMPLATE.format(year=self.year, month=self.month)

    @property
    def zip_filename(self) -> str:
        return BTS_ZIP_FILENAME_TEMPLATE.format(year=self.year, month=self.month)

    @property
    def zip_path(self):
        return BTS_RAW_DIR / self.zip_filename


def load_origin_airports() -> set[str]:
    with AIRPORTS_CSV.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        return {row["airport_code"].strip().upper() for row in reader if row.get("airport_code")}
