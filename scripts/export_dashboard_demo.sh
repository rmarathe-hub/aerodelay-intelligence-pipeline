#!/usr/bin/env bash
# Export agg marts to dashboard/demo_data/*.parquet for Streamlit Cloud deploy.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

VENV_DIR="${ROOT_DIR}/.venv-dashboard"
if [[ ! -x "${VENV_DIR}/bin/python" ]]; then
  python3 -m venv "${VENV_DIR}"
  "${VENV_DIR}/bin/pip" install -q --upgrade pip
  "${VENV_DIR}/bin/pip" install -q -r dashboard/requirements.txt
fi

export PYTHONPATH="${ROOT_DIR}${PYTHONPATH:+:${PYTHONPATH}}"
"${VENV_DIR}/bin/python" <<'PY'
from pathlib import Path

import pandas as pd
import psycopg2

from dashboard.config import DEMO_DATA_DIR, get_settings
from dashboard.data import AGG_TABLES, PARQUET_FILES

DEMO_DATA_DIR.mkdir(parents=True, exist_ok=True)
settings = get_settings()

with psycopg2.connect(settings.dsn()) as conn:
    for key, relation in AGG_TABLES.items():
        df = pd.read_sql_query(f"SELECT * FROM {relation}", conn)
        out = PARQUET_FILES[key]
        df.to_parquet(out, index=False)
        size_kb = out.stat().st_size / 1024
        print(f"{key:14} {len(df):>6,} rows -> {out.relative_to(Path.cwd())} ({size_kb:.1f} KB)")
PY

echo "Demo parquet export complete."
