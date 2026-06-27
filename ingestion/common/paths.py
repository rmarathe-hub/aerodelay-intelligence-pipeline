from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
DOCS_DIR = PROJECT_ROOT / "docs"
DATA_DIR = PROJECT_ROOT / "data"
BTS_RAW_DIR = DATA_DIR / "raw" / "bts"
WEATHER_RAW_DIR = DATA_DIR / "raw" / "weather"
AIRPORTS_CSV = DOCS_DIR / "airports_45.csv"
STATION_MAP_CSV = DOCS_DIR / "airport_station_map.csv"
