#!/usr/bin/env bash
# Build the public exhibits after making the archival pipeline unavailable.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
BASE="$(mktemp -d)"
COPY="$BASE/package"
trap 'rm -rf "$BASE"' EXIT
cp -a "$ROOT" "$COPY"
rm -rf "$COPY/reference-code" "$COPY/outputs/figures" "$COPY/outputs/floats" \
       "$COPY/outputs/key_numbers.csv"
( cd / && Rscript "$COPY/00_setup.R" >/dev/null && \
  Rscript "$COPY/exhibits/00_build_all.R" >/dev/null && \
  Rscript "$COPY/verification/verify_numeric_basis.R" >/dev/null && \
  Rscript "$COPY/verification/verify_reproduction.R" >/dev/null )
echo "PASS  build and numeric reproduction succeed without reference-code/"
