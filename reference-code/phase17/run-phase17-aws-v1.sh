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

phase17_root="codebase/research/v4/cluster-polytomous/empirical-swmdk/phase17"
design="${phase17_root}/protocol/v4-phase17-task-design-v1.csv"
runner="${phase17_root}/run-phase17-task-v1.R"
log_root="${phase17_root}/aws-logs"
mkdir -p "${log_root}"

run_task() {
  local task_id="$1"
  Rscript "${runner}" "${task_id}" \
    >"${log_root}/${task_id}.log" 2>&1
}
export -f run_task
export runner log_root
awk -F, 'NR > 1 {gsub(/\r/, "", $1); print $1}' "${design}" |
  xargs -I{} -P 12 bash -c 'run_task "$1"' _ {}

completed=$(find "${phase17_root}/aws-raw" -maxdepth 1 \
  -name "P17-T*-receipt-v1.json" | wc -l | tr -d ' ')
if [[ "${completed}" != "12" ]]; then
  echo "Expected 12 task receipts, found ${completed}." >&2
  exit 6
fi
echo "PASS: Phase 17 completed 12/12 tasks with 12 workers."
