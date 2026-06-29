#!/usr/bin/env bash
# Day 1 ML engineer track: extract → EDA → CV → Optuna → ablation
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -d .venv-ml ]]; then
  # shellcheck disable=SC1091
  source .venv-ml/bin/activate
else
  echo "Create venv first: python -m venv .venv-ml && source .venv-ml/bin/activate && pip install -r ml/requirements.txt"
  exit 1
fi

export PYTHONPATH="$ROOT${PYTHONPATH:+:$PYTHONPATH}"

echo "=== 1/5 Extract ==="
python ml/extract.py "$@"

echo "=== 2/5 EDA ==="
python ml/eda.py

echo "=== 3/5 CV (baseline + logistic + HGB defaults) ==="
python ml/cv.py

echo "=== 4/5 Optuna tuning ==="
python ml/tune.py

echo "=== 5/5 Ablation ==="
python ml/ablation.py

echo "Day 1 complete. Artifacts in ml/artifacts/"
