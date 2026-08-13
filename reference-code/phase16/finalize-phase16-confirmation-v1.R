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
confirm_root <- file.path(v4_root, "confirmatory")
artifact_root <- file.path(confirm_root, "artifacts")
raw_root <- file.path(confirm_root, "aws-raw")
dir.create(artifact_root, recursive = TRUE, showWarnings = FALSE)

read_json <- function(path) {
  jsonlite::read_json(path, simplifyVector = TRUE)
}
rel <- function(path) {
  sub(paste0("^", project_root, "/"), "", path)
}
path_v4 <- function(...) file.path(v4_root, ...)

authority_path <- file.path(
  confirm_root, "v4-phase16-fresh-confirmation-authority-v1.json"
)
protocol_path <- file.path(
  confirm_root, "v4-phase16-confirmation-protocol-v1.yml"
)
design_path <- file.path(
  confirm_root, "v4-phase16-confirmation-design-v1.csv"
)
method_lock_path <- path_v4(
  "validation", "artifacts",
  "v4-phase15-final-method-lock-v1.json"
)
ready_receipt_path <- file.path(
  artifact_root, "v4-phase16-protocol-ready-receipt-v1.json"
)
runner_path <- file.path(confirm_root, "run-phase16-cell-v1.R")
launcher_path <- file.path(
  confirm_root, "run-phase16-authorized-aws-v1.sh"
)
evaluator_path <- file.path(
  confirm_root, "evaluate-phase16-confirmation-v1.R"
)
decision_path <- file.path(
  artifact_root, "v4-phase16-confirmation-decision-v1.json"
)
overall_path <- file.path(
  artifact_root, "v4-phase16-confirmation-overall-summary-v1.csv"
)
cell_path <- file.path(
  artifact_root, "v4-phase16-confirmation-cell-summary-v1.csv"
)
subgroup_path <- file.path(
  artifact_root, "v4-phase16-confirmation-subgroup-summary-v1.csv"
)
evaluator_gate_path <- file.path(
  artifact_root, "v4-phase16-confirmation-gate-checks-v1.csv"
)
raw_manifest_path <- file.path(
  artifact_root, "v4-phase16-confirmation-raw-manifest-v1.csv"
)
bundle_path <- file.path(
  artifact_root, "execution-bundles",
  "v4-phase16-aws-execution-bundle-v1.tar.gz"
)
baseline_path <- path_v4(
  "governance", "v4-source-and-freeze-inventory-v1.csv"
)
crosswalk_path <- path_v4(
  "protocol", "v4-original-source-crosswalk-schedule-v1.json"
)

required <- c(
  authority_path, protocol_path, design_path, method_lock_path,
  ready_receipt_path, runner_path, launcher_path, evaluator_path,
  decision_path, overall_path, cell_path, subgroup_path,
  evaluator_gate_path, raw_manifest_path, bundle_path,
  baseline_path, crosswalk_path
)
stopifnot(all(file.exists(required)))

authority <- read_json(authority_path)
protocol <- yaml::read_yaml(protocol_path)
design <- utils::read.csv(design_path, stringsAsFactors = FALSE)
method_lock <- read_json(method_lock_path)
ready <- read_json(ready_receipt_path)
decision <- read_json(decision_path)
overall <- utils::read.csv(
  overall_path, stringsAsFactors = FALSE
)
cell_summary <- utils::read.csv(
  cell_path, stringsAsFactors = FALSE
)
subgroups <- utils::read.csv(
  subgroup_path, stringsAsFactors = FALSE
)
evaluator_gate <- utils::read.csv(
  evaluator_gate_path, stringsAsFactors = FALSE
)
raw_manifest <- utils::read.csv(
  raw_manifest_path, stringsAsFactors = FALSE
)
baseline <- utils::read.csv(
  baseline_path, stringsAsFactors = FALSE
)
crosswalk <- read_json(crosswalk_path)

stopifnot(
  identical(
    authority$status,
    "AUTHORIZED_PHASE16_FRESH_CONFIRMATION"
  ),
  authority$output_count_at_authorization == 0L,
  identical(
    authority$protocol_sha256,
    unname(tools::sha256sum(protocol_path))
  ),
  identical(
    authority$method_lock_sha256,
    unname(tools::sha256sum(method_lock_path))
  ),
  identical(
    authority$runner_sha256,
    unname(tools::sha256sum(runner_path))
  ),
  identical(
    authority$launcher_sha256,
    unname(tools::sha256sum(launcher_path))
  ),
  identical(
    authority$evaluator_sha256,
    unname(tools::sha256sum(evaluator_path))
  ),
  identical(
    unname(tools::sha256sum(bundle_path)),
    "d4a252b5812f39e34345fdc8d6f252670da0cd444229a7662e06619695dd5614"
  ),
  identical(
    decision$decision,
    "CONFIRM_CLUSTER_POLYTOMOUS_METHOD"
  ),
  decision$checks_passed == 7L,
  decision$checks_total == 7L,
  isFALSE(decision$phase17_authorized),
  all(evaluator_gate$pass)
)

result_files <- list.files(
  raw_root,
  pattern = "^P16-C[0-9]{3}-replications-v1\\.csv$",
  full.names = TRUE
)
truth_files <- list.files(
  raw_root,
  pattern = "^P16-C[0-9]{3}-truth-v1\\.csv$",
  full.names = TRUE
)
receipt_files <- list.files(
  raw_root,
  pattern = "^P16-C[0-9]{3}-receipt-v1\\.json$",
  full.names = TRUE
)
receipts <- lapply(
  receipt_files, jsonlite::read_json, simplifyVector = TRUE
)
receipt_hash_pass <- vapply(receipts, function(receipt) {
  output_file <- file.path(project_root, receipt$output$path)
  truth_file <- file.path(project_root, receipt$truth$path)
  identical(
    unname(tools::sha256sum(output_file)),
    receipt$output$sha256
  ) && identical(
    unname(tools::sha256sum(truth_file)),
    receipt$truth$sha256
  )
}, logical(1))
raw_manifest_hash <- unname(tools::sha256sum(
  file.path(project_root, raw_manifest$project_relative_path)
))
confirmation <- do.call(rbind, lapply(
  result_files, utils::read.csv, stringsAsFactors = FALSE
))
rownames(confirmation) <- NULL
stopifnot(
  length(result_files) == 24L,
  length(truth_files) == 24L,
  length(receipt_files) == 24L,
  all(receipt_hash_pass),
  all(raw_manifest_hash == raw_manifest$sha256),
  nrow(confirmation) == 86400L,
  length(unique(paste(
    confirmation$cell_id, confirmation$replication
  ))) == 9600L,
  setequal(unique(confirmation$cell_id), design$cell_id),
  all(table(confirmation$cell_id) == 3600L),
  all(confirmation$stage == "confirmation"),
  setequal(
    unique(confirmation$gamma_cluster[
      confirmation$candidate
    ]),
    c(0, -1.5)
  )
)

summarize_rows <- function(data) {
  coverage <- mean(data$cover)
  data.frame(
    replications = nrow(data),
    coverage = coverage,
    coverage_mcse = sqrt(
      coverage * (1 - coverage) / nrow(data)
    ),
    mean_interval_length = mean(data$interval_length),
    median_interval_length =
      stats::median(data$interval_length),
    mean_bias = mean(data$bias),
    maximum_invalid_fraction =
      max(data$invalid_fraction, na.rm = TRUE),
    status_ok_fraction = mean(data$status == "OK"),
    stringsAsFactors = FALSE
  )
}
make_summary <- function(data, variables) {
  key <- do.call(
    interaction,
    c(data[variables], list(drop = TRUE, lex.order = TRUE))
  )
  groups <- split(data, key)
  output <- do.call(rbind, lapply(groups, function(rows) {
    cbind(
      rows[1L, variables, drop = FALSE],
      summarize_rows(rows)
    )
  }))
  rownames(output) <- NULL
  output
}

selected_gamma <- method_lock$final_gamma_cluster
selected <- confirmation[
  confirmation$candidate &
    abs(confirmation$gamma_cluster - selected_gamma) < 1e-12,
  ,
  drop = FALSE
]
selected$target <- ifelse(
  selected$target_id ==
    "V4-TARGET-RESPONDENT-WEIGHTED-v1",
  "respondent",
  "equal_cluster"
)
lane_summary <- make_summary(
  selected,
  c("regularity", "target", "method_id")
)
lane_summary_path <- file.path(
  artifact_root, "v4-phase16-confirmation-lane-summary-v1.csv"
)
utils::write.csv(
  lane_summary, lane_summary_path, row.names = FALSE
)

comparators <- confirmation[
  !confirmation$candidate, , drop = FALSE
]
comparator_summary <- make_summary(
  comparators,
  c("regularity", "method_id", "target_id")
)
comparator_summary_path <- file.path(
  artifact_root,
  "v4-phase16-confirmation-comparator-summary-v1.csv"
)
utils::write.csv(
  comparator_summary, comparator_summary_path, row.names = FALSE
)

target_row <- function(data, gamma, target) {
  row <- data[
    abs(data$gamma_cluster - gamma) < 1e-12 &
      data$target == target,
    ,
    drop = FALSE
  ]
  stopifnot(nrow(row) == 1L)
  row
}
selected_resp <- target_row(overall, selected_gamma, "respondent")
selected_cluster <- target_row(
  overall, selected_gamma, "equal_cluster"
)
raw_resp <- target_row(overall, 0, "respondent")
raw_cluster <- target_row(overall, 0, "equal_cluster")
selected_cells <- cell_summary[
  abs(cell_summary$gamma_cluster - selected_gamma) < 1e-12,
  ,
  drop = FALSE
]
selected_subgroups <- subgroups[
  abs(subgroups$gamma_cluster - selected_gamma) < 1e-12,
  ,
  drop = FALSE
]
length_ratio <- selected_resp$mean_interval_length /
  raw_resp$mean_interval_length
minimum_cell <- min(selected_cells$coverage)
minimum_g <- min(selected_subgroups$coverage[
  selected_subgroups$grouping_variable == "G"
])
minimum_size <- min(selected_subgroups$coverage[
  selected_subgroups$grouping_variable == "size_mechanism"
])
maximum_invalid <- max(selected$invalid_fraction)

acceptance <- protocol$acceptance
gate_evidence <- data.frame(
  criterion = c(
    "respondent_regular_coverage",
    "equal_cluster_regular_coverage",
    "minimum_regular_cell_coverage",
    "minimum_G_group_coverage",
    "minimum_size_mechanism_group_coverage",
    "maximum_invalid_fraction",
    "maximum_respondent_mean_length_to_raw_ratio"
  ),
  threshold = c(
    paste(
      acceptance$respondent_regular_coverage,
      collapse = " to "
    ),
    paste(
      acceptance$equal_cluster_regular_coverage,
      collapse = " to "
    ),
    paste0(">=", acceptance$minimum_regular_cell_coverage),
    paste0(">=", acceptance$minimum_G_group_coverage),
    paste0(
      ">=",
      acceptance$minimum_size_mechanism_group_coverage
    ),
    paste0("<=", acceptance$maximum_invalid_fraction),
    paste0(
      "<=",
      acceptance$
        maximum_respondent_mean_length_to_raw_ratio
    )
  ),
  observed = c(
    selected_resp$coverage,
    selected_cluster$coverage,
    minimum_cell,
    minimum_g,
    minimum_size,
    maximum_invalid,
    length_ratio
  ),
  pass = evaluator_gate$pass[
    match(
      c(
        "respondent_regular_coverage",
        "equal_cluster_regular_coverage",
        "minimum_regular_cell_coverage",
        "minimum_G_group_coverage",
        "minimum_size_mechanism_group_coverage",
        "maximum_invalid_fraction",
        "maximum_respondent_mean_length_to_raw_ratio"
      ),
      evaluator_gate$criterion
    )
  ],
  stringsAsFactors = FALSE
)
gate_evidence_path <- file.path(
  artifact_root,
  "v4-phase16-confirmation-gate-evidence-v1.csv"
)
utils::write.csv(
  gate_evidence, gate_evidence_path, row.names = FALSE
)

lane_value <- function(regularity, target, field) {
  row <- lane_summary[
    lane_summary$regularity == regularity &
      lane_summary$target == target,
    ,
    drop = FALSE
  ]
  stopifnot(nrow(row) == 1L)
  row[[field]]
}
metrics <- list(
  schema_version = "paperA-v4-phase16-key-metrics-v1",
  generated_at_utc = format(
    Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"
  ),
  decision = decision$decision,
  method = list(
    gamma_cluster = selected_gamma,
    respondent_method_id =
      method_lock$final_respondent_method_id,
    equal_cluster_method_id =
      method_lock$final_equal_cluster_method_id
  ),
  regular = list(
    replications_per_target = selected_resp$replications,
    respondent_coverage = selected_resp$coverage,
    respondent_coverage_mcse = selected_resp$coverage_mcse,
    equal_cluster_coverage = selected_cluster$coverage,
    equal_cluster_coverage_mcse =
      selected_cluster$coverage_mcse,
    respondent_mean_length =
      selected_resp$mean_interval_length,
    equal_cluster_mean_length =
      selected_cluster$mean_interval_length,
    raw_respondent_coverage = raw_resp$coverage,
    raw_equal_cluster_coverage = raw_cluster$coverage,
    raw_respondent_mean_length =
      raw_resp$mean_interval_length,
    selected_to_raw_length_ratio = length_ratio,
    minimum_cell_coverage = minimum_cell,
    minimum_G_group_coverage = minimum_g,
    minimum_size_mechanism_group_coverage = minimum_size,
    maximum_invalid_fraction = maximum_invalid
  ),
  diagnostic_lanes = list(
    near_knot_respondent_coverage =
      lane_value("near_knot", "respondent", "coverage"),
    near_knot_equal_cluster_coverage =
      lane_value("near_knot", "equal_cluster", "coverage"),
    exact_knot_respondent_coverage =
      lane_value("exact_knot", "respondent", "coverage"),
    exact_knot_equal_cluster_coverage =
      lane_value("exact_knot", "equal_cluster", "coverage")
  ),
  restrictions = list(
    regular_lane_is_decision_domain = TRUE,
    near_knot_is_diagnostic_only = TRUE,
    exact_knot_is_diagnostic_only = TRUE,
    source_crosswalk_status = crosswalk$status,
    phase17_authorized = FALSE
  )
)
metrics_path <- file.path(
  artifact_root, "v4-phase16-key-metrics-v1.json"
)
jsonlite::write_json(
  metrics, metrics_path, pretty = TRUE,
  auto_unbox = TRUE, digits = 16, null = "null"
)

generated_times <- vapply(
  receipts, `[[`, character(1), "generated_at_utc"
)
elapsed <- vapply(
  receipts, `[[`, numeric(1), "elapsed_seconds"
)
execution_receipt <- list(
  schema_version = "paperA-v4-phase16-aws-execution-receipt-v1",
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
    memory_total_kb = 64524216,
    memory_available_kb_at_preflight = 63437532,
    state_after_execution = "stopped"
  ),
  workers = list(
    protocol_count = protocol$compute$workers,
    authorized_count =
      authority$compute_override$authorized_worker_count,
    used = 24,
    override_scope = "worker_parallelism_only"
  ),
  execution = list(
    cells = length(receipts),
    replications = 9600,
    method_rows = nrow(confirmation),
    draws_per_replication =
      protocol$design$random_weight_draws,
    first_cell_receipt_utc = min(generated_times),
    last_cell_receipt_utc = max(generated_times),
    maximum_cell_elapsed_seconds = max(elapsed),
    sum_cell_elapsed_seconds = sum(elapsed)
  ),
  raw_transfer = list(
    remote_receipts = 24,
    local_result_files = length(result_files),
    local_truth_files = length(truth_files),
    local_receipt_files = length(receipt_files),
    receipt_hashes_passed = sum(receipt_hash_pass),
    raw_manifest_files = nrow(raw_manifest),
    download_completed_before_evaluation = TRUE
  ),
  execution_bundle = list(
    path = rel(bundle_path),
    sha256 = unname(tools::sha256sum(bundle_path)),
    uploaded_sha256 =
      "d4a252b5812f39e34345fdc8d6f252670da0cd444229a7662e06619695dd5614"
  ),
  gcp_accessed = FALSE,
  gcp_used = FALSE
)
execution_receipt_path <- file.path(
  artifact_root,
  "v4-phase16-aws-execution-receipt-v1.json"
)
jsonlite::write_json(
  execution_receipt, execution_receipt_path,
  pretty = TRUE, auto_unbox = TRUE,
  digits = 16, null = "null"
)

baseline_hash <- unname(tools::sha256sum(
  file.path(project_root, baseline$project_relative_path)
))
closure_checks <- data.frame(
  check_id = c(
    "P16F-001_AUTHORITY",
    "P16F-002_ZERO_OUTPUT_AUTHORIZATION",
    "P16F-003_PROTOCOL_HASH",
    "P16F-004_METHOD_LOCK_HASH",
    "P16F-005_EXECUTION_CODE_HASHES",
    "P16F-006_WORKER_OVERRIDE_ONLY",
    "P16F-007_AWS_ONLY",
    "P16F-008_CELL_COMPLETION",
    "P16F-009_REPLICATION_COMPLETION",
    "P16F-010_ROW_COMPLETION",
    "P16F-011_RECEIPT_HASHES",
    "P16F-012_RAW_MANIFEST_HASHES",
    "P16F-013_RAW_FIRST_EVALUATION",
    "P16F-014_FROZEN_METHOD_ONLY",
    "P16F-015_GATE_DECISION",
    "P16F-016_ALL_BLOCKING_GATES",
    "P16F-017_INVALID_FRACTION",
    "P16F-018_PROTECTED_BASELINE",
    "P16F-019_AWS_STOPPED",
    "P16F-020_PHASE17_BLOCKED",
    "P16F-021_SOURCE_RESTRICTION",
    "P16F-022_TERMINAL_STATE"
  ),
  criterion = c(
    "Fresh Phase 16 authority is valid",
    "Authority was issued before any confirmation output",
    "Frozen protocol hash matches authority",
    "Frozen method-lock hash matches authority",
    "Runner, launcher, evaluator, and execution bundle hashes match",
    "24-worker change is compute parallelism only",
    "Heavy compute used AWS and GCP remained prohibited",
    "All 24 cells completed",
    "All 9,600 replications completed",
    "All 86,400 method rows are present",
    "All 24 output/truth receipt hashes match",
    "All 72 raw-manifest hashes match",
    "Raw transfer completed before frozen evaluation",
    "Only locked gamma and raw comparator were evaluated",
    "Frozen evaluator confirmed the method",
    "All seven blocking criteria passed",
    "Selected method has zero invalid fraction",
    "Protected Step 14.1 baseline remains intact",
    "AWS instance was stopped after transfer",
    "Phase 17 remains unauthorized",
    "Original-source crosswalk restriction remains",
    "Stop before Phase 17"
  ),
  pass = c(
    identical(
      authority$status,
      "AUTHORIZED_PHASE16_FRESH_CONFIRMATION"
    ),
    authority$output_count_at_authorization == 0L,
    identical(
      authority$protocol_sha256,
      unname(tools::sha256sum(protocol_path))
    ),
    identical(
      authority$method_lock_sha256,
      unname(tools::sha256sum(method_lock_path))
    ),
    identical(
      authority$runner_sha256,
      unname(tools::sha256sum(runner_path))
    ) &&
      identical(
        authority$launcher_sha256,
        unname(tools::sha256sum(launcher_path))
      ) &&
      identical(
        authority$evaluator_sha256,
        unname(tools::sha256sum(evaluator_path))
      ) &&
      identical(
        unname(tools::sha256sum(bundle_path)),
        "d4a252b5812f39e34345fdc8d6f252670da0cd444229a7662e06619695dd5614"
      ),
    authority$compute_override$authorized_worker_count == 24L &&
      identical(
        authority$compute_override$override_scope,
        "worker_parallelism_only"
      ),
    identical(protocol$compute$provider, "AWS_ONLY") &&
      isFALSE(authority$compute_override$gcp_allowed) &&
      isFALSE(execution_receipt$gcp_accessed) &&
      isFALSE(execution_receipt$gcp_used),
    length(receipts) == 24L &&
      all(vapply(
        receipts,
        function(x) identical(x$status, "PASS_CELL_COMPLETE"),
        logical(1)
      )),
    length(unique(paste(
      confirmation$cell_id, confirmation$replication
    ))) == 9600L,
    nrow(confirmation) == 86400L,
    all(receipt_hash_pass),
    all(raw_manifest_hash == raw_manifest$sha256),
    isTRUE(decision$raw_download_complete_before_evaluation),
    setequal(
      unique(confirmation$gamma_cluster[
        confirmation$candidate
      ]),
      c(0, method_lock$final_gamma_cluster)
    ),
    identical(
      decision$decision,
      "CONFIRM_CLUSTER_POLYTOMOUS_METHOD"
    ),
    decision$checks_passed == 7L &&
      all(evaluator_gate$pass),
    maximum_invalid == 0,
    all(baseline_hash == baseline$sha256),
    identical(
      execution_receipt$instance$state_after_execution,
      "stopped"
    ),
    isFALSE(decision$phase17_authorized) &&
      isFALSE(authority$phase17_authorized),
    identical(
      protocol$restrictions$source_crosswalk,
      "unresolved_production_blocker"
    ),
    identical(
      authority$terminal_rule,
      "STOP_AT_PHASE16_CONFIRMATION_DECISION_BEFORE_PHASE17"
    )
  ),
  stringsAsFactors = FALSE
)
closure_checks$observed <- ifelse(
  closure_checks$pass, "PASS", "FAIL"
)
closure_checks_path <- file.path(
  artifact_root, "v4-phase16-final-closure-checks-v1.csv"
)
utils::write.csv(
  closure_checks, closure_checks_path, row.names = FALSE
)

evidence_files <- c(
  authority_path, protocol_path, design_path, method_lock_path,
  ready_receipt_path, runner_path, launcher_path, evaluator_path,
  bundle_path, decision_path, overall_path, cell_path,
  subgroup_path, evaluator_gate_path, gate_evidence_path,
  raw_manifest_path, lane_summary_path, comparator_summary_path,
  metrics_path, execution_receipt_path, closure_checks_path,
  baseline_path, crosswalk_path
)
stopifnot(all(file.exists(evidence_files)))
evidence_manifest <- data.frame(
  project_relative_path = rel(evidence_files),
  size_bytes = as.numeric(file.info(evidence_files)$size),
  sha256 = unname(tools::sha256sum(evidence_files)),
  stringsAsFactors = FALSE
)
evidence_manifest_path <- file.path(
  artifact_root, "v4-phase16-evidence-manifest-v1.csv"
)
utils::write.csv(
  evidence_manifest, evidence_manifest_path, row.names = FALSE
)

closure_receipt <- list(
  schema_version =
    "paperA-v4-phase16-final-closure-receipt-v1",
  generated_at_utc = format(
    Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"
  ),
  decision = decision$decision,
  status = if (all(closure_checks$pass)) {
    "PHASE16_CONFIRMATION_COMPLETE"
  } else {
    "PHASE16_CLOSURE_FAILED"
  },
  method = list(
    gamma_cluster = method_lock$final_gamma_cluster,
    respondent_method_id =
      method_lock$final_respondent_method_id,
    equal_cluster_method_id =
      method_lock$final_equal_cluster_method_id
  ),
  blocking_gates = list(
    passed = decision$checks_passed,
    total = decision$checks_total,
    failed = decision$checks_total - decision$checks_passed,
    evidence_path = rel(gate_evidence_path),
    evidence_sha256 =
      unname(tools::sha256sum(gate_evidence_path))
  ),
  closure_checks = list(
    passed = sum(closure_checks$pass),
    total = nrow(closure_checks),
    failed = sum(!closure_checks$pass),
    path = rel(closure_checks_path),
    sha256 = unname(tools::sha256sum(closure_checks_path))
  ),
  key_metrics = list(
    path = rel(metrics_path),
    sha256 = unname(tools::sha256sum(metrics_path))
  ),
  evidence_manifest = list(
    path = rel(evidence_manifest_path),
    files = nrow(evidence_manifest),
    sha256 =
      unname(tools::sha256sum(evidence_manifest_path))
  ),
  compute = list(
    workers = 24,
    instance_state = "stopped",
    gcp_accessed = FALSE,
    gcp_used = FALSE
  ),
  phase17_authorized = FALSE,
  terminal_state =
    "STOP_AT_PHASE16_CONFIRMATION_DECISION_BEFORE_PHASE17"
)
closure_receipt_path <- file.path(
  artifact_root,
  "v4-phase16-final-closure-receipt-v1.json"
)
jsonlite::write_json(
  closure_receipt, closure_receipt_path,
  pretty = TRUE, auto_unbox = TRUE,
  digits = 16, null = "null"
)
message(
  closure_receipt$decision, ": blocking gates ",
  closure_receipt$blocking_gates$passed, "/",
  closure_receipt$blocking_gates$total,
  "; closure checks ",
  closure_receipt$closure_checks$passed, "/",
  closure_receipt$closure_checks$total, "."
)
if (!all(closure_checks$pass)) {
  print(closure_checks[!closure_checks$pass, ])
  quit(status = 1L)
}
