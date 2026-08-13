#!/usr/bin/env python3
"""Prove that the registered runnable layer cannot execute archival code."""
import csv
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
RUN_ROOTS = ("common/", "exhibits/", "verification/")
EXTENSIONS = {".r", ".py", ".sh"}
SELF_TESTS = {"verification/verify_quarantine.py", "verification/negative_controls.sh"}
EXEC = re.compile(r"(?:\bsource\s*\(|\bsys\.source\s*\(|\bsystem2?\s*\(|"
                  r"\bsubprocess\.|\bos\.system\s*\(|\bRscript\b|\bpython[23]?\b|"
                  r"\bbash\b|\bsh\b)", re.I)
ASSIGN = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_.]*)\s*(?:<-|=)")
ARCHIVE_REF = re.compile(r"(?:reference-code/|[\"']reference-code[\"'])", re.I)

def runnable_on_disk():
    out = set()
    for p in ROOT.rglob("*"):
        if not p.is_file() or p.suffix.lower() not in EXTENSIONS:
            continue
        rel = p.relative_to(ROOT).as_posix()
        if "__pycache__" in p.parts or "/.quarto/" in f"/{rel}/":
            continue
        if rel == "00_setup.R" or rel.startswith(RUN_ROOTS):
            out.add(rel)
    return out

def code_lines(path):
    for number, raw in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        yield number, raw

def main():
    findings = []
    with (ROOT / "provenance/runnable-code.csv").open(newline="", encoding="utf-8") as fh:
        registered = [r["path"] for r in csv.DictReader(fh)]
    actual = runnable_on_disk()
    for rel in sorted(actual ^ set(registered)):
        findings.append((rel, 0, "runnable-manifest-mismatch"))
    for rel in sorted(actual - SELF_TESTS):
        tainted = set()
        for number, line in code_lines(ROOT / rel):
            lower = line.lower()
            if ARCHIVE_REF.search(line):
                match = ASSIGN.match(line)
                if match:
                    tainted.add(match.group(1))
                if EXEC.search(line):
                    findings.append((rel, number, "direct archival execution"))
            if EXEC.search(line) and any(re.search(rf"\b{re.escape(name)}\b", line)
                                         for name in tainted):
                findings.append((rel, number, "tainted archival path executed"))
    print("\narchival-code quarantine")
    print("-" * 72)
    print(f"registered runnable files : {len(registered)}")
    print(f"findings                  : {len(findings)}")
    for rel, line, why in findings:
        print(f"  {rel}:{line}: {why}")
    print("-" * 72)
    if findings:
        print("FAIL")
        return 1
    print("PASS  runnable manifest is complete and archival code is never executed")
    return 0

if __name__ == "__main__":
    sys.exit(main())
