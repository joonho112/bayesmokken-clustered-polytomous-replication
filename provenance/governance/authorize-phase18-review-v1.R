project_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
v4_root <- file.path(
  project_root,
  "codebase", "research", "v4", "cluster-polytomous"
)
phase18_root <- file.path(v4_root, "phase18-review")
governance_root <- file.path(v4_root, "governance")
phase17_closure_path <- file.path(
  v4_root, "empirical-swmdk", "phase17", "artifacts",
  "v4-phase17-final-closure-receipt-v1.json"
)
phase17_gate_path <- file.path(
  v4_root, "empirical-swmdk", "phase17", "artifacts",
  "v4-g17-gate-criteria-v1.csv"
)
source_schedule_path <- file.path(
  v4_root, "protocol",
  "v4-original-source-crosswalk-schedule-v1.json"
)
baseline_path <- file.path(
  governance_root, "v4-source-and-freeze-inventory-v1.csv"
)
out_path <- file.path(
  governance_root, "v4-phase18-review-authority-v1.json"
)

stopifnot(all(file.exists(c(
  phase17_closure_path, phase17_gate_path,
  source_schedule_path, baseline_path
))))
closure <- jsonlite::read_json(
  phase17_closure_path, simplifyVector = TRUE
)
gate <- utils::read.csv(
  phase17_gate_path, stringsAsFactors = FALSE
)
source_schedule <- jsonlite::read_json(
  source_schedule_path, simplifyVector = TRUE
)
review_output_roots <- c(
  file.path(phase18_root, "sources", "original"),
  file.path(phase18_root, "sources", "extracted"),
  file.path(phase18_root, "results"),
  file.path(phase18_root, "artifacts")
)
existing_outputs <- unlist(lapply(
  review_output_roots,
  function(path) {
    if (dir.exists(path)) {
      list.files(
        path, recursive = TRUE, full.names = TRUE,
        all.files = FALSE
      )
    } else {
      character()
    }
  }
), use.names = FALSE)
existing_outputs <- existing_outputs[file.exists(existing_outputs)]

stopifnot(
  identical(
    closure$status,
    "PHASE17_EMPIRICAL_APPLICATION_COMPLETE"
  ),
  identical(
    closure$decision,
    "PROCEED_TO_PHASE18_REVIEW"
  ),
  closure$blocking_gates$passed == 14L,
  closure$blocking_gates$failed == 0L,
  all(gate$pass),
  isFALSE(closure$phase18_authorized),
  identical(
    closure$terminal_state,
    "STOP_AT_G17_BEFORE_PHASE18"
  ),
  identical(
    source_schedule$status,
    "SCHEDULED_UNRESOLVED_PRODUCTION_BLOCKER"
  ),
  length(existing_outputs) == 0L
)

receipt <- list(
  schema_version = "paperA-v4-phase18-review-authority-v1",
  generated_at_utc = format(
    Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"
  ),
  status = "AUTHORIZED_PHASE18_1_TO_G18A_ONLY",
  authority_text = "AUTHORIZE_PHASE18_1_THROUGH_G18A_ONLY",
  parent = list(
    phase17_status = closure$status,
    phase17_decision = closure$decision,
    phase17_closure_path = sub(
      paste0("^", project_root, "/"), "", phase17_closure_path
    ),
    phase17_closure_sha256 =
      unname(tools::sha256sum(phase17_closure_path)),
    phase17_gate_sha256 =
      unname(tools::sha256sum(phase17_gate_path))
  ),
  authorized = c(
    "Phase 18.1 authority and fail-closed review protocol",
    "lawful acquisition and local hashing of three original sources",
    "page-level formula/theorem mapping for article sources",
    "file-and-line mapping for the Andreadis software release",
    "assumption and difference ledger",
    "application and manuscript-claim eligibility decision at G18-A",
    "integrated-versus-dedicated paper architecture decision",
    "QMD, HTML, and machine-readable review evidence"
  ),
  explicitly_not_authorized = c(
    "production package source changes",
    "public cluster-polytomous API export",
    "manuscript drafting or section edits",
    "new empirical or simulation outcome generation",
    "post-Phase17 method or gamma tuning",
    "formal H threshold decision",
    "Phase 18 work after G18-A",
    "GCP access or use"
  ),
  source_scope = c(
    "Molenaar (1991)",
    "Rueschendorf (1982)",
    "Andreadis (2017) v1.0.0"
  ),
  output_count_at_authorization = length(existing_outputs),
  production_package_changes_at_authorization = FALSE,
  manuscript_drafting_at_authorization = FALSE,
  phase18_post_G18A_authorized = FALSE,
  required_stop = "STOP_AT_G18A_BEFORE_PACKAGE_OR_MANUSCRIPT"
)
jsonlite::write_json(
  receipt, out_path, pretty = TRUE,
  auto_unbox = TRUE, digits = 16, null = "null"
)
message(
  receipt$status, ": outputs = ",
  receipt$output_count_at_authorization,
  "; stop = ", receipt$required_stop, "."
)
