#!/usr/bin/env bash
# Generate a Fernet key for Airflow and write it to .env
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  cp "${ROOT_DIR}/.env.example" "${ENV_FILE}"
  echo "Created ${ENV_FILE} from .env.example"
fi

# pip/conda often install to `python` while `python3` is a different interpreter (common on macOS)
pick_python() {
  local candidate
  for candidate in "${PYTHON:-}" python python3; do
    [[ -z "${candidate}" ]] && continue
    if command -v "${candidate}" >/dev/null 2>&1 \
      && "${candidate}" -c "from cryptography.fernet import Fernet" 2>/dev/null; then
      echo "${candidate}"
      return 0
    fi
  done
  return 1
}

PYTHON_BIN="$(pick_python)" || {
  echo "No Python with 'cryptography' found."
  echo "Install into the Python this script will use, e.g.:"
  echo "  python -m pip install cryptography"
  echo "Or set PYTHON=/path/to/your/python and retry."
  exit 1
}

echo "Using ${PYTHON_BIN} ($(command -v "${PYTHON_BIN}"))"
KEY=$("${PYTHON_BIN}" -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")

if grep -q "^AIRFLOW__CORE__FERNET_KEY=$" "${ENV_FILE}" || grep -q "^AIRFLOW__CORE__FERNET_KEY=\s*$" "${ENV_FILE}"; then
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s|^AIRFLOW__CORE__FERNET_KEY=.*|AIRFLOW__CORE__FERNET_KEY=${KEY}|" "${ENV_FILE}"
  else
    sed -i "s|^AIRFLOW__CORE__FERNET_KEY=.*|AIRFLOW__CORE__FERNET_KEY=${KEY}|" "${ENV_FILE}"
  fi
  echo "Set AIRFLOW__CORE__FERNET_KEY in .env"
elif grep -q "^AIRFLOW__CORE__FERNET_KEY=" "${ENV_FILE}"; then
  echo "AIRFLOW__CORE__FERNET_KEY already set in .env — leaving unchanged"
else
  echo "AIRFLOW__CORE__FERNET_KEY=${KEY}" >> "${ENV_FILE}"
  echo "Appended AIRFLOW__CORE__FERNET_KEY to .env"
fi
