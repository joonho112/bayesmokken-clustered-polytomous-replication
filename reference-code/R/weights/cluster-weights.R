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

# Research-only random-weight laws for clustered ordinal data.

v4_validate_cluster <- function(cluster) {
  if (length(cluster) < 2L || anyNA(cluster)) {
    stop("cluster must be complete and contain at least two rows.",
         call. = FALSE)
  }
  label <- as.character(cluster)
  levels <- unique(label)
  index <- match(label, levels)
  sizes <- tabulate(index, nbins = length(levels))
  if (length(levels) < 2L || any(sizes < 1L)) {
    stop("At least two nonempty clusters are required.", call. = FALSE)
  }
  list(
    label = label,
    levels = levels,
    index = index,
    sizes = sizes,
    G = length(levels),
    N = length(label)
  )
}

v4_with_seed <- function(seed, code) {
  seed <- as.integer(seed)
  if (length(seed) != 1L || is.na(seed) || seed < 0L) {
    stop("seed must be one nonnegative integer.", call. = FALSE)
  }
  old_kind <- RNGkind()
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) old_seed <- get(".Random.seed", envir = .GlobalEnv)
  on.exit({
    do.call(RNGkind, as.list(old_kind))
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)
  RNGkind("L'Ecuyer-CMRG")
  set.seed(seed)
  force(code)
}

v4_dirichlet_matrix <- function(k, draws) {
  out <- matrix(stats::rexp(k * draws), nrow = k, ncol = draws)
  sweep(out, 2L, colSums(out), "/")
}

v4_cluster_hash <- function(cluster_info) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("Package 'digest' is required for weight metadata.",
         call. = FALSE)
  }
  digest::digest(
    list(
      labels = cluster_info$levels,
      index = cluster_info$index,
      sizes = cluster_info$sizes
    ),
    algo = "sha256",
    serialize = TRUE
  )
}

v4_weight_object <- function(weights, law_id, target_id, cluster_info,
                             normalization_formula, seed,
                             replication_id = NA_character_,
                             unseen_pattern_mass_allowed = FALSE) {
  weights <- v4_normalize_weights(weights, cluster_info$N)
  structure(
    list(
      weights = weights,
      metadata = list(
        law_id = law_id,
        target_id = target_id,
        row_grain = "respondent",
        cluster_id_hash = v4_cluster_hash(cluster_info),
        cluster_sizes = as.integer(cluster_info$sizes),
        normalization_formula = normalization_formula,
        rng_kind = "L'Ecuyer-CMRG",
        seed = as.integer(seed),
        replication_id = as.character(replication_id),
        draw_ids = seq_len(ncol(weights)),
        unseen_pattern_mass_allowed =
          isTRUE(unseen_pattern_mass_allowed)
      )
    ),
    class = "v4_cluster_weight_draws"
  )
}

v4_point_weights <- function(cluster, target = c("respondent", "cluster")) {
  target <- match.arg(target)
  info <- v4_validate_cluster(cluster)
  if (target == "respondent") {
    rep(1 / info$N, info$N)
  } else {
    1 / (info$G * info$sizes[info$index])
  }
}

v4_iid_bb_weights <- function(cluster, draws, seed,
                              replication_id = NA_character_) {
  info <- v4_validate_cluster(cluster)
  weights <- v4_with_seed(seed, v4_dirichlet_matrix(info$N, draws))
  v4_weight_object(
    weights = weights,
    law_id = "V4-CMP-IID-RESP-BB-v1",
    target_id = "WORKING-INDEPENDENCE-RESPONDENT",
    cluster_info = info,
    normalization_formula = "W_i = E_i / sum_r E_r",
    seed = seed,
    replication_id = replication_id
  )
}

v4_one_stage_cluster_bb_weights <- function(
    cluster, draws, seed,
    target = c("respondent", "cluster"),
    replication_id = NA_character_) {
  target <- match.arg(target)
  info <- v4_validate_cluster(cluster)
  weights <- v4_with_seed(seed, {
    A <- v4_dirichlet_matrix(info$G, draws)
    if (target == "respondent") {
      denominator <- colSums(info$sizes * A)
      out <- A[info$index, , drop = FALSE]
      sweep(out, 2L, denominator, "/")
    } else {
      out <- A[info$index, , drop = FALSE]
      out / info$sizes[info$index]
    }
  })
  v4_weight_object(
    weights = weights,
    law_id = if (target == "respondent") {
      "V4-CMP-ONE-STAGE-CLUSTER-BB-RESP-v1"
    } else {
      "V4-CMP-ONE-STAGE-CLUSTER-BB-CLUSTER-v1"
    },
    target_id = if (target == "respondent") {
      "V4-TARGET-RESPONDENT-WEIGHTED-v1"
    } else {
      "V4-TARGET-EQUAL-CLUSTER-v1"
    },
    cluster_info = info,
    normalization_formula = if (target == "respondent") {
      "W_gi = A_g / sum_h m_h A_h"
    } else {
      "W_gi = A_g / m_g"
    },
    seed = seed,
    replication_id = replication_id
  )
}

v4_two_stage_hbb_weights <- function(
    cluster, draws, seed,
    target = c("respondent", "cluster"),
    replication_id = NA_character_) {
  target <- match.arg(target)
  info <- v4_validate_cluster(cluster)
  weights <- v4_with_seed(seed, {
    A <- v4_dirichlet_matrix(info$G, draws)
    out <- matrix(0, nrow = info$N, ncol = draws)
    denominator <- if (target == "respondent") {
      colSums(info$sizes * A)
    } else {
      rep(1, draws)
    }
    for (g in seq_len(info$G)) {
      rows <- which(info$index == g)
      B_g <- v4_dirichlet_matrix(length(rows), draws)
      if (target == "respondent") {
        out[rows, ] <- sweep(
          B_g,
          2L,
          info$sizes[g] * A[g, ] / denominator,
          "*"
        )
      } else {
        out[rows, ] <- sweep(B_g, 2L, A[g, ], "*")
      }
    }
    out
  })
  v4_weight_object(
    weights = weights,
    law_id = if (target == "respondent") {
      "V4-PRI-TWO-STAGE-HBB-RESP-v1"
    } else {
      "V4-SENS-TWO-STAGE-HBB-CLUSTER-v1"
    },
    target_id = if (target == "respondent") {
      "V4-TARGET-RESPONDENT-WEIGHTED-v1"
    } else {
      "V4-TARGET-EQUAL-CLUSTER-v1"
    },
    cluster_info = info,
    normalization_formula = if (target == "respondent") {
      "W_gi = m_g A_g B_gi / sum_h m_h A_h"
    } else {
      "W_gi = A_g B_gi"
    },
    seed = seed,
    replication_id = replication_id
  )
}

v4_two_stage_frequentist_weights <- function(
    cluster, draws, seed,
    target = c("respondent", "cluster"),
    replication_id = NA_character_) {
  target <- match.arg(target)
  info <- v4_validate_cluster(cluster)
  weights <- v4_with_seed(seed, {
    out <- matrix(0, nrow = info$N, ncol = draws)
    rows_by_cluster <- lapply(
      seq_len(info$G),
      function(g) which(info$index == g)
    )
    for (b in seq_len(draws)) {
      selected <- sample.int(info$G, size = info$G, replace = TRUE)
      draw_weight <- numeric(info$N)
      for (g in selected) {
        rows <- rows_by_cluster[[g]]
        sampled <- sample(rows, size = length(rows), replace = TRUE)
        counts <- tabulate(match(sampled, rows), nbins = length(rows))
        if (target == "respondent") {
          draw_weight[rows] <- draw_weight[rows] + counts
        } else {
          draw_weight[rows] <- draw_weight[rows] +
            counts / (info$G * length(rows))
        }
      }
      if (target == "respondent") {
        draw_weight <- draw_weight / sum(draw_weight)
      }
      out[, b] <- draw_weight
    }
    out
  })
  v4_weight_object(
    weights = weights,
    law_id = if (target == "respondent") {
      "V4-CMP-TWO-STAGE-FREQ-BOOT-RESP-v1"
    } else {
      "V4-CMP-TWO-STAGE-FREQ-BOOT-CLUSTER-v1"
    },
    target_id = if (target == "respondent") {
      "V4-TARGET-RESPONDENT-WEIGHTED-v1"
    } else {
      "V4-TARGET-EQUAL-CLUSTER-v1"
    },
    cluster_info = info,
    normalization_formula = if (target == "respondent") {
      "normalize respondent counts after cluster and within-cluster resampling"
    } else {
      "each selected cluster occurrence has mass 1/G"
    },
    seed = seed,
    replication_id = replication_id
  )
}

v4_within_stage_hbb_weights <- function(
    cluster, draws, seed,
    target = c("respondent", "cluster"),
    replication_id = NA_character_) {
  target <- match.arg(target)
  info <- v4_validate_cluster(cluster)
  weights <- v4_with_seed(seed, {
    out <- matrix(0, nrow = info$N, ncol = draws)
    for (g in seq_len(info$G)) {
      rows <- which(info$index == g)
      B_g <- v4_dirichlet_matrix(length(rows), draws)
      if (target == "respondent") {
        out[rows, ] <- B_g * info$sizes[g] / info$N
      } else {
        out[rows, ] <- B_g / info$G
      }
    }
    out
  })
  v4_weight_object(
    weights = weights,
    law_id = if (target == "respondent") {
      "V4-DIAG-WITHIN-STAGE-HBB-RESP-v1"
    } else {
      "V4-DIAG-WITHIN-STAGE-HBB-CLUSTER-v1"
    },
    target_id = if (target == "respondent") {
      "V4-TARGET-RESPONDENT-WEIGHTED-v1"
    } else {
      "V4-TARGET-EQUAL-CLUSTER-v1"
    },
    cluster_info = info,
    normalization_formula = if (target == "respondent") {
      "W_gi = m_g B_gi / N with fixed cluster totals"
    } else {
      "W_gi = B_gi / G with fixed equal cluster totals"
    },
    seed = seed,
    replication_id = replication_id
  )
}
