#!/usr/bin/env bash
# =============================================================================
# verification/negative_controls.sh -- do the gates fail when they should?
#
#     bash verification/negative_controls.sh
#
# A gate that cannot fail is not a gate. Two sibling projects shipped checks
# that reported success without ever running: one grepped a Latin-1 TeX log,
# which grep silently skips as binary; the other compared a chart's numbers and
# its picture but never the two to each other. Both were green for months.
#
# So each control here plants ONE defect in a scratch copy of the package and
# asserts that exactly the gate which owns it turns red. A control that does not
# produce a failure is itself a failure: it means the gate is inert.
#
# Nothing is written to the real package. Everything happens under a temporary
# copy that is removed on exit.
# =============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

pass=0; fail=0
note() {
  printf '%-6s %s\n' "$1" "$2"
  if [ "$1" = "ok" ]; then pass=$((pass+1)); else fail=$((fail+1)); fi
}

fresh_copy() {
  local dst="$SCRATCH/$1"
  rm -rf "$dst"
  cp -a "$ROOT" "$dst"     # -a preserves the gzip containers byte-for-byte
  echo "$dst"
}

run_gate() {
  local dir="$1" gate="$2"
  case "$gate" in
    *.py) ( cd /tmp && python3 "$dir/verification/$gate" >/dev/null 2>&1 ) ;;
    *)    ( cd /tmp && Rscript  "$dir/verification/$gate" >/dev/null 2>&1 ) ;;
  esac
  echo $?
}

echo
echo "negative controls"
printf -- '----------------------------------------------------------------------\n'

# ---- control 1: a corrupted float must fail reproduction --------------------
d=$(fresh_copy c1)
printf '\n%%%% planted defect\n' >> "$d/outputs/floats/tab3_swmdk.tex"
s=$(run_gate "$d" verify_reproduction.R)
if [ "$s" -ne 0 ]; then note ok "corrupted float -> verify_reproduction FAILS"
else note FAIL "corrupted float did NOT fail verify_reproduction"; fi

# ---- control 2: a perturbed ledger must fail the number gate ----------------
d=$(fresh_copy c2)
python3 - "$d" <<'PY'
import csv, sys, pathlib
p = pathlib.Path(sys.argv[1]) / "outputs/key_numbers.csv"
rows = list(csv.DictReader(p.open()))
for r in rows:
    if r["key"] == "p16_reps_per_target":
        r["value"] = "6399"       # the paper says 6,400 per target
        break
with p.open("w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=rows[0].keys(), quoting=csv.QUOTE_ALL)
    w.writeheader(); w.writerows(rows)
PY
s=$(run_gate "$d" verify_manuscript_numbers.R)
if [ "$s" -ne 0 ]; then note ok "perturbed ledger -> verify_manuscript_numbers FAILS"
else note FAIL "perturbed ledger did NOT fail the number gate"; fi

# ---- control 3: a reversed chart-direction claim must fail semantics --------
# The control for the failure mode that slipped past every automated check
# twice: picture fine, numbers fine, caption pointing the other way.
d=$(fresh_copy c3)
python3 - "$d" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]) / "provenance/chart-specs.csv"
t = p.read_text().replace(",tightens,B_INTERVAL_TIGHTENS,",
                          ",widens,B_INTERVAL_TIGHTENS,")
p.write_text(t)
PY
s=$(run_gate "$d" verify_semantics.R)
if [ "$s" -ne 0 ]; then note ok "reversed chart-direction claim -> verify_semantics FAILS"
else note FAIL "reversed chart claim did NOT fail verify_semantics"; fi

# ---- control 4: an absolute path must fail the disclosure scan --------------
d=$(fresh_copy c4)
# Assembled at runtime rather than written literally: a control script that
# contains the string it plants would trip its own scan (control 7 caught
# exactly that), and suppressing it with an allowlist entry would be worse.
leak="/$(printf 'Users')/someone/secret/path"
echo "# ${leak}" >> "$d/exhibits/00_common.R"
s=$(run_gate "$d" disclosure_scan.py)
if [ "$s" -ne 0 ]; then note ok "planted absolute path -> disclosure_scan FAILS"
else note FAIL "planted absolute path did NOT fail the scan"; fi

# ---- control 5: an unledgered file must fail the disclosure scan ------------
d=$(fresh_copy c5)
echo "surprise" > "$d/data-frozen/design/undeclared-file.csv"
s=$(run_gate "$d" disclosure_scan.py)
if [ "$s" -ne 0 ]; then note ok "file with no ship-ledger verdict -> disclosure_scan FAILS"
else note FAIL "unledgered file did NOT fail the scan"; fi

# ---- control 6: a broken receipt reference must fail governance -------------
d=$(fresh_copy c6)
python3 - "$d" <<'PY'
import pathlib, sys, csv
# Remove one documented exclusion so a receipt reference resolves to nothing.
p = pathlib.Path(sys.argv[1]) / "provenance/excluded-digests.csv"
rows = list(csv.DictReader(p.open()))
rows = [r for r in rows if "SWMDK" not in r["name"]]
with p.open("w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=rows[0].keys()); w.writeheader(); w.writerows(rows)
PY
s=$(run_gate "$d" verify_governance.R)
if [ "$s" -ne 0 ]; then note ok "dropped SWMDK object-digest record -> verify_governance FAILS"
else note FAIL "dropped SWMDK digest did NOT fail the chain check"; fi

# ---- control 7: removing the defect banner must fail semantics --------------
# Paper B ships one file with a known archival defect. If its "do not port"
# banner can be deleted without a gate noticing, the warning is decorative.
d=$(fresh_copy c7b)
python3 - "$d" <<'PYX'
import pathlib, sys
p = pathlib.Path(sys.argv[1]) / "reference-code/R/core/ordinal-h.R"
t = p.read_text()
i = t.index("# +---")          # keep the generic banner, drop the defect notice
p.write_text(t[i:])
PYX
s=$(run_gate "$d" verify_semantics.R)
if [ "$s" -ne 0 ]; then note ok "removed archival-defect banner -> verify_semantics FAILS"
else note FAIL "removing the defect banner did NOT fail verify_semantics"; fi

# ---- control 8: a wrong declared ledger size must fail the number gate ------
d=$(fresh_copy c8)
python3 - "$d" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]) / "config.yml"
p.write_text(p.read_text().replace("key_numbers_rows: 144", "key_numbers_rows: 145"))
PY
s=$(run_gate "$d" verify_manuscript_numbers.R)
if [ "$s" -ne 0 ]; then note ok "wrong ledger-row contract -> verify_manuscript_numbers FAILS"
else note FAIL "wrong ledger-row contract did NOT fail the number gate"; fi

# ---- control 9: package outputs can never self-bless the parity target ------
d=$(fresh_copy c9)
printf '\n%%%% planted visible change\n' >> "$d/outputs/floats/tab3_swmdk.tex"
( cd /tmp && Rscript "$d/verification/build_expected.R" --i-mean-it >/dev/null 2>&1 )
s=$?
if [ "$s" -ne 0 ]; then note ok "self-bless attempt -> build_expected REFUSES"
else note FAIL "package outputs were allowed to replace the parity target"; fi

# ---- control 10: a substituted public guide image must fail ----------------
d=$(fresh_copy c10)
cp "$d/docs/assets/fig2_design.png" "$d/docs/assets/fig1_concept.png"
cp "$d/docs/assets/fig2_design.png" "$d/docs/_book/assets/fig1_concept.png"
s=$(run_gate "$d" verify_guide_assets.py)
if [ "$s" -ne 0 ]; then note ok "substituted guide image -> verify_guide_assets FAILS"
else note FAIL "wrong public guide image did NOT fail integrity"; fi

# ---- control 11: a changed non-Figure-1 draw must fail numeric reconciliation
d=$(fresh_copy c11)
python3 - "$d" <<'PY'
import csv, gzip, pathlib, sys
p = pathlib.Path(sys.argv[1]) / "data-frozen/empirical/aws-raw/P17-T02-draws-v1.csv.gz"
with gzip.open(p, "rt", newline="") as fh:
    rows = list(csv.reader(fh))
j = rows[0].index("H")
rows[1][j] = str(float(rows[1][j]) + 0.5)
with gzip.open(p, "wt", newline="") as fh:
    csv.writer(fh).writerows(rows)
PY
s=$(run_gate "$d" verify_numeric_basis.R)
if [ "$s" -ne 0 ]; then note ok "changed T02 draw -> verify_numeric_basis FAILS"
else note FAIL "changed non-T01 draw did NOT fail numeric reconciliation"; fi

# ---- control 12: generators must route SWMDK through the digest lock --------
d=$(fresh_copy c12)
python3 - "$d" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]) / "config.yml"
t = p.read_text()
t = t.replace("object_digest_sha256: e1257f", "object_digest_sha256: 01257f")
p.write_text(t)
PY
( cd /tmp && Rscript "$d/exhibits/01_fig1_concept.R" >/dev/null 2>&1 )
s=$?
if [ "$s" -ne 0 ]; then note ok "wrong SWMDK digest -> exhibit generator FAILS"
else note FAIL "Figure 1 bypassed the SWMDK digest lock"; fi

# ---- control 13: a changed safety certificate must fail direct reconstruction
d=$(fresh_copy c13)
python3 - "$d" <<'PY'
import csv, pathlib, sys
p = pathlib.Path(sys.argv[1]) / "verification/archival/results/archival-safety-certificate.csv"
rows = list(csv.DictReader(p.open()))
rows[0]["corrected_H"] = str(float(rows[0]["corrected_H"]) + 0.01)
with p.open("w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=rows[0].keys()); w.writeheader(); w.writerows(rows)
PY
s=$(run_gate "$d" archival/verify_archival_safety.R)
if [ "$s" -ne 0 ]; then note ok "changed archival certificate -> direct verifier FAILS"
else note FAIL "changed archival certificate was accepted"; fi

# ---- control 14: a nonzero oracle failure count must fail the wrapper -------
d=$(fresh_copy c14)
python3 - "$d" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]) / "verification/oracles/transport-lp/run-exhaustive-grid.R"
t = p.read_text()
needle = "failures <- detail[!detail$pass, ]"
t = t.replace(needle, "summary$failed[1] <- 1L\nsummary$passed[1] <- summary$passed[1] - 1L\n" + needle)
p.write_text(t)
PY
s=$(run_gate "$d" oracles/run_oracles.R)
if [ "$s" -ne 0 ]; then note ok "oracle failed=1 -> run_oracles FAILS"
else note FAIL "oracle wrapper ignored a nonzero failure count"; fi

# ---- control 15: a hidden unregistered file must fail the exact release set -
d=$(fresh_copy c15)
echo "benign but undeclared" > "$d/.hidden-release-file"
s=$(run_gate "$d" disclosure_scan.py)
if [ "$s" -ne 0 ]; then note ok "hidden unregistered file -> disclosure_scan FAILS"
else note FAIL "hidden unregistered file escaped the release boundary"; fi

# ---- control 16: a leak inside a declared archive member must be scanned ----
d=$(fresh_copy c16)
python3 - "$d" <<'PY'
import csv, io, pathlib, sys, tarfile
root = pathlib.Path(sys.argv[1])
p = root / "fixture.tar"
payload = ("/" + "Users" + "/someone/private/archive-member").encode()
with tarfile.open(p, "w") as tf:
    info = tarfile.TarInfo("nested/note.txt"); info.size = len(payload)
    tf.addfile(info, io.BytesIO(payload))
with (root / "provenance/release-files.csv").open("a", newline="") as fh:
    csv.writer(fh).writerow(["fixture.tar", "negative-control", "CC-BY-4.0"])
PY
s=$(run_gate "$d" disclosure_scan.py)
if [ "$s" -ne 0 ]; then note ok "archive-member leak -> disclosure_scan FAILS"
else note FAIL "archive-member leak escaped the scan"; fi

# ---- control 17: runnable code may not source archival code -----------------
d=$(fresh_copy c17)
printf '\nsource(file.path(PATHS$root, "reference-code", "R", "core", "ordinal-h.R"))\n' >> "$d/exhibits/00_common.R"
s=$(run_gate "$d" verify_quarantine.py)
if [ "$s" -ne 0 ]; then note ok "archival source call -> verify_quarantine FAILS"
else note FAIL "archival source call escaped quarantine"; fi

# ---- control 18: a reproduction-map source mutation must fail semantics -----
d=$(fresh_copy c18)
python3 - "$d" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]) / "provenance/reproduction-map.csv"
p.write_text(p.read_text().replace(
    "fig3_coverage,exhibits/03_fig3_coverage.R,confirmatory/v4-phase16-confirmation-lane-summary-v1.csv;",
    "fig3_coverage,exhibits/03_fig3_coverage.R,confirmatory/v4-phase16-confirmation-cell-summary-v1.csv;"))
PY
s=$(run_gate "$d" verify_semantics.R)
if [ "$s" -ne 0 ]; then note ok "mutated source declaration -> verify_semantics FAILS"
else note FAIL "mutated source declaration was accepted"; fi

# ---- control 19: the gates must PASS on an untouched copy -------------------
# Without this, every control above could be passing for the wrong reason.
d=$(fresh_copy c19)
allok=0
for g in verify_numeric_basis.R archival/verify_archival_safety.R oracles/run_oracles.R verify_reproduction.R verify_manuscript_numbers.R verify_semantics.R verify_governance.R; do
  if [ "$(run_gate "$d" "$g")" -ne 0 ]; then allok=1; echo "      (untouched copy failed $g)"; fi
done
if [ "$(run_gate "$d" disclosure_scan.py)" -ne 0 ]; then allok=1; echo "      (untouched copy failed disclosure_scan.py)"; fi
if [ "$(run_gate "$d" verify_quarantine.py)" -ne 0 ]; then allok=1; echo "      (untouched copy failed verify_quarantine.py)"; fi
if [ "$(run_gate "$d" verify_guide_assets.py)" -ne 0 ]; then allok=1; echo "      (untouched copy failed verify_guide_assets.py)"; fi
if [ "$allok" -eq 0 ]; then note ok "untouched copy -> all integrity gates PASS"
else note FAIL "untouched copy did not pass every gate"; fi

printf -- '----------------------------------------------------------------------\n'
printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
