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
phase17_root <- file.path(
  v4_root, "empirical-swmdk", "phase17"
)
protocol_root <- file.path(phase17_root, "protocol")
test_root <- file.path(phase17_root, "tests")
test_artifact_root <- file.path(test_root, "artifacts")
raw_root <- file.path(phase17_root, "aws-raw")
log_root <- file.path(phase17_root, "aws-logs")
result_root <- file.path(phase17_root, "results")
artifact_root <- file.path(phase17_root, "artifacts")
bundle_root <- file.path(phase17_root, "execution-bundles")
dir.create(artifact_root, recursive = TRUE, showWarnings = FALSE)

rel <- function(path) {
  sub(paste0("^", project_root, "/"), "", path)
}
read_json <- function(path) {
  jsonlite::read_json(path, simplifyVector = TRUE)
}

authority_path <- file.path(
  v4_root, "governance",
  "v4-phase17-empirical-application-authority-v1.json"
)
protocol_path <- file.path(
  protocol_root, "v4-phase17-swmdk-empirical-protocol-v1.yml"
)
protocol_lock_path <- file.path(
  protocol_root, "v4-phase17-protocol-lock-receipt-v1.json"
)
code_lock_path <- file.path(
  protocol_root, "v4-phase17-execution-code-lock-v1.json"
)
design_path <- file.path(
  protocol_root, "v4-phase17-task-design-v1.csv"
)
test_runner_path <- file.path(
  test_root, "run-phase17-tests-v1.R"
)
test_results_path <- file.path(
  test_artifact_root, "v4-phase17-test-results-v1.csv"
)
test_receipt_path <- file.path(
  test_artifact_root, "v4-phase17-test-receipt-v1.json"
)
runner_path <- file.path(
  phase17_root, "run-phase17-task-v1.R"
)
launcher_path <- file.path(
  phase17_root, "run-phase17-aws-v1.sh"
)
evaluator_path <- file.path(
  phase17_root, "evaluate-phase17-swmdk-v1.R"
)
finalizer_path <- file.path(
  phase17_root, "finalize-phase17-empirical-application-v1.R"
)
bundle_path <- file.path(
  bundle_root, "v4-phase17-aws-execution-bundle-v1.tar.gz"
)
parent_path <- file.path(
  v4_root, "confirmatory", "artifacts",
  "v4-phase16-final-closure-receipt-v1.json"
)
method_lock_path <- file.path(
  v4_root, "validation", "artifacts",
  "v4-phase15-final-method-lock-v1.json"
)
baseline_path <- file.path(
  v4_root, "governance", "v4-source-and-freeze-inventory-v1.csv"
)
crosswalk_path <- file.path(
  v4_root, "protocol",
  "v4-original-source-crosswalk-schedule-v1.json"
)
method_path <- file.path(
  result_root, "v4-phase17-method-summary-v1.csv"
)
diagnostic_path <- file.path(
  result_root, "v4-phase17-target-knot-diagnostics-v1.csv"
)
icc_path <- file.path(
  result_root, "v4-phase17-icc-summary-v1.csv"
)
category_path <- file.path(
  result_root, "v4-phase17-category-profile-v1.csv"
)
profile_path <- file.path(
  result_root, "v4-phase17-data-profile-v1.csv"
)
stability_path <- file.path(
  result_root, "v4-phase17-quantile-stability-v1.csv"
)
gate_path <- file.path(
  artifact_root, "v4-g17-gate-criteria-v1.csv"
)
decision_path <- file.path(
  artifact_root, "v4-g17-decision-receipt-v1.json"
)
evaluator_manifest_path <- file.path(
  artifact_root, "v4-phase17-evidence-manifest-v1.csv"
)

required <- c(
  authority_path, protocol_path, protocol_lock_path,
  code_lock_path, design_path, test_runner_path,
  test_results_path, test_receipt_path, runner_path,
  launcher_path, evaluator_path, finalizer_path, bundle_path,
  parent_path, method_lock_path, baseline_path, crosswalk_path,
  method_path, diagnostic_path, icc_path, category_path,
  profile_path, stability_path, gate_path, decision_path,
  evaluator_manifest_path
)
stopifnot(all(file.exists(required)))

authority <- read_json(authority_path)
protocol <- yaml::read_yaml(protocol_path)
protocol_lock <- read_json(protocol_lock_path)
code_lock <- read_json(code_lock_path)
design <- utils::read.csv(
  design_path, stringsAsFactors = FALSE
)
test_results <- utils::read.csv(
  test_results_path, stringsAsFactors = FALSE
)
test_receipt <- read_json(test_receipt_path)
parent <- read_json(parent_path)
method_lock <- read_json(method_lock_path)
crosswalk <- read_json(crosswalk_path)
baseline <- utils::read.csv(
  baseline_path, stringsAsFactors = FALSE
)
method_summary <- utils::read.csv(
  method_path, stringsAsFactors = FALSE
)
diagnostics <- utils::read.csv(
  diagnostic_path, stringsAsFactors = FALSE
)
icc <- utils::read.csv(
  icc_path, stringsAsFactors = FALSE
)
category <- utils::read.csv(
  category_path, stringsAsFactors = FALSE
)
profile <- utils::read.csv(
  profile_path, stringsAsFactors = FALSE
)
stability <- utils::read.csv(
  stability_path, stringsAsFactors = FALSE
)
gate <- utils::read.csv(
  gate_path, stringsAsFactors = FALSE
)
decision <- read_json(decision_path)
evaluator_manifest <- utils::read.csv(
  evaluator_manifest_path, stringsAsFactors = FALSE
)

raw_files <- list.files(
  raw_root, pattern = "^P17-T[0-9]{2}-",
  full.names = TRUE
)
receipt_files <- raw_files[
  grepl("-receipt-v1\\.json$", raw_files)
]
draw_files <- raw_files[
  grepl("-draws-v1\\.csv\\.gz$", raw_files)
]
batch_files <- raw_files[
  grepl("-batch-manifest-v1\\.csv$", raw_files)
]
log_files <- list.files(
  log_root, pattern = "^P17-T[0-9]{2}\\.log$",
  full.names = TRUE
)
receipts <- lapply(
  receipt_files, read_json
)
receipt_task_ids <- vapply(
  receipts, `[[`, character(1), "task_id"
)
receipt_hash_pass <- vapply(receipts, function(receipt) {
  draw_path <- file.path(project_root, receipt$draw_output$path)
  batch_path <- file.path(
    project_root, receipt$batch_manifest$path
  )
  identical(
    unname(tools::sha256sum(draw_path)),
    receipt$draw_output$sha256
  ) &&
    identical(
      unname(tools::sha256sum(batch_path)),
      receipt$batch_manifest$sha256
    )
}, logical(1))
receipt_code_hash_pass <- vapply(receipts, function(receipt) {
  identical(
    receipt$code_hashes$task_runner_sha256,
    code_lock$files$task_runner$sha256
  ) &&
    identical(
      receipt$code_hashes$ordinal_h_sha256,
      code_lock$files$ordinal_h$sha256
    ) &&
    identical(
      receipt$code_hashes$cluster_weights_sha256,
      code_lock$files$cluster_weights$sha256
    )
}, logical(1))

raw_manifest <- data.frame(
  project_relative_path = rel(raw_files),
  size_bytes = as.numeric(file.info(raw_files)$size),
  sha256 = unname(tools::sha256sum(raw_files)),
  stringsAsFactors = FALSE
)
raw_manifest <- raw_manifest[
  order(raw_manifest$project_relative_path), , drop = FALSE
]
raw_manifest_path <- file.path(
  artifact_root, "v4-phase17-raw-manifest-v1.csv"
)
utils::write.csv(
  raw_manifest, raw_manifest_path, row.names = FALSE
)

selected <- method_summary[
  method_summary$interval_role ==
    "phase16_confirmed_selected",
  ,
  drop = FALSE
]
raw_hbb <- method_summary[
  method_summary$method_id %in% c(
    protocol$method$raw_base$respondent_method_id,
    protocol$method$raw_base$equal_cluster_method_id
  ),
  ,
  drop = FALSE
]
delta <- method_summary[
  method_summary$method_id ==
    "V4-CMP-MOKKEN-TWOLEVEL-DELTA-v1",
  ,
  drop = FALSE
]
selected_raw <- merge(
  selected[, c(
    "scale", "target_role", "method_id", "point_estimate",
    "lower", "upper", "interval_length"
  )],
  raw_hbb[, c("scale", "target_role", "interval_length")],
  by = c("scale", "target_role"),
  suffixes = c("_selected", "_raw")
)
selected_raw$selected_to_raw_length_ratio <-
  selected_raw$interval_length_selected /
  selected_raw$interval_length_raw
selected_delta <- merge(
  selected[selected$target_role == "respondent", c(
    "scale", "interval_length"
  )],
  delta[, c("scale", "interval_length")],
  by = "scale", suffixes = c("_selected", "_delta")
)
selected_delta$selected_to_delta_length_ratio <-
  selected_delta$interval_length_selected /
  selected_delta$interval_length_delta

metric_for <- function(data, scale, target, field) {
  data[
    data$scale == scale & data$target_role == target,
    field
  ][1L]
}
diagnostic_for <- function(scale, target, field) {
  diagnostics[
    diagnostics$scale == scale &
      diagnostics$target == target,
    field
  ][1L]
}
icc_for <- function(scale) {
  icc$ICC[icc$scale == scale][1L]
}

key_metrics <- list(
  schema_version = "paperA-v4-phase17-key-metrics-v1",
  generated_at_utc = format(
    Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"
  ),
  decision = decision$decision,
  gate = list(
    passed = sum(gate$pass),
    total = nrow(gate),
    failed = sum(!gate$pass)
  ),
  dataset = list(
    object = "mokken::SWMDK",
    respondents = 639,
    clusters = 30,
    cluster_size_range = c(5L, 29L),
    minimum_fixed_category_count = min(category$count),
    minimum_fixed_category_mass = min(category$mass)
  ),
  method = list(
    gamma_cluster = method_lock$final_gamma_cluster,
    width_multiplier_at_G_30 =
      protocol$method$selected$multiplier_at_G_30,
    selected_to_raw_length_ratio =
      protocol$method$selected$multiplier_at_G_30,
    observed_selected_to_raw_length_ratio_range = range(
      selected_raw$selected_to_raw_length_ratio
    ),
    maximum_invalid_fraction =
      decision$execution$maximum_invalid_fraction,
    maximum_split_half_endpoint_difference =
      max(stability$maximum_endpoint_difference),
    split_half_threshold =
      protocol$precision$
        split_half_endpoint_stability_threshold
  ),
  teacher = list(
    respondent_point_H =
      metric_for(selected, "teacher", "respondent",
                 "point_estimate"),
    respondent_selected_interval = c(
      lower = metric_for(
        selected, "teacher", "respondent", "lower"
      ),
      upper = metric_for(
        selected, "teacher", "respondent", "upper"
      )
    ),
    respondent_selected_length =
      metric_for(
        selected, "teacher", "respondent", "interval_length"
      ),
    equal_cluster_point_H =
      metric_for(
        selected, "teacher", "equal_cluster",
        "point_estimate"
      ),
    equal_cluster_selected_interval = c(
      lower = metric_for(
        selected, "teacher", "equal_cluster", "lower"
      ),
      upper = metric_for(
        selected, "teacher", "equal_cluster", "upper"
      )
    ),
    target_difference =
      diagnostic_for(
        "teacher", "equal_cluster",
        "target_difference_from_respondent"
      ),
    ICC = icc_for("teacher"),
    respondent_exact_knot_count =
      diagnostic_for(
        "teacher", "respondent", "exact_knot_count"
      )
  ),
  classmate = list(
    respondent_point_H =
      metric_for(selected, "classmate", "respondent",
                 "point_estimate"),
    respondent_selected_interval = c(
      lower = metric_for(
        selected, "classmate", "respondent", "lower"
      ),
      upper = metric_for(
        selected, "classmate", "respondent", "upper"
      )
    ),
    respondent_selected_length =
      metric_for(
        selected, "classmate", "respondent", "interval_length"
      ),
    equal_cluster_point_H =
      metric_for(
        selected, "classmate", "equal_cluster",
        "point_estimate"
      ),
    equal_cluster_selected_interval = c(
      lower = metric_for(
        selected, "classmate", "equal_cluster", "lower"
      ),
      upper = metric_for(
        selected, "classmate", "equal_cluster", "upper"
      )
    ),
    target_difference =
      diagnostic_for(
        "classmate", "equal_cluster",
        "target_difference_from_respondent"
      ),
    ICC = icc_for("classmate"),
    respondent_exact_knot_count =
      diagnostic_for(
        "classmate", "respondent", "exact_knot_count"
      )
  ),
  comparator_context = list(
    selected_to_delta_length_ratio = list(
      teacher =
        selected_delta$selected_to_delta_length_ratio[
          selected_delta$scale == "teacher"
        ][1L],
      classmate =
        selected_delta$selected_to_delta_length_ratio[
          selected_delta$scale == "classmate"
        ][1L]
    ),
    working_independence_is_a_comparator_not_the_target = TRUE
  ),
  interpretation = list(
    primary_target =
      "respondent-weighted cluster-superpopulation posterior-functional interval",
    equal_cluster_is_sensitivity = TRUE,
    formal_H_threshold_decision = FALSE,
    exact_knot_is_empirical_diagnostic_only = TRUE,
    source_crosswalk_status = crosswalk$status
  ),
  phase18_authorized = FALSE,
  terminal_state = "STOP_AT_G17_BEFORE_PHASE18"
)
key_metrics_path <- file.path(
  artifact_root, "v4-phase17-key-metrics-v1.json"
)
jsonlite::write_json(
  key_metrics, key_metrics_path, pretty = TRUE,
  auto_unbox = TRUE, digits = 16, null = "null"
)

generated_times <- vapply(
  receipts, `[[`, character(1), "generated_at_utc"
)
elapsed <- vapply(
  receipts, `[[`, numeric(1), "elapsed_seconds"
)
execution_receipt <- list(
  schema_version =
    "paperA-v4-phase17-aws-execution-receipt-v1",
  generated_at_utc = format(
    Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"
  ),
  status = "PASS_AWS_EXECUTION_AND_RAW_TRANSFER",
  provider = "AWS_ONLY",
  instance = list(
    id = "i-0ad4ffafc8bb19ff0",
    name = "simulation-aws",
    type = "c6a.8xlarge",
    vcpus = 32,
    memory_total_kb = 64524224,
    memory_available_kb_at_preflight = 63394500,
    state_after_execution = "stopped"
  ),
  workers = list(
    protocol_count = protocol$compute$workers,
    used = 12
  ),
  execution = list(
    tasks = length(receipts),
    batches = sum(vapply(
      receipts, `[[`, numeric(1), "batches"
    )),
    draws_per_task =
      protocol$precision$draws_per_random_weight_task,
    total_random_weight_draws = sum(vapply(
      receipts, `[[`, numeric(1), "draws"
    )),
    first_task_receipt_utc = min(generated_times),
    last_task_receipt_utc = max(generated_times),
    maximum_task_elapsed_seconds = max(elapsed),
    sum_task_elapsed_seconds = sum(elapsed)
  ),
  raw_transfer = list(
    remote_raw_files = 36,
    local_draw_files = length(draw_files),
    local_batch_manifest_files = length(batch_files),
    local_receipt_files = length(receipt_files),
    receipt_hashes_passed = sum(receipt_hash_pass),
    receipt_code_hashes_passed =
      sum(receipt_code_hash_pass),
    raw_manifest_files = nrow(raw_manifest),
    download_completed_before_evaluation = TRUE
  ),
  execution_bundle = list(
    path = rel(bundle_path),
    sha256 = unname(tools::sha256sum(bundle_path)),
    uploaded_sha256 =
      "5ebf8ace89bf01563bb88e8faae57df00f2676ec4ee9117012e9720e6ced723f"
  ),
  gcp_accessed = FALSE,
  gcp_used = FALSE
)
execution_receipt_path <- file.path(
  artifact_root, "v4-phase17-aws-execution-receipt-v1.json"
)
jsonlite::write_json(
  execution_receipt, execution_receipt_path,
  pretty = TRUE, auto_unbox = TRUE,
  digits = 16, null = "null"
)

baseline_hash <- unname(tools::sha256sum(
  file.path(project_root, baseline$project_relative_path)
))
evaluator_manifest_hash <- unname(tools::sha256sum(
  file.path(
    project_root,
    evaluator_manifest$project_relative_path
  )
))
code_lock_pass <- vapply(
  names(code_lock$files), function(name) {
    file <- code_lock$files[[name]]
    identical(
      unname(tools::sha256sum(
        file.path(project_root, file$path)
      )),
      file$sha256
    )
  },
  logical(1)
)
raw_manifest_hash <- unname(tools::sha256sum(
  file.path(project_root, raw_manifest$project_relative_path)
))

closure_checks <- data.frame(
  check_id = c(
    "P17F-001_AUTHORITY",
    "P17F-002_ZERO_OUTPUT_AUTHORITY",
    "P17F-003_PROTOCOL_LOCK",
    "P17F-004_CODE_LOCK",
    "P17F-005_PREOUTCOME_TESTS",
    "P17F-006_PARENT_METHOD",
    "P17F-007_AWS_ONLY",
    "P17F-008_TASK_COMPLETION",
    "P17F-009_DRAW_COMPLETION",
    "P17F-010_BATCH_COMPLETION",
    "P17F-011_RECEIPT_HASHES",
    "P17F-012_RECEIPT_CODE_HASHES",
    "P17F-013_RAW_MANIFEST",
    "P17F-014_RAW_FIRST",
    "P17F-015_G17_DECISION",
    "P17F-016_G17_GATES",
    "P17F-017_INVALID_FRACTION",
    "P17F-018_SELECTED_INTERVALS",
    "P17F-019_STABILITY",
    "P17F-020_DISCLOSURES",
    "P17F-021_EVALUATOR_EVIDENCE",
    "P17F-022_PROTECTED_BASELINE",
    "P17F-023_AWS_STOPPED",
    "P17F-024_PHASE18_BLOCKED",
    "P17F-025_SOURCE_RESTRICTION",
    "P17F-026_TERMINAL_STATE"
  ),
  criterion = c(
    "Phase 17 authority is valid through G17 only",
    "Authority was issued before empirical outputs",
    "Outcome-blind protocol lock is intact",
    "All execution code-lock hashes remain intact",
    "All pre-outcome executable tests passed",
    "Phase 16 confirmed method and gamma are inherited",
    "Heavy compute used AWS and never GCP",
    "All 12 prespecified tasks completed",
    "All 1,199,988 random-weight draws completed",
    "All 600 prespecified batches completed",
    "All raw output hashes match task receipts",
    "All task code hashes match the pre-outcome code lock",
    "All 36 local raw files match the raw manifest",
    "Raw download completed before frozen evaluation",
    "Frozen evaluator returned the G17 pass decision",
    "All 14 blocking G17 criteria passed",
    "Maximum invalid fraction is zero",
    "All four selected intervals are valid and contain point H",
    "All selected split-half endpoint differences pass",
    "ICC, sparse-category, target, and knot disclosures exist",
    "All frozen-evaluator evidence hashes remain intact",
    "Protected Step 14.1 baseline remains intact",
    "AWS instance was stopped after raw transfer",
    "Phase 18 remains unauthorized",
    "Original-source crosswalk restriction remains explicit",
    "Terminal state stops at G17 before Phase 18"
  ),
  pass = c(
    identical(
      authority$status,
      "AUTHORIZED_PHASE17_TO_G17_ONLY"
    ) && isFALSE(authority$phase18_authorized),
    authority$output_count_at_authorization == 0L,
    identical(
      protocol_lock$status,
      "PASS_FROZEN_PRE_PHASE17_EMPIRICAL_OUTCOME"
    ) &&
      protocol_lock$execution_output_count_at_lock == 0L,
    all(code_lock_pass) &&
      code_lock$execution_output_count_at_code_lock == 0L,
    identical(test_receipt$status, "PASS") &&
      test_receipt$tests_passed == 17L &&
      all(test_results$pass),
    identical(
      parent$decision,
      "CONFIRM_CLUSTER_POLYTOMOUS_METHOD"
    ) &&
      method_lock$final_gamma_cluster == -1.5,
    identical(protocol$compute$heavy_provider, "AWS_ONLY") &&
      isFALSE(protocol$compute$gcp_allowed) &&
      isFALSE(execution_receipt$gcp_accessed) &&
      isFALSE(execution_receipt$gcp_used),
    length(receipts) == 12L &&
      setequal(receipt_task_ids, design$task_id) &&
      all(vapply(receipts, function(receipt) {
        identical(receipt$status, "PASS_TASK_COMPLETE")
      }, logical(1))),
    sum(vapply(
      receipts, `[[`, numeric(1), "draws"
    )) == 1199988L,
    sum(vapply(
      receipts, `[[`, numeric(1), "batches"
    )) == 600L,
    all(receipt_hash_pass),
    all(receipt_code_hash_pass),
    nrow(raw_manifest) == 36L &&
      all(raw_manifest_hash == raw_manifest$sha256),
    isTRUE(
      decision$execution$
        raw_download_complete_before_evaluation
    ),
    identical(
      decision$decision,
      "PROCEED_TO_PHASE18_REVIEW"
    ),
    nrow(gate) == 14L && all(gate$pass),
    decision$execution$maximum_invalid_fraction == 0,
    nrow(selected) == 4L &&
      all(selected$lower < selected$upper) &&
      all(selected$lower <= selected$point_estimate) &&
      all(selected$point_estimate <= selected$upper),
    nrow(stability) == 4L && all(stability$pass),
    nrow(icc) == 2L &&
      nrow(category) == 55L &&
      nrow(diagnostics) == 4L &&
      any(diagnostics$exact_knot_count > 0L),
    all(
      evaluator_manifest_hash ==
        evaluator_manifest$sha256
    ),
    all(baseline_hash == baseline$sha256),
    identical(
      execution_receipt$instance$state_after_execution,
      "stopped"
    ),
    isFALSE(decision$phase18_authorized) &&
      isFALSE(protocol$phase18$authorized),
    identical(
      crosswalk$status,
      "SCHEDULED_UNRESOLVED_PRODUCTION_BLOCKER"
    ),
    identical(
      decision$terminal_state,
      "STOP_AT_G17_BEFORE_PHASE18"
    )
  ),
  stringsAsFactors = FALSE
)
closure_checks$observed <- ifelse(
  closure_checks$pass, "PASS", "FAIL"
)
closure_checks_path <- file.path(
  artifact_root, "v4-phase17-final-closure-checks-v1.csv"
)
utils::write.csv(
  closure_checks, closure_checks_path, row.names = FALSE
)

result_files <- list.files(
  result_root, full.names = TRUE
)
evidence_files <- unique(c(
  authority_path, protocol_path, protocol_lock_path,
  code_lock_path, design_path, test_runner_path,
  test_results_path, test_receipt_path, runner_path,
  launcher_path, evaluator_path, finalizer_path, bundle_path,
  parent_path, method_lock_path, raw_files, log_files,
  result_files, gate_path, decision_path,
  evaluator_manifest_path, raw_manifest_path,
  key_metrics_path, execution_receipt_path,
  closure_checks_path, baseline_path, crosswalk_path
))
stopifnot(all(file.exists(evidence_files)))
final_evidence <- data.frame(
  project_relative_path = rel(evidence_files),
  size_bytes = as.numeric(file.info(evidence_files)$size),
  sha256 = unname(tools::sha256sum(evidence_files)),
  stringsAsFactors = FALSE
)
final_evidence_path <- file.path(
  artifact_root,
  "v4-phase17-final-evidence-manifest-v1.csv"
)
utils::write.csv(
  final_evidence, final_evidence_path, row.names = FALSE
)

closure_receipt <- list(
  schema_version =
    "paperA-v4-phase17-final-closure-receipt-v1",
  generated_at_utc = format(
    Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"
  ),
  decision = decision$decision,
  status = if (all(closure_checks$pass)) {
    "PHASE17_EMPIRICAL_APPLICATION_COMPLETE"
  } else {
    "PHASE17_CLOSURE_FAILED"
  },
  dataset = decision$dataset,
  method = decision$method,
  execution = decision$execution,
  blocking_gates = list(
    passed = sum(gate$pass),
    total = nrow(gate),
    failed = sum(!gate$pass),
    path = rel(gate_path),
    sha256 = unname(tools::sha256sum(gate_path))
  ),
  closure_checks = list(
    passed = sum(closure_checks$pass),
    total = nrow(closure_checks),
    failed = sum(!closure_checks$pass),
    path = rel(closure_checks_path),
    sha256 = unname(tools::sha256sum(closure_checks_path))
  ),
  key_metrics = list(
    path = rel(key_metrics_path),
    sha256 = unname(tools::sha256sum(key_metrics_path))
  ),
  raw_manifest = list(
    path = rel(raw_manifest_path),
    files = nrow(raw_manifest),
    sha256 = unname(tools::sha256sum(raw_manifest_path))
  ),
  evidence_manifest = list(
    path = rel(final_evidence_path),
    files = nrow(final_evidence),
    sha256 = unname(tools::sha256sum(final_evidence_path))
  ),
  compute = list(
    provider = "AWS_ONLY",
    workers = 12,
    instance_state = "stopped",
    gcp_accessed = FALSE,
    gcp_used = FALSE
  ),
  restrictions = list(
    formal_H_threshold_decision = FALSE,
    source_crosswalk_status = crosswalk$status
  ),
  phase18_authorized = FALSE,
  terminal_state = "STOP_AT_G17_BEFORE_PHASE18"
)
closure_receipt_path <- file.path(
  artifact_root,
  "v4-phase17-final-closure-receipt-v1.json"
)
jsonlite::write_json(
  closure_receipt, closure_receipt_path,
  pretty = TRUE, auto_unbox = TRUE,
  digits = 16, null = "null"
)
message(
  closure_receipt$decision, ": G17 ",
  closure_receipt$blocking_gates$passed, "/",
  closure_receipt$blocking_gates$total,
  "; closure ",
  closure_receipt$closure_checks$passed, "/",
  closure_receipt$closure_checks$total, "."
)
if (!all(closure_checks$pass)) {
  print(closure_checks[!closure_checks$pass, ])
  quit(status = 1L)
}
