# Codebook — the frozen snapshot

Eight tiers, 207 evidence files, 28.23 MB, laid out along the evidence chain that produced
them:

```
Phase 14 pilot ──► Phase 15 training ──► Phase 15 held-out validation
                                              │
                                              ▼
                          Phase 16 fresh 24-cell confirmation
                                              │
                                              ▼
                        Phase 17 SWMDK application ──► Phase 18 crosswalk
```

| Tier | Files | Size | What |
|---|---:|---:|---|
| `design/` | 13 | 0.03 MB | the estimand and sampling contract, the weight law, the Phase 14/15 designs and their lock receipts |
| `pilot/` | 23 | 4.46 MB | Phase 14 feasibility |
| `development/` | 5 | 0.03 MB | Phase 15 training tier |
| `validation/` | 6 | 0.03 MB | Phase 15 held-out validation |
| `confirmatory/` | 19 | 0.05 MB | Phase 16, locked: cell, lane, comparator, subgroup summaries; gate checks; the decision (the redundant execution bundle is excluded) |
| `confirmatory-raw/` | 72 | 5.00 MB | **86,400 raw replication rows**, gzipped |
| `empirical/` | 52 | 18.56 MB | the SWMDK application, including **12 × 99,999 draw streams** |
| `phase18/` | 17 | 0.07 MB | the original-source crosswalk (G18-A) and production integration (G18-B) |

No item responses are here. `SWMDK` loads from the `mokken` package under a
locked digest — see [`../DATA_ACCESS.md`](../DATA_ACCESS.md).

## Reading it

```r
source("common/R/paths.R")
source("common/R/io.R")

cell <- read_tier("confirmatory", "v4-phase16-confirmation-cell-summary-v1.csv")
raw  <- read_confirmatory_raw()      # 86,400 rows, binds all 24 files
draws<- read_draws(task = 1)         # 99,999 draws from P17-T01
swmdk<- read_swmdk()                 # from mokken, digest asserted
```

The named raw readers assert their declared dimensions. The generic
`read_tier()` asserts existence; `verification/verify_numeric_basis.R` performs
the exact schema, manifest/receipt, key/domain, and raw-to-result checks.

::: {.callout-warning}
Never hand a `.gz` path to `data.table::fread()` — it decompresses in place and
mutates the frozen snapshot. The readers open `gzfile()` connections.
:::

## The two population targets

This is the distinction the whole paper turns on, so it is the first thing the
design tier fixes:

| Target id | Means |
|---|---|
| `V4-TARGET-RESPONDENT-WEIGHTED-v1` | every respondent counts equally |
| `V4-TARGET-EQUAL-CLUSTER-v1` | every cluster counts equally |

Under **informative cluster size** — when a cluster's size is associated with
its scalability — these are different population quantities, not two estimators
of one. `v4-estimand-and-sampling-contract-v1.yml` requires the target to be
**declared**, never inferred, and every locked summary carries a `target`
column.

## design

The pre-outcome tier. `v4-estimand-and-sampling-contract-v1.yml` (the estimand,
the sampling model, the conditioning), `v4-weight-law-specification-v1.yml` (the
two-stage weight law), the Phase 14 pilot design, the Phase 15 training and
validation designs, and the two protocol-lock receipts that sealed them.

## pilot, development, validation

Phase 14 established feasibility. Phase 15 split into a **training** tier, where
the cluster-count-dependent calibration factor was fitted, and a **held-out
validation** tier, where it was tested on data it had not seen.

`tabE1_training.tex` and `tabE2_validation.tex` come from these two, and the
split is visible in the row counts rather than only asserted in the protocol.

## confirmatory

Phase 16: a **fresh** 24-cell confirmation at 6,400 replications per target,
run after the calibration was frozen.

| File | What |
|---|---|
| `…confirmation-design-v1.csv` | the 24 cells |
| `…confirmation-cell-summary-v1.csv` | per cell × target |
| `…confirmation-lane-summary-v1.csv` | the four lanes: {exact, near} knot × {equal-cluster, respondent} |
| `…confirmation-comparator-summary-v1.csv` | against the comparators |
| `…confirmation-subgroup-summary-v1.csv` | subgroup breakdowns |
| `…confirmation-gate-checks-v1.csv`, `…-gate-evidence-v1.csv` | the acceptance gate |
| `…confirmation-decision-v1.json` | the verdict |
| `…final-closure-receipt-v1.json` | closure |

Coverage columns carry a Monte Carlo standard error beside them throughout.

## confirmatory-raw

The 24 per-cell replication files — **86,400 rows** — from which the 48-row
all-cell summary is derived and cross-checked against the locked regular-cell
artifact at a 1e-12 tolerance.

This tier is **load-bearing, not archival**: `exhibits/01_build_key_numbers.R`
reads it through `list.files()` to build `derived_p16_allcell_summary.csv`,
which feeds `tabF1_cells.tex` and `FigF1_cells.pdf`.

Selection within it: `candidate == TRUE` and `gamma_cluster == -1.5` gives the
19,200 selected rows, all with `invalid_fraction == 0` and `total_draws == 499`.

Each cell also ships a `-truth-v1.csv` and a `-receipt-v1.json`.

## empirical

The SWMDK application.

| Path | What |
|---|---|
| `empirical/aws-raw/` | **12 tasks × 99,999 draws** of H, gzipped, plus per-task batch manifests and receipts |
| `empirical/artifacts/` | the locked application results, evidence manifests, the G17 decision receipt |
| `empirical/results/` | the derived application tables |

The draw streams are the "complete raw draw streams of the application" the
article promises. They are bootstrap draws of the coefficient — no
respondent-level data.

## phase18

`review/` is the G18-A original-source crosswalk: the check that the method as
implemented matched the published sources it claims to follow.
`production/` is G18-B, the integration into the `bayesmokken` package, with its
final decision receipt.

## A note on the paths inside these files

Many locked receipts record the project-relative path each file had in the
research tree — `codebase/research/v4/cluster-polytomous/…`. That is
provenance. Nothing in this package's code reaches into that tree, and the
disclosure scan checks the severance separately. See
[`../DATA_ACCESS.md`](../DATA_ACCESS.md#a-note-on-paths-inside-the-locked-artifacts).
