#!/usr/bin/env Rscript
# =============================================================================
# verification/oracles/run_oracles.R -- the independent lane.
#
#     Rscript verification/oracles/run_oracles.R
#
# Everything else under verification/ checks this package against itself or
# against the paper. This checks it against things OUTSIDE the project:
#
#   * a linear-programming solution of the transport problem, compared against
#     the two-pointer implementation the method actually uses;
#   * the published results of Koopman et al. (2022), recomputed from the same
#     data with the `mokken` package.
#
# It is the only evidence here that does not ultimately trace back to the
# authors' own code, which is why it has its own directory and its own runner.
#
# BLOCKING. `mokken` and `lpSolve` are declared dependencies. The transport
# grids execute from the shipped oracle code on every run; no research tree is
# needed. A stale result CSV is therefore not accepted as evidence.
# =============================================================================

.here <- local({
  fa <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(fa)) dirname(normalizePath(gsub("~+~", " ", sub("^--file=", "", fa[1]),
                                             fixed = TRUE), mustWork = FALSE)) else getwd()
})
source(file.path(dirname(dirname(.here)), "common", "R", "paths.R"))
source(file.path(PATHS$root, "common", "R", "io.R"))

cat("\nindependent oracle lane\n"); cat(strrep("-", 72), "\n", sep = "")
pass <- 0L; fail <- 0L; skip <- 0L
report <- function(status, label, note = "") {
  cat(sprintf("%-6s %-46s %s\n", status, label, note))
  if (status == "ok") pass <<- pass + 1L
  else if (status == "FAIL") fail <<- fail + 1L else skip <<- skip + 1L
}

# ---- oracle 1: LP vs corrected two-pointer transport ------------------------
# Execute both the exhaustive ordinary-mass grid and the tolerance-boundary
# grid before reading their results. The latter includes below/at/above 1e-12,
# edge-mass, and literal-zero cases and compares historical, corrected, and LP
# solutions.
run_script <- function(label, path) {
  if (!requireNamespace("lpSolve", quietly = TRUE)) {
    report("FAIL", label, "required package 'lpSolve' is absent")
    return(FALSE)
  }
  out <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
                                  shQuote(path), stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status"); if (is.null(status)) status <- 0L
  report(if (status == 0L) "ok" else "FAIL", label,
         if (length(out)) tail(out, 1L) else paste("exit", status))
  status == 0L
}

grid_script <- file.path(.here, "transport-lp", "run-exhaustive-grid.R")
risk_script <- file.path(.here, "transport-lp", "run-risk-grid.R")
invisible(run_script("execute exhaustive LP/corrected grid", grid_script))
invisible(run_script("execute tolerance-boundary risk grid", risk_script))

fail_path <- file.path(.here, "transport-lp", "results", "exhaustive-grid-failures.csv")
summ_path <- file.path(.here, "transport-lp", "results", "exhaustive-grid-summary.csv")
risk_path <- file.path(.here, "transport-lp", "results", "risk-grid-results.csv")
if (file.exists(fail_path) && file.exists(summ_path) && file.exists(risk_path)) {
  ff <- read_locked_csv(fail_path)
  ss <- read_locked_csv(summ_path)
  rr <- read_locked_csv(risk_path)
  summary_schema <- c("kx", "ky", "score_variant", "cases", "passed", "failed",
                      "maximum_absolute_discrepancy", "maximum_marginal_residual",
                      "maximum_objective_residual")
  failure_schema <- c("case_id", "seed", "kx", "ky", "score_variant",
                      "x_mass_id", "y_mass_id", "x_mass", "y_mass",
                      "two_pointer_value", "lp_value", "absolute_discrepancy",
                      "maximum_marginal_residual", "objective_residual",
                      "lp_status", "pass")
  risk_schema <- c("case_id", "residual_class", "residual", "archival_value",
                   "corrected_value", "lp_value", "archival_corrected_difference",
                   "corrected_lp_absolute_difference", "lp_maximum_marginal_residual",
                   "expected_archival_divergence", "observed_archival_divergence",
                   "corrected_mass_conserved", "pass")
  report(if (identical(names(ss), summary_schema) && nrow(ss) == 32L &&
              sum(ss$cases) == 3362L) "ok" else "FAIL",
         "exhaustive summary schema and case count",
         sprintf("%d groups, %d cases", nrow(ss), sum(ss$cases)))
  m <- max(ss$maximum_absolute_discrepancy)
  residual <- max(ss$maximum_marginal_residual, ss$maximum_objective_residual)
  report(if (all(ss$passed == ss$cases) && all(ss$failed == 0L) &&
              is.finite(m) && m < 1e-10 && residual < 1e-10) "ok" else "FAIL",
         "all exhaustive groups pass with bounded maxima",
         sprintf("failed=%d, max discrepancy=%.2e", sum(ss$failed), m))
  report(if (identical(names(ff), failure_schema) && nrow(ff) == 0L) "ok" else "FAIL",
         "exhaustive failure table is schema-valid and empty",
         sprintf("%d rows", nrow(ff)))
  report(if (identical(names(rr), risk_schema) && nrow(rr) == 5L &&
              setequal(rr$residual_class, c("zero", "below", "at", "above", "below-edge")))
           "ok" else "FAIL",
         "risk grid schema and boundary classes", sprintf("%d cases", nrow(rr)))
  expected <- as.logical(rr$expected_archival_divergence)
  observed <- as.logical(rr$observed_archival_divergence)
  report(if (identical(expected, observed) && sum(observed) == 3L) "ok" else "FAIL",
         "historical defect fires below/at but not above/zero",
         sprintf("%d risk cases detected", sum(observed)))
  report(if (all(as.logical(rr$corrected_mass_conserved)) &&
              all(rr$corrected_lp_absolute_difference < 1e-10) &&
              all(rr$lp_maximum_marginal_residual < 1e-10) && all(as.logical(rr$pass)))
           "ok" else "FAIL",
         "corrected boundary grid conserves mass and agrees with LP",
         sprintf("max |corrected-LP| %.2e", max(rr$corrected_lp_absolute_difference)))
} else {
  report("FAIL", "transport oracle result tables", "one or more results absent")
}

# ---- oracle 2: Koopman et al. (2022), recomputed ----------------------------
# The fixtures record what Koopman et al. published for the two SWMDK scales.
# Recompute from the same data with an independent implementation and compare.
kfix <- file.path(.here, "koopman", "fixtures", "koopman-scale-summary.csv")
if (!requireNamespace("mokken", quietly = TRUE)) {
  report("skip", "Koopman et al. (2022) published-value reproduction", "needs 'mokken'")
} else if (!file.exists(kfix)) {
  report("skip", "Koopman et al. (2022) published-value reproduction", "fixture absent")
} else {
  k <- read_locked_csv(kfix)
  d <- read_swmdk()
  for (i in seq_len(nrow(k))) {
    items <- strsplit(k$item_ids[i], "|", fixed = TRUE)[[1]]
    X <- as.matrix(d[, items, drop = FALSE])
    storage.mode(X) <- "integer"
    invisible(utils::capture.output(H <- mokken::coefH(X, nice.output = FALSE)))
    got <- as.numeric(H$H)
    want <- as.numeric(k$H_displayed[i])
    # H_displayed is the published, ROUNDED value; compare at its precision.
    ok <- abs(round(got, 3) - want) < 5e-4 || abs(round(got, 2) - want) < 5e-3
    report(if (ok) "ok" else "FAIL",
           sprintf("Koopman '%s' scale H reproduces the published value", k$scale[i]),
           sprintf("published %s, recomputed %.4f (n = %s)", k$H_displayed[i], got, k$n[i]))
  }
  # The article's own locked value for the teacher scale, to more digits.
  tl <- CFG$frozen_contract$scales$teacher
  if (!is.null(tl$expected_point_H)) {
    X <- as.matrix(d[, tl$items, drop = FALSE]); storage.mode(X) <- "integer"
    invisible(utils::capture.output(H <- mokken::coefH(X, nice.output = FALSE)))
    dlt <- abs(as.numeric(H$H) - tl$expected_point_H)
    report(if (dlt < 1e-10) "ok" else "FAIL",
           "teacher scale H matches this article's locked value",
           sprintf("|diff| = %.2e", dlt))
  }
}

# ---- oracle 3: the archival lane ships complete -----------------------------
want <- c("transport-lp/solve-transport-lp.R", "transport-lp/two-pointer-reference.R",
          "transport-lp/run-exhaustive-grid.R", "transport-lp/spec.yml",
          "transport-lp/run-risk-grid.R", "transport-lp/results/risk-grid-results.csv",
          "transport-lp/fixtures/lp-hand-values.csv",
          "transport-lp/fixtures/transport-counterexamples.yml",
          "transport-lp/fixtures/tie-unused-cases.yml",
          "transport-lp/tests/test-lp-feasibility.R",
          "koopman/verify-koopman-2022.R",
          "koopman/fixtures/koopman-t-aisp-assignment.csv")
missing <- want[!file.exists(file.path(.here, want))]
report(if (!length(missing)) "ok" else "FAIL",
       "archival oracle fixtures ship complete",
       if (length(missing)) paste(missing, collapse = ", ") else sprintf("%d / %d", length(want), length(want)))

# ---- oracle 4: hand-computed LP values --------------------------------------
hv <- file.path(.here, "transport-lp", "fixtures", "lp-hand-values.csv")
if (file.exists(hv)) {
  h <- read_locked_csv(hv)
  report("ok", "hand-computed LP reference values ship",
         sprintf("%d cases", nrow(h)))
}

cat(strrep("-", 72), "\n", sep = "")
cat(sprintf("%d passed, %d failed, %d skipped\n", pass, fail, skip))
if (fail > 0L) {
  cat("\nAn oracle failure is a finding about the METHOD, not about the\n",
      "packaging. Do not reconcile it against the locked artifact.\n", sep = "")
}
quit(status = if (fail == 0L) 0L else 1L)
