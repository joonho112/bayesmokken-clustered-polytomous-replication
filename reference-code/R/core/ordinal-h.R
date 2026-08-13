# +===========================================================================+
# | KNOWN ARCHIVAL DEFECT -- DO NOT PORT THIS FILE.                           |
# |                                                                           |
# | The deterministic per-pair transport helper below advances its pointers   |
# | on a 1e-12 mass tolerance and can drop a valid tiny POSITIVE mass. The     |
# | corrected implementation -- exact-zero advancement plus a mass-            |
# | conservation assertion -- is the package kernel, in bayesmokken's          |
# | R/ordinal-transport.R.                                                     |
# |                                                                           |
# | WHY NO LOCKED RESULT IS AFFECTED, AND HOW THIS PACKAGE CHECKS IT.          |
# |                                                                           |
# | The helper compares the CURRENT RESIDUAL ATOM MASS, before and after each  |
# | allocation. That residual can be an original marginal category mass or a  |
# | cross-CDF residual. The exact risk set is therefore inclusive:             |
# |                                                                           |
# |                         0 < residual <= 1e-12.                              |
# |                                                                           |
# | verification/archival/verify_archival_safety.R reconstructs all 168        |
# | population-truth helper executions (Phase 14; Phase 15 training and        |
# | validation; Phase 16), runs both historical and corrected transports, and  |
# | checks conservation directly. Across those locked configurations:          |
# |                                                                           |
# |     risk residuals in (0, 1e-12] ........ 0                                |
# |     minimum positive marginal mass ...... 0.0155404871882598                |
# |     minimum positive cross-CDF gap ....... 0.0000193915947650503             |
# |     maximum |old H - corrected H| ........ 0                                |
# |                                                                           |
# | Literal zero is safe: both versions advance, and simultaneous exhaustion   |
# | advances both pointers. The Phase 16 summary's eight rows with scalar       |
# | minimum zero are exact-knot diagnostics, not a count of literal zero gaps.  |
# | Per-replication point/draw calculations use the survival/pmin kernel below  |
# | and do not call this helper; the direct certificate covers every path that  |
# | actually did call it for a locked result.                                   |
# |                                                                           |
# | The file is preserved UNCHANGED as the frozen historical implementation.   |
# | A replication package that quietly fixes the code it exists to document    |
# | stops documenting anything. Any future work must use or port from the      |
# | corrected package kernel, never this copy.                                 |
# +===========================================================================+

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

# Research-only weighted polytomous Mokken H engine for Paper A v4.
#
# Provenance:
# - the vectorized survival-mass representation is explicitly ported from
#   codebase/research/v3/ordinal-extension-feasibility/R/
#   ordinal-h-feasibility.R;
# - the finite-support transport implementation follows the independently
#   checked Phase 8 two-pointer specification;
# - this file is not part of the bayesmokken package.

v4_normalize_weights <- function(W, n) {
  if (is.null(dim(W))) {
    W <- matrix(as.numeric(W), ncol = 1L)
  }
  if (!is.matrix(W) || nrow(W) != n) {
    stop("W must be an n by B numeric matrix.", call. = FALSE)
  }
  storage.mode(W) <- "double"
  if (any(!is.finite(W)) || any(W < 0)) {
    stop("Weights must be finite and nonnegative.", call. = FALSE)
  }
  totals <- colSums(W)
  if (any(!is.finite(totals)) || any(totals <= 0)) {
    stop("Every weight draw must have positive total mass.", call. = FALSE)
  }
  sweep(W, 2L, totals, "/")
}

v4_validate_ordinal_data <- function(X, supports = NULL) {
  X <- as.matrix(X)
  storage.mode(X) <- "double"
  if (nrow(X) < 2L || ncol(X) < 2L || any(!is.finite(X))) {
    stop(
      "X must contain at least two complete rows, two items, and finite scores.",
      call. = FALSE
    )
  }
  if (is.null(colnames(X))) {
    colnames(X) <- paste0("Item", seq_len(ncol(X)))
  }
  if (anyDuplicated(colnames(X))) {
    stop("Item names must be unique.", call. = FALSE)
  }
  if (is.null(supports)) {
    supports <- lapply(
      seq_len(ncol(X)),
      function(j) sort(unique(X[, j]))
    )
  }
  if (length(supports) != ncol(X)) {
    stop("One declared score support is required per item.", call. = FALSE)
  }
  supports <- lapply(seq_along(supports), function(j) {
    support <- as.numeric(supports[[j]])
    if (
      length(support) < 2L ||
      any(!is.finite(support)) ||
      any(diff(support) <= 0) ||
      any(!X[, j] %in% support)
    ) {
      stop(
        "Each support must be finite, strictly increasing, and contain data.",
        call. = FALSE
      )
    }
    support
  })
  names(supports) <- colnames(X)
  list(X = X, supports = supports)
}

v4_max_covariance_transport <- function(x_scores, x_mass,
                                        y_scores, y_mass,
                                        mass_tol = 1e-12) {
  x_scores <- as.numeric(x_scores)
  y_scores <- as.numeric(y_scores)
  x_mass <- as.numeric(x_mass)
  y_mass <- as.numeric(y_mass)
  valid <- (
    length(x_scores) == length(x_mass) &&
      length(y_scores) == length(y_mass) &&
      length(x_scores) >= 2L &&
      length(y_scores) >= 2L &&
      all(is.finite(c(x_scores, y_scores, x_mass, y_mass))) &&
      all(diff(x_scores) > 0) &&
      all(diff(y_scores) > 0) &&
      all(x_mass >= 0) &&
      all(y_mass >= 0) &&
      abs(sum(x_mass) - 1) <= mass_tol &&
      abs(sum(y_mass) - 1) <= mass_tol
  )
  if (!valid) {
    stop("Invalid finite-support transport input.", call. = FALSE)
  }
  x_mass <- x_mass / sum(x_mass)
  y_mass <- y_mass / sum(y_mass)
  remaining_x <- x_mass
  remaining_y <- y_mass
  i <- 1L
  j <- 1L
  maximum_product <- 0
  while (i <= length(x_scores) && j <= length(y_scores)) {
    if (remaining_x[i] <= mass_tol) {
      i <- i + 1L
      next
    }
    if (remaining_y[j] <= mass_tol) {
      j <- j + 1L
      next
    }
    moved <- min(remaining_x[i], remaining_y[j])
    maximum_product <- maximum_product +
      moved * x_scores[i] * y_scores[j]
    remaining_x[i] <- remaining_x[i] - moved
    remaining_y[j] <- remaining_y[j] - moved
    if (remaining_x[i] <= mass_tol) i <- i + 1L
    if (remaining_y[j] <= mass_tol) j <- j + 1L
  }
  mu_x <- sum(x_scores * x_mass)
  mu_y <- sum(y_scores * y_mass)
  list(
    maximum_product = maximum_product,
    maximum_covariance = maximum_product - mu_x * mu_y,
    mean_x = mu_x,
    mean_y = mu_y
  )
}

v4_ordinal_h_draws <- function(X, W, supports = NULL,
                               zero_tol = 1e-12) {
  validated <- v4_validate_ordinal_data(X, supports)
  X <- validated$X
  supports <- validated$supports
  W <- v4_normalize_weights(W, nrow(X))
  J <- ncol(X)
  B <- ncol(W)
  means <- crossprod(X, W)
  survival <- vector("list", J)

  for (j in seq_len(J)) {
    thresholds <- supports[[j]][-1L]
    indicators <- vapply(
      thresholds,
      function(threshold) as.numeric(X[, j] >= threshold),
      numeric(nrow(X))
    )
    if (is.null(dim(indicators))) {
      indicators <- matrix(indicators, ncol = 1L)
    }
    survival[[j]] <- crossprod(indicators, W)
  }

  numerator <- numeric(B)
  denominator <- numeric(B)
  minimum_pair_denominator <- rep(Inf, B)

  for (j in seq_len(J - 1L)) {
    for (k in (j + 1L):J) {
      observed_product <- as.numeric(
        crossprod(X[, j] * X[, k], W)
      )
      observed_covariance <- observed_product -
        means[j, ] * means[k, ]

      gaps_j <- diff(supports[[j]])
      gaps_k <- diff(supports[[k]])
      maximum_product_shifted <- numeric(B)
      for (a in seq_along(gaps_j)) {
        for (b in seq_along(gaps_k)) {
          maximum_product_shifted <- maximum_product_shifted +
            gaps_j[a] * gaps_k[b] *
            pmin(survival[[j]][a, ], survival[[k]][b, ])
        }
      }
      shifted_mean_j <- means[j, ] - min(supports[[j]])
      shifted_mean_k <- means[k, ] - min(supports[[k]])
      maximum_covariance <- maximum_product_shifted -
        shifted_mean_j * shifted_mean_k

      numerator <- numerator + observed_covariance
      denominator <- denominator + maximum_covariance
      minimum_pair_denominator <- pmin(
        minimum_pair_denominator,
        maximum_covariance
      )
    }
  }

  H <- numerator / denominator
  defined <- (
    is.finite(H) &
      is.finite(denominator) &
      denominator > zero_tol &
      minimum_pair_denominator > zero_tol
  )
  H[!defined] <- NA_real_

  data.frame(
    H = H,
    numerator = numerator,
    denominator = denominator,
    minimum_pair_denominator = minimum_pair_denominator,
    defined = defined,
    stringsAsFactors = FALSE
  )
}

v4_ordinal_h_point <- function(X, weights = NULL, supports = NULL,
                               zero_tol = 1e-12) {
  X <- as.matrix(X)
  if (is.null(weights)) {
    weights <- rep(1 / nrow(X), nrow(X))
  }
  v4_ordinal_h_draws(
    X = X,
    W = weights,
    supports = supports,
    zero_tol = zero_tol
  )[1L, ]
}

v4_h_from_population_moments <- function(
    marginal_probabilities,
    joint_products,
    supports,
    zero_tol = 1e-12) {
  J <- length(marginal_probabilities)
  if (
    J < 2L ||
      length(supports) != J ||
      !is.matrix(joint_products) ||
      any(dim(joint_products) != c(J, J))
  ) {
    stop("Invalid population moment object.", call. = FALSE)
  }
  means <- numeric(J)
  for (j in seq_len(J)) {
    mass <- as.numeric(marginal_probabilities[[j]])
    support <- as.numeric(supports[[j]])
    if (
      length(mass) != length(support) ||
      any(mass < 0) ||
      abs(sum(mass) - 1) > 1e-10
    ) {
      stop("Invalid population marginal mass.", call. = FALSE)
    }
    means[j] <- sum(mass * support)
  }

  numerator <- 0
  denominator <- 0
  minimum_pair_denominator <- Inf
  for (j in seq_len(J - 1L)) {
    for (k in (j + 1L):J) {
      covariance <- joint_products[j, k] - means[j] * means[k]
      maximum_covariance <- v4_max_covariance_transport(
        supports[[j]], marginal_probabilities[[j]],
        supports[[k]], marginal_probabilities[[k]]
      )$maximum_covariance
      numerator <- numerator + covariance
      denominator <- denominator + maximum_covariance
      minimum_pair_denominator <- min(
        minimum_pair_denominator,
        maximum_covariance
      )
    }
  }
  H <- numerator / denominator
  defined <- (
    is.finite(H) &&
      denominator > zero_tol &&
      minimum_pair_denominator > zero_tol
  )
  list(
    H = if (defined) H else NA_real_,
    numerator = numerator,
    denominator = denominator,
    minimum_pair_denominator = minimum_pair_denominator,
    defined = defined,
    means = means
  )
}
