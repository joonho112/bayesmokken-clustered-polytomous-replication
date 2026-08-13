# Which licence covers which file

Two licences apply. This file routes every artifact class to one of them so the
question never needs to be inferred from a file's location.

The machine-readable authority is `provenance/release-files.csv`, with one row
per public file. **Executable type takes precedence over directory:** every
`.R`, `.py`, and `.sh` file is MIT-licensed even when it sits under
`data-frozen/` or `provenance/`. Thus copied test runners and protocol
evaluators are code, not CC-BY evidence merely because of their path.

| Path | Class | Licence |
|---|---|---|
| `00_setup.R`, `common/`, `exhibits/`, `verification/`, `reference-code/` | code | [MIT](LICENSE) |
| `data-frozen/design/`, `pilot/`, `development/`, `validation/`, `confirmatory/`, `confirmatory-raw/` | synthetic simulation evidence | [CC BY 4.0](LICENSE-DATA) |
| `data-frozen/empirical/` | bootstrap draws and derived statistics from the SWMDK application | [CC BY 4.0](LICENSE-DATA) |
| `data-frozen/phase18/` | crosswalk and integration receipts | [CC BY 4.0](LICENSE-DATA) |
| `outputs/` | rebuilt figures and tables | [CC BY 4.0](LICENSE-DATA) |
| `provenance/` | protocol, receipts, registers, claim register (except executable code) | [CC BY 4.0](LICENSE-DATA) |
| `docs/` | the replication guide | [CC BY 4.0](LICENSE-DATA) |
| `verification/oracles/` | code | [MIT](LICENSE) |

The release-boundary audit rejects an executable whose per-file register does
not resolve to MIT and rejects any public file missing a classification.

## The case that does not arise here

Unlike the companion Paper A package, **no third-party response data is
redistributed**. `SWMDK` is loaded from the `mokken` package at run time and
never copied into this repository, so no upstream data licence is inherited by
a downstream user of these files.

## What is not here

The `bayesmokken` package is not vendored. It is a separate public repository
with its own licence: <https://github.com/joonho112/bayesmokken>.

`SWMDK` is not vendored. It belongs to the `mokken` package:
<https://cran.r-project.org/package=mokken>.
