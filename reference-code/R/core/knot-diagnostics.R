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

# Weighted marginal cumulative-mass diagnostics for transport path stability.

v4_knot_diagnostics <- function(X, weights = NULL, supports = NULL,
                                exact_tol = 1e-12,
                                near_tol = 1e-4) {
  validated <- v4_validate_ordinal_data(X, supports)
  X <- validated$X
  supports <- validated$supports
  if (is.null(weights)) {
    weights <- rep(1 / nrow(X), nrow(X))
  }
  weights <- as.numeric(v4_normalize_weights(weights, nrow(X)))
  J <- ncol(X)
  cdfs <- lapply(seq_len(J), function(j) {
    vapply(
      supports[[j]][-length(supports[[j]])],
      function(score) sum(weights[X[, j] <= score]),
      numeric(1)
    )
  })
  rows <- list()
  index <- 0L
  for (j in seq_len(J - 1L)) {
    for (k in (j + 1L):J) {
      gap <- abs(outer(cdfs[[j]], cdfs[[k]], "-"))
      index <- index + 1L
      rows[[index]] <- data.frame(
        item_j = colnames(X)[j],
        item_k = colnames(X)[k],
        minimum_internal_cdf_gap = min(gap),
        exact_knot_count = sum(gap <= exact_tol),
        near_knot_count = sum(gap <= near_tol),
        stringsAsFactors = FALSE
      )
    }
  }
  pair <- do.call(rbind, rows)
  list(
    pair = pair,
    minimum_internal_cdf_gap = min(pair$minimum_internal_cdf_gap),
    exact_knot_count = sum(pair$exact_knot_count),
    near_knot_count = sum(pair$near_knot_count)
  )
}

v4_population_knot_diagnostics <- function(marginal_probabilities,
                                           exact_tol = 1e-12,
                                           near_tol = 1e-4) {
  cdfs <- lapply(
    marginal_probabilities,
    function(mass) cumsum(mass)[-length(mass)]
  )
  J <- length(cdfs)
  minimum_gap <- Inf
  exact_count <- 0L
  near_count <- 0L
  for (j in seq_len(J - 1L)) {
    for (k in (j + 1L):J) {
      gap <- abs(outer(cdfs[[j]], cdfs[[k]], "-"))
      minimum_gap <- min(minimum_gap, gap)
      exact_count <- exact_count + sum(gap <= exact_tol)
      near_count <- near_count + sum(gap <= near_tol)
    }
  }
  list(
    minimum_internal_cdf_gap = minimum_gap,
    exact_knot_count = exact_count,
    near_knot_count = near_count
  )
}

