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
phase17_root <- file.path(
  v4_root, "empirical-swmdk", "phase17"
)
protocol_root <- file.path(phase17_root, "protocol")
artifact_root <- file.path(phase17_root, "tests", "artifacts")
dir.create(artifact_root, recursive = TRUE, showWarnings = FALSE)

source(file.path(r_root, "core", "ordinal-h.R"))
source(file.path(r_root, "weights", "cluster-weights.R"))
source(file.path(r_root, "evaluation", "phase15-calibration.R"))

protocol_path <- file.path(
  protocol_root, "v4-phase17-swmdk-empirical-protocol-v1.yml"
)
lock_path <- file.path(
  protocol_root, "v4-phase17-protocol-lock-receipt-v1.json"
)
design_path <- file.path(
  protocol_root, "v4-phase17-task-design-v1.csv"
)
authority_path <- file.path(
  v4_root, "governance",
  "v4-phase17-empirical-application-authority-v1.json"
)
parent_path <- file.path(
  v4_root, "confirmatory", "artifacts",
  "v4-phase16-final-closure-receipt-v1.json"
)
method_lock_path <- file.path(
  v4_root, "validation", "artifacts",
  "v4-phase15-final-method-lock-v1.json"
)
runner_path <- file.path(phase17_root, "run-phase17-task-v1.R")
launcher_path <- file.path(phase17_root, "run-phase17-aws-v1.sh")
evaluator_path <- file.path(
  phase17_root, "evaluate-phase17-swmdk-v1.R"
)

stopifnot(all(file.exists(c(
  protocol_path, lock_path, design_path, authority_path,
  parent_path, method_lock_path, runner_path, launcher_path,
  evaluator_path
))))

protocol <- yaml::read_yaml(protocol_path)
lock <- jsonlite::read_json(lock_path, simplifyVector = TRUE)
authority <- jsonlite::read_json(
  authority_path, simplifyVector = TRUE
)
parent <- jsonlite::read_json(parent_path, simplifyVector = TRUE)
method_lock <- jsonlite::read_json(
  method_lock_path, simplifyVector = TRUE
)
design <- utils::read.csv(
  design_path, stringsAsFactors = FALSE
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
  "P17-T001_AUTHORITY",
  "Phase 17 authority extends only through G17",
  identical(
    authority$status,
    "AUTHORIZED_PHASE17_TO_G17_ONLY"
  ) &&
    authority$output_count_at_authorization == 0L &&
    isFALSE(authority$phase18_authorized)
)
record(
  "P17-T002_PROTOCOL_LOCK",
  "Protocol was frozen before empirical outcomes",
  identical(
    lock$status,
    "PASS_FROZEN_PRE_PHASE17_EMPIRICAL_OUTCOME"
  ) &&
    lock$execution_output_count_at_lock == 0L
)
record(
  "P17-T003_PARENT",
  "Phase 16 confirmed the inherited method",
  identical(
    parent$decision,
    "CONFIRM_CLUSTER_POLYTOMOUS_METHOD"
  ) &&
    identical(
      parent$status,
      "PHASE16_CONFIRMATION_COMPLETE"
    )
)
record(
  "P17-T004_METHOD",
  "The Phase 16 method lock is inherited without tuning",
  method_lock$final_gamma_cluster == -1.5 &&
    protocol$method$selected$gamma_cluster ==
      method_lock$final_gamma_cluster &&
    identical(
      protocol$method$selected$respondent_method_id,
      method_lock$final_respondent_method_id
    ) &&
    identical(
      protocol$method$selected$equal_cluster_method_id,
      method_lock$final_equal_cluster_method_id
    ) &&
    isFALSE(protocol$method$tuning_permitted) &&
    isFALSE(protocol$method$fallback_permitted)
)
record(
  "P17-T005_LOCK_HASHES",
  "Protocol and task-design hashes match the lock receipt",
  identical(
    unname(tools::sha256sum(protocol_path)),
    lock$files$protocol$sha256
  ) &&
    identical(
      unname(tools::sha256sum(design_path)),
      lock$files$task_design$sha256
    )
)

data("SWMDK", package = "mokken", envir = environment())
dataset_hash <- digest::digest(SWMDK, algo = "sha256")
fixed_items <- unique(c(
  unlist(protocol$scales$teacher$items),
  unlist(protocol$scales$classmate$items)
))
record(
  "P17-T006_DATASET",
  "SWMDK digest, dimensions, clusters, and fixed scales match",
  identical(
    dataset_hash,
    protocol$dataset$object_digest_sha256
  ) &&
    nrow(SWMDK) == 639L &&
    length(unique(SWMDK$classId)) == 30L &&
    identical(
      as.integer(range(table(SWMDK$classId))),
      c(5L, 29L)
    ) &&
    !anyNA(SWMDK[, fixed_items]) &&
    all(unlist(SWMDK[, fixed_items]) %in% 1:5)
)

expected_tasks <- expand.grid(
  scale = c("teacher", "classmate"),
  method_key = c(
    "hbb_respondent", "hbb_cluster", "iid", "one_stage",
    "two_stage_frequentist", "within_stage"
  ),
  stringsAsFactors = FALSE
)
task_key <- function(data) {
  paste(data$scale, data$method_key, sep = "|")
}
record(
  "P17-T007_TASKS",
  "All and only the 12 prespecified scale-by-method tasks exist",
  nrow(design) == 12L &&
    !anyDuplicated(design$task_id) &&
    !anyDuplicated(design$task_index) &&
    identical(design$task_index, seq_len(12L)) &&
    setequal(task_key(design), task_key(expected_tasks))
)

batch_grid <- expand.grid(
  task_index = design$task_index,
  batch_id = seq_len(protocol$precision$batches_per_task)
)
batch_grid$seed <- protocol$precision$seed_base +
  batch_grid$task_index * 10000L + batch_grid$batch_id
record(
  "P17-T008_SEEDS",
  "All 600 batch seeds are deterministic and globally unique",
  nrow(batch_grid) == 600L &&
    !anyDuplicated(batch_grid$seed) &&
    min(batch_grid$seed) > 0 &&
    max(batch_grid$seed) < .Machine$integer.max
)
record(
  "P17-T009_PRECISION",
  "Draw and batch counts reproduce the frozen precision contract",
  protocol$precision$draws_per_random_weight_task == 99999L &&
    protocol$precision$batch_size == 2000L &&
    protocol$precision$batches_per_task == 50L &&
    nrow(design) *
      protocol$precision$draws_per_random_weight_task ==
      1199988L
)
record(
  "P17-T010_MULTIPLIER",
  "The selected gamma gives the frozen G=30 multiplier",
  abs(
    (1 + protocol$method$selected$gamma_cluster / sqrt(30)) -
      protocol$method$selected$multiplier_at_G_30
  ) < 1e-15
)

fixture_cluster <- rep(1:4, c(2, 3, 4, 5))
fixture_weights <- list(
  hbb_respondent = v4_two_stage_hbb_weights(
    fixture_cluster, 11, 4101, "respondent"
  ),
  hbb_cluster = v4_two_stage_hbb_weights(
    fixture_cluster, 11, 4102, "cluster"
  ),
  iid = v4_iid_bb_weights(
    fixture_cluster, 11, 4103
  ),
  one_stage = v4_one_stage_cluster_bb_weights(
    fixture_cluster, 11, 4104, "respondent"
  ),
  two_stage_frequentist = v4_two_stage_frequentist_weights(
    fixture_cluster, 11, 4105, "respondent"
  ),
  within_stage = v4_within_stage_hbb_weights(
    fixture_cluster, 11, 4106, "respondent"
  )
)
record(
  "P17-T011_WEIGHT_LAWS",
  "Every prespecified random-weight law is finite and normalized",
  all(vapply(fixture_weights, function(object) {
    all(is.finite(object$weights)) &&
      min(object$weights) >= 0 &&
      max(abs(colSums(object$weights) - 1)) < 1e-12
  }, logical(1)))
)

raw_fixture <- c(lower = 0.5, upper = 0.7)
selected_fixture <- v4_calibrated_interval_from_raw(
  raw_fixture[["lower"]], raw_fixture[["upper"]],
  G = 30, gamma = -1.5
)
record(
  "P17-T012_TRANSFORM",
  "Frozen calibration preserves center and strictly shortens width",
  abs(selected_fixture[["center"]] - mean(raw_fixture)) <
    1e-15 &&
    selected_fixture[["length"]] < diff(raw_fixture) &&
    selected_fixture[["length"]] > 0
)
record(
  "P17-T013_CODE_PARSE",
  "Runner and frozen evaluator parse before execution",
  {
    parse(file = runner_path)
    parse(file = evaluator_path)
    TRUE
  }
)
record(
  "P17-T014_AWS_ONLY",
  "Heavy execution is AWS-only and GCP is prohibited",
  identical(protocol$compute$heavy_provider, "AWS_ONLY") &&
    isFALSE(protocol$compute$gcp_allowed)
)
record(
  "P17-T015_INTERPRETATION",
  "Threshold crossing is diagnostic and not a formal decision",
  isFALSE(
    protocol$diagnostics$threshold_crossing_is_formal_decision
  ) &&
    identical(
      protocol$diagnostics$exact_knot_claim,
      "diagnostic_empirical_disclosure_only"
    )
)
record(
  "P17-T016_STOP_RULE",
  "Phase 18 remains unauthorized and execution stops at G17",
  isFALSE(protocol$phase18$authorized) &&
    identical(
      protocol$stop_rule,
      "STOP_AT_G17_BEFORE_PHASE18"
    )
)

empirical_outputs <- c(
  list.files(
    file.path(phase17_root, "aws-raw"),
    recursive = TRUE, full.names = TRUE
  ),
  list.files(
    file.path(phase17_root, "results"),
    recursive = TRUE, full.names = TRUE
  ),
  list.files(
    file.path(phase17_root, "artifacts"),
    recursive = TRUE, full.names = TRUE
  )
)
empirical_outputs <- empirical_outputs[
  file.exists(empirical_outputs)
]
record(
  "P17-T017_OUTCOME_BLIND",
  "No Phase 17 empirical output exists at pre-execution test time",
  length(empirical_outputs) == 0L
)

results <- do.call(rbind, results)
results_path <- file.path(
  artifact_root, "v4-phase17-test-results-v1.csv"
)
utils::write.csv(results, results_path, row.names = FALSE, na = "")
receipt <- list(
  schema_version = "paperA-v4-phase17-test-receipt-v1",
  generated_at_utc = format(
    Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"
  ),
  status = if (all(results$pass)) "PASS" else "FAIL",
  tests_total = nrow(results),
  tests_passed = sum(results$pass),
  tests_failed = sum(!results$pass),
  empirical_output_count_at_test = length(empirical_outputs),
  output = list(
    path = sub(
      paste0("^", project_root, "/"), "", results_path
    ),
    sha256 = unname(tools::sha256sum(results_path))
  ),
  phase18_authorized = FALSE,
  terminal_rule = "STOP_AT_G17_BEFORE_PHASE18"
)
receipt_path <- file.path(
  artifact_root, "v4-phase17-test-receipt-v1.json"
)
jsonlite::write_json(
  receipt, receipt_path, pretty = TRUE,
  auto_unbox = TRUE, digits = 16, null = "null"
)
message(
  receipt$status, ": ", receipt$tests_passed,
  "/", receipt$tests_total, " Phase 17 tests passed."
)
if (!all(results$pass)) {
  print(results[!results$pass, ])
  quit(status = 1L)
}
