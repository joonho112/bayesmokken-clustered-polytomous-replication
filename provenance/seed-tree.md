# The seed tree

## Where randomness enters

Three places, all governed before the outcomes they produce:

| Stage | What is drawn | Governed by |
|---|---|---|
| data generation | clustered ordinal responses per cell | the Phase 14/15 designs |
| the two-stage bootstrap | cluster weights, then respondent weights within cluster | `v4-weight-law-specification-v1.yml` |
| comparators | nonparametric and one-stage bootstrap draws | the same protocol |

## What the confirmation fixed

| | |
|---|---|
| Cells | 24 |
| Replications per cell-target | 400 |
| Replications per target | **6,400** |
| Bootstrap draws per replication | **499** |
| Phase 15 draws per replication | 299 |
| Selected lane | `candidate == TRUE`, `gamma_cluster == -1.5` |
| Selected rows | 19,200, all with `invalid_fraction == 0` |

Those counts are asserted by `common/R/io.R` on every read of the raw tier and
appear as registered ledger keys.

## The application

12 tasks × **99,999** draws = **1,199,988** draws, **zero invalid**.

Each task ships its own receipt and batch manifest in
`data-frozen/empirical/aws-raw/`, so a reader can see what each task was asked
for and what it returned.

## What is checkable

The per-replication seed record that the companion Paper A package ships is not
present here — the confirmation's raw tier carries per-replication *outcomes*
(`cover`, `interval_length`, `invalid_fraction`, `total_draws`) rather than the
seeds that produced them.

What that supports is still substantial: the 48-row all-cell summary is
**re-derived from the 86,400 raw rows on every build** and cross-checked against
the locked regular-cell artifact at a 1e-12 tolerance. So the aggregation is
verified end to end even though an individual replication cannot be regenerated
from this package alone.

That difference between the two packages is worth stating plainly rather than
leaving a reader to infer it from an absent column.
