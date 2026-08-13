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

# Clustered graded-response DGP and deterministic quadrature truth.

v4_graded_category_probabilities <- function(theta, discrimination,
                                             thresholds) {
  theta <- as.numeric(theta)
  thresholds <- as.numeric(thresholds)
  cumulative <- matrix(
    stats::plogis(
      discrimination * (
        rep(theta, times = length(thresholds)) -
          rep(thresholds, each = length(theta))
      )
    ),
    nrow = length(theta),
    ncol = length(thresholds)
  )
  probabilities <- cbind(
    1 - cumulative[, 1L],
    cumulative[, -ncol(cumulative), drop = FALSE] -
      cumulative[, -1L, drop = FALSE],
    cumulative[, ncol(cumulative)]
  )
  probabilities[probabilities < 0 & probabilities > -1e-14] <- 0
  if (any(probabilities < 0) || any(!is.finite(probabilities))) {
    stop("Invalid graded-response probabilities.", call. = FALSE)
  }
  probabilities / rowSums(probabilities)
}

v4_dgp_item_spec <- function(strength, regularity) {
  discrimination <- switch(
    strength,
    weak = c(0.55, 0.62, 0.68, 0.74, 0.80),
    medium = c(0.95, 1.05, 1.15, 1.25, 1.35),
    strong = c(1.45, 1.60, 1.75, 1.90, 2.05),
    stop("Unknown strength.", call. = FALSE)
  )
  offset <- switch(
    regularity,
    regular = c(-0.45, -0.20, 0.05, 0.30, 0.55),
    near_knot = c(0.00, 0.0002, -0.35, 0.32, 0.65),
    exact_knot = rep(0, 5L),
    stop("Unknown regularity class.", call. = FALSE)
  )
  if (regularity == "near_knot") {
    discrimination[1:2] <- mean(discrimination[1:2])
  }
  if (regularity == "exact_knot") {
    discrimination[] <- mean(discrimination)
  }
  base_thresholds <- c(-1.20, -0.35, 0.40, 1.25)
  thresholds <- t(vapply(
    offset,
    function(value) base_thresholds + value,
    numeric(length(base_thresholds))
  ))
  colnames(thresholds) <- paste0("threshold_", seq_len(ncol(thresholds)))
  rownames(thresholds) <- paste0("Item", seq_len(nrow(thresholds)))
  list(
    strength = strength,
    regularity = regularity,
    discrimination = discrimination,
    thresholds = thresholds,
    supports = rep(list(0:4), 5L)
  )
}

v4_swmdk_size_pool <- function() {
  c(
    15L, 15L, 21L, 29L, 29L, 25L, 20L, 25L, 27L, 28L,
    28L, 23L, 5L, 13L, 19L, 21L, 22L, 15L, 24L, 10L,
    27L, 25L, 23L, 27L, 23L, 27L, 28L, 18L, 8L, 19L
  )
}

v4_cluster_sizes <- function(cluster_effect, mechanism) {
  G <- length(cluster_effect)
  switch(
    mechanism,
    balanced = rep(20L, G),
    swmdk_like = sample(
      v4_swmdk_size_pool(),
      size = G,
      replace = TRUE
    ),
    informative = 5L + as.integer(round(
      24 * stats::plogis(cluster_effect)
    )),
    stop("Unknown cluster-size mechanism.", call. = FALSE)
  )
}

v4_sample_categories <- function(probabilities) {
  cumulative <- t(apply(probabilities, 1L, cumsum))
  uniforms <- stats::runif(nrow(probabilities))
  as.integer(rowSums(uniforms > cumulative))
}

v4_simulate_clustered_ordinal <- function(
    G, latent_icc, size_mechanism,
    strength, regularity, seed) {
  if (
    length(G) != 1L || G < 2L ||
      length(latent_icc) != 1L ||
      latent_icc <= 0 || latent_icc >= 1
  ) {
    stop("Invalid G or latent ICC.", call. = FALSE)
  }
  spec <- v4_dgp_item_spec(strength, regularity)
  v4_with_seed(seed, {
    cluster_effect <- stats::rnorm(G)
    cluster_size <- v4_cluster_sizes(cluster_effect, size_mechanism)
    cluster <- rep(seq_len(G), times = cluster_size)
    individual_effect <- stats::rnorm(length(cluster))
    theta <- sqrt(latent_icc) * cluster_effect[cluster] +
      sqrt(1 - latent_icc) * individual_effect
    X <- matrix(
      0,
      nrow = length(cluster),
      ncol = length(spec$discrimination)
    )
    for (j in seq_len(ncol(X))) {
      probabilities <- v4_graded_category_probabilities(
        theta,
        spec$discrimination[j],
        spec$thresholds[j, ]
      )
      X[, j] <- v4_sample_categories(probabilities)
    }
    colnames(X) <- paste0("Item", seq_len(ncol(X)))
    list(
      X = X,
      cluster = cluster,
      cluster_effect = cluster_effect,
      cluster_size = cluster_size,
      theta = theta,
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

v4_clustered_ordinal_truth <- function(
    latent_icc, size_mechanism,
    strength, regularity,
    target = c("respondent", "cluster"),
    quadrature_nodes = 31L) {
  target <- match.arg(target)
  if (!requireNamespace("statmod", quietly = TRUE)) {
    stop("Package 'statmod' is required for deterministic truth.",
         call. = FALSE)
  }
  spec <- v4_dgp_item_spec(strength, regularity)
  quadrature <- statmod::gauss.quad.prob(
    quadrature_nodes,
    dist = "normal"
  )
  grid <- expand.grid(
    u = quadrature$nodes,
    e = quadrature$nodes,
    KEEP.OUT.ATTRS = FALSE
  )
  grid_weight <- as.vector(outer(
    quadrature$weights,
    quadrature$weights
  ))
  theta <- sqrt(latent_icc) * grid$u +
    sqrt(1 - latent_icc) * grid$e

  size_weight <- if (size_mechanism == "informative") {
    5 + round(24 * stats::plogis(grid$u))
  } else {
    rep(1, nrow(grid))
  }
  if (target == "cluster") {
    size_weight[] <- 1
  }
  integration_weight <- grid_weight * size_weight
  integration_weight <- integration_weight / sum(integration_weight)

  J <- length(spec$discrimination)
  K <- length(spec$supports[[1L]])
  marginal <- vector("list", J)
  conditional_mean <- matrix(0, nrow = nrow(grid), ncol = J)
  for (j in seq_len(J)) {
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
  names(marginal) <- paste0("Item", seq_len(J))
  joint_products <- matrix(NA_real_, nrow = J, ncol = J)
  for (j in seq_len(J)) {
    joint_products[j, j] <- sum(
      integration_weight *
        v4_graded_category_probabilities(
          theta,
          spec$discrimination[j],
          spec$thresholds[j, ]
        ) %*% (spec$supports[[j]]^2)
    )
    if (j < J) {
      for (k in (j + 1L):J) {
        joint_products[j, k] <- sum(
          integration_weight *
            conditional_mean[, j] *
            conditional_mean[, k]
        )
        joint_products[k, j] <- joint_products[j, k]
      }
    }
  }
  h <- v4_h_from_population_moments(
    marginal_probabilities = marginal,
    joint_products = joint_products,
    supports = spec$supports
  )
  knot <- v4_population_knot_diagnostics(marginal)
  list(
    target = target,
    H = h$H,
    numerator = h$numerator,
    denominator = h$denominator,
    minimum_pair_denominator = h$minimum_pair_denominator,
    defined = h$defined,
    marginal_probabilities = marginal,
    joint_products = joint_products,
    knot = knot,
    quadrature_nodes = quadrature_nodes
  )
}
