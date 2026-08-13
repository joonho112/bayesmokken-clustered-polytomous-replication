#!/usr/bin/env bash
# +---------------------------------------------------------------------------+
# | REFERENCE CODE -- ARCHIVAL. NOTHING IN THIS PACKAGE SOURCES THIS FILE.     |
# |                                                                           |
# | This is the pipeline that produced data-frozen/, preserved as it ran. It   |
# | is here to be READ, not executed: it expects the research tree, an AWS     |
# | fleet, and inputs this package does not ship. The exhibit layer rebuilds   |
# | every number from the frozen snapshot instead.                             |
# |                                                                           |
# | Only this banner was added. Every code line below is byte-identical to     |
# | the archival original; reference-code/README.md records the digests.       |
# +---------------------------------------------------------------------------+

set -euo pipefail

v4_root="codebase/research/v4/cluster-polytomous"
confirm_root="${v4_root}/confirmatory"
authority="${confirm_root}/v4-phase16-fresh-confirmation-authority-v1.json"
if [[ ! -f "${authority}" ]]; then
  echo "BLOCKED: Phase 16 fresh confirmation authority is absent." >&2
  exit 4
fi
if ! grep -q '"AUTHORIZED_PHASE16_FRESH_CONFIRMATION"' "${authority}"; then
  echo "BLOCKED: Phase 16 authority is not executable." >&2
  exit 5
fi

design="${confirm_root}/v4-phase16-confirmation-design-v1.csv"
runner="${confirm_root}/run-phase16-cell-v1.R"
log_root="${confirm_root}/aws-logs"
mkdir -p "${log_root}"
run_cell() {
  local cell_id="$1"
  Rscript "${runner}" "${cell_id}" \
    >"${log_root}/${cell_id}.log" 2>&1
}
export -f run_cell
export runner log_root
awk -F, 'NR > 1 {gsub(/\r/, "", $1); print $1}' "${design}" |
  xargs -I{} -P 12 bash -c 'run_cell "$1"' _ {}

completed=$(find "${confirm_root}/aws-raw" -maxdepth 1 \
  -name "P16-C*-receipt-v1.json" | wc -l | tr -d ' ')
if [[ "${completed}" != "24" ]]; then
  echo "Expected 24 receipts, found ${completed}." >&2
  exit 6
fi
echo "PASS: Phase 16 confirmation completed 24/24 cells."
