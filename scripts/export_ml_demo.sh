#!/usr/bin/env bash
# Copy small ML artifacts into dashboard/demo_data for Streamlit Cloud.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/ml/artifacts"
DST="$ROOT/dashboard/demo_data"
mkdir -p "$DST"

copy_if() {
  local src_name="$1"
  local dst_name="$2"
  if [[ -f "$SRC/$src_name" ]]; then
    cp "$SRC/$src_name" "$DST/$dst_name"
    echo "  $dst_name"
  fi
}

echo "Exporting ML demo bundle → dashboard/demo_data/"
copy_if metrics_2025_holdout.json ml_metrics_2025_holdout.json
copy_if cv_summary.json ml_cv_summary.json
copy_if best_params.json ml_best_params.json
copy_if permutation_importance.csv ml_permutation_importance.csv
copy_if segment_metrics.csv ml_segment_metrics.csv
copy_if pr_curve.png ml_pr_curve.png
copy_if calibration_curve.png ml_calibration_curve.png
copy_if shap_summary.png ml_shap_summary.png
echo "Done."
