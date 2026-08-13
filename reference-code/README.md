# Reference code — archival, never sourced

The pipeline that produced `data-frozen/`, preserved as it ran.
**Nothing in this package sources it.**

Run the source/import-aware audit instead:

```bash
python3 verification/verify_quarantine.py
```

Verification may read archival files as text/data to check banners, digests,
and safety certificates. It may not `source`, import, or execute them.

It cannot run here — it expects the research tree and an AWS fleet — and
keeping it unsourced means it cannot break a build. That is what lets it stay
faithful to what actually ran, including the defect below.

## Fidelity

Twenty of the 21 files are byte-identical to the archival original **except for
a nine-line banner**. `ARCHIVAL-DIGESTS.csv` records both digests for all 21, so
`tail -n +11 <file> | shasum -a 256` recovers the original for those twenty.

The exception is `phase16/authorize-phase16-fresh-confirmation-v1.R`. The field
recording where its authority came from named the command-line harness through
which the author's instruction arrived; that name was removed before release.
The instruction text itself is unchanged, and
[`../provenance/redactions.csv`](../provenance/redactions.csv) carries the
digest the file had beforehand.

## The known defect

`R/core/ordinal-h.R` carries a second, larger banner. Its deterministic
per-pair transport helper advances its pointers on a `1e-12` mass tolerance and
can drop a valid tiny **positive** mass.

**The corrected implementation is the package kernel** — `ordinal-transport.R`
inside the [`bayesmokken`](https://github.com/joonho112/bayesmokken) package,
which uses exact-zero advancement plus a mass-conservation assertion.

No locked result is affected, and the package checks that rather than asserting
it. The helper compares a current residual atom mass, so the vulnerable set is
`0 < residual <= 1e-12`, including both marginal masses and cross-CDF
residuals. `verification/archival/verify_archival_safety.R` rebuilds all 168
population truths from Phases 14–16, runs historical and corrected kernels,
checks mass conservation, and exercises below/at/above-boundary fixtures. Risk
events and old/corrected differences are both zero for the locked truths.

The file ships **unchanged**. A replication package that quietly fixes the code
it exists to document stops documenting anything.

## Layout

```
R/core/         ordinal-h.R (see above), knot-diagnostics.R
R/dgp/          clustered ordinal data-generating processes
R/evaluation/   intervals, comparators, the Phase 15 calibration
R/weights/      the two-stage cluster weight law
phase16/        the confirmation runner, evaluator, finalizer
phase17/        the application runner, evaluator, finalizer, tests
tests/          the Phase 14 and 15 suites, with receipts
PIPELINE.md     the narrative
```
