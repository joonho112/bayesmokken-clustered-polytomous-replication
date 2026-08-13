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

project_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
v4_root <- file.path(
  project_root,
  "codebase", "research", "v4", "cluster-polytomous"
)
r_root <- file.path(v4_root, "R")
artifact_root <- file.path(v4_root, "tests", "artifacts")
dir.create(artifact_root, recursive = TRUE, showWarnings = FALSE)

source(file.path(r_root, "core", "ordinal-h.R"))
source(file.path(r_root, "core", "knot-diagnostics.R"))
source(file.path(r_root, "weights", "cluster-weights.R"))
source(file.path(r_root, "dgp", "clustered-ordinal-dgp.R"))
source(file.path(r_root, "evaluation", "intervals-and-comparators.R"))
source(file.path(
  project_root,
  "codebase", "oracles", "transport-lp", "two-pointer-reference.R"
))
source(file.path(
  project_root,
  "codebase", "oracles", "transport-lp", "solve-transport-lp.R"
))
source(file.path(
  project_root,
  "codebase", "research", "v3", "ordinal-extension-feasibility",
  "R", "ordinal-h-feasibility.R"
))

results <- list()
record_check <- function(check_id, description, expression) {
  started <- proc.time()[["elapsed"]]
  error_message <- ""
  observed <- ""
  pass <- tryCatch({
    value <- force(expression)
    if (is.list(value) && !is.null(value$pass)) {
      observed <- as.character(value$observed)
      isTRUE(value$pass)
    } else {
      observed <- paste(as.character(value), collapse = "|")
      isTRUE(value)
    }
  }, error = function(error) {
    error_message <<- conditionMessage(error)
    FALSE
  })
  results[[length(results) + 1L]] <<- data.frame(
    check_id = check_id,
    description = description,
    observed = observed,
    pass = pass,
    error = error_message,
    elapsed_seconds = proc.time()[["elapsed"]] - started,
    stringsAsFactors = FALSE
  )
  invisible(pass)
}

protocol_receipt <- jsonlite::read_json(
  file.path(
    v4_root, "protocol", "v4-phase14-protocol-lock-receipt-v1.json"
  ),
  simplifyVector = TRUE
)
record_check(
  "T001_PROTOCOL_LOCK",
  "Phase 14 protocol was frozen before outcomes",
  identical(protocol_receipt$status, "PASS_FROZEN_PRE_OUTCOME")
)
record_check(
  "T002_PHASE15_BLOCKED",
  "Phase 15 remains unauthorized",
  isFALSE(protocol_receipt$phase15_authorized)
)

X_fixture <- matrix(
  c(
    0, 0, 1,
    0, 1, 1,
    1, 1, 2,
    1, 2, 2,
    2, 2, 3,
    3, 3, 3,
    0, 1, 2,
    2, 3, 3
  ),
  ncol = 3L,
  byrow = TRUE
)
colnames(X_fixture) <- c("A", "B", "C")
fixture_supports <- rep(list(0:3), 3L)
phase13_fixture <- phase13_ordinal_h_point(
  X_fixture,
  supports = fixture_supports
)
v4_fixture <- v4_ordinal_h_point(
  X_fixture,
  supports = fixture_supports
)
record_check(
  "T003_PHASE13_POINT_CONCORDANCE",
  "v4 point H matches the Phase 13 reference",
  list(
    pass = abs(v4_fixture$H - phase13_fixture$H) < 1e-12,
    observed = abs(v4_fixture$H - phase13_fixture$H)
  )
)

data("SWMDK", package = "mokken")
swmdk_scales <- list(
  teacher = paste0("Item", 1:6),
  classmate = c(paste0("Item", 8:11), "Item13")
)
swmdk_differences <- vapply(swmdk_scales, function(items) {
  X <- as.matrix(SWMDK[, items])
  v4_H <- v4_ordinal_h_point(X)$H
  invisible(utils::capture.output(
    fit <- mokken::coefH(X, se = FALSE, nice.output = FALSE)
  ))
  abs(v4_H - as.numeric(fit$H))
}, numeric(1))
record_check(
  "T004_SWMDK_MOKKEN_CONCORDANCE",
  "v4 fixed-scale H matches mokken::coefH on both fixed SWMDK scales",
  list(
    pass = max(swmdk_differences) < 1e-10,
    observed = max(swmdk_differences)
  )
)

transport_cases <- list(
  list(x = c(0, 1), px = c(.25, .75),
       y = c(0, 1), py = c(.5, .5)),
  list(x = c(0, 1, 3), px = c(.25, .5, .25),
       y = c(0, 2, 3), py = c(.5, .25, .25)),
  list(x = c(-1, 0, 2, 4), px = c(.1, .2, .3, .4),
       y = c(0, 3, 5), py = c(.4, .35, .25))
)
transport_discrepancy <- vapply(transport_cases, function(case) {
  internal <- v4_max_covariance_transport(
    case$x, case$px, case$y, case$py
  )
  reference <- transport_two_pointer(
    case$x, case$px, case$y, case$py
  )
  lp <- transport_lp_oracle(
    case$x, case$px, case$y, case$py
  )
  max(abs(c(
    internal$maximum_covariance - reference$maximum_covariance,
    internal$maximum_covariance - lp$maximum_covariance
  )))
}, numeric(1))
record_check(
  "T005_TRANSPORT_ORACLE_CONCORDANCE",
  "internal transport agrees with independent two-pointer and LP oracles",
  list(
    pass = max(transport_discrepancy) < 1e-10,
    observed = max(transport_discrepancy)
  )
)
record_check(
  "T006_SCORE_GAP_PRESERVED",
  "declared score gaps reproduce the frozen counterexample value",
  list(
    pass = abs(
      v4_max_covariance_transport(
        c(0, 1, 3), c(.25, .5, .25),
        c(0, 2, 3), c(.25, .5, .25)
      )$maximum_covariance - 1.0625
    ) < 1e-12,
    observed = v4_max_covariance_transport(
      c(0, 1, 3), c(.25, .5, .25),
      c(0, 2, 3), c(.25, .5, .25)
    )$maximum_covariance
  )
)

cluster <- rep(c("c1", "c2", "c3"), c(2, 3, 5))
weight_objects <- list(
  iid = v4_iid_bb_weights(cluster, 50, 101),
  one_stage = v4_one_stage_cluster_bb_weights(
    cluster, 50, 102, "respondent"
  ),
  hbb_respondent = v4_two_stage_hbb_weights(
    cluster, 50, 103, "respondent"
  ),
  hbb_cluster = v4_two_stage_hbb_weights(
    cluster, 50, 104, "cluster"
  ),
  frequentist = v4_two_stage_frequentist_weights(
    cluster, 50, 105, "respondent"
  )
)
for (name in names(weight_objects)) {
  object <- weight_objects[[name]]
  record_check(
    paste0("T_WNORM_", toupper(name)),
    paste("draw normalization and nonnegativity:", name),
    list(
      pass = (
        max(abs(colSums(object$weights) - 1)) < 1e-12 &&
          min(object$weights) >= 0
      ),
      observed = max(abs(colSums(object$weights) - 1))
    )
  )
}

respondent_point <- v4_point_weights(cluster, "respondent")
cluster_point <- v4_point_weights(cluster, "cluster")
record_check(
  "T012_RESPONDENT_POINT_IDENTITY",
  "respondent target has uniform 1/N row weights",
  list(
    pass = max(abs(respondent_point - 1 / length(cluster))) < 1e-15,
    observed = max(abs(respondent_point - 1 / length(cluster)))
  )
)
record_check(
  "T013_CLUSTER_POINT_IDENTITY",
  "equal-cluster target assigns 1/(G m_g) per respondent",
  list(
    pass = (
      abs(sum(cluster_point) - 1) < 1e-15 &&
        all(tapply(cluster_point, cluster, sum) == 1 / 3)
    ),
    observed = paste(tapply(cluster_point, cluster, sum), collapse = "|")
  )
)
record_check(
  "T014_TARGET_WEIGHT_SEPARATION",
  "unequal sizes separate respondent and equal-cluster point weights",
  list(
    pass = max(abs(respondent_point - cluster_point)) > 0.01,
    observed = max(abs(respondent_point - cluster_point))
  )
)

same_seed_a <- v4_two_stage_hbb_weights(
  cluster, 20, 501, "respondent"
)
same_seed_b <- v4_two_stage_hbb_weights(
  cluster, 20, 501, "respondent"
)
different_seed <- v4_two_stage_hbb_weights(
  cluster, 20, 502, "respondent"
)
record_check(
  "T015_RNG_REPRODUCIBILITY",
  "same law and seed reproduce exact weights",
  identical(same_seed_a$weights, same_seed_b$weights)
)
record_check(
  "T016_RNG_SEPARATION",
  "different seeds produce different weights",
  !identical(same_seed_a$weights, different_seed$weights)
)
record_check(
  "T017_METADATA_COMPLETE",
  "weight object stores all required provenance fields",
  all(c(
    "law_id", "target_id", "row_grain", "cluster_id_hash",
    "cluster_sizes", "normalization_formula", "rng_kind", "seed",
    "replication_id", "draw_ids", "unseen_pattern_mass_allowed"
  ) %in% names(same_seed_a$metadata))
)

relabeled <- c(c1 = "z", c2 = "x", c3 = "y")[cluster]
relabeled_weights <- v4_two_stage_hbb_weights(
  relabeled, 20, 501, "respondent"
)
record_check(
  "T018_CLUSTER_RELABELING_INVARIANCE",
  "cluster label values do not alter the weight path",
  identical(same_seed_a$weights, relabeled_weights$weights)
)

one_per_cluster <- paste0("g", seq_len(8))
one_stage_one <- v4_one_stage_cluster_bb_weights(
  one_per_cluster, 30, 601, "respondent"
)
two_stage_one <- v4_two_stage_hbb_weights(
  one_per_cluster, 30, 601, "respondent"
)
record_check(
  "T019_ONE_RESPONDENT_SPECIAL_CASE",
  "two-stage and one-stage laws coincide when m_g=1",
  max(abs(one_stage_one$weights - two_stage_one$weights)) < 1e-15
)

set.seed(11)
X_perm <- matrix(sample(0:3, 30, replace = TRUE), ncol = 3)
colnames(X_perm) <- c("I1", "I2", "I3")
cluster_perm <- rep(1:5, each = 2)
order_perm <- c(10, 9, 4, 3, 8, 7, 2, 1, 6, 5)
h_before <- v4_ordinal_h_point(
  X_perm, v4_point_weights(cluster_perm, "cluster"),
  rep(list(0:3), 3)
)$H
h_after <- v4_ordinal_h_point(
  X_perm[order_perm, ],
  v4_point_weights(cluster_perm[order_perm], "cluster"),
  rep(list(0:3), 3)
)$H
record_check(
  "T020_ROW_RELABELING_INVARIANCE",
  "matched row and cluster permutation leaves point H invariant",
  list(
    pass = abs(h_before - h_after) < 1e-12,
    observed = abs(h_before - h_after)
  )
)

dgp_a <- v4_simulate_clustered_ordinal(
  20, .17, "informative", "medium", "regular", 7001
)
dgp_b <- v4_simulate_clustered_ordinal(
  20, .17, "informative", "medium", "regular", 7001
)
record_check(
  "T021_DGP_REPRODUCIBILITY",
  "same DGP seed reproduces responses, clusters, and sizes",
  identical(dgp_a[c("X", "cluster", "cluster_size")],
            dgp_b[c("X", "cluster", "cluster_size")])
)
record_check(
  "T022_BALANCED_SIZE_RULE",
  "balanced mechanism fixes every cluster at size 20",
  all(v4_simulate_clustered_ordinal(
    20, .17, "balanced", "medium", "regular", 7002
  )$cluster_size == 20L)
)
record_check(
  "T023_INFORMATIVE_SIZE_RULE",
  "informative size is bounded and positively associated with cluster effect",
  list(
    pass = (
      all(dgp_a$cluster_size >= 5L & dgp_a$cluster_size <= 29L) &&
        dgp_a$size_effect_correlation > .8
    ),
    observed = dgp_a$size_effect_correlation
  )
)
record_check(
  "T024_SWMDK_SIZE_RULE",
  "SWMDK-like size pool retains the observed 5 to 29 support",
  identical(range(v4_swmdk_size_pool()), c(5L, 29L))
)

truth_regular <- v4_clustered_ordinal_truth(
  .17, "balanced", "medium", "regular", "respondent", 31
)
truth_near <- v4_clustered_ordinal_truth(
  .17, "balanced", "medium", "near_knot", "respondent", 31
)
truth_exact <- v4_clustered_ordinal_truth(
  .17, "balanced", "medium", "exact_knot", "respondent", 31
)
record_check(
  "T025_TRUTH_DEFINED",
  "quadrature truth is defined with positive denominator",
  isTRUE(truth_regular$defined) &&
    truth_regular$denominator > 0 &&
    is.finite(truth_regular$H)
)
record_check(
  "T026_REGULAR_KNOT_CLASS",
  "regular truth has no exact or near knot",
  truth_regular$knot$exact_knot_count == 0L &&
    truth_regular$knot$near_knot_count == 0L
)
record_check(
  "T027_NEAR_KNOT_CLASS",
  "near-knot truth has a near but not exact equality",
  truth_near$knot$exact_knot_count == 0L &&
    truth_near$knot$near_knot_count > 0L
)
record_check(
  "T028_EXACT_KNOT_CLASS",
  "exact-knot truth has exact cumulative equalities",
  truth_exact$knot$exact_knot_count > 0L
)

simulated_point <- v4_ordinal_h_point(
  dgp_a$X, supports = dgp_a$supports
)$H
invisible(utils::capture.output(
  simulated_mokken <- mokken::coefH(
    dgp_a$X, se = FALSE, nice.output = FALSE
  )
))
record_check(
  "T029_SIMULATED_MOKKEN_CONCORDANCE",
  "simulated unweighted point agrees with mokken::coefH",
  list(
    pass = abs(simulated_point - as.numeric(simulated_mokken$H)) < 1e-10,
    observed = abs(simulated_point - as.numeric(simulated_mokken$H))
  )
)

delta <- v4_mokken_twolevel_delta(
  dgp_a$X, dgp_a$cluster, truth_regular$H
)
record_check(
  "T030_DELTA_COMPARATOR",
  "two-level mokken delta comparator executes with finite SE",
  delta$status == "OK" &&
    is.finite(delta$se_equivalent) &&
    delta$se_equivalent > 0
)

probability <- v4_graded_category_probabilities(
  seq(-2, 2, length.out = 21),
  1.2,
  c(-1.2, -.35, .4, 1.25)
)
record_check(
  "T031_GRADED_PROBABILITY",
  "graded-response probabilities are nonnegative and row normalized",
  max(abs(rowSums(probability) - 1)) < 1e-14 &&
    min(probability) >= 0
)

invalid_cluster_failed <- inherits(try(
  v4_two_stage_hbb_weights(
    c("one", "one", "one"), 10, 1, "respondent"
  ),
  silent = TRUE
), "try-error")
record_check(
  "T032_INVALID_CLUSTER_FAILS_CLOSED",
  "one-cluster input fails closed",
  invalid_cluster_failed
)

knots <- v4_knot_diagnostics(
  as.matrix(SWMDK[, swmdk_scales$teacher])
)
record_check(
  "T033_SWMDK_KNOT_DIAGNOSTIC",
  "SWMDK teacher fixed scale exposes exact empirical knots",
  knots$exact_knot_count > 0L
)
record_check(
  "T034_SWMDK_FIXED_COMPLETE",
  "both fixed SWMDK scales have no missing responses",
  !anyNA(SWMDK[, unique(unlist(swmdk_scales))])
)

results <- do.call(rbind, results)
results_path <- file.path(
  artifact_root,
  "v4-phase14-test-results-v1.csv"
)
utils::write.csv(results, results_path, row.names = FALSE, na = "")

receipt <- list(
  schema_version = "paperA-v4-phase14-test-receipt-v1",
  generated_at_utc = format(
    Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"
  ),
  status = if (all(results$pass)) "PASS" else "FAIL",
  tests_total = nrow(results),
  tests_passed = sum(results$pass),
  tests_failed = sum(!results$pass),
  maximum_transport_discrepancy = max(transport_discrepancy),
  maximum_swmdk_mokken_difference = max(swmdk_differences),
  phase13_point_difference = abs(v4_fixture$H - phase13_fixture$H),
  output = list(
    path = sub(
      paste0("^", project_root, "/"), "", results_path
    ),
    sha256 = unname(tools::sha256sum(results_path))
  ),
  production_authorized = FALSE,
  package_change_authorized = FALSE
)
receipt_path <- file.path(
  artifact_root,
  "v4-phase14-test-receipt-v1.json"
)
jsonlite::write_json(
  receipt, receipt_path, pretty = TRUE,
  auto_unbox = TRUE, digits = 16, null = "null"
)

cat(
  sprintf(
    "%s: %d/%d tests passed.\n",
    receipt$status,
    receipt$tests_passed,
    receipt$tests_total
  )
)
if (!all(results$pass)) {
  print(results[!results$pass, ])
  quit(status = 1L)
}
