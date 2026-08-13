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

source(file.path(r_root, "core", "ordinal-h.R"))
source(file.path(r_root, "core", "knot-diagnostics.R"))
source(file.path(r_root, "weights", "cluster-weights.R"))
source(file.path(r_root, "dgp", "clustered-ordinal-dgp.R"))
source(file.path(r_root, "dgp", "phase15-clustered-ordinal-dgp.R"))
source(file.path(r_root, "evaluation", "intervals-and-comparators.R"))
source(file.path(r_root, "evaluation", "phase15-calibration.R"))

protocol <- yaml::read_yaml(file.path(
  v4_root, "protocol",
  "v4-phase15-development-validation-protocol-v1.yml"
))
lock <- jsonlite::read_json(
  file.path(
    v4_root, "protocol",
    "v4-phase15-protocol-lock-receipt-v1.json"
  ),
  simplifyVector = TRUE
)
training <- utils::read.csv(
  file.path(
    v4_root, "protocol",
    "v4-phase15-training-design-v1.csv"
  ),
  stringsAsFactors = FALSE
)
validation <- utils::read.csv(
  file.path(
    v4_root, "protocol",
    "v4-phase15-validation-design-v1.csv"
  ),
  stringsAsFactors = FALSE
)

results <- list()
record <- function(id, description, expression) {
  error_message <- ""
  observed <- ""
  pass <- tryCatch({
    value <- force(expression)
    if (is.list(value) && !is.null(value$pass)) {
      observed <- paste(value$observed, collapse = "|")
      isTRUE(value$pass)
    } else {
      observed <- paste(value, collapse = "|")
      isTRUE(value)
    }
  }, error = function(error) {
    error_message <<- conditionMessage(error)
    FALSE
  })
  results[[length(results) + 1L]] <<- data.frame(
    check_id = id,
    description = description,
    observed = observed,
    pass = pass,
    error = error_message,
    stringsAsFactors = FALSE
  )
}

record(
  "P15-T001_LOCK",
  "Phase 15 protocol is frozen pre-training outcome",
  identical(lock$status, "PASS_FROZEN_PRE_TRAINING_OUTCOME")
)
record(
  "P15-T002_PHASE16_BLOCKED",
  "Phase 16 confirmation remains unauthorized",
  isFALSE(lock$phase16_confirmation_authorized)
)
record(
  "P15-T003_DESIGN_COUNTS",
  "Training and validation cell counts are fixed",
  nrow(training) == 24L && nrow(validation) == 18L
)
record(
  "P15-T004_DESIGN_DISJOINT",
  "Validation conditions and IDs are disjoint from training",
  {
    key <- function(data) paste(
      data$G, data$latent_icc, data$discrimination_center,
      data$threshold_profile, sep = "|"
    )
    !any(key(validation) %in% key(training)) &&
      length(intersect(training$cell_id, validation$cell_id)) == 0L
  }
)
record(
  "P15-T005_SEEDS_DISJOINT",
  "Training and validation seed bases differ",
  protocol$training$seed_base != protocol$validation$seed_base
)
record(
  "P15-T006_GAMMA_GRID",
  "Candidate grid is fixed and excludes inherited binary gamma",
  identical(
    as.numeric(unlist(protocol$interval_candidates$gamma_cluster)),
    c(0, -0.5, -0.75, -1, -1.25, -1.5)
  ) &&
    isFALSE(protocol$interval_candidates$binary_gamma_0_25_inherited)
)

raw_interval <- c(lower = 0.2, upper = 0.6)
gamma_zero <- v4_calibrated_interval_from_raw(
  raw_interval[1], raw_interval[2], 25, 0
)
record(
  "P15-T007_RAW_IDENTITY",
  "gamma zero preserves raw endpoints exactly",
  max(abs(gamma_zero[c("lower", "upper")] - raw_interval)) < 1e-15
)
gamma_negative <- v4_calibrated_interval_from_raw(
  raw_interval[1], raw_interval[2], 25, -1
)
record(
  "P15-T008_NEGATIVE_GAMMA_SHRINKS",
  "negative gamma preserves center and reduces positive width",
  gamma_negative["center"] == mean(raw_interval) &&
    gamma_negative["length"] < diff(raw_interval) &&
    gamma_negative["length"] > 0
)
record(
  "P15-T009_MULTIPLIERS_POSITIVE",
  "every candidate multiplier is positive for all frozen G values",
  {
    gamma <- as.numeric(unlist(
      protocol$interval_candidates$gamma_cluster
    ))
    all(outer(
      gamma,
      c(training$G, validation$G),
      function(g, G) 1 + g / sqrt(G)
    ) > 0)
  }
)
record(
  "P15-T010_METHOD_IDS_UNIQUE",
  "candidate method IDs are unique by target and gamma",
  {
    gamma <- as.numeric(unlist(
      protocol$interval_candidates$gamma_cluster
    ))
    ids <- c(
      vapply(gamma, v4_gamma_method_id, character(1),
             target = "respondent"),
      vapply(gamma, v4_gamma_method_id, character(1),
             target = "cluster")
    )
    !anyDuplicated(ids)
  }
)

cluster <- rep(1:4, c(2, 3, 4, 5))
within <- v4_within_stage_hbb_weights(
  cluster, 40, 1001, "respondent"
)
record(
  "P15-T011_WITHIN_NORMALIZATION",
  "within-stage diagnostic weights normalize",
  max(abs(colSums(within$weights) - 1)) < 1e-12 &&
    min(within$weights) >= 0
)
record(
  "P15-T012_WITHIN_FIXED_TOTALS",
  "within-stage respondent law fixes size-weighted cluster totals",
  {
    info <- v4_validate_cluster(cluster)
    totals <- vapply(
      seq_len(info$G),
      function(g) colSums(
        within$weights[info$index == g, , drop = FALSE]
      ),
      numeric(ncol(within$weights))
    )
    expected <- info$sizes / info$N
    max(abs(sweep(totals, 2L, expected, "-"))) < 1e-12
  }
)

train_cell <- training[1L, ]
val_cell <- validation[2L, ]
sim_a <- v4_phase15_simulate(
  train_cell, "training", 2001
)
sim_b <- v4_phase15_simulate(
  train_cell, "training", 2001
)
record(
  "P15-T013_DGP_REPRODUCIBLE",
  "Phase 15 DGP is seed reproducible",
  identical(sim_a[c("X", "cluster", "cluster_size")],
            sim_b[c("X", "cluster", "cluster_size")])
)
record(
  "P15-T014_DGP_SIZE_BOUNDS",
  "Frozen cluster-size mechanisms stay in 5 to 29",
  all(sim_a$cluster_size >= 5L & sim_a$cluster_size <= 29L)
)

regular_truth <- v4_phase15_truth(
  training[training$regularity == "regular", ][1L, ],
  "training", "respondent", 31
)
near_truth <- v4_phase15_truth(
  val_cell, "validation", "respondent", 31
)
exact_truth <- v4_phase15_truth(
  training[training$regularity == "exact_knot", ][1L, ],
  "training", "respondent", 31
)
record(
  "P15-T015_TRUTH_DEFINED",
  "Quadrature truth is finite with positive denominator",
  is.finite(regular_truth$H) && regular_truth$denominator > 0
)
record(
  "P15-T016_REGULAR_DOMAIN",
  "Regular truth has no exact cumulative knot",
  regular_truth$knot$exact_knot_count == 0L
)
record(
  "P15-T017_NEAR_DOMAIN",
  "Validation near-knot truth is near but not exact",
  near_truth$knot$near_knot_count > 0L &&
    near_truth$knot$exact_knot_count == 0L
)
record(
  "P15-T018_EXACT_DOMAIN",
  "Exact-knot truth has cumulative equalities",
  exact_truth$knot$exact_knot_count > 0L
)

candidate_fixture <- v4_evaluate_gamma_candidates(
  draws = seq(.2, .6, length.out = 299),
  point_estimate = .4,
  truth = .4,
  G = 25,
  target = "respondent",
  gamma_candidates = as.numeric(unlist(
    protocol$interval_candidates$gamma_cluster
  ))
)
record(
  "P15-T019_CANDIDATE_ROWS",
  "One row is returned for every frozen candidate",
  nrow(candidate_fixture) == 6L &&
    all(candidate_fixture$status == "OK")
)
record(
  "P15-T020_CANDIDATE_LENGTH_ORDER",
  "Candidate length decreases monotonically with more negative gamma",
  all(diff(candidate_fixture$interval_length) < 0)
)
record(
  "P15-T021_NO_CLIPPING",
  "Candidate transformation can cross logical bounds and does not clip",
  {
    out <- v4_calibrated_interval_from_raw(-.2, 1.2, 25, 0)
    abs(out["lower"] - (-.2)) < 1e-15 &&
      abs(out["upper"] - 1.2) < 1e-15 &&
      out["lower"] < 0 &&
      out["upper"] > 1
  }
)
record(
  "P15-T022_AWS_ONLY",
  "Heavy execution provider is AWS and GCP is prohibited",
  identical(protocol$compute$heavy_provider, "AWS_ONLY") &&
    isFALSE(protocol$compute$gcp_allowed)
)

results <- do.call(rbind, results)
results_path <- file.path(
  artifact_root, "v4-phase15-test-results-v1.csv"
)
utils::write.csv(results, results_path, row.names = FALSE, na = "")
receipt <- list(
  schema_version = "paperA-v4-phase15-test-receipt-v1",
  generated_at_utc = format(
    Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"
  ),
  status = if (all(results$pass)) "PASS" else "FAIL",
  tests_total = nrow(results),
  tests_passed = sum(results$pass),
  tests_failed = sum(!results$pass),
  output = list(
    path = sub(paste0("^", project_root, "/"), "", results_path),
    sha256 = unname(tools::sha256sum(results_path))
  ),
  phase16_confirmation_authorized = FALSE
)
receipt_path <- file.path(
  artifact_root, "v4-phase15-test-receipt-v1.json"
)
jsonlite::write_json(
  receipt, receipt_path, pretty = TRUE,
  auto_unbox = TRUE, digits = 16, null = "null"
)
cat(sprintf(
  "%s: %d/%d Phase 15 tests passed.\n",
  receipt$status, receipt$tests_passed, receipt$tests_total
))
if (!all(results$pass)) {
  print(results[!results$pass, ])
  quit(status = 1L)
}
