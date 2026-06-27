#!/usr/bin/env bash
# Run dbt with project .env loaded (Postgres credentials)
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

VENV_DIR="${ROOT_DIR}/.venv-dbt"
if [[ ! -x "${VENV_DIR}/bin/dbt" ]]; then
  echo "Creating dbt virtualenv at ${VENV_DIR}..."
  python3 -m venv "${VENV_DIR}"
  "${VENV_DIR}/bin/pip" install -q --upgrade pip
  "${VENV_DIR}/bin/pip" install -q -r "${ROOT_DIR}/dbt/requirements.txt"
fi

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

export DBT_PROFILES_DIR="${ROOT_DIR}/dbt"
cd "${ROOT_DIR}/dbt"
exec "${VENV_DIR}/bin/dbt" "$@"
