# Data access

**No item responses ship with this package.** That is the simple case, and it
is worth stating plainly at the top.

| Tier | Origin | Ships? |
|---|---|---|
| design, pilot, development, validation, confirmatory | synthetic, from a documented seed tree | yes |
| `confirmatory-raw/` | 86,400 raw replication rows | yes, gzipped |
| `empirical/aws-raw/` | 12 × 99,999 bootstrap draws of H | yes |
| **the application responses** | `SWMDK`, inside the `mokken` package | **no — load it** |

The Phase 17 draw streams are *derived* quantities: bootstrap draws of the
scalability coefficient. They contain no respondent-level data.

## Getting the application data

```r
install.packages("mokken")
library(mokken)
data(SWMDK)
```

This is why **`mokken` is a required dependency** of this package rather than
an optional one, unlike in the companion Paper A package.

`common/R/io.R` loads it for you and checks it:

```r
source("common/R/paths.R"); source("common/R/io.R")
d <- read_swmdk()          # asserts the Phase 17 lock on every load
```

## What was locked, and what a mismatch means

The Phase 17 protocol recorded these facts about the object **before** the
application ran (`provenance/governance/protocol/phase17/v4-phase17-swmdk-empirical-protocol-v1.yml`):

| | |
|---|---|
| Object | `mokken::SWMDK` |
| `mokken` version at lock | **3.1.2** |
| SHA-256 of the object | `e1257ff16f821ef3cf6c5eed88a91ae2ffa5a067e12603f32c02660d47270797` |
| Respondents | **639** |
| Clusters | **30** (`classId`) |
| Cluster size range | 5 – 29 |
| Score support | 1 – 5 |
| Missing values on the fixed scale | 0 |

Verify by hand:

```r
library(mokken); library(digest)
data(SWMDK)
digest(SWMDK, algo = "sha256")
#> e1257ff16f821ef3cf6c5eed88a91ae2ffa5a067e12603f32c02660d47270797
```

::: {.callout-note}
The digest is of the **data frame as loaded**. `digest(as.matrix(SWMDK))` gives
a different value; `config.yml` records which one the lock means
(`digest_target: data.frame`).
:::

**If the digest does not match**, the `mokken` you have installed ships
different data from the one the application ran on. `read_swmdk()` stops with
both digests and both version numbers in the message. That is a finding about
the data source — report it rather than working around it, because every
application number in the paper is conditional on this object.

## Where SWMDK comes from

None of this is the authors' to relicense:

- a documented subset of the Dutch **COOL^5-18^** cohort study;
- items from **Peetsma and Van der Veen**;
- subset construction following **Koopman et al. (2022)**.

The scale analysed here is the six-item **teacher** scale (`Item1`–`Item6`),
whose locked point H is 0.61992 and scale ICC 0.169.

Its licence is the `mokken` package's own:
<https://cran.r-project.org/package=mokken>.

## A note on paths inside the locked artifacts

Seventy-five of the shipped receipts record the project-relative path each file
had in the research tree when the run happened — strings beginning
`codebase/research/v4/cluster-polytomous/…`.

Those are **provenance, not dependencies**. The runnable exhibit/verification
layer does not reach into that tree; copied executable evidence is explicitly
outside that narrower claim. The paths were left legible rather than rewritten
because editing locked evidence to tidy its appearance would break its digests.

## What does not ship

AWS scheduling logs and execution bundles — 37 files recording how the compute
was arranged rather than what was decided. The excluded Phase 16 bundle digest
is `d4a252b5…dd5614`; it is not present in the public package. Each has a verdict in
[`provenance/ship-ledger.csv`](provenance/ship-ledger.csv) and the reasoning is
in [`provenance/publication-boundary.md`](provenance/publication-boundary.md).

## The engine

`bayesmokken` is pinned, not vendored: <https://github.com/joonho112/bayesmokken>
(version 0.9.0). It is **optional** here — the exhibit layer rebuilds from the
frozen snapshot without it.
