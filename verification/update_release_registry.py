#!/usr/bin/env python3
"""Regenerate exact release, runnable-code, size, origin, and licence registers."""
import csv, gzip, hashlib, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
WORKSPACE = ROOT.parent.parent
RELEASE = ROOT / "provenance/release-files.csv"
RUNNABLE = ROOT / "provenance/runnable-code.csv"
IGNORED_DIRS = {".git", ".quarto", "__pycache__"}
IGNORED_FILES = {".DS_Store"}

def files_on_disk():
    out = []
    for p in ROOT.rglob("*"):
        if not p.is_file() or p.name in IGNORED_FILES:
            continue
        rel = p.relative_to(ROOT)
        if any(part in IGNORED_DIRS for part in rel.parts):
            continue
        out.append(rel.as_posix())
    return sorted(out)

def licence(rel):
    p = pathlib.PurePosixPath(rel)
    ext = p.suffix.lower()
    if ext in {".r", ".py", ".sh"} or rel == "00_setup.R":
        return "code", "MIT"
    if rel.startswith(("common/", "exhibits/", "verification/", "reference-code/")):
        return "code-or-code-documentation", "MIT"
    if rel.startswith("data-frozen/"):
        return "frozen-evidence", "CC-BY-4.0"
    if rel.startswith("outputs/"):
        return "generated-exhibit", "CC-BY-4.0"
    if rel.startswith("docs/"):
        return "replication-guide", "CC-BY-4.0"
    if rel.startswith("provenance/"):
        return "provenance", "CC-BY-4.0"
    if rel in {"LICENSE", "DESCRIPTION", "config.yml", ".replication-root",
               ".gitignore", ".gitattributes"} or rel.endswith(".Rproj"):
        return "package-infrastructure", "MIT"
    return "documentation-or-metadata", "CC-BY-4.0"

def write_csv(path, fields, rows):
    with path.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=fields)
        w.writeheader(); w.writerows(rows)

def update_sizes_and_origins():
    ledger_path = ROOT / "provenance/ship-ledger.csv"
    with ledger_path.open(newline="", encoding="utf-8") as fh:
        ledger = list(csv.DictReader(fh)); fields = list(ledger[0])
    shipped = {}
    for row in ledger:
        if row["verdict"] != "exclude" and row["target_path"]:
            target = ROOT / row["target_path"]
            if not target.is_file():
                raise SystemExit(f"shipped target absent: {row['target_path']}")
            row["bytes_shipped"] = str(target.stat().st_size)
            shipped[row["target_path"]] = row
    write_csv(ledger_path, fields, ledger)

    origin_path = ROOT / "provenance/package-file-origins.csv"
    with origin_path.open(newline="", encoding="utf-8") as fh:
        origins = list(csv.DictReader(fh)); ofields = list(origins[0])
    origins = [r for r in origins if r["target_path"] in shipped]
    by_target = {r["target_path"]: r for r in origins}
    for target_rel, row in shipped.items():
        target = ROOT / target_rel
        if target_rel not in by_target:
            source = WORKSPACE / row["source_path"]
            source_for_digest = source if source.is_file() else target
            payload = source_for_digest.read_bytes()
            new = {
                "target_path": target_rel,
                "source_path": row["source_path"],
                "tier": row["tier"],
                "verdict": "gzip" if target_rel.endswith(".gz") else "ship",
                "bytes_uncompressed": str(len(payload)),
                "bytes_shipped": str(target.stat().st_size),
                "sha256_uncompressed": hashlib.sha256(payload).hexdigest(),
            }
            origins.append(new); by_target[target_rel] = new
        by_target[target_rel]["bytes_shipped"] = str(target.stat().st_size)
    origins.sort(key=lambda r: r["target_path"])
    write_csv(origin_path, ofields, origins)

def main():
    if sys.argv[1:] != ["--write"]:
        raise SystemExit("usage: update_release_registry.py --write")
    RELEASE.touch(exist_ok=True)
    RUNNABLE.touch(exist_ok=True)
    update_sizes_and_origins()
    paths = files_on_disk()
    release_rows = []
    for rel in paths:
        cls, lic = licence(rel)
        release_rows.append({"path": rel, "classification": cls,
                             "governing_license": lic})
    write_csv(RELEASE, ["path", "classification", "governing_license"], release_rows)
    runnable = []
    for rel in paths:
        p = pathlib.PurePosixPath(rel)
        if p.suffix.lower() not in {".r", ".py", ".sh"}:
            continue
        if rel == "00_setup.R" or rel.startswith(("common/", "exhibits/", "verification/")):
            runnable.append({"path": rel,
                             "role": "entrypoint" if rel == "00_setup.R" or
                             rel.startswith("verification/") else "build-support"})
    write_csv(RUNNABLE, ["path", "role"], runnable)
    print(f"release files: {len(release_rows)}; runnable code: {len(runnable)}")

if __name__ == "__main__":
    main()
