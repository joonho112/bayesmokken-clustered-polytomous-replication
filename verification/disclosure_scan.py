#!/usr/bin/env python3
"""Audit the exact public release set, including hidden and archived payloads."""
import csv
import gzip
import pathlib
import re
import sys
import tarfile
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
AUTHOR_EMAIL = "jlee296@ua.edu"
IGNORED_DIRS = {".git", ".quarto", "__pycache__"}
IGNORED_FILES = {".DS_Store"}
PATTERNS = [
    ("absolute-home-path", re.compile(rb"/Users/[A-Za-z0-9._-]+/")),
    ("absolute-home-path", re.compile(rb"/home/(?!ubuntu\b)[A-Za-z0-9._-]+/")),
    ("project-dir-name", re.compile(rb"00_IRT Project")),
    ("email", re.compile(rb"[A-Za-z0-9._%+-]{1,64}@[A-Za-z0-9.-]{1,255}\.[A-Za-z]{2,24}")),
]
ANCHORS = (b"/Users/", b"/home/", b"00_IRT Project", b"@")
PATTERN_DEFINER = "verification/disclosure_scan.py"
PATH_RECORDS = {"provenance/redactions.csv"}
NODE_PATH_RECORDS = {"provenance/governance/artifacts/v3-aws-run-v1.log"}

def rows(path):
    with path.open(newline="", encoding="utf-8") as fh:
        return list(csv.DictReader(fh))

def release_files():
    out = set()
    for p in ROOT.rglob("*"):
        if not p.is_file() or p.name in IGNORED_FILES:
            continue
        rel = p.relative_to(ROOT)
        if any(part in IGNORED_DIRS for part in rel.parts):
            continue
        out.add(rel.as_posix())
    return out

def payloads(rel, path):
    raw = path.read_bytes()
    yield rel, raw
    try:
        if tarfile.is_tarfile(path):
            with tarfile.open(path, "r:*") as tf:
                for member in tf.getmembers():
                    yield f"{rel}!{member.name}", member.name.encode()
                    if member.isfile():
                        fh = tf.extractfile(member)
                        if fh is not None:
                            yield f"{rel}!{member.name}", fh.read()
            return
    except (OSError, tarfile.TarError):
        pass
    try:
        if zipfile.is_zipfile(path):
            with zipfile.ZipFile(path) as zf:
                for name in zf.namelist():
                    yield f"{rel}!{name}", name.encode()
                    if not name.endswith("/"):
                        yield f"{rel}!{name}", zf.read(name)
            return
    except (OSError, zipfile.BadZipFile):
        pass
    if path.suffix == ".gz":
        try:
            yield f"{rel}!gunzip", gzip.decompress(raw)
        except OSError:
            pass

def main():
    findings = []
    on_disk = release_files()
    manifest_rows = rows(ROOT / "provenance/release-files.csv")
    manifest_paths = [r["path"] for r in manifest_rows]
    if len(manifest_paths) != len(set(manifest_paths)):
        findings.append(("provenance/release-files.csv", "duplicate-path", ""))
    for rel in sorted(on_disk - set(manifest_paths)):
        findings.append((rel, "not-in-release-manifest", ""))
    for rel in sorted(set(manifest_paths) - on_disk):
        findings.append((rel, "manifest-file-missing", ""))

    ship = [r for r in rows(ROOT / "provenance/ship-ledger.csv")
            if r["verdict"] != "exclude" and r["target_path"]]
    ship_paths = [r["target_path"] for r in ship]
    origins = rows(ROOT / "provenance/package-file-origins.csv")
    origin_paths = [r["target_path"] for r in origins]
    if len(ship_paths) != len(set(ship_paths)):
        findings.append(("provenance/ship-ledger.csv", "duplicate-target", ""))
    if len(origin_paths) != len(set(origin_paths)):
        findings.append(("provenance/package-file-origins.csv", "duplicate-target", ""))
    for rel in sorted(set(ship_paths) ^ set(origin_paths)):
        findings.append((rel, "ship-origin-coverage-mismatch", ""))
    for row in ship:
        rel = row["target_path"]
        if rel not in on_disk:
            findings.append((rel, "shipped-target-missing", "")); continue
        if int(row["bytes_shipped"]) != (ROOT / rel).stat().st_size:
            findings.append((rel, "stale-ship-size", row["bytes_shipped"]))
    for row in origins:
        rel = row["target_path"]
        if rel in on_disk and int(row["bytes_shipped"]) != (ROOT / rel).stat().st_size:
            findings.append((rel, "stale-origin-size", row["bytes_shipped"]))

    for row in manifest_rows:
        rel = row["path"]
        if not row["classification"] or not row["governing_license"]:
            findings.append((rel, "missing-release-classification", ""))
        if pathlib.PurePosixPath(rel).suffix.lower() in {".r", ".py", ".sh"} \
                and row["governing_license"] != "MIT":
            findings.append((rel, "executable-not-MIT", row["governing_license"]))

    scanned = 0
    for rel in sorted(on_disk):
        path = ROOT / rel
        for logical, data in payloads(rel, path):
            scanned += 1
            if rel == PATTERN_DEFINER or not any(a in data for a in ANCHORS):
                continue
            for label, rx in PATTERNS:
                match = rx.search(data)
                if match is None:
                    continue
                hit = match.group().decode("utf-8", "replace")
                if label == "email" and hit == AUTHOR_EMAIL:
                    continue
                if label == "absolute-home-path" and rel in NODE_PATH_RECORDS \
                        and hit.startswith("/home/ubuntu/"):
                    continue
                if rel in PATH_RECORDS and label in {"absolute-home-path", "project-dir-name"}:
                    continue
                findings.append((logical, label, hit[:80]))

    print("\ndisclosure and release-boundary audit")
    print("-" * 72)
    print(f"release files      : {len(on_disk)}")
    print(f"logical payloads   : {scanned}")
    print(f"ledger targets     : {len(ship_paths)}")
    print(f"origin rows        : {len(origin_paths)}")
    print(f"findings           : {len(findings)}")
    for rel, label, hit in findings[:80]:
        print(f"  {label:<30} {rel}")
        if hit:
            print(f"  {'':<30} {hit}")
    print("-" * 72)
    if findings:
        print("FAIL")
        return 1
    print("PASS  exact release set and every logical payload are public-safe")
    return 0

if __name__ == "__main__":
    sys.exit(main())
