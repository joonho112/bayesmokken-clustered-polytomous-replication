# Replication package: cluster-aware uncertainty for polytomous Mokken scalability

[![Code: MIT](https://img.shields.io/badge/Code-MIT-blue.svg)](LICENSE)
[![Content: CC BY 4.0](https://img.shields.io/badge/Content-CC%20BY%204.0-green.svg)](LICENSE-DATA)
[![R >= 4.1](https://img.shields.io/badge/R-%3E%3D%204.1-1f65b7.svg)](https://www.r-project.org/)

This repository is the replication package for

> **Cluster-Aware Uncertainty for Polytomous Mokken Scalability:
> A Calibrated Hierarchical Bayesian Bootstrap.**
> JoonHo Lee (2026). arXiv preprint (identifier forthcoming).
> <!-- TODO(author): replace with the arXiv identifier / DOI once posted. -->

It contains the code that produces every number, figure and table in the paper;
the frozen data those exhibits are built from, including the complete raw draw
streams of the application; an annotated reference copy of the pipeline; and the
governance record showing what was fixed before what. A rendered walkthrough is
the [**replication guide**](https://joonho112.github.io/bayesmokken-clustered-polytomous-replication/).

---

## Quick start

```bash
Rscript 00_setup.R                          # reports what's missing; installs nothing
Rscript exhibits/00_build_all.R             # 7 figures + 8 floats + the ledger, ~5s
Rscript verification/verify_reproduction.R  # 16 / 16
bash verification/cold_start_rehearsal.sh   # everything, from a bare copy
```

The release build requires macOS, R ≥ 4.1, twelve CRAN packages, and
`pdfinfo`, `pdftoppm`, `python3`, and `quarto`. It includes **`mokken`, which is
required** because the application data `SWMDK` is distributed inside it and no
responses ship here. `00_setup.R` exercises the Quartz PDF and JSON paths.

---

## What is reproduced

- **All 15 published exhibits.** The eight floats are **byte-identical** to what
  the paper prints; the seven figures match on page geometry and a fixed-DPI
  render hash. The target is the published manuscript build.
- **The 144-key ledger, byte-identical** to the one the manuscript was verified
  against (SHA-256 `6a42e7352e455ff0…`).
- **All 69 of the manuscript's concordance predicates**, re-expressed against
  the *rebuilt* ledger.

Headline: a fresh 24-cell confirmation at **6,400 replications per target**
brings coverage from a raw 99.75 % / 99.63 % to **97.36 % / 97.38 %** at about
**75 %** of the raw length. Both population targets — respondent-weighted and
equal-cluster — are reported separately throughout, because under informative
cluster size they are different population quantities.

## What is *not* reproduced

The Phase 16 confirmation and the Phase 17 application, both of which ran on
AWS. The pipeline ships as annotated reference code and is documented in
[`PIPELINE.md`](reference-code/PIPELINE.md).

---

## The raw evidence does ship

| Tier | Size | What |
|---|---:|---|
| `empirical/aws-raw/` | 18.5 MB | 12 tasks × **99,999** draws — the complete application draw streams |
| `confirmatory-raw/` | 5.0 MB | **86,400** raw replication rows, gzipped |

The 48-row all-cell summary is **re-derived from those raw rows on every build**
and cross-checked against the locked artifact at a 1e-12 tolerance.

## Data availability

**No item responses ship.** `SWMDK` is distributed inside the `mokken` package:

```r
library(mokken); data(SWMDK)
```

The Phase 17 protocol locked its digest, version and dimensions **before** the
application ran — 639 pupils, 30 clusters, `mokken` 3.1.2, SHA-256
`e1257ff16f821ef3…`. `read_swmdk()` asserts all of it on every load and stops
loudly if your copy differs.

Provenance: a documented subset of the Dutch COOL^5-18^ cohort study, items from
Peetsma and Van der Veen, subset construction per Koopman et al. (2022). See
[`DATA_ACCESS.md`](DATA_ACCESS.md).
## Layout

```
├── 00_setup.R              environment check; installs nothing
├── config.yml              tiers, counts, gates, the SWMDK lock
├── common/R/               paths.R (the only location resolver), io.R
├── data-frozen/            28 MB, 8 tiers — see CODEBOOK.md
├── exhibits/               the runnable layer
├── outputs/                7 figures, 8 floats, the 144-key ledger
├── reference-code/         the pipeline, annotated, NEVER sourced
├── provenance/             boundary, governance, the registers
├── verification/           the gates, their controls, and the oracles
└── docs/                   the replication guide
```

Three conventions: absolute paths live in one file; the executable paths listed
in `provenance/runnable-code.csv` never source or execute `reference-code/`; and
the runnable build layer does not depend on the companion research tree. The
quarantine verifier checks source/import/subprocess calls, while the disclosure
scan separately permits research-tree strings inside copied receipts and
archival evidence as provenance data.


---

## Verification

| Gate | Asks | Result |
|---|---|---|
| `verify_reproduction.R` | did the build reproduce the paper's exhibits? | **16 / 16** |
| `verify_manuscript_numbers.R` | does the rebuilt ledger agree with the paper? | digest match + **69 / 69** |
| `verify_semantics.R` | registers, exact inputs, claims, chart direction, the archival defect | **21 / 21** |
| `verify_governance.R` | does the receipt chain close? | **30 / 30** |
| `verify_quarantine.py` | can runnable code execute the archival pipeline? | **0 findings** |
| `disclosure_scan.py` | does the exact release set contain a disclosure or licence defect? | **0 findings** |
| `oracles/run_oracles.R` | do published, exhaustive, and boundary oracles agree? | **13 / 13** |
| `negative_controls.sh` | do the gates fail when they should? | **19 / 19** |
| `cold_start_rehearsal.sh` | does the full build work from a bare copy? | **15 / 15** |

```bash
bash verification/cold_start_rehearsal.sh   # runs all of the above
```

**The oracle lane reproduces Koopman et al. (2022)'s published values** from the
same data (teacher 0.62 → 0.6199, classmate 0.592 → 0.5923), and confirms a
linear-programming solution of the transport problem agrees with the
implementation across 3,362 exhaustive-grid cases (32 strata) and five
zero/tolerance/edge-mass boundary cases, with zero failed cases.

### One file ships with a known defect

`reference-code/R/core/ordinal-h.R` carries a "do not port" banner: its
transport helper advances on a 1e-12 mass tolerance and can drop a valid tiny
positive mass. The corrected kernel is in the `bayesmokken` package.

**No locked result is affected, and the package checks that directly.** The
vulnerable set is a current residual atom mass in `(0, 1e-12]`, inclusive; it
may arise from a marginal category mass or a cross-CDF residual. The archival
safety verifier rebuilds all 168 population truths from Phases 14–16 and runs
both kernels: risk events **0**, minimum positive marginal mass **0.0155405**,
minimum positive cross-CDF gap **1.93916e-05**, maximum `abs(old-new)` **0**.
Synthetic below/at/above-boundary and edge-mass controls confirm the test can
detect the defect.

---

## Software

| Package | Version | Source |
|---|---|---|
| bayesmokken | ≥ 0.9.0 | <https://github.com/joonho112/bayesmokken> |
| mokken | ≥ 3.1.2 | CRAN — **required**, it carries SWMDK |

## Companion package

The binary, independent-respondent case:
[`bayesmokken-scalability-replication`](https://github.com/joonho112/bayesmokken-scalability-replication).

Neither package depends on the other and they share no data. A reviewed base
set of **14 release-support files** is byte-identical; the exact paths and
SHA-256 values are recorded in `provenance/shared-harness-files.csv`. This set
includes `00_setup.R`, licence/metadata files, six verification scripts, shared
styles, handoff, and upstream-oracle documentation. Package-specific code and
all evidence remain separate.

## Citation

```
Lee, J. (2026). Replication package for "Cluster-Aware Uncertainty for
Polytomous Mokken Scalability: A Calibrated Hierarchical Bayesian Bootstrap."
```

## Licence

Code is [MIT](LICENSE); data, exhibits and the guide are
[CC BY 4.0](LICENSE-DATA). No third-party response data is redistributed.
