#!/usr/bin/env bash
# Run Streamlit dashboard with project .env loaded
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

VENV_DIR="${ROOT_DIR}/.venv-dashboard"
if [[ ! -x "${VENV_DIR}/bin/streamlit" ]]; then
  echo "Creating dashboard virtualenv at ${VENV_DIR}..."
  python3 -m venv "${VENV_DIR}"
  "${VENV_DIR}/bin/pip" install -q --upgrade pip
  "${VENV_DIR}/bin/pip" install -q -r "${ROOT_DIR}/dashboard/requirements.txt"
fi

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

export PYTHONPATH="${ROOT_DIR}${PYTHONPATH:+:${PYTHONPATH}}"
exec "${VENV_DIR}/bin/streamlit" run dashboard/app.py --server.headless true "$@"
