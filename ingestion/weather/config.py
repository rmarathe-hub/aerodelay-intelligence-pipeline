from __future__ import annotations

import calendar
import csv
from dataclasses import dataclass

from ingestion.common.paths import STATION_MAP_CSV, WEATHER_RAW_DIR

IEM_ASOS_URL = "https://mesonet.agron.iastate.edu/cgi-bin/request/asos.py"

WEATHER_COLUMNS = (
    "tmpf",
    "dwpf",
    "relh",
    "drct",
    "sknt",
    "p01i",
    "alti",
    "mslp",
    "vsby",
    "gust",
    "skyc1",
    "skyc2",
    "skyc3",
    "skyc4",
    "skyl1",
    "skyl2",
    "skyl3",
    "skyl4",
    "wxcodes",
    "feel",
    "metar",
    "snowdepth",
)


@dataclass(frozen=True)
class WeatherMonth:
    year: int
    month: int

    @property
    def year_month(self) -> str:
        return f"{self.year:04d}-{self.month:02d}"

    @property
    def last_day(self) -> int:
        return calendar.monthrange(self.year, self.month)[1]


@dataclass(frozen=True)
class WeatherStationMonth:
    station: str
    year: int
    month: int

    @property
    def year_month(self) -> str:
        return f"{self.year:04d}-{self.month:02d}"

    @property
    def csv_filename(self) -> str:
        return f"weather_{self.station}_{self.year}_{self.month:02d}.csv"

    @property
    def csv_path(self):
        return WEATHER_RAW_DIR / self.csv_filename

    @property
    def iem_params(self) -> dict[str, str]:
        month = WeatherMonth(year=self.year, month=self.month)
        return {
            "station": self.station,
            "data": "all",
            "tz": "Etc/UTC",
            "format": "comma",
            "year1": str(self.year),
            "month1": str(self.month),
            "day1": "1",
            "year2": str(self.year),
            "month2": str(self.month),
            "day2": str(month.last_day),
        }


def load_weather_stations() -> list[str]:
    with STATION_MAP_CSV.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        stations = {
            row["weather_station_id"].strip().upper()
            for row in reader
            if row.get("weather_station_id")
        }
    return sorted(stations)
