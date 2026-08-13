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
raw_root <- file.path(confirm_root, "aws-raw")
artifact_root <- file.path(confirm_root, "artifacts")
dir.create(artifact_root, recursive = TRUE, showWarnings = FALSE)

authority_path <- file.path(
  confirm_root, "v4-phase16-fresh-confirmation-authority-v1.json"
)
if (!file.exists(authority_path)) {
  stop(
    "Phase 16 evaluation is blocked without fresh authority.",
    call. = FALSE
  )
}
authority <- jsonlite::read_json(
  authority_path, simplifyVector = TRUE
)
stopifnot(identical(
  authority$status,
  "AUTHORIZED_PHASE16_FRESH_CONFIRMATION"
))

protocol_path <- file.path(
  confirm_root, "v4-phase16-confirmation-protocol-v1.yml"
)
design_path <- file.path(
  confirm_root, "v4-phase16-confirmation-design-v1.csv"
)
method_lock_path <- file.path(
  v4_root, "validation", "artifacts",
  "v4-phase15-final-method-lock-v1.json"
)
protocol <- yaml::read_yaml(protocol_path)
design <- utils::read.csv(design_path, stringsAsFactors = FALSE)
method_lock <- jsonlite::read_json(
  method_lock_path, simplifyVector = TRUE
)
stopifnot(
  identical(
    protocol$status,
    "FROZEN_PROTOCOL_READY_NOT_EXECUTED"
  ),
  identical(
    method_lock$status,
    "LOCKED_FOR_PHASE16_CONFIRMATION"
  ),
  protocol$method$gamma_cluster ==
    method_lock$final_gamma_cluster,
  identical(
    unname(tools::sha256sum(protocol_path)),
    authority$protocol_sha256
  ),
  identical(
    unname(tools::sha256sum(method_lock_path)),
    authority$method_lock_sha256
  )
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
stopifnot(
  length(result_files) == protocol$design$cells,
  length(truth_files) == protocol$design$cells,
  length(receipt_files) == protocol$design$cells
)
receipts <- lapply(
  receipt_files, jsonlite::read_json, simplifyVector = TRUE
)
stopifnot(
  setequal(
    vapply(receipts, `[[`, character(1), "cell_id"),
    design$cell_id
  ),
  all(vapply(
    receipts,
    function(x) identical(x$status, "PASS_CELL_COMPLETE"),
    logical(1)
  )),
  all(vapply(
    receipts,
    function(x) x$replications ==
      protocol$design$replications_per_cell,
    logical(1)
  ))
)
hash_matches <- vapply(receipts, function(receipt) {
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
stopifnot(all(hash_matches))

confirmation <- do.call(rbind, lapply(
  result_files, utils::read.csv, stringsAsFactors = FALSE
))
candidate <- confirmation[
  confirmation$candidate &
    confirmation$regularity == "regular",
  ,
  drop = FALSE
]
selected_gamma <- protocol$method$gamma_cluster
stopifnot(
  setequal(unique(candidate$gamma_cluster), c(0, selected_gamma)),
  length(unique(paste(
    confirmation$cell_id, confirmation$replication
  ))) == protocol$design$scheduled_replications
)
candidate$target <- ifelse(
  candidate$target_id ==
    "V4-TARGET-RESPONDENT-WEIGHTED-v1",
  "respondent",
  "equal_cluster"
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
    median_interval_length = stats::median(data$interval_length),
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
overall <- make_summary(
  candidate, c("gamma_cluster", "method_id", "target")
)
cell_summary <- make_summary(
  candidate,
  c("gamma_cluster", "method_id", "target", "cell_id")
)
g_summary <- make_summary(
  candidate,
  c("gamma_cluster", "method_id", "target", "G")
)
g_summary$grouping_variable <- "G"
g_summary$grouping_value <- as.character(g_summary$G)
g_summary$G <- NULL
size_summary <- make_summary(
  candidate,
  c(
    "gamma_cluster", "method_id", "target",
    "size_mechanism"
  )
)
size_summary$grouping_variable <- "size_mechanism"
size_summary$grouping_value <- size_summary$size_mechanism
size_summary$size_mechanism <- NULL
subgroups <- rbind(g_summary, size_summary)

selected <- overall[
  abs(overall$gamma_cluster - selected_gamma) < 1e-12,
  ,
  drop = FALSE
]
raw <- overall[
  abs(overall$gamma_cluster) < 1e-12,
  ,
  drop = FALSE
]
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
target_row <- function(data, target) {
  row <- data[data$target == target, , drop = FALSE]
  stopifnot(nrow(row) == 1L)
  row
}
selected_resp <- target_row(selected, "respondent")
selected_cluster <- target_row(selected, "equal_cluster")
raw_resp <- target_row(raw, "respondent")
acceptance <- protocol$acceptance
checks <- c(
  respondent_regular_coverage =
    selected_resp$coverage >=
      acceptance$respondent_regular_coverage[1L] &&
    selected_resp$coverage <=
      acceptance$respondent_regular_coverage[2L],
  equal_cluster_regular_coverage =
    selected_cluster$coverage >=
      acceptance$equal_cluster_regular_coverage[1L] &&
    selected_cluster$coverage <=
      acceptance$equal_cluster_regular_coverage[2L],
  minimum_regular_cell_coverage =
    min(selected_cells$coverage) >=
      acceptance$minimum_regular_cell_coverage,
  minimum_G_group_coverage =
    min(selected_subgroups$coverage[
      selected_subgroups$grouping_variable == "G"
    ]) >= acceptance$minimum_G_group_coverage,
  minimum_size_mechanism_group_coverage =
    min(selected_subgroups$coverage[
      selected_subgroups$grouping_variable == "size_mechanism"
    ]) >= acceptance$minimum_size_mechanism_group_coverage,
  maximum_invalid_fraction =
    max(selected$maximum_invalid_fraction) <=
      acceptance$maximum_invalid_fraction,
  maximum_respondent_mean_length_to_raw_ratio =
    selected_resp$mean_interval_length /
      raw_resp$mean_interval_length <=
      acceptance$maximum_respondent_mean_length_to_raw_ratio
)
decision <- if (all(checks)) {
  acceptance$success_decision
} else {
  acceptance$failure_decision
}

overall_path <- file.path(
  artifact_root, "v4-phase16-confirmation-overall-summary-v1.csv"
)
cell_path <- file.path(
  artifact_root, "v4-phase16-confirmation-cell-summary-v1.csv"
)
subgroup_path <- file.path(
  artifact_root, "v4-phase16-confirmation-subgroup-summary-v1.csv"
)
gate_path <- file.path(
  artifact_root, "v4-phase16-confirmation-gate-checks-v1.csv"
)
manifest_path <- file.path(
  artifact_root, "v4-phase16-confirmation-raw-manifest-v1.csv"
)
receipt_path <- file.path(
  artifact_root, "v4-phase16-confirmation-decision-v1.json"
)
utils::write.csv(overall, overall_path, row.names = FALSE)
utils::write.csv(cell_summary, cell_path, row.names = FALSE)
utils::write.csv(subgroups, subgroup_path, row.names = FALSE)
gate <- data.frame(
  criterion = names(checks),
  pass = unname(checks),
  stringsAsFactors = FALSE
)
utils::write.csv(gate, gate_path, row.names = FALSE)
manifest_files <- sort(c(result_files, truth_files, receipt_files))
manifest <- data.frame(
  project_relative_path = sub(
    paste0("^", project_root, "/"), "", manifest_files
  ),
  size_bytes = as.numeric(file.info(manifest_files)$size),
  sha256 = unname(tools::sha256sum(manifest_files)),
  stringsAsFactors = FALSE
)
utils::write.csv(manifest, manifest_path, row.names = FALSE)

receipt <- list(
  schema_version = "paperA-v4-phase16-confirmation-decision-v1",
  generated_at_utc = format(
    Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"
  ),
  decision = decision,
  checks_passed = sum(checks),
  checks_total = length(checks),
  selected_gamma_cluster = selected_gamma,
  raw_download_complete_before_evaluation = TRUE,
  phase17_authorized = FALSE,
  note = paste(
    "Phase 17 requires separate authority even after a",
    "successful confirmation decision."
  ),
  source_hashes = list(
    protocol_sha256 = unname(tools::sha256sum(protocol_path)),
    method_lock_sha256 =
      unname(tools::sha256sum(method_lock_path)),
    raw_manifest_sha256 =
      unname(tools::sha256sum(manifest_path)),
    gate_checks_sha256 = unname(tools::sha256sum(gate_path))
  )
)
jsonlite::write_json(
  receipt, receipt_path, pretty = TRUE,
  auto_unbox = TRUE, digits = 16, null = "null"
)
message(
  "PASS: Phase 16 confirmation evaluated; decision = ",
  decision, "."
)
