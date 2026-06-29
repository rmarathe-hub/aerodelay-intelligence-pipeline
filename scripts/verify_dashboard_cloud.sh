#!/usr/bin/env bash
# Smoke-test dashboard imports the way Streamlit Cloud runs (no PYTHONPATH).
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

VENV_DIR="${ROOT_DIR}/.venv-dashboard"
if [[ ! -x "${VENV_DIR}/bin/python" ]]; then
  echo "Run: make dashboard-deps"
  exit 1
fi

export PYTHONPATH=""
"${VENV_DIR}/bin/python" <<'PY'
import sys
from pathlib import Path

# Streamlit adds the script directory to sys.path when running dashboard/app.py
sys.path.insert(0, str(Path("dashboard").resolve()))
import bootstrap  # noqa: F401

from dashboard.config import DEMO_DATA_DIR, get_settings
from dashboard.data import load_all_aggs, using_demo_parquet

assert using_demo_parquet(), f"Missing parquet under {DEMO_DATA_DIR}"
aggs = load_all_aggs(get_settings())
print(
    "cloud smoke OK:",
    len(aggs["airport_hour"]),
    len(aggs["weather_bucket"]),
    len(aggs["carrier_route"]),
)
PY

echo "Dashboard cloud smoke test passed."
