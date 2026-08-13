#!/usr/bin/env Rscript
# Direct safety certificate for the historical ordinal transport defect.
#
# This script deliberately DOES NOT source reference-code/.  It contains two
# small, named transport reproductions: the historical tolerance-advancement
# algorithm and the corrected exact-zero/conservation algorithm.  It rebuilds
# all 168 population truth configurations from the shipped designs and compares
# the algorithms pair by pair.  The historical file's archival digest is still
# checked, so the reproduced algorithm remains tied to the recorded source.

.here <- local({
  fa <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(fa)) dirname(normalizePath(gsub("~+~", " ", sub("^--file=", "", fa[1]),
                                             fixed = TRUE), mustWork = FALSE)) else getwd()
})
ROOT <- normalizePath(file.path(.here, "..", ".."))
TOL <- 1e-12

stopifnot(requireNamespace("statmod", quietly = TRUE),
          requireNamespace("digest", quietly = TRUE))

archival_transport <- function(x_scores, x_mass, y_scores, y_mass,
                               mass_tol = TOL) {
  x_mass <- as.numeric(x_mass) / sum(x_mass)
  y_mass <- as.numeric(y_mass) / sum(y_mass)
  remaining_x <- x_mass; remaining_y <- y_mass
  i <- 1L; j <- 1L; value <- 0; moved_total <- 0
  while (i <= length(x_scores) && j <= length(y_scores)) {
    if (remaining_x[i] <= mass_tol) { i <- i + 1L; next }
    if (remaining_y[j] <= mass_tol) { j <- j + 1L; next }
    moved <- min(remaining_x[i], remaining_y[j])
    value <- value + moved * x_scores[i] * y_scores[j]
    moved_total <- moved_total + moved
    remaining_x[i] <- remaining_x[i] - moved
    remaining_y[j] <- remaining_y[j] - moved
    if (remaining_x[i] <= mass_tol) i <- i + 1L
    if (remaining_y[j] <= mass_tol) j <- j + 1L
  }
  list(maximum_product = value, moved_total = moved_total)
}

corrected_transport <- function(x_scores, x_mass, y_scores, y_mass,
                                mass_tol = TOL) {
  x_mass <- as.numeric(x_mass) / sum(x_mass)
  y_mass <- as.numeric(y_mass) / sum(y_mass)
  remaining_x <- x_mass; remaining_y <- y_mass
  i <- 1L; j <- 1L; value <- 0; moved_total <- 0
  while (i <= length(x_scores) && j <= length(y_scores)) {
    if (remaining_x[i] == 0) { i <- i + 1L; next }
    if (remaining_y[j] == 0) { j <- j + 1L; next }
    moved <- min(remaining_x[i], remaining_y[j])
    value <- value + moved * x_scores[i] * y_scores[j]
    moved_total <- moved_total + moved
    exhaust_x <- remaining_x[i] <= remaining_y[j]
    exhaust_y <- remaining_y[j] <= remaining_x[i]
    remaining_x[i] <- if (exhaust_x) 0 else remaining_x[i] - moved
    remaining_y[j] <- if (exhaust_y) 0 else remaining_y[j] - moved
    if (exhaust_x) i <- i + 1L
    if (exhaust_y) j <- j + 1L
  }
  if (abs(moved_total - 1) > mass_tol) {
    stop("corrected transport mass conservation failed", call. = FALSE)
  }
  list(maximum_product = value, moved_total = moved_total)
}

graded_probabilities <- function(theta, discrimination, thresholds) {
  cumulative <- matrix(stats::plogis(
    discrimination * (rep(theta, times = length(thresholds)) -
                        rep(thresholds, each = length(theta)))),
    nrow = length(theta), ncol = length(thresholds))
  p <- cbind(1 - cumulative[, 1L],
             cumulative[, -ncol(cumulative), drop = FALSE] -
               cumulative[, -1L, drop = FALSE],
             cumulative[, ncol(cumulative)])
  p[p < 0 & p > -1e-14] <- 0
  stopifnot(all(is.finite(p)), all(p >= 0))
  p / rowSums(p)
}

p14_spec <- function(strength, regularity) {
  discrimination <- switch(strength,
    weak = c(.55, .62, .68, .74, .80),
    medium = c(.95, 1.05, 1.15, 1.25, 1.35),
    strong = c(1.45, 1.60, 1.75, 1.90, 2.05))
  offset <- switch(regularity,
    regular = c(-.45, -.20, .05, .30, .55),
    near_knot = c(0, .0002, -.35, .32, .65),
    exact_knot = rep(0, 5L))
  if (regularity == "near_knot") discrimination[1:2] <- mean(discrimination[1:2])
  if (regularity == "exact_knot") discrimination[] <- mean(discrimination)
  base <- c(-1.20, -.35, .40, 1.25)
  list(discrimination = discrimination,
       thresholds = t(vapply(offset, function(x) base + x, numeric(4))))
}

p15_spec <- function(center, regularity, profile, stage) {
  profiles <- list(
    standard = c(-1.20, -.35, .40, 1.25),
    rare_high = c(-1.80, -.80, .30, 2.10),
    rare_low = c(-2.10, -.30, .80, 1.80),
    standard_shifted = c(-1.10, -.20, .55, 1.40),
    rare_high_shifted = c(-1.70, -.65, .45, 2.25),
    rare_low_shifted = c(-2.25, -.45, .65, 1.70),
    standard_confirm = c(-1.05, -.28, .48, 1.33),
    rare_high_confirm = c(-1.65, -.72, .37, 2.18),
    rare_low_confirm = c(-2.18, -.38, .72, 1.76))
  discrimination <- center * c(.85, .925, 1, 1.075, 1.15)
  offset <- switch(regularity,
    regular = c(-.45, -.20, .05, .30, .55),
    near_knot = switch(stage,
      training = c(0, .0002, -.35, .32, .65),
      validation = c(0, .00035, -.28, .38, .72),
      confirmation = c(0, .0005, -.31, .41, .76)),
    exact_knot = rep(0, 5L))
  if (regularity == "near_knot") discrimination[1:2] <- mean(discrimination[1:2])
  if (regularity == "exact_knot") discrimination[] <- center
  list(discrimination = discrimination,
       thresholds = t(vapply(offset, function(x) profiles[[profile]] + x, numeric(4))))
}

truth_moments <- function(cell, stage, target, nodes) {
  spec <- if (stage == "pilot") {
    p14_spec(cell$strength, cell$regularity)
  } else {
    p15_spec(cell$discrimination_center, cell$regularity,
             cell$threshold_profile, stage)
  }
  quadrature <- statmod::gauss.quad.prob(nodes, dist = "normal")
  grid <- expand.grid(u = quadrature$nodes, e = quadrature$nodes,
                      KEEP.OUT.ATTRS = FALSE)
  weight <- as.vector(outer(quadrature$weights, quadrature$weights))
  mechanism <- cell$size_mechanism
  size_weight <- if (stage == "pilot") {
    if (mechanism == "informative") 5 + round(24 * stats::plogis(grid$u))
    else rep(1, nrow(grid))
  } else {
    switch(mechanism,
      informative_positive = 5 + round(24 * stats::plogis(cell$informative_slope * grid$u)),
      informative_negative = 5 + round(24 * stats::plogis(-cell$informative_slope * grid$u)),
      rep(1, nrow(grid)))
  }
  if (target == "cluster") size_weight[] <- 1
  weight <- weight * size_weight; weight <- weight / sum(weight)
  theta <- sqrt(cell$latent_icc) * grid$u + sqrt(1 - cell$latent_icc) * grid$e
  supports <- rep(list(0:4), 5L)
  marginal <- vector("list", 5L)
  conditional_mean <- matrix(0, nrow(grid), 5L)
  for (j in seq_len(5L)) {
    p <- graded_probabilities(theta, spec$discrimination[j], spec$thresholds[j, ])
    marginal[[j]] <- colSums(weight * p)
    conditional_mean[, j] <- as.numeric(p %*% supports[[j]])
  }
  joint <- matrix(NA_real_, 5L, 5L)
  for (j in seq_len(4L)) for (k in (j + 1L):5L) {
    joint[j, k] <- joint[k, j] <- sum(weight * conditional_mean[, j] * conditional_mean[, k])
  }
  list(marginal = marginal, joint = joint, supports = supports)
}

evaluate_moments <- function(m) {
  means <- vapply(seq_len(5L), function(j) sum(m$marginal[[j]] * m$supports[[j]]), numeric(1))
  numerator <- 0; denominator_old <- 0; denominator_new <- 0
  max_pair_difference <- 0; max_conservation_error <- 0
  all_cross_gaps <- numeric()
  for (j in seq_len(4L)) for (k in (j + 1L):5L) {
    covariance <- m$joint[j, k] - means[j] * means[k]
    old <- archival_transport(m$supports[[j]], m$marginal[[j]],
                              m$supports[[k]], m$marginal[[k]])
    new <- corrected_transport(m$supports[[j]], m$marginal[[j]],
                               m$supports[[k]], m$marginal[[k]])
    numerator <- numerator + covariance
    denominator_old <- denominator_old + old$maximum_product - means[j] * means[k]
    denominator_new <- denominator_new + new$maximum_product - means[j] * means[k]
    max_pair_difference <- max(max_pair_difference,
                               abs(old$maximum_product - new$maximum_product))
    max_conservation_error <- max(max_conservation_error, abs(new$moved_total - 1))
    cx <- cumsum(m$marginal[[j]])[-5L]
    cy <- cumsum(m$marginal[[k]])[-5L]
    all_cross_gaps <- c(all_cross_gaps, abs(outer(cx, cy, "-")))
  }
  masses <- unlist(m$marginal, use.names = FALSE)
  positive_mass <- masses[masses > 0]
  positive_gap <- all_cross_gaps[all_cross_gaps > 0]
  list(
    old_H = numerator / denominator_old,
    corrected_H = numerator / denominator_new,
    max_pair_difference = max_pair_difference,
    max_conservation_error = max_conservation_error,
    minimum_positive_marginal_mass = min(positive_mass),
    minimum_positive_cross_cdf_gap = min(positive_gap),
    exact_cross_cdf_equalities = sum(all_cross_gaps == 0),
    risk_residual_count = sum(positive_mass <= TOL) + sum(positive_gap <= TOL)
  )
}

read_design <- function(name) utils::read.csv(file.path(ROOT, "data-frozen", "design", name),
                                               stringsAsFactors = FALSE)
p14 <- read_design("v4-phase14-pilot-design-v1.csv")
p15t <- read_design("v4-phase15-training-design-v1.csv")
p15v <- read_design("v4-phase15-validation-design-v1.csv")
p16 <- utils::read.csv(file.path(ROOT, "data-frozen", "confirmatory",
                                 "v4-phase16-confirmation-design-v1.csv"),
                       stringsAsFactors = FALSE)
p14_lock <- utils::read.csv(file.path(ROOT, "data-frozen", "pilot",
                                      "v4-phase14-pilot-truth-v1.csv"),
                            stringsAsFactors = FALSE)
p16_lock <- do.call(rbind, lapply(sort(list.files(
  file.path(ROOT, "data-frozen", "confirmatory-raw"), "truth-v1[.]csv$", full.names = TRUE)),
  utils::read.csv, stringsAsFactors = FALSE))

jobs <- list(
  list(stage = "pilot", design = p14, nodes = 31L, lock = p14_lock),
  list(stage = "training", design = p15t, nodes = 41L, lock = NULL),
  list(stage = "validation", design = p15v, nodes = 41L, lock = NULL),
  list(stage = "confirmation", design = p16, nodes = 51L, lock = p16_lock))

rows <- list(); z <- 0L
for (job in jobs) for (i in seq_len(nrow(job$design))) for (target in c("respondent", "cluster")) {
  z <- z + 1L
  cell <- job$design[i, ]
  ans <- evaluate_moments(truth_moments(cell, job$stage, target, job$nodes))
  lock_H <- NA_real_
  if (!is.null(job$lock)) {
    q <- job$lock[job$lock$cell_id == cell$cell_id & job$lock$target == target, ]
    stopifnot(nrow(q) == 1L)
    lock_H <- q$H
  }
  rows[[z]] <- data.frame(
    stage = job$stage, cell_id = cell$cell_id, target = target,
    old_H = ans$old_H, corrected_H = ans$corrected_H,
    absolute_old_corrected_difference = abs(ans$old_H - ans$corrected_H),
    maximum_pair_transport_difference = ans$max_pair_difference,
    maximum_conservation_error = ans$max_conservation_error,
    minimum_positive_marginal_mass = ans$minimum_positive_marginal_mass,
    minimum_positive_cross_cdf_gap = ans$minimum_positive_cross_cdf_gap,
    exact_cross_cdf_equalities = ans$exact_cross_cdf_equalities,
    risk_residual_count = ans$risk_residual_count,
    locked_H = lock_H,
    locked_absolute_difference = if (is.na(lock_H)) NA_real_ else abs(ans$old_H - lock_H),
    stringsAsFactors = FALSE)
}
certificate <- do.call(rbind, rows)

# The exact compared quantity is a current residual atom mass.  These fixtures
# distinguish literal zero, a small original edge mass, and cross-CDF residuals
# below, at, and above the inclusive historical threshold.
risk_case <- function(id, x, y, expected_risk) {
  old <- archival_transport(0:2, x, 0:2, y)
  new <- corrected_transport(0:2, x, 0:2, y)
  data.frame(case_id = id, old = old$maximum_product, corrected = new$maximum_product,
             difference = old$maximum_product - new$maximum_product,
             expected_risk = expected_risk, stringsAsFactors = FALSE)
}
risk <- rbind(
  risk_case("literal-zero-identical-margins", c(.3, .3, .4), c(.3, .3, .4), FALSE),
  risk_case("cross-gap-below", c(.3, .3, .4), c(.3 + .5e-12, .3, .4 - .5e-12), TRUE),
  risk_case("cross-gap-at", c(.3, .3, .4), c(.3 + 1e-12, .3, .4 - 1e-12), TRUE),
  risk_case("cross-gap-above", c(.3, .3, .4), c(.3 + 1.0001e-12, .3, .4 - 1.0001e-12), FALSE),
  risk_case("edge-mass-below", c(.5e-12, .5, .5 - .5e-12), c(.3, .3, .4), TRUE))

reg <- utils::read.csv(file.path(ROOT, "reference-code", "ARCHIVAL-DIGESTS.csv"),
                       stringsAsFactors = FALSE)
ord <- reg[reg$path == "reference-code/R/core/ordinal-h.R", ]
stopifnot(nrow(ord) == 1L, ord$sha256_archival ==
  "a9fef7ae0a9e8dd135790ad2b4fa88896416643b2403422aad29140c725964c4")

stopifnot(nrow(certificate) == 168L,
          identical(as.integer(table(certificate$stage)[c("pilot", "training", "validation", "confirmation")]),
                    c(36L, 48L, 36L, 48L)),
          max(certificate$absolute_old_corrected_difference) == 0,
          max(certificate$maximum_pair_transport_difference) == 0,
          max(certificate$maximum_conservation_error) <= TOL,
          sum(certificate$risk_residual_count) == 0L,
          min(certificate$minimum_positive_marginal_mass) > TOL,
          min(certificate$minimum_positive_cross_cdf_gap) > TOL,
          max(certificate$locked_absolute_difference, na.rm = TRUE) < 2e-12,
          risk$difference[!risk$expected_risk] == 0,
          abs(risk$difference[risk$expected_risk]) > 0)

result_dir <- file.path(.here, "results")
fixture <- file.path(result_dir, "archival-safety-certificate.csv")
if ("--write-certificate" %in% commandArgs(trailingOnly = TRUE)) {
  dir.create(result_dir, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(certificate, fixture, row.names = FALSE)
} else {
  stopifnot(file.exists(fixture))
  expected <- utils::read.csv(fixture, stringsAsFactors = FALSE)
  stopifnot(identical(expected[c("stage", "cell_id", "target")],
                      certificate[c("stage", "cell_id", "target")]))
  num <- setdiff(names(certificate), c("stage", "cell_id", "target"))
  for (nm in num) {
    ok <- (is.na(expected[[nm]]) & is.na(certificate[[nm]])) |
      (is.finite(expected[[nm]]) & is.finite(certificate[[nm]]) &
         abs(expected[[nm]] - certificate[[nm]]) <= 2e-14)
    stopifnot(all(ok))
  }
}

cat("archival ordinal-transport safety certificate\n")
cat(strrep("-", 72), "\n", sep = "")
cat("configurations:", nrow(certificate), "(36 pilot + 48 training + 36 validation + 48 confirmation)\n")
cat("risk residuals in (0, 1e-12]:", sum(certificate$risk_residual_count), "\n")
cat("minimum positive marginal mass:",
    format(min(certificate$minimum_positive_marginal_mass), digits = 16), "\n")
cat("minimum positive cross-CDF gap:",
    format(min(certificate$minimum_positive_cross_cdf_gap), digits = 16), "\n")
cat("literal exact cross-CDF equalities:", sum(certificate$exact_cross_cdf_equalities), "\n")
cat("maximum |old H - corrected H|:",
    format(max(certificate$absolute_old_corrected_difference), scientific = TRUE), "\n")
cat("locked Phase 14/16 maximum reconstruction difference:",
    format(max(certificate$locked_absolute_difference, na.rm = TRUE), scientific = TRUE), "\n")
cat("risk fixtures:", sum(risk$expected_risk), "detected;",
    sum(!risk$expected_risk), "safe\n")
cat("PASS  the locked helper executions are safe; inclusive synthetic risk cases diverge\n")
