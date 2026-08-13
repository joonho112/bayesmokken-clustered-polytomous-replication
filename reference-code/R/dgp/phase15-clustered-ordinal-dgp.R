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

# Clustered ordinal DGP with disjoint Phase 15 and Phase 16 profiles.

v4_phase15_threshold_profiles <- function() {
  list(
    standard = c(-1.20, -0.35, 0.40, 1.25),
    rare_high = c(-1.80, -0.80, 0.30, 2.10),
    rare_low = c(-2.10, -0.30, 0.80, 1.80),
    standard_shifted = c(-1.10, -0.20, 0.55, 1.40),
    rare_high_shifted = c(-1.70, -0.65, 0.45, 2.25),
    rare_low_shifted = c(-2.25, -0.45, 0.65, 1.70),
    standard_confirm = c(-1.05, -0.28, 0.48, 1.33),
    rare_high_confirm = c(-1.65, -0.72, 0.37, 2.18),
    rare_low_confirm = c(-2.18, -0.38, 0.72, 1.76)
  )
}

v4_phase15_item_spec <- function(discrimination_center,
                                 regularity,
                                 threshold_profile,
                                 stage = c(
                                   "training", "validation",
                                   "confirmation"
                                 )) {
  stage <- match.arg(stage)
  profiles <- v4_phase15_threshold_profiles()
  if (!threshold_profile %in% names(profiles)) {
    stop("Unknown Phase 15 threshold profile.", call. = FALSE)
  }
  multiplier <- c(0.85, 0.925, 1.0, 1.075, 1.15)
  discrimination <- discrimination_center * multiplier
  offset <- switch(
    regularity,
    regular = c(-0.45, -0.20, 0.05, 0.30, 0.55),
    near_knot = switch(
      stage,
      training = c(0.0, 0.0002, -0.35, 0.32, 0.65),
      validation = c(0.0, 0.00035, -0.28, 0.38, 0.72),
      confirmation = c(0.0, 0.0005, -0.31, 0.41, 0.76)
    ),
    exact_knot = rep(0, 5L),
    stop("Unknown regularity class.", call. = FALSE)
  )
  if (regularity == "near_knot") {
    discrimination[1:2] <- mean(discrimination[1:2])
  }
  if (regularity == "exact_knot") {
    discrimination[] <- discrimination_center
  }
  thresholds <- t(vapply(
    offset,
    function(value) profiles[[threshold_profile]] + value,
    numeric(4)
  ))
  rownames(thresholds) <- paste0("Item", seq_len(5L))
  colnames(thresholds) <- paste0("threshold_", seq_len(4L))
  list(
    discrimination = discrimination,
    thresholds = thresholds,
    supports = rep(list(0:4), 5L),
    regularity = regularity,
    threshold_profile = threshold_profile,
    stage = stage
  )
}

v4_phase15_cluster_sizes <- function(cluster_effect,
                                     mechanism,
                                     informative_slope) {
  G <- length(cluster_effect)
  switch(
    mechanism,
    balanced = rep(20L, G),
    swmdk_like = sample(
      v4_swmdk_size_pool(), G, replace = TRUE
    ),
    informative_positive = 5L + as.integer(round(
      24 * stats::plogis(informative_slope * cluster_effect)
    )),
    informative_negative = 5L + as.integer(round(
      24 * stats::plogis(-informative_slope * cluster_effect)
    )),
    stop("Unknown Phase 15 cluster-size mechanism.", call. = FALSE)
  )
}

v4_phase15_simulate <- function(cell, stage, seed) {
  spec <- v4_phase15_item_spec(
    cell$discrimination_center,
    cell$regularity,
    cell$threshold_profile,
    stage
  )
  v4_with_seed(seed, {
    cluster_effect <- stats::rnorm(cell$G)
    cluster_size <- v4_phase15_cluster_sizes(
      cluster_effect,
      cell$size_mechanism,
      cell$informative_slope
    )
    cluster <- rep(seq_len(cell$G), times = cluster_size)
    individual_effect <- stats::rnorm(length(cluster))
    theta <- sqrt(cell$latent_icc) * cluster_effect[cluster] +
      sqrt(1 - cell$latent_icc) * individual_effect
    X <- matrix(0, nrow = length(cluster), ncol = 5L)
    for (j in seq_len(5L)) {
      probabilities <- v4_graded_category_probabilities(
        theta,
        spec$discrimination[j],
        spec$thresholds[j, ]
      )
      X[, j] <- v4_sample_categories(probabilities)
    }
    colnames(X) <- paste0("Item", seq_len(5L))
    list(
      X = X,
      cluster = cluster,
      cluster_effect = cluster_effect,
      cluster_size = cluster_size,
      supports = spec$supports,
      specification = spec,
      size_effect_correlation = if (stats::sd(cluster_size) > 0) {
        stats::cor(cluster_effect, cluster_size)
      } else {
        0
      }
    )
  })
}

v4_phase15_truth <- function(cell, stage,
                             target = c("respondent", "cluster"),
                             quadrature_nodes = 41L) {
  target <- match.arg(target)
  if (!requireNamespace("statmod", quietly = TRUE)) {
    stop("Package 'statmod' is required.", call. = FALSE)
  }
  spec <- v4_phase15_item_spec(
    cell$discrimination_center,
    cell$regularity,
    cell$threshold_profile,
    stage
  )
  quadrature <- statmod::gauss.quad.prob(
    quadrature_nodes, dist = "normal"
  )
  grid <- expand.grid(
    u = quadrature$nodes,
    e = quadrature$nodes,
    KEEP.OUT.ATTRS = FALSE
  )
  integration_weight <- as.vector(outer(
    quadrature$weights,
    quadrature$weights
  ))
  size_weight <- switch(
    cell$size_mechanism,
    informative_positive =
      5 + round(24 * stats::plogis(
        cell$informative_slope * grid$u
      )),
    informative_negative =
      5 + round(24 * stats::plogis(
        -cell$informative_slope * grid$u
      )),
    rep(1, nrow(grid))
  )
  if (target == "cluster") size_weight[] <- 1
  integration_weight <- integration_weight * size_weight
  integration_weight <- integration_weight / sum(integration_weight)
  theta <- sqrt(cell$latent_icc) * grid$u +
    sqrt(1 - cell$latent_icc) * grid$e

  marginal <- vector("list", 5L)
  conditional_mean <- matrix(0, nrow = nrow(grid), ncol = 5L)
  for (j in seq_len(5L)) {
    probability <- v4_graded_category_probabilities(
      theta,
      spec$discrimination[j],
      spec$thresholds[j, ]
    )
    marginal[[j]] <- colSums(integration_weight * probability)
    conditional_mean[, j] <- as.numeric(
      probability %*% spec$supports[[j]]
    )
  }
  names(marginal) <- paste0("Item", seq_len(5L))
  joint <- matrix(NA_real_, nrow = 5L, ncol = 5L)
  for (j in seq_len(5L)) {
    joint[j, j] <- NA_real_
    if (j < 5L) {
      for (k in (j + 1L):5L) {
        joint[j, k] <- sum(
          integration_weight *
            conditional_mean[, j] *
            conditional_mean[, k]
        )
        joint[k, j] <- joint[j, k]
      }
    }
  }
  h <- v4_h_from_population_moments(
    marginal, joint, spec$supports
  )
  knot <- v4_population_knot_diagnostics(marginal)
  list(
    target = target,
    H = h$H,
    numerator = h$numerator,
    denominator = h$denominator,
    minimum_pair_denominator = h$minimum_pair_denominator,
    marginal_probabilities = marginal,
    knot = knot,
    quadrature_nodes = quadrature_nodes
  )
}
