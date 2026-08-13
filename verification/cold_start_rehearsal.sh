#!/usr/bin/env bash
# =============================================================================
# verification/cold_start_rehearsal.sh -- does this work for someone who has
# only this package?
#
#     bash verification/cold_start_rehearsal.sh
#
# Copies the package to a bare temporary location and runs the whole workflow
# there, by ABSOLUTE PATH FROM OUTSIDE THE COPY. That last part is the point:
# it is how a reader will actually invoke things, and it is what catches path
# handling that only works when the working directory happens to be right.
#
# It also catches the space-in-path family of bugs. R's commandArgs() encodes
# spaces in --file= as `~+~`, so an absolute invocation from a directory whose
# name contains a space silently resolves to a path that does not exist. That
# is not hypothetical -- it broke 00_setup.R here and was found by this test.
#
# The temporary copy is removed on exit. Nothing touches the real package.
# =============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
NAME="$(basename "$ROOT")"

# Deliberately put the bare copy under a directory whose name contains a space.
BASE="$(mktemp -d)"
WORK="$BASE/cold start rehearsal"
mkdir -p "$WORK"
COPY="$WORK/$NAME"
trap 'rm -rf "$BASE"' EXIT

pass=0; fail=0
step() {
  local label="$1"; shift
  local t0 t1 status
  t0=$(date +%s)
  if ( cd / && "$@" >"$BASE/out.log" 2>&1 ); then status="ok"; else status="FAIL"; fi
  t1=$(date +%s)
  printf '%-6s %-42s %4ss\n' "$status" "$label" "$((t1-t0))"
  if [ "$status" = "ok" ]; then pass=$((pass+1)); else
    fail=$((fail+1)); sed 's/^/         /' "$BASE/out.log" | tail -12
  fi
}

echo
echo "cold-start rehearsal"
echo "bare copy: $COPY"
printf -- '----------------------------------------------------------------------\n'

# Copy the package as a reader would receive it: without build outputs, so the
# rehearsal genuinely rebuilds rather than checking what is already there.
cp -a "$ROOT" "$COPY"
rm -rf "$COPY/outputs/figures" "$COPY/outputs/floats" "$COPY/outputs/key_numbers.csv"
rm -rf "$COPY/.git" "$COPY/docs/_book" "$COPY/docs/.quarto"

step "00_setup.R"                    Rscript "$COPY/00_setup.R"
step "exhibits/00_build_all.R"       Rscript "$COPY/exhibits/00_build_all.R"
step "verify_numeric_basis.R"        Rscript "$COPY/verification/verify_numeric_basis.R"
step "verify_archival_safety.R"      Rscript "$COPY/verification/archival/verify_archival_safety.R"
step "verify_reproduction.R"         Rscript "$COPY/verification/verify_reproduction.R"
step "verify_manuscript_numbers.R"   Rscript "$COPY/verification/verify_manuscript_numbers.R"
step "verify_semantics.R"            Rscript "$COPY/verification/verify_semantics.R"
step "verify_governance.R"           Rscript "$COPY/verification/verify_governance.R"
step "verify_quarantine.py"          python3 "$COPY/verification/verify_quarantine.py"
step "without reference-code"        bash "$COPY/verification/rehearse_without_reference_code.sh"
step "oracles/run_oracles.R"         Rscript "$COPY/verification/oracles/run_oracles.R"
step "quarto render docs"            quarto render "$COPY/docs"
step "verify_guide_assets.py"        python3 "$COPY/verification/verify_guide_assets.py"

if [ -f "$COPY/verification/check_guide_links.py" ]; then
  step "check_guide_links.py"        python3 "$COPY/verification/check_guide_links.py"
fi
step "disclosure_scan.py"            python3 "$COPY/verification/disclosure_scan.py"

printf -- '----------------------------------------------------------------------\n'
SIZE=$(du -sk "$COPY" | cut -f1)
printf 'bare copy size: %s MB\n' "$((SIZE/1024))"
printf '%d passed, %d failed\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  echo
  echo "PASS  the package works from a bare copy, invoked by absolute path"
  echo "      from outside it, under a directory whose name contains a space."
  exit 0
fi
exit 1
