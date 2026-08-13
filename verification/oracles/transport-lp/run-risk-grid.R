#!/usr/bin/env Rscript
# Boundary grid for the historical tolerance-advancement defect.  LP and the
# corrected exact-zero pointer are independent solutions; the historical
# reproduction is included only to prove the control detects below/at-threshold
# loss and does not misclassify literal zero or an above-threshold residual.

script_arg <- grep("^--file=", commandArgs(), value = TRUE)
oracle_dir <- if (length(script_arg)) {
  dirname(normalizePath(gsub("~+~", " ", sub("^--file=", "", script_arg[[1]]),
                               fixed = TRUE)))
} else normalizePath(getwd())
source(file.path(oracle_dir, "solve-transport-lp.R"))
source(file.path(oracle_dir, "two-pointer-reference.R"))

archival_pointer <- function(x_scores, x_mass, y_scores, y_mass,
                             mass_tol = 1e-12) {
  x_mass <- x_mass / sum(x_mass); y_mass <- y_mass / sum(y_mass)
  rx <- x_mass; ry <- y_mass; i <- 1L; j <- 1L; value <- 0
  while (i <= length(x_scores) && j <= length(y_scores)) {
    if (rx[i] <= mass_tol) { i <- i + 1L; next }
    if (ry[j] <= mass_tol) { j <- j + 1L; next }
    moved <- min(rx[i], ry[j])
    value <- value + moved * x_scores[i] * y_scores[j]
    rx[i] <- rx[i] - moved; ry[j] <- ry[j] - moved
    if (rx[i] <= mass_tol) i <- i + 1L
    if (ry[j] <= mass_tol) j <- j + 1L
  }
  value
}

cases <- list(
  list(id = "literal-zero", class = "zero", eps = 0,
       x = c(.3, .3, .4), y = c(.3, .3, .4), diverges = FALSE),
  list(id = "cross-gap-below", class = "below", eps = .5e-12,
       x = c(.3, .3, .4), y = c(.3 + .5e-12, .3, .4 - .5e-12), diverges = TRUE),
  list(id = "cross-gap-at", class = "at", eps = 1e-12,
       x = c(.3, .3, .4), y = c(.3 + 1e-12, .3, .4 - 1e-12), diverges = TRUE),
  list(id = "cross-gap-above", class = "above", eps = 1.0001e-12,
       x = c(.3, .3, .4), y = c(.3 + 1.0001e-12, .3, .4 - 1.0001e-12), diverges = FALSE),
  list(id = "edge-mass-below", class = "below-edge", eps = .5e-12,
       x = c(.5e-12, .5, .5 - .5e-12), y = c(.3, .3, .4), diverges = TRUE))

out <- do.call(rbind, lapply(cases, function(z) {
  old <- archival_pointer(0:2, z$x, 0:2, z$y)
  corrected <- transport_two_pointer(0:2, z$x, 0:2, z$y)
  lp <- transport_lp_oracle(0:2, z$x, 0:2, z$y)
  old_diff <- old - corrected$maximum_product
  lp_diff <- corrected$maximum_product - lp$maximum_product
  detected <- abs(old_diff) > 0
  data.frame(
    case_id = z$id, residual_class = z$class, residual = z$eps,
    archival_value = old, corrected_value = corrected$maximum_product,
    lp_value = lp$maximum_product,
    archival_corrected_difference = old_diff,
    corrected_lp_absolute_difference = abs(lp_diff),
    lp_maximum_marginal_residual = lp$maximum_marginal_residual,
    expected_archival_divergence = z$diverges,
    observed_archival_divergence = detected,
    corrected_mass_conserved = abs(corrected$moved_total - 1) <= 1e-12,
    pass = identical(detected, z$diverges) &&
      abs(lp_diff) <= 1e-10 && lp$maximum_marginal_residual <= 1e-10 &&
      abs(corrected$moved_total - 1) <= 1e-12,
    stringsAsFactors = FALSE)
}))

results_dir <- file.path(oracle_dir, "results")
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
write.csv(out, file.path(results_dir, "risk-grid-results.csv"), row.names = FALSE)
cat("cases=", nrow(out), " failed=", sum(!out$pass),
    " risk_detected=", sum(out$observed_archival_divergence), "\n", sep = "")
if (any(!out$pass)) quit(status = 1L)
