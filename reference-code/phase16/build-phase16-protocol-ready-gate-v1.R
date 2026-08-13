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
artifact_root <- file.path(v4_root, "artifacts")
confirm_root <- file.path(v4_root, "confirmatory")
confirm_artifact_root <- file.path(confirm_root, "artifacts")
dir.create(artifact_root, recursive = TRUE, showWarnings = FALSE)
dir.create(
  confirm_artifact_root, recursive = TRUE, showWarnings = FALSE
)

read_json <- function(path) {
  jsonlite::read_json(path, simplifyVector = TRUE)
}
rel <- function(path) {
  sub(paste0("^", project_root, "/"), "", path)
}
path_v4 <- function(...) file.path(v4_root, ...)

authority_path <- path_v4(
  "governance",
  "v4-phase15-autonomous-authority-addendum-v1.json"
)
g14_path <- path_v4(
  "artifacts", "v4-g14-decision-receipt-v1.json"
)
phase15_protocol_path <- path_v4(
  "protocol",
  "v4-phase15-development-validation-protocol-v1.yml"
)
phase15_protocol_lock_path <- path_v4(
  "protocol", "v4-phase15-protocol-lock-receipt-v1.json"
)
training_design_path <- path_v4(
  "protocol", "v4-phase15-training-design-v1.csv"
)
validation_design_path <- path_v4(
  "protocol", "v4-phase15-validation-design-v1.csv"
)
test_receipt_path <- path_v4(
  "tests", "artifacts", "v4-phase15-test-receipt-v1.json"
)
training_lock_path <- path_v4(
  "development", "artifacts",
  "v4-phase15-training-method-lock-v1.json"
)
final_lock_path <- path_v4(
  "validation", "artifacts",
  "v4-phase15-final-method-lock-v1.json"
)
validation_overall_path <- path_v4(
  "validation", "artifacts",
  "v4-phase15-validation-overall-summary-v1.csv"
)
validation_cell_path <- path_v4(
  "validation", "artifacts",
  "v4-phase15-validation-cell-summary-v1.csv"
)
validation_subgroup_path <- path_v4(
  "validation", "artifacts",
  "v4-phase15-validation-subgroup-summary-v1.csv"
)
validation_gate_path <- path_v4(
  "validation", "artifacts",
  "v4-phase15-validation-gate-checks-v1.csv"
)
confirmation_protocol_path <- file.path(
  confirm_root, "v4-phase16-confirmation-protocol-v1.yml"
)
confirmation_design_path <- file.path(
  confirm_root, "v4-phase16-confirmation-design-v1.csv"
)
confirmation_runner_path <- file.path(
  confirm_root, "run-phase16-cell-v1.R"
)
confirmation_launcher_path <- file.path(
  confirm_root, "run-phase16-aws-v1.sh"
)
confirmation_evaluator_path <- file.path(
  confirm_root, "evaluate-phase16-confirmation-v1.R"
)
execution_bundle_path <- path_v4(
  "artifacts", "execution-bundles",
  "v4-phase15-aws-execution-bundle-v1.tar.gz"
)
fresh_authority_path <- file.path(
  confirm_root, "v4-phase16-fresh-confirmation-authority-v1.json"
)

required <- c(
  authority_path, g14_path, phase15_protocol_path,
  phase15_protocol_lock_path, training_design_path,
  validation_design_path, test_receipt_path, training_lock_path,
  final_lock_path, validation_overall_path, validation_cell_path,
  validation_subgroup_path, validation_gate_path,
  confirmation_protocol_path, confirmation_design_path,
  confirmation_runner_path, confirmation_launcher_path,
  confirmation_evaluator_path, execution_bundle_path
)
stopifnot(all(file.exists(required)))
stopifnot(identical(
  unname(tools::sha256sum(execution_bundle_path)),
  "801a6857f8deb8a81929d92a3d599f5620c96fb39d718cb2a8f83030977d0fa7"
))

authority <- read_json(authority_path)
g14 <- read_json(g14_path)
phase15_protocol <- yaml::read_yaml(phase15_protocol_path)
phase15_protocol_lock <- read_json(phase15_protocol_lock_path)
test_receipt <- read_json(test_receipt_path)
training_lock <- read_json(training_lock_path)
final_lock <- read_json(final_lock_path)
confirmation_protocol <- yaml::read_yaml(
  confirmation_protocol_path
)
training_design <- utils::read.csv(
  training_design_path, stringsAsFactors = FALSE
)
validation_design <- utils::read.csv(
  validation_design_path, stringsAsFactors = FALSE
)
confirmation_design <- utils::read.csv(
  confirmation_design_path, stringsAsFactors = FALSE
)
validation_overall <- utils::read.csv(
  validation_overall_path, stringsAsFactors = FALSE
)
validation_cell <- utils::read.csv(
  validation_cell_path, stringsAsFactors = FALSE
)
validation_subgroup <- utils::read.csv(
  validation_subgroup_path, stringsAsFactors = FALSE
)
validation_gate <- utils::read.csv(
  validation_gate_path, stringsAsFactors = FALSE
)

training_raw_root <- path_v4("development", "aws-raw")
validation_raw_root <- path_v4("validation", "aws-raw")
confirmation_raw_root <- file.path(confirm_root, "aws-raw")
training_result_files <- list.files(
  training_raw_root,
  pattern = "^P15-T[0-9]{3}-replications-v1\\.csv$",
  full.names = TRUE
)
training_truth_files <- list.files(
  training_raw_root,
  pattern = "^P15-T[0-9]{3}-truth-v1\\.csv$",
  full.names = TRUE
)
training_receipt_files <- list.files(
  training_raw_root,
  pattern = "^P15-T[0-9]{3}-receipt-v1\\.json$",
  full.names = TRUE
)
validation_result_files <- list.files(
  validation_raw_root,
  pattern = "^P15-V[0-9]{3}-replications-v1\\.csv$",
  full.names = TRUE
)
validation_truth_files <- list.files(
  validation_raw_root,
  pattern = "^P15-V[0-9]{3}-truth-v1\\.csv$",
  full.names = TRUE
)
validation_receipt_files <- list.files(
  validation_raw_root,
  pattern = "^P15-V[0-9]{3}-receipt-v1\\.json$",
  full.names = TRUE
)
confirmation_outputs <- if (dir.exists(confirmation_raw_root)) {
  list.files(
    confirmation_raw_root, all.files = FALSE, full.names = TRUE
  )
} else {
  character()
}

training <- do.call(rbind, lapply(
  training_result_files,
  utils::read.csv,
  stringsAsFactors = FALSE
))
validation <- do.call(rbind, lapply(
  validation_result_files,
  utils::read.csv,
  stringsAsFactors = FALSE
))
training_replications <- length(unique(paste(
  training$cell_id, training$replication
)))
validation_replications <- length(unique(paste(
  validation$cell_id, validation$replication
)))

selected_gamma <- final_lock$final_gamma_cluster
selected_validation <- validation[
  validation$candidate &
    abs(validation$gamma_cluster - selected_gamma) < 1e-12,
  ,
  drop = FALSE
]
raw_validation <- validation[
  validation$candidate &
    abs(validation$gamma_cluster) < 1e-12,
  ,
  drop = FALSE
]
lane_summary_function <- function(data) {
  data.frame(
    replications = nrow(data),
    coverage = mean(data$cover),
    coverage_mcse = sqrt(
      mean(data$cover) * (1 - mean(data$cover)) / nrow(data)
    ),
    mean_interval_length = mean(data$interval_length),
    mean_bias = mean(data$bias),
    maximum_invalid_fraction =
      max(data$invalid_fraction, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}
selected_validation$target <- ifelse(
  selected_validation$target_id ==
    "V4-TARGET-RESPONDENT-WEIGHTED-v1",
  "respondent",
  "equal_cluster"
)
lane_groups <- split(
  selected_validation,
  interaction(
    selected_validation$regularity,
    selected_validation$target,
    drop = TRUE,
    lex.order = TRUE
  )
)
lane_summary <- do.call(rbind, lapply(lane_groups, function(data) {
  cbind(
    data.frame(
      regularity = data$regularity[1L],
      target = data$target[1L],
      method_id = data$method_id[1L],
      stringsAsFactors = FALSE
    ),
    lane_summary_function(data)
  )
}))
rownames(lane_summary) <- NULL
lane_summary_path <- path_v4(
  "artifacts", "v4-phase15-validation-lane-summary-v1.csv"
)
utils::write.csv(lane_summary, lane_summary_path, row.names = FALSE)

comparators <- validation[
  !validation$candidate, , drop = FALSE
]
comparator_groups <- split(
  comparators,
  interaction(
    comparators$method_id, comparators$regularity,
    drop = TRUE, lex.order = TRUE
  )
)
comparator_summary <- do.call(
  rbind, lapply(comparator_groups, function(data) {
    cbind(
      data.frame(
        method_id = data$method_id[1L],
        regularity = data$regularity[1L],
        target_id = data$target_id[1L],
        stringsAsFactors = FALSE
      ),
      lane_summary_function(data)
    )
  })
)
rownames(comparator_summary) <- NULL
comparator_summary_path <- path_v4(
  "artifacts", "v4-phase15-comparator-summary-v1.csv"
)
utils::write.csv(
  comparator_summary, comparator_summary_path, row.names = FALSE
)

design_key <- function(data) {
  paste(
    data$G, data$latent_icc, data$discrimination_center,
    data$threshold_profile, sep = "|"
  )
}
phase15_conditions <- c(
  design_key(training_design), design_key(validation_design)
)
confirmation_conditions <- design_key(confirmation_design)
runner_lines <- readLines(confirmation_runner_path, warn = FALSE)
evaluator_lines <- readLines(
  confirmation_evaluator_path, warn = FALSE
)
invisible(parse(file = confirmation_runner_path))
invisible(parse(file = confirmation_evaluator_path))

baseline_path <- path_v4(
  "governance", "v4-source-and-freeze-inventory-v1.csv"
)
baseline <- utils::read.csv(
  baseline_path, stringsAsFactors = FALSE
)
baseline_current_hash <- unname(tools::sha256sum(
  file.path(project_root, baseline$project_relative_path)
))
protected_baseline_intact <- all(
  baseline_current_hash == unname(baseline$sha256)
)

checks <- data.frame(
  check_id = c(
    "P16R-001_AUTHORITY",
    "P16R-002_PARENT_G14",
    "P16R-003_PHASE15_PROTOCOL",
    "P16R-004_TESTS",
    "P16R-005_TRAINING_COMPLETE",
    "P16R-006_TRAINING_LOCK_BLIND",
    "P16R-007_VALIDATION_COMPLETE",
    "P16R-008_FINAL_METHOD_LOCK",
    "P16R-009_VALIDATION_GATES",
    "P16R-010_RAW_FIRST_TRANSFER",
    "P16R-011_CONFIRM_DESIGN_COUNT",
    "P16R-012_CONFIRM_CONDITIONS_FRESH",
    "P16R-013_CONFIRM_SEEDS_FRESH",
    "P16R-014_METHOD_IMMUTABLE",
    "P16R-015_RUNNER_GUARD",
    "P16R-016_EVALUATOR_GUARD",
    "P16R-017_AWS_ONLY",
    "P16R-018_CONFIRM_AUTH_ABSENT",
    "P16R-019_CONFIRM_OUTPUTS_ZERO",
    "P16R-020_CONFIRM_NOT_EXECUTED",
    "P16R-021_PROTECTED_BASELINE",
    "P16R-022_SOURCE_RESTRICTION",
    "P16R-023_TERMINAL_RULE"
  ),
  criterion = c(
    "Phase 15-only authority and required stop are intact",
    "G14 authorized clustered-polytomous development",
    "Phase 15 protocol was frozen before training outcomes",
    "All Phase 15 deterministic tests pass",
    "Training raw bundle has 24 cells and 2,880 replications",
    "Training lock records zero validation outcomes accessed",
    "Held-out raw bundle has 18 cells and 3,240 replications",
    "One calibrated method is locked after held-out validation",
    "Every selected-method held-out gate passes",
    "Validation lock records raw download before evaluation",
    "Fresh confirmation design contains 24 fixed cells",
    "Confirmation conditions are disjoint from Phase 15",
    "Confirmation seed namespace is disjoint from Phase 15",
    "Protocol method and gamma equal the final method lock",
    "Confirmation runner blocks absent fresh authority",
    "Confirmation evaluator blocks absent fresh authority",
    "Heavy compute is AWS-only and GCP is prohibited",
    "Fresh Phase 16 authority file is absent",
    "Fresh confirmation raw output count is zero",
    "Protocol records confirmation as unauthorized/unexecuted",
    "Step 14.1 protected source baseline remains intact",
    "Unresolved source crosswalk remains a production blocker",
    "Required stop is before fresh confirmation"
  ),
  pass = c(
    identical(authority$status, "AUTHORIZED_PHASE15_ONLY") &&
      identical(
        authority$required_stop,
        "STOP_AT_PHASE16_PROTOCOL_READY_BEFORE_CONFIRMATION"
      ),
    identical(
      g14$decision,
      "PROCEED_TO_CLUSTER_POLYTOMOUS_DEVELOPMENT"
    ),
    identical(
      phase15_protocol_lock$status,
      "PASS_FROZEN_PRE_TRAINING_OUTCOME"
    ),
    identical(test_receipt$status, "PASS") &&
      test_receipt$tests_passed == 22L &&
      test_receipt$tests_failed == 0L,
    length(training_result_files) == 24L &&
      length(training_truth_files) == 24L &&
      length(training_receipt_files) == 24L &&
      training_replications == 2880L &&
      nrow(training) == 48960L,
    identical(
      training_lock$status,
      "LOCKED_FOR_HELD_OUT_VALIDATION"
    ) &&
      isFALSE(training_lock$validation_outcomes_accessed) &&
      training_lock$validation_output_count_at_lock == 0L,
    length(validation_result_files) == 18L &&
      length(validation_truth_files) == 18L &&
      length(validation_receipt_files) == 18L &&
      validation_replications == 3240L &&
      nrow(validation) == 29160L,
    identical(
      final_lock$status,
      "LOCKED_FOR_PHASE16_CONFIRMATION"
    ) &&
      identical(
        final_lock$final_method_label,
        "CALIBRATED_CANDIDATE"
      ) &&
      isTRUE(final_lock$training_selected_passed_validation),
    all(validation_gate$pass[
      validation_gate$method_role ==
        "selected_training_candidate"
    ]),
    isTRUE(
      final_lock$validation$
        raw_download_complete_before_evaluation
    ),
    nrow(confirmation_design) == 24L &&
      !anyDuplicated(confirmation_design$cell_id),
    !any(confirmation_conditions %in% phase15_conditions) &&
      length(intersect(
        confirmation_design$cell_id,
        c(training_design$cell_id, validation_design$cell_id)
      )) == 0L,
    !confirmation_protocol$design$seed_base %in% c(
      phase15_protocol$training$seed_base,
      phase15_protocol$validation$seed_base
    ),
    confirmation_protocol$method$gamma_cluster ==
      final_lock$final_gamma_cluster &&
      identical(
        confirmation_protocol$method$respondent_method_id,
        final_lock$final_respondent_method_id
      ) &&
      isFALSE(confirmation_protocol$method$tuning_permitted),
    any(grepl("fresh confirmation authority", runner_lines)) &&
      any(grepl("authority_path", runner_lines)),
    any(grepl("blocked without fresh authority", evaluator_lines)) &&
      any(grepl("authority_path", evaluator_lines)),
    identical(confirmation_protocol$compute$provider, "AWS_ONLY") &&
      confirmation_protocol$compute$workers == 12L &&
      isFALSE(confirmation_protocol$compute$gcp_allowed),
    !file.exists(fresh_authority_path),
    length(confirmation_outputs) == 0L,
    isFALSE(confirmation_protocol$execution$authorized) &&
      isFALSE(confirmation_protocol$execution$executed) &&
      confirmation_protocol$execution$output_count_at_lock == 0L,
    protected_baseline_intact,
    identical(
      confirmation_protocol$restrictions$source_crosswalk,
      "unresolved_production_blocker"
    ),
    identical(
      confirmation_protocol$stop_rule,
      "STOP_AT_PHASE16_PROTOCOL_READY_BEFORE_CONFIRMATION"
    )
  ),
  stringsAsFactors = FALSE
)
checks$observed <- ifelse(checks$pass, "PASS", "FAIL")
checks_path <- file.path(
  confirm_artifact_root,
  "v4-phase16-protocol-ready-checks-v1.csv"
)
utils::write.csv(checks, checks_path, row.names = FALSE)

preflight <- list(
  schema_version = "paperA-v4-phase15-aws-preflight-receipt-v1",
  recorded_at_utc = format(
    Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"
  ),
  status = "PASS_AWS_ONLY_RESOURCE_PREFLIGHT",
  provider = "AWS",
  alias = "aws-vm",
  instance_id = "i-0ad4ffafc8bb19ff0",
  instance_name = "simulation-aws",
  instance_type = "c6a.8xlarge",
  state_before = "stopped",
  state_for_execution = "running",
  state_after_execution = "stopped",
  public_ip = "3.224.106.101",
  vcpus = 32,
  memory_total_kb = 64524232,
  memory_available_kb_at_preflight = 63419872,
  workers_authorized = 12,
  active_research_processes_at_preflight = 0,
  r_version = "4.6.0",
  required_packages_available = TRUE,
  execution_bundle = list(
    path = rel(execution_bundle_path),
    sha256 = unname(tools::sha256sum(execution_bundle_path)),
    uploaded_sha256 =
      "801a6857f8deb8a81929d92a3d599f5620c96fb39d718cb2a8f83030977d0fa7"
  ),
  package_repair = list(
    installed = c("statmod", "Rcpp", "mokken"),
    reason = "statmod absent and mokken required a current Rcpp for R 4.6"
  ),
  gcp_accessed = FALSE,
  gcp_used = FALSE,
  compute_closure = list(
    training_receipts_remote = 24,
    validation_receipts_remote = 18,
    local_raw_download_verified = TRUE,
    instance_stopped_after_download = TRUE
  )
)
preflight_path <- path_v4(
  "artifacts", "v4-phase15-aws-preflight-receipt-v1.json"
)
jsonlite::write_json(
  preflight, preflight_path, pretty = TRUE,
  auto_unbox = TRUE, digits = 16, null = "null"
)

selected_resp <- validation_overall[
  abs(validation_overall$gamma_cluster - selected_gamma) < 1e-12 &
    validation_overall$target == "respondent",
  ,
  drop = FALSE
]
selected_cluster <- validation_overall[
  abs(validation_overall$gamma_cluster - selected_gamma) < 1e-12 &
    validation_overall$target == "equal_cluster",
  ,
  drop = FALSE
]
raw_resp <- validation_overall[
  abs(validation_overall$gamma_cluster) < 1e-12 &
    validation_overall$target == "respondent",
  ,
  drop = FALSE
]
raw_cluster <- validation_overall[
  abs(validation_overall$gamma_cluster) < 1e-12 &
    validation_overall$target == "equal_cluster",
  ,
  drop = FALSE
]
execution_summary <- list(
  schema_version = "paperA-v4-phase15-execution-summary-v1",
  generated_at_utc = format(
    Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"
  ),
  status = "PHASE15_COMPLETE_METHOD_LOCKED",
  training = list(
    cells = 24,
    replications = training_replications,
    method_rows = nrow(training),
    raw_files = length(c(
      training_result_files, training_truth_files,
      training_receipt_files
    )),
    selected_gamma_cluster =
      training_lock$selected_gamma_cluster,
    eligible_candidate_count =
      training_lock$eligible_candidate_count,
    selected_respondent_coverage =
      training_lock$selected_training_metrics$
        respondent_coverage,
    selected_equal_cluster_coverage =
      training_lock$selected_training_metrics$
        equal_cluster_coverage
  ),
  held_out_validation = list(
    cells = 18,
    replications = validation_replications,
    method_rows = nrow(validation),
    raw_files = length(c(
      validation_result_files, validation_truth_files,
      validation_receipt_files
    )),
    selected_respondent_coverage =
      selected_resp$coverage,
    selected_respondent_coverage_mcse =
      selected_resp$coverage_mcse,
    selected_equal_cluster_coverage =
      selected_cluster$coverage,
    selected_equal_cluster_coverage_mcse =
      selected_cluster$coverage_mcse,
    selected_respondent_mean_length =
      selected_resp$mean_interval_length,
    raw_respondent_coverage = raw_resp$coverage,
    raw_equal_cluster_coverage = raw_cluster$coverage,
    raw_respondent_mean_length =
      raw_resp$mean_interval_length,
    selected_to_raw_length_ratio =
      selected_resp$mean_interval_length /
        raw_resp$mean_interval_length,
    minimum_selected_regular_cell_coverage = min(
      validation_cell$coverage[
        abs(validation_cell$gamma_cluster -
              selected_gamma) < 1e-12
      ]
    ),
    minimum_selected_G_group_coverage = min(
      validation_subgroup$coverage[
        abs(validation_subgroup$gamma_cluster -
              selected_gamma) < 1e-12 &
          validation_subgroup$grouping_variable == "G"
      ]
    ),
    minimum_selected_size_group_coverage = min(
      validation_subgroup$coverage[
        abs(validation_subgroup$gamma_cluster -
              selected_gamma) < 1e-12 &
          validation_subgroup$grouping_variable ==
            "size_mechanism"
      ]
    ),
    maximum_invalid_fraction =
      max(selected_validation$invalid_fraction)
  ),
  final_method = list(
    label = final_lock$final_method_label,
    gamma_cluster = final_lock$final_gamma_cluster,
    respondent_method_id =
      final_lock$final_respondent_method_id,
    equal_cluster_method_id =
      final_lock$final_equal_cluster_method_id,
    raw_only_fallback_passed = FALSE
  ),
  phase16 = list(
    gate = if (all(checks$pass)) {
      "READY_FOR_PHASE16_FRESH_CONFIRMATION_AWAITING_AUTHORIZATION"
    } else {
      "NOT_PROTOCOL_READY"
    },
    fresh_authority_present = file.exists(fresh_authority_path),
    confirmation_executed = FALSE,
    raw_output_count = length(confirmation_outputs)
  )
)
execution_summary_path <- path_v4(
  "artifacts", "v4-phase15-execution-summary-v1.json"
)
jsonlite::write_json(
  execution_summary, execution_summary_path, pretty = TRUE,
  auto_unbox = TRUE, digits = 16, null = "null"
)

evidence_files <- c(
  authority_path, g14_path, phase15_protocol_path,
  phase15_protocol_lock_path, training_design_path,
  validation_design_path, test_receipt_path,
  path_v4(
    "tests", "artifacts", "v4-phase15-test-results-v1.csv"
  ),
  path_v4("R", "dgp", "phase15-clustered-ordinal-dgp.R"),
  path_v4("R", "evaluation", "phase15-calibration.R"),
  path_v4("development", "run-phase15-cell-v1.R"),
  path_v4(
    "development", "select-phase15-training-method-v1.R"
  ),
  path_v4(
    "development", "artifacts",
    "v4-phase15-training-raw-manifest-v1.csv"
  ),
  path_v4(
    "development", "artifacts",
    "v4-phase15-training-candidate-summary-v1.csv"
  ),
  path_v4(
    "development", "artifacts",
    "v4-phase15-training-subgroup-summary-v1.csv"
  ),
  path_v4(
    "development", "artifacts",
    "v4-phase15-training-candidate-decisions-v1.csv"
  ),
  training_lock_path,
  path_v4("validation", "evaluate-phase15-heldout-v1.R"),
  path_v4(
    "validation", "artifacts",
    "v4-phase15-validation-raw-manifest-v1.csv"
  ),
  validation_overall_path, validation_cell_path,
  validation_subgroup_path, validation_gate_path, final_lock_path,
  lane_summary_path, comparator_summary_path, preflight_path,
  execution_summary_path, confirmation_protocol_path,
  confirmation_design_path, confirmation_runner_path,
  confirmation_launcher_path, confirmation_evaluator_path,
  execution_bundle_path, baseline_path,
  path_v4(
    "protocol", "v4-original-source-crosswalk-schedule-v1.json"
  )
)
stopifnot(all(file.exists(evidence_files)))
evidence_manifest <- data.frame(
  project_relative_path = rel(evidence_files),
  size_bytes = as.numeric(file.info(evidence_files)$size),
  sha256 = unname(tools::sha256sum(evidence_files)),
  stringsAsFactors = FALSE
)
evidence_manifest_path <- path_v4(
  "artifacts", "v4-phase15-evidence-manifest-v1.csv"
)
utils::write.csv(
  evidence_manifest, evidence_manifest_path, row.names = FALSE
)

receipt <- list(
  schema_version = "paperA-v4-phase16-protocol-ready-receipt-v1",
  generated_at_utc = format(
    Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"
  ),
  decision = if (all(checks$pass)) {
    "READY_FOR_PHASE16_FRESH_CONFIRMATION_AWAITING_AUTHORIZATION"
  } else {
    "NOT_PROTOCOL_READY"
  },
  checks = list(
    passed = sum(checks$pass),
    total = nrow(checks),
    failed = sum(!checks$pass),
    path = rel(checks_path),
    sha256 = unname(tools::sha256sum(checks_path))
  ),
  final_method = list(
    label = final_lock$final_method_label,
    gamma_cluster = final_lock$final_gamma_cluster,
    respondent_method_id =
      final_lock$final_respondent_method_id,
    equal_cluster_method_id =
      final_lock$final_equal_cluster_method_id,
    method_lock_path = rel(final_lock_path),
    method_lock_sha256 =
      unname(tools::sha256sum(final_lock_path))
  ),
  confirmation_protocol = list(
    path = rel(confirmation_protocol_path),
    sha256 = unname(tools::sha256sum(
      confirmation_protocol_path
    )),
    design_path = rel(confirmation_design_path),
    design_sha256 = unname(tools::sha256sum(
      confirmation_design_path
    )),
    cells = nrow(confirmation_design),
    scheduled_replications =
      confirmation_protocol$design$scheduled_replications
  ),
  evidence_manifest = list(
    path = rel(evidence_manifest_path),
    files = nrow(evidence_manifest),
    sha256 = unname(tools::sha256sum(evidence_manifest_path))
  ),
  phase16_fresh_confirmation = list(
    authorized = FALSE,
    executed = FALSE,
    raw_output_count = length(confirmation_outputs),
    authority_file_present = file.exists(fresh_authority_path)
  ),
  phase17_authorized = FALSE,
  terminal_state =
    "STOP_AT_PHASE16_PROTOCOL_READY_BEFORE_CONFIRMATION"
)
receipt_path <- file.path(
  confirm_artifact_root,
  "v4-phase16-protocol-ready-receipt-v1.json"
)
jsonlite::write_json(
  receipt, receipt_path, pretty = TRUE,
  auto_unbox = TRUE, digits = 16, null = "null"
)
message(
  receipt$decision, ": ", receipt$checks$passed,
  "/", receipt$checks$total, " protocol-ready checks passed."
)
if (!all(checks$pass)) {
  print(checks[!checks$pass, ])
  quit(status = 1L)
}
