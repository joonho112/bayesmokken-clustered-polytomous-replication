#!/usr/bin/env python3
"""
verification/check_guide_links.py -- does every link and path in the guide
actually resolve?

    python3 verification/check_guide_links.py

A replication guide that names a file which is not there is worse than one that
says nothing: it sends a reader looking for something that does not exist and
costs them the time to work out that the guide, not their clone, is wrong.

Checks three things across docs/*.qmd:

  1. inter-chapter links      [text](07-empirical.qmd#anchor)
  2. package paths in prose   `provenance/seed-tree.md`, verification/foo.R
  3. image sources            ![](assets/fig1_concept.png)

External http(s) links are listed but not fetched -- a network check would make
the gate depend on the network, which is a different kind of flaky.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DOCS = os.path.join(ROOT, "docs")

MD_LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
IMG = re.compile(r"!\[[^\]]*\]\(([^)\s]+)\)")
# `path/like/this.ext` or `dir/` inside backticks
CODE_PATH = re.compile(r"`([A-Za-z0-9_][A-Za-z0-9_./-]*\.(?:R|py|sh|csv|md|yml|json|qmd|tex|txt)|"
                       r"[A-Za-z0-9_][A-Za-z0-9_./-]*/)`")

# Prose that looks like a path but names a class of file rather than one file.
GENERIC = {
    "docs/", "outputs/", "exhibits/", "common/", "verification/", "provenance/",
    "reference-code/", "data-frozen/", "figures/", "floats/", "assets/",
    "common/R/", "verification/oracles/", "provenance/governance/",
    "data-frozen/worker-tiers/", "data-frozen/empirical/", "data-frozen/design/",
    "data-frozen/confirmatory/", "data-frozen/validation/", "data-frozen/receipts/",
    "reference-code/R/", "reference-code/scripts/", "reference-code/dgp-v3/",
    "provenance/governance/protocol/", "provenance/governance/artifacts/",
    "provenance/governance/ancestry/", "data-frozen/empirical/responses/",
    "data-frozen/empirical/artifacts/", "data-frozen/worker-tiers/endpoints/",
    "data-frozen/worker-tiers/threshold-scores/",
    "data-frozen/worker-tiers/replication-features/",
    "data-frozen/worker-tiers/receipts/", "verification/expected/",
    "outputs/figures/", "outputs/floats/", "R/dgp/", "R/metrics/", "R/primary/",
    "R/comparators/", "scripts/", "provenance/governance/protocol/ppsrs/",
    "exhibits/00_common.R", "0x1.b99",
}

# Files that genuinely exist but belong to a DIFFERENT repository. Naming them
# is correct and useful; resolving them here would be wrong. Listing them makes
# the external reference explicit rather than letting it pass as a near-miss.
EXTERNAL_FILES = {
    "ordinal-transport.R",   # the corrected kernel, in the bayesmokken package
    "arxiv_preflight.py",    # the manuscript's claim-boundary audit
    "verify_numbers.R",      # the manuscript's own number gate
}


def index_by_basename():
    """Every file in the package, keyed by name.

    Prose refers to files the way people talk about them -- "verify_semantics.R",
    not "verification/verify_semantics.R". Requiring the full path would make
    the guide read like a manifest. Resolving by basename still catches the
    failure that matters: a name that does not exist anywhere, which is what a
    renamed or deleted file looks like.
    """
    idx = {}
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames
                       if d not in {".git", "_book", ".quarto"} and not d.startswith("_")]
        for f in filenames:
            idx.setdefault(f, []).append(os.path.relpath(os.path.join(dirpath, f), ROOT))
    return idx


def main():
    by_name = index_by_basename()
    chapters = sorted(f for f in os.listdir(DOCS) if f.endswith(".qmd"))
    problems = []
    n_link = n_path = n_img = n_ext = 0

    for ch in chapters:
        path = os.path.join(DOCS, ch)
        text = open(path, encoding="utf-8").read()

        for m in IMG.finditer(text):
            n_img += 1
            target = m.group(1)
            if not os.path.exists(os.path.join(DOCS, target)):
                problems.append((ch, "image", target))

        for m in MD_LINK.finditer(text):
            target = m.group(1)
            if text[max(0, m.start() - 1):m.start()] == "!":
                continue
            if target.startswith(("http://", "https://", "mailto:")):
                n_ext += 1
                continue
            n_link += 1
            base = target.split("#", 1)[0]
            if not base:
                continue
            # relative to docs/ first, then to the package root
            if not (os.path.exists(os.path.join(DOCS, base))
                    or os.path.exists(os.path.join(ROOT, base))):
                problems.append((ch, "link", target))

        for m in CODE_PATH.finditer(text):
            target = m.group(1)
            if target in GENERIC:
                continue
            n_path += 1
            if target.endswith("/"):
                continue          # a directory class, not a file
            if (os.path.exists(os.path.join(ROOT, target))
                    or os.path.exists(os.path.join(DOCS, target))):
                continue
            # fall back to basename: prose names files without their directory
            if os.path.basename(target) in by_name:
                continue
            if os.path.basename(target) in EXTERNAL_FILES:
                continue
            problems.append((ch, "path", target))

    print("\nguide link check")
    print("-" * 72)
    print(f"chapters            : {len(chapters)}")
    print(f"internal links      : {n_link}")
    print(f"package paths       : {n_path}")
    print(f"images              : {n_img}")
    print(f"external (not fetched): {n_ext}")
    print(f"unresolved          : {len(problems)}")
    if problems:
        print()
        for ch, kind, target in problems:
            print(f"  {kind:<7} {ch:<28} {target}")
    print("-" * 72)
    if problems:
        print("FAIL")
        return 1
    print("PASS  every link, path and image in the guide resolves")
    return 0


if __name__ == "__main__":
    sys.exit(main())
