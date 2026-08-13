# How the frozen snapshot was produced

Five gates, in order. Every figure below comes from a receipt that ships under
[`../provenance/governance/`](../provenance/governance/) or
[`../data-frozen/`](../data-frozen/).

## The chain

```
G14 feasibility ──► Phase 15 training ──► Phase 15 held-out validation
                                                │
                                                ▼
                            G16 fresh 24-cell confirmation
                                                │
                                                ▼
                    G17 SWMDK application ──► G18-A crosswalk ──► G18-B integration
```

**The order is the argument.** The calibration was fitted on training data,
tested on held-out data, and only then run on a *fresh* confirmation — so the
confirmation's coverage is not the coverage the calibration was tuned to.

## G14 — feasibility

Established that a cluster-aware interval was worth building. Recorded in
`v4-g14-decision-receipt-v1.json`, which the Phase 15 authority addendum
descends from.

## Phase 15 — train, then hold out

The calibration factor k_G = 1 − 1.5/√G was fitted on a **training** tier at
299 bootstrap draws per replication, then tested on a **held-out validation**
tier. The split is visible in the shipped row counts, not only asserted in the
protocol.

Both tiers ship: `data-frozen/development/` and `data-frozen/validation/`,
producing Tables E1 and E2.

## G16 — the fresh confirmation

| | |
|---|---|
| Cells | 24 |
| Replications per cell-target | 400 |
| **Replications per target** | **6,400** |
| Bootstrap draws per replication | 499 |
| Raw replication rows | **86,400** |
| Selected lane | `candidate`, `gamma_cluster == -1.5` → 19,200 rows |
| Invalid draws | 0 throughout |

Ran on AWS under a hash-bound protocol lock written beforehand. The 24 per-cell
replication files ship gzipped as `data-frozen/confirmatory-raw/`, and
`exhibits/01_build_key_numbers.R` re-derives the 48-row all-cell summary from
them on every build, **cross-checked against the locked regular-cell artifact at
a 1e-12 tolerance**.

Result: calibrated coverage 97.36 % (respondent) and 97.38 % (equal-cluster),
against raw 99.75 % and 99.63 %. The calibration tightens; length falls to
about 75 % of raw.

## G17 — the SWMDK application

12 tasks × **99,999** draws = **1,199,988**, zero invalid. Each task ships its
draw stream, batch manifest and receipt in `data-frozen/empirical/aws-raw/`.

The data object was digest-locked *before* the run
(`v4-phase17-swmdk-empirical-protocol-v1.yml`), which is what makes the
application checkable at all given that no responses ship.

## G18-A — checking the method against its sources

Before integration, the implementation was checked against the published
sources it claims to follow: **three crosswalks closed** across 13 blocking
checks, with page- and line-level registers shipping under
`data-frozen/phase18/review/`.

That is what makes the Andreadis (2017) predecessor credit in claim CL-03 a
finding rather than a courtesy.

## G18-B — integration

Into the `bayesmokken` package: 791 expectations, `R CMD check` clean. The
final decision receipt ships under `data-frozen/phase18/production/`.

**This is also where the archival defect was corrected.** The kernel that went
into the package uses exact-zero advancement; the copy here does not. See
[`README.md`](README.md).

## What you can and cannot re-run

**Cannot:** G16 or G17. Both ran on AWS and are documented rather than enabled.

**Can:** the whole exhibit layer, in about five seconds.

**Can, independently:** re-derive the 48-row all-cell summary from the 86,400
raw rows — the build does exactly this, with the 1e-12 cross-check — and
recompute the application's point estimates from `data(SWMDK)`, which the
oracle lane does while also reproducing Koopman et al. (2022).

## What is not here

The per-replication **seed** record. Paper A's confirmation stored one row per
replication carrying its seeds; this one stored per-replication *outcomes*
instead. So an individual replication cannot be regenerated from this package
alone, while the aggregation from raw rows to published table is verified end to
end. `../provenance/seed-tree.md` states that difference plainly.
