#!/usr/bin/env bash
# Day 2 ML engineer track: final train → 2025 holdout → export demo bundle
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -d .venv-ml ]]; then
  # shellcheck disable=SC1091
  source .venv-ml/bin/activate
else
  echo "Run: make ml-deps"
  exit 1
fi

export PYTHONPATH="$ROOT${PYTHONPATH:+:$PYTHONPATH}"

echo "=== 1/3 Final train (2023-2024) ==="
python ml/train.py "$@"

echo "=== 2/3 Evaluate 2025 holdout (once) ==="
python ml/evaluate.py

echo "=== 3/3 Export Streamlit demo bundle ==="
bash scripts/export_ml_demo.sh

echo "Day 2 complete. Open dashboard → Delay Risk Model page."
