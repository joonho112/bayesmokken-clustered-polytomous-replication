project_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
v4_root <- file.path(
  project_root,
  "codebase", "research", "v4", "cluster-polytomous"
)
governance_root <- file.path(v4_root, "governance")
phase17_root <- file.path(
  v4_root, "empirical-swmdk", "phase17"
)
parent_closure_path <- file.path(
  v4_root, "confirmatory", "artifacts",
  "v4-phase16-final-closure-receipt-v1.json"
)
parent_decision_path <- file.path(
  v4_root, "confirmatory", "artifacts",
  "v4-phase16-confirmation-decision-v1.json"
)
method_lock_path <- file.path(
  v4_root, "validation", "artifacts",
  "v4-phase15-final-method-lock-v1.json"
)
authority_path <- file.path(
  governance_root,
  "v4-phase17-empirical-application-authority-v1.json"
)

stopifnot(
  requireNamespace("jsonlite", quietly = TRUE),
  all(file.exists(c(
    parent_closure_path, parent_decision_path, method_lock_path
  ))),
  !file.exists(authority_path)
)
parent_closure <- jsonlite::read_json(
  parent_closure_path, simplifyVector = TRUE
)
parent_decision <- jsonlite::read_json(
  parent_decision_path, simplifyVector = TRUE
)
method_lock <- jsonlite::read_json(
  method_lock_path, simplifyVector = TRUE
)
phase17_outputs <- if (dir.exists(phase17_root)) {
  list.files(
    phase17_root,
    pattern = "\\.(csv|csv\\.gz|json|rds)$",
    recursive = TRUE,
    full.names = TRUE
  )
} else {
  character()
}
stopifnot(
  identical(
    parent_closure$decision,
    "CONFIRM_CLUSTER_POLYTOMOUS_METHOD"
  ),
  identical(
    parent_closure$status,
    "PHASE16_CONFIRMATION_COMPLETE"
  ),
  parent_closure$blocking_gates$failed == 0L,
  identical(
    parent_decision$decision,
    "CONFIRM_CLUSTER_POLYTOMOUS_METHOD"
  ),
  identical(
    method_lock$status,
    "LOCKED_FOR_PHASE16_CONFIRMATION"
  ),
  method_lock$final_gamma_cluster == -1.5,
  length(phase17_outputs) == 0L
)

authority <- list(
  schema_version =
    "paperA-v4-phase17-empirical-application-authority-v1",
  recorded_at_utc = format(
    Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"
  ),
  authority_source = "author instruction",
  authority_text = "AUTHORIZE_PHASE17_IN_FULL_STOP_BEFORE_PHASE18",
  status = "AUTHORIZED_PHASE17_TO_G17_ONLY",
  parent_phase16 = list(
    closure_path = sub(
      paste0("^", project_root, "/"), "", parent_closure_path
    ),
    closure_sha256 =
      unname(tools::sha256sum(parent_closure_path)),
    decision_path = sub(
      paste0("^", project_root, "/"), "", parent_decision_path
    ),
    decision_sha256 =
      unname(tools::sha256sum(parent_decision_path)),
    decision = parent_decision$decision
  ),
  locked_method = list(
    path = sub(
      paste0("^", project_root, "/"), "", method_lock_path
    ),
    sha256 = unname(tools::sha256sum(method_lock_path)),
    gamma_cluster = method_lock$final_gamma_cluster,
    respondent_method_id =
      method_lock$final_respondent_method_id,
    equal_cluster_method_id =
      method_lock$final_equal_cluster_method_id
  ),
  authorized_scope = list(
    phase = 17,
    work = c(
      "outcome-blind SWMDK empirical protocol lock",
      "fixed-scale high-precision random-weight execution",
      "primary respondent and equal-cluster sensitivity analysis",
      "prespecified comparator and diagnostic analysis",
      "G17 empirical application gate",
      "machine-readable evidence and QMD+HTML log"
    ),
    autonomous_repairs_within_scope = TRUE,
    heavy_compute_provider = "AWS_ONLY"
  ),
  explicitly_not_authorized = c(
    "Phase 18 package or application architecture",
    "production API changes",
    "item reselection or T-AISP",
    "scale modification or reverse-key changes",
    "post-outcome gamma tuning",
    "formal H threshold decision",
    "manuscript drafting or journal repositioning",
    "GCP access or use"
  ),
  output_count_at_authorization = length(phase17_outputs),
  required_stop = "STOP_AT_G17_BEFORE_PHASE18",
  phase18_authorized = FALSE
)
jsonlite::write_json(
  authority, authority_path, pretty = TRUE,
  auto_unbox = TRUE, digits = 16, null = "null"
)
message(
  "AUTHORIZED_PHASE17_TO_G17_ONLY: outputs at authority = ",
  authority$output_count_at_authorization, "."
)
