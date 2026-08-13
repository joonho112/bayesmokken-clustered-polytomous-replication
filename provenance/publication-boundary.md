# The publication boundary

What ships, what does not, and why. Per-file verdicts are in
[`ship-ledger.csv`](ship-ledger.csv).

## The shape of the decision

| | Raw | Shipped |
|---|---:|---:|
| Phase 16 confirmation raw (86,400 rows) | 36.7 MB | **5.0 MB** gzipped |
| Phase 17 application draws (12 × 99,999) | 18.5 MB | 18.5 MB |
| everything else | ~5 MB | ~5 MB |
| **total** | | **~29 MB** |

The article promises "the complete raw draw streams of the application". They
ship in full.

## What does not ship

**The application responses.** `SWMDK` is distributed inside the `mokken`
package and is not the authors' to redistribute. It loads under a locked digest
instead — see [`../DATA_ACCESS.md`](../DATA_ACCESS.md). This is the only tier
whose absence a reader must act on, and `00_setup.R` checks for `mokken` up
front because of it.

**AWS scheduling logs and execution bundles** — 37 files recording how the
compute was arranged rather than what was decided. This includes
`v4-phase16-aws-execution-bundle-v1.tar.gz` (SHA-256
`d4a252b5812f39e34345fdc8d6f252670da0cd444229a7662e06619695dd5614`),
whose meaningful members already ship individually with the reference-code
warning and correct licence. It is absent from the public package.

Nothing excluded is an input to a claim.

## The severance from the companion paper

Paper B's evidence originated inside the companion binary paper's research
tree, because that is how the research branch grew. The explicit **runnable
exhibit and verification layer** (`00_setup.R`, `common/`, `exhibits/`, and
the entry points listed in `runnable-code.csv`) does not reach into it.
`verify_quarantine.py` checks source/import/subprocess calls, and a clean-room
build runs with `reference-code/` unavailable.

Copied executable evidence and seventy-five locked receipts still *record* the project-relative paths their
files had when the run happened. Those are provenance, and rewriting them would
break their digests and defeat the point of shipping them. The severance rule
is therefore applied to the runnable layer, not to copied archival evidence.

## Where the receipt chain stops

`verify_governance.R` requires every reference made by a v4 receipt to resolve —
30 of 30 do. References reach three kinds of target: a shipped file, a
documented exclusion, or the recorded pre-banner digest of a reference-code
file.

One resolves to none of those in the ordinary sense: the **SWMDK object
digest**. It is the digest of an R object rather than a file, so it is
registered in `excluded-digests.csv` pointing at the live check in
`read_swmdk()`.

## Two documented departures from byte-identity

21 reference-code files carry a nine-line archival banner —
including `ordinal-h.R`, whose banner records a known defect. **No code line was
changed**, and `reference-code/ARCHIVAL-DIGESTS.csv` records both digests, so
`tail -n +11` recovers the original for every one of them except the redacted
file named below.

Ten files were redacted, in two fields of the authority records they carry. The
first named the command-line harness through which the author's instruction was
received. The second held that instruction verbatim, as a short colloquial
message; it is now an English authority token of the same form the companion
package uses.

Neither field carried evidence. What each authority licensed is in
`authorized_scope`, what it withheld is in `explicitly_not_authorized`, where it
had to stop is in `required_stop`, and when it was recorded and what it descends
from are in `recorded_at_utc` and `parent_governance.sha256` — all unchanged,
and all of it machine-readable, which the prose never was.

One of the ten is
`reference-code/phase16/authorize-phase16-fresh-confirmation-v1.R`, and one is
in the frozen data tier. [`redactions.csv`](redactions.csv) records the upstream
and shipped SHA-256 for all ten.

The rule is *record it*, not *avoid it*: a package that modifies what it ships
without saying so cannot be audited, and one that refuses to annotate archival
code ships a hazard without a warning label.
