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
protocol_path <- file.path(
  confirm_root, "v4-phase16-confirmation-protocol-v1.yml"
)
method_lock_path <- file.path(
  v4_root, "validation", "artifacts",
  "v4-phase15-final-method-lock-v1.json"
)
ready_receipt_path <- file.path(
  confirm_root, "artifacts",
  "v4-phase16-protocol-ready-receipt-v1.json"
)
runner_path <- file.path(
  confirm_root, "run-phase16-cell-v1.R"
)
launcher_path <- file.path(
  confirm_root, "run-phase16-authorized-aws-v1.sh"
)
evaluator_path <- file.path(
  confirm_root, "evaluate-phase16-confirmation-v1.R"
)
authority_path <- file.path(
  confirm_root, "v4-phase16-fresh-confirmation-authority-v1.json"
)
raw_root <- file.path(confirm_root, "aws-raw")

required <- c(
  protocol_path, method_lock_path, ready_receipt_path,
  runner_path, launcher_path, evaluator_path
)
stopifnot(all(file.exists(required)))
protocol <- yaml::read_yaml(protocol_path)
method_lock <- jsonlite::read_json(
  method_lock_path, simplifyVector = TRUE
)
ready <- jsonlite::read_json(
  ready_receipt_path, simplifyVector = TRUE
)
raw_outputs <- if (dir.exists(raw_root)) {
  list.files(raw_root, all.files = FALSE, full.names = TRUE)
} else {
  character()
}

stopifnot(
  identical(
    protocol$status,
    "FROZEN_PROTOCOL_READY_NOT_EXECUTED"
  ),
  isFALSE(protocol$execution$authorized),
  isFALSE(protocol$execution$executed),
  protocol$execution$output_count_at_lock == 0L,
  identical(
    method_lock$status,
    "LOCKED_FOR_PHASE16_CONFIRMATION"
  ),
  identical(
    ready$decision,
    "READY_FOR_PHASE16_FRESH_CONFIRMATION_AWAITING_AUTHORIZATION"
  ),
  ready$checks$failed == 0L,
  isFALSE(ready$phase16_fresh_confirmation$authorized),
  isFALSE(ready$phase16_fresh_confirmation$executed),
  ready$phase16_fresh_confirmation$raw_output_count == 0L,
  length(raw_outputs) == 0L,
  !file.exists(authority_path)
)

authority <- list(
  schema_version =
    "paperA-v4-phase16-fresh-confirmation-authority-v1",
  recorded_at_utc = format(
    Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"
  ),
  authority_source = "author instruction",
  authority_text = "AUTHORIZE_PHASE16_FRESH_CONFIRMATION_WORKER_COUNT_NOT_CAPPED",
  status = "AUTHORIZED_PHASE16_FRESH_CONFIRMATION",
  authorized_scope = list(
    phase = 16,
    work = c(
      "execute the frozen fresh confirmation protocol",
      "download raw outputs before frozen evaluation",
      "issue the Phase 16 confirmation decision",
      "create machine-readable evidence and QMD+HTML log"
    ),
    required_stop =
      "STOP_AT_PHASE16_CONFIRMATION_DECISION_BEFORE_PHASE17"
  ),
  scientific_lock = list(
    protocol_path = sub(
      paste0("^", project_root, "/"), "", protocol_path
    ),
    method_lock_path = sub(
      paste0("^", project_root, "/"), "", method_lock_path
    ),
    method_label = method_lock$final_method_label,
    gamma_cluster = method_lock$final_gamma_cluster,
    tuning_permitted = FALSE,
    fallback_permitted = FALSE
  ),
  compute_override = list(
    provider = "AWS_ONLY",
    aws_alias = "aws-vm",
    protocol_worker_count = protocol$compute$workers,
    authorized_worker_count = 24,
    override_scope = "worker_parallelism_only",
    scientific_results_invariant_to_worker_count = TRUE,
    reason = paste(
      "User explicitly removed the 12-worker ceiling;",
      "24 leaves 8 of 32 vCPUs for system and I/O headroom."
    ),
    gcp_allowed = FALSE
  ),
  protocol_sha256 = unname(tools::sha256sum(protocol_path)),
  method_lock_sha256 =
    unname(tools::sha256sum(method_lock_path)),
  protocol_ready_receipt_sha256 =
    unname(tools::sha256sum(ready_receipt_path)),
  runner_sha256 = unname(tools::sha256sum(runner_path)),
  launcher_sha256 = unname(tools::sha256sum(launcher_path)),
  evaluator_sha256 = unname(tools::sha256sum(evaluator_path)),
  output_count_at_authorization = length(raw_outputs),
  phase17_authorized = FALSE,
  terminal_rule =
    "STOP_AT_PHASE16_CONFIRMATION_DECISION_BEFORE_PHASE17"
)
jsonlite::write_json(
  authority, authority_path, pretty = TRUE,
  auto_unbox = TRUE, digits = 16, null = "null"
)
message(
  "AUTHORIZED_PHASE16_FRESH_CONFIRMATION: worker override = ",
  authority$compute_override$authorized_worker_count,
  ", outputs at authorization = ",
  authority$output_count_at_authorization, "."
)
