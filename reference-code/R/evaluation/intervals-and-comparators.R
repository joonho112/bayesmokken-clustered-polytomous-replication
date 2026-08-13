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

# Raw interval construction and independent comparator wrappers.

v4_raw_interval <- function(draws, point_estimate,
                            level = 0.95,
                            quantile_type = 8L,
                            minimum_defined_fraction = 0.99) {
  draws <- as.numeric(draws)
  finite <- is.finite(draws)
  defined <- draws[finite]
  required <- ceiling(minimum_defined_fraction * length(draws))
  if (length(defined) < required || length(defined) < 20L) {
    return(list(
      lower = NA_real_,
      upper = NA_real_,
      center = NA_real_,
      length = NA_real_,
      se_equivalent = NA_real_,
      defined_draws = length(defined),
      total_draws = length(draws),
      invalid_fraction = mean(!finite),
      status = "INSUFFICIENT_DEFINED_DRAWS"
    ))
  }
  alpha <- 1 - level
  interval <- as.numeric(stats::quantile(
    defined,
    probs = c(alpha / 2, 1 - alpha / 2),
    type = quantile_type,
    names = FALSE
  ))
  list(
    lower = interval[1L],
    upper = interval[2L],
    center = mean(interval),
    length = diff(interval),
    se_equivalent = stats::sd(defined),
    defined_draws = length(defined),
    total_draws = length(draws),
    invalid_fraction = mean(!finite),
    status = "OK",
    point_estimate = point_estimate
  )
}

v4_evaluate_random_weight_method <- function(
    X, supports, weight_object,
    point_weights, truth,
    method_id = weight_object$metadata$law_id,
    target_id = weight_object$metadata$target_id) {
  point <- v4_ordinal_h_point(X, point_weights, supports)
  draws <- v4_ordinal_h_draws(
    X,
    weight_object$weights,
    supports
  )
  interval <- v4_raw_interval(draws$H, point$H)
  data.frame(
    method_id = method_id,
    target_id = target_id,
    point_estimate = point$H,
    truth = truth,
    bias = point$H - truth,
    lower = interval$lower,
    upper = interval$upper,
    center = interval$center,
    interval_length = interval$length,
    se_equivalent = interval$se_equivalent,
    cover = isTRUE(
      is.finite(interval$lower) &&
        interval$lower <= truth &&
        truth <= interval$upper
    ),
    defined_draws = interval$defined_draws,
    total_draws = interval$total_draws,
    invalid_fraction = interval$invalid_fraction,
    status = interval$status,
    stringsAsFactors = FALSE
  )
}

v4_mokken_twolevel_delta <- function(X, cluster, truth,
                                     level = 0.95) {
  if (!requireNamespace("mokken", quietly = TRUE)) {
    stop("Package 'mokken' is required for the delta comparator.",
         call. = FALSE)
  }
  X_frame <- as.data.frame(X)
  invisible(utils::capture.output(
    fit <- mokken::coefH(
      X_frame,
      se = TRUE,
      ci = FALSE,
      nice.output = FALSE,
      level.two.var = cluster
    )
  ))
  point <- as.numeric(fit$H)
  standard_error <- as.numeric(fit$se.H)
  critical <- stats::qnorm(1 - (1 - level) / 2)
  lower <- point - critical * standard_error
  upper <- point + critical * standard_error
  data.frame(
    method_id = "V4-CMP-MOKKEN-TWOLEVEL-DELTA-v1",
    target_id = "V4-TARGET-RESPONDENT-WEIGHTED-v1",
    point_estimate = point,
    truth = truth,
    bias = point - truth,
    lower = lower,
    upper = upper,
    center = point,
    interval_length = upper - lower,
    se_equivalent = standard_error,
    cover = is.finite(lower) && lower <= truth && truth <= upper,
    defined_draws = NA_integer_,
    total_draws = NA_integer_,
    invalid_fraction = 0,
    status = if (
      is.finite(point) && is.finite(standard_error) && standard_error >= 0
    ) {
      "OK"
    } else {
      "DELTA_UNDEFINED"
    },
    stringsAsFactors = FALSE
  )
}
