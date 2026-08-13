#!/usr/bin/env python3
"""Require the public guide to contain exactly the rebuilt figure PNGs."""
from pathlib import Path
import hashlib
import sys

ROOT = Path(__file__).resolve().parent.parent
LOCATIONS = {
    "outputs": ROOT / "outputs" / "figures",
    "source guide": ROOT / "docs" / "assets",
    "rendered guide": ROOT / "docs" / "_book" / "assets",
}

def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()

expected = {p.name for p in LOCATIONS["outputs"].glob("*.png")}
problems = []
for label, directory in LOCATIONS.items():
    found = {p.name for p in directory.glob("*.png")} if directory.is_dir() else set()
    if found != expected:
        problems.append(f"{label}: PNG set differs (missing={sorted(expected-found)}, extra={sorted(found-expected)})")

for name in sorted(expected):
    values = {label: digest(directory / name) for label, directory in LOCATIONS.items()
              if (directory / name).is_file()}
    if len(values) != 3 or len(set(values.values())) != 1:
        problems.append(f"{name}: digest mismatch {values}")

print("\nguide asset integrity")
print("-" * 72)
print(f"canonical output PNGs: {len(expected)}")
if problems:
    for problem in problems:
        print("FAIL ", problem)
    sys.exit(1)
print("PASS  outputs, source assets, and rendered assets are byte-identical")
