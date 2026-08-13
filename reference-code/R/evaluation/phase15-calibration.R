# +---------------------------------------------------------------------------+
# | REFERENCE CODE -- ARCHIVAL. NOTHING IN THIS PACKAGE SOURCES THIS FILE.     |
# |                                                                           |
# | This is the pipeline that produced data-frozen/, preserved as it ran. It   |
# | is here to be READ, not executed: it expects the research tree, an AWS     |
# | fleet, and inputs this package does not ship. The exhibit layer rebuilds   |
# | every number from the frozen snapshot instead.                             |
# |                                                                           |
# | Only this banner was added. Every code line below is byte-identical to     |
# | the archival original; reference-code/README.md records the digests.       |
# +---------------------------------------------------------------------------+

# Phase 15 minimal cluster-width candidate construction.

v4_gamma_method_id <- function(target, gamma) {
  target_code <- if (target == "respondent") "RESP" else "CLUSTER"
  gamma_code <- if (gamma == 0) {
    "G000"
  } else if (gamma < 0) {
    paste0("GN", sprintf("%03d", as.integer(round(abs(gamma) * 100))))
  } else {
    paste0("GP", sprintf("%03d", as.integer(round(gamma * 100))))
  }
  paste("V4-P15-HBB", target_code, gamma_code, "v1", sep = "-")
}

v4_calibrated_interval_from_raw <- function(raw_lower, raw_upper,
                                            G, gamma) {
  raw_lower <- as.numeric(raw_lower)
  raw_upper <- as.numeric(raw_upper)
  G <- as.numeric(G)
  gamma <- as.numeric(gamma)
  multiplier <- 1 + gamma / sqrt(G)
  if (!is.finite(multiplier) || multiplier <= 0) {
    stop("Cluster width multiplier must be positive.", call. = FALSE)
  }
  midpoint <- (raw_lower + raw_upper) / 2
  half_width <- (raw_upper - raw_lower) / 2
  c(
    lower = midpoint - multiplier * half_width,
    upper = midpoint + multiplier * half_width,
    center = midpoint,
    length = 2 * multiplier * half_width,
    multiplier = multiplier
  )
}

v4_evaluate_gamma_candidates <- function(draws, point_estimate,
                                         truth, G, target,
                                         gamma_candidates) {
  raw <- v4_raw_interval(
    draws = draws,
    point_estimate = point_estimate,
    level = 0.95,
    quantile_type = 8L,
    minimum_defined_fraction = 0.99
  )
  rows <- lapply(gamma_candidates, function(gamma) {
    if (raw$status != "OK") {
      interval <- c(
        lower = NA_real_, upper = NA_real_,
        center = NA_real_, length = NA_real_,
        multiplier = NA_real_
      )
    } else {
      interval <- v4_calibrated_interval_from_raw(
        raw$lower, raw$upper, G, gamma
      )
    }
    data.frame(
      method_id = v4_gamma_method_id(target, gamma),
      base_method_id = if (target == "respondent") {
        "V4-PRI-TWO-STAGE-HBB-RESP-v1"
      } else {
        "V4-SENS-TWO-STAGE-HBB-CLUSTER-v1"
      },
      target_id = if (target == "respondent") {
        "V4-TARGET-RESPONDENT-WEIGHTED-v1"
      } else {
        "V4-TARGET-EQUAL-CLUSTER-v1"
      },
      candidate = TRUE,
      gamma_cluster = gamma,
      width_multiplier = interval[["multiplier"]],
      point_estimate = point_estimate,
      truth = truth,
      bias = point_estimate - truth,
      lower = interval[["lower"]],
      upper = interval[["upper"]],
      center = interval[["center"]],
      interval_length = interval[["length"]],
      se_equivalent = raw$se_equivalent,
      cover = isTRUE(
        is.finite(interval[["lower"]]) &&
          interval[["lower"]] <= truth &&
          truth <= interval[["upper"]]
      ),
      defined_draws = raw$defined_draws,
      total_draws = raw$total_draws,
      invalid_fraction = raw$invalid_fraction,
      status = raw$status,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}
