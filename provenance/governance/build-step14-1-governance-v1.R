project_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
v4_root <- file.path(
  project_root,
  "codebase", "research", "v4", "cluster-polytomous"
)
governance_root <- file.path(v4_root, "governance")

stopifnot(
  dir.exists(v4_root),
  dir.exists(governance_root),
  requireNamespace("jsonlite", quietly = TRUE)
)

project_path <- function(...) file.path(project_root, ...)
relative_path <- function(path) {
  prefix <- paste0(project_root, "/")
  sub(paste0("^", prefix), "", normalizePath(path, winslash = "/"))
}
sha256_file <- function(path) unname(tools::sha256sum(path))

required_directories <- c(
  "governance",
  "protocol",
  "R/core",
  "R/weights",
  "R/dgp",
  "R/evaluation",
  "oracles",
  "tests",
  "pilot",
  "development",
  "validation",
  "confirmatory",
  "empirical-swmdk",
  "artifacts"
)

make_rows <- function(paths, inventory_class, mutation_policy, reuse_policy) {
  paths <- sort(unique(paths))
  data.frame(
    inventory_class = inventory_class,
    mutation_policy = mutation_policy,
    reuse_policy = reuse_policy,
    project_relative_path = paths,
    stringsAsFactors = FALSE
  )
}

tree_files <- function(root, exclude = character()) {
  paths <- list.files(
    project_path(root),
    recursive = TRUE,
    full.names = TRUE,
    all.files = TRUE,
    include.dirs = FALSE,
    no.. = TRUE
  )
  rel <- vapply(paths, relative_path, character(1))
  if (length(exclude)) {
    remove <- Reduce(
      `|`,
      lapply(exclude, function(pattern) grepl(pattern, rel))
    )
    rel <- rel[!remove]
  }
  sort(rel)
}

authority_paths <- c(
  "log/034_handoff-cluster-polytomous-development.qmd",
  "log/034_handoff-cluster-polytomous-development.html",
  "log/033_phase13-ordinal-extension-feasibility.qmd",
  "log/033_phase13-ordinal-extension-feasibility.html",
  "log/008_phase08-polytomous-transport-g2.qmd",
  "log/008_phase08-polytomous-transport-g2.html",
  "theory/estimand/weight-law-separation.qmd",
  "theory/v3/manuscript-support/minimal-width-calibration-theory-note-v1.qmd"
)

phase13_paths <- tree_files(
  "codebase/research/v3/ordinal-extension-feasibility"
)
transport_paths <- tree_files("codebase/oracles/transport-lp")
package_paths <- tree_files(
  "codebase/bayesmokken",
  exclude = c(
    "/\\.\\.Rcheck/",
    "/\\.DS_Store$"
  )
)
frozen_evidence_paths <- c(
  paste0(
    "codebase/research/v3/confirmatory-restart/evaluation-runs/",
    "fresh-untouched-test-v1/final/result-lock-v1.json"
  ),
  paste0(
    "codebase/research/v3/confirmatory-restart/evaluation-runs/",
    "fresh-untouched-test-v1/final/family_metrics-v1.csv"
  ),
  paste0(
    "codebase/research/v3/confirmatory-restart/evaluation-runs/",
    "fresh-untouched-test-v1/final/gate_criteria-v1.csv"
  ),
  paste0(
    "codebase/research/v3/empirical-ppsrs/artifacts/",
    "ppsrs-empirical-analysis-receipt-v1.json"
  ),
  paste0(
    "codebase/research/v3/package-integration/artifacts/",
    "phase11-application-ready-receipt-v1.json"
  ),
  paste0(
    "codebase/research/v3/manuscript-positioning/artifacts/",
    "paper-a-journal-positioning-decision-v1.json"
  )
)

inventory <- rbind(
  make_rows(
    authority_paths,
    "authority_and_theory",
    "READ_ONLY",
    "CITE_OR_AUDIT_ONLY"
  ),
  make_rows(
    phase13_paths,
    "phase13_nonproduction_baseline",
    "READ_ONLY",
    "PORT_EXPLICITLY_INTO_V4_WITH_REGRESSION_TESTS"
  ),
  make_rows(
    transport_paths,
    "independent_transport_oracle",
    "READ_ONLY",
    "CALL_OR_COPY_EXPLICITLY_WITH_PROVENANCE"
  ),
  make_rows(
    package_paths,
    "frozen_binary_package_source",
    "NO_V4_MUTATION",
    "REGRESSION_FIXTURE_OR_EXPLICIT_PORT_ONLY"
  ),
  make_rows(
    frozen_evidence_paths,
    "frozen_binary_evidence",
    "IMMUTABLE",
    "BENCHMARK_OR_CITATION_ONLY"
  )
)

if (anyDuplicated(inventory$project_relative_path)) {
  duplicates <- unique(
    inventory$project_relative_path[
      duplicated(inventory$project_relative_path)
    ]
  )
  stop(
    "Duplicate baseline paths: ",
    paste(duplicates, collapse = ", "),
    call. = FALSE
  )
}

absolute_inventory_paths <- project_path(inventory$project_relative_path)
inventory$exists <- file.exists(absolute_inventory_paths)
stopifnot(all(inventory$exists))
inventory$size_bytes <- as.numeric(file.info(absolute_inventory_paths)$size)
inventory$sha256 <- vapply(
  absolute_inventory_paths,
  sha256_file,
  character(1)
)
inventory <- inventory[order(
  inventory$inventory_class,
  inventory$project_relative_path
), ]
rownames(inventory) <- NULL

inventory_path <- file.path(
  governance_root,
  "v4-source-and-freeze-inventory-v1.csv"
)
utils::write.csv(inventory, inventory_path, row.names = FALSE, na = "")

phase13_receipt <- jsonlite::read_json(
  project_path(
    "codebase/research/v3/ordinal-extension-feasibility/artifacts/",
    "phase13-feasibility-receipt-v1.json"
  ),
  simplifyVector = TRUE
)
package_receipt <- jsonlite::read_json(
  project_path(
    "codebase/research/v3/package-integration/artifacts/",
    "phase11-application-ready-receipt-v1.json"
  ),
  simplifyVector = TRUE
)
journal_receipt <- jsonlite::read_json(
  project_path(
    "codebase/research/v3/manuscript-positioning/artifacts/",
    "paper-a-journal-positioning-decision-v1.json"
  ),
  simplifyVector = TRUE
)

created_at_utc <- format(
  Sys.time(),
  tz = "UTC",
  format = "%Y-%m-%dT%H:%M:%SZ"
)
created_at_local <- format(
  Sys.time(),
  tz = "America/Chicago",
  format = "%Y-%m-%dT%H:%M:%S%z"
)

directory_contract <- lapply(
  required_directories,
  function(path) {
    list(
      path = path,
      purpose = switch(
        path,
        governance = "authority, firewalls, hashes, and receipts",
        protocol = "prospective estimand, method, DGP, and gate contracts",
        `R/core` = "weighted ordinal H and regularity diagnostics",
        `R/weights` = "iid and cluster random-weight laws",
        `R/dgp` = "clustered ordinal data-generating mechanisms",
        `R/evaluation` = "coverage, length, failure, and gate evaluation",
        oracles = "independent transport and population-truth calculations",
        tests = "research-only deterministic and stochastic tests",
        pilot = "Phase 14 low-cost feasibility work",
        development = "Phase 15 training and candidate development",
        validation = "Phase 15 disjoint held-out validation",
        confirmatory = "Phase 16 fresh untouched confirmation",
        `empirical-swmdk` = "fixed teacher and classmate scale analyses",
        artifacts = "branch-level receipts and manifests"
      )
    )
  }
)

inventory_counts <- as.list(table(inventory$inventory_class))
inventory_counts <- lapply(inventory_counts, as.integer)

manifest <- list(
  schema_version = "paperA-v4-cluster-polytomous-governance-manifest-v1",
  created_at_utc = created_at_utc,
  created_at_local = created_at_local,
  branch = list(
    project_relative_root =
      "codebase/research/v4/cluster-polytomous",
    status = "NONPRODUCTION_RESEARCH_ONLY",
    isolated_from_package = TRUE,
    production_api_connected = FALSE
  ),
  authority = list(
    source = "author instruction",
    instruction =
      "AUTHORIZE_STEP_14_1_V4_STRUCTURE_GOVERNANCE_AND_MASTER_PLAN",
    completed_scope = c(
      "create isolated v4 directory contract",
      "create machine-readable nonproduction governance",
      "hash reusable and protected evidence baseline",
      "write and render log 035 master plan"
    ),
    execution_beyond_step_14_1_authorized = FALSE
  ),
  terminal_control = list(
    completed_step = "14.1",
    current_terminal_state = "STOP_AFTER_STEP_14_1_V4_FOUNDATION",
    next_sequenced_step = "14.2 ESTIMAND_AND_SAMPLING_LAW_CONTRACT",
    fresh_instruction_required_for_next_step = TRUE,
    gate_before_phase_15 = "G14"
  ),
  scientific_state = list(
    frozen_binary_status = "CONFIRMED_AND_PROTECTED",
    ordinal_status = "FEASIBILITY_PASSED_WITH_RESTRICTIONS",
    cluster_polytomous_status = "NOT_IMPLEMENTED",
    primary_candidate =
      "SIZE_AWARE_TWO_STAGE_HIERARCHICAL_BAYESIAN_BOOTSTRAP",
    primary_candidate_accepted = FALSE,
    respondent_weighted_target_frozen = FALSE,
    equal_cluster_target_frozen = FALSE,
    cluster_calibration_frozen = FALSE
  ),
  authorization_firewall = list(
    production_authorized = FALSE,
    package_change_authorized = FALSE,
    manuscript_drafting_authorized = FALSE,
    manuscript_claim_upgrade_authorized = FALSE,
    phase15_calibration_authorized = FALSE,
    phase16_confirmation_authorized = FALSE,
    phase17_empirical_claim_authorized = FALSE,
    binary_gamma_0_25_transfer_authorized = FALSE,
    iid_respondent_bb_cluster_validity_authorized = FALSE,
    swmdk_item_reselection_authorized = FALSE
  ),
  protected_roots = list(
    list(
      path = "codebase/bayesmokken",
      policy = "NO_MUTATION_PHASE_14_TO_16"
    ),
    list(
      path = "codebase/research/v3",
      policy = "READ_ONLY_FROZEN_EVIDENCE"
    ),
    list(
      path = "codebase/oracles/transport-lp",
      policy = "READ_ONLY_INDEPENDENT_ORACLE"
    )
  ),
  source_crosswalk = list(
    status = "UNRESOLVED_PRODUCTION_BLOCKER",
    sources = c(
      "Molenaar (1991)",
      "Rueschendorf (1982)",
      "Andreadis (2017)"
    ),
    phase14_action =
      "complete or record a page-level acquisition and crosswalk schedule",
    consequence =
      "no production ordinal claim until the crosswalk is closed"
  ),
  compute_policy = list(
    local_allowed = c(
      "low-cost unit tests",
      "oracle comparisons",
      "small smoke and feasibility pilots"
    ),
    heavy_compute_provider = "AWS_ONLY",
    gcp_access_allowed = FALSE,
    expected_aws_alias = "aws-vm",
    expected_workers_after_preflight = 12L,
    checkpoint_raw_before_postprocessing = TRUE,
    download_raw_before_final_evaluation = TRUE
  ),
  directory_contract = directory_contract,
  evidence_baseline = list(
    inventory_path = relative_path(inventory_path),
    inventory_sha256 = sha256_file(inventory_path),
    rows = nrow(inventory),
    missing = sum(!inventory$exists),
    class_counts = inventory_counts,
    status = "PASS_BASELINE_CAPTURED"
  ),
  inherited_receipts = list(
    phase13_decision = phase13_receipt$decision,
    phase13_production_authorized =
      phase13_receipt$production_authorized,
    package_overall_pass = package_receipt$overall_pass,
    package_r_cmd_check = package_receipt$r_cmd_check_status,
    journal_primary_target = journal_receipt$primary_target,
    journal_manuscript_drafting_authorized =
      journal_receipt$manuscript_drafting_authorized
  ),
  decision_labels = list(
    gate_g14 = c(
      "PROCEED_TO_CLUSTER_POLYTOMOUS_DEVELOPMENT",
      "REPAIR_AND_REPEAT_FEASIBILITY",
      "STOP_CLUSTER_POLYTOMOUS_BRANCH"
    )
  ),
  status = "STEP_14_1_FOUNDATION_COMPLETE_NONPRODUCTION"
)

manifest_path <- file.path(
  governance_root,
  "v4-cluster-polytomous-governance-manifest-v1.json"
)
jsonlite::write_json(
  manifest,
  manifest_path,
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null",
  digits = 16
)

actual_inventory_hash <- vapply(
  project_path(inventory$project_relative_path),
  sha256_file,
  character(1)
)
actual_inventory_hash <- unname(actual_inventory_hash)

checks <- data.frame(
  check_id = c(
    "S14_1_DIRECTORY_CONTRACT",
    "S14_1_README_EXISTS",
    "S14_1_INVENTORY_NONEMPTY",
    "S14_1_INVENTORY_ALL_PRESENT",
    "S14_1_INVENTORY_HASH_REPRODUCIBLE",
    "S14_1_PHASE13_RESTRICTED_DECISION",
    "S14_1_PHASE13_PRODUCTION_BLOCKED",
    "S14_1_BINARY_PACKAGE_BASELINE_PRESENT",
    "S14_1_PACKAGE_GATE_PASSED",
    "S14_1_PACKAGE_API_MUTATION_BLOCKED",
    "S14_1_CLUSTER_METHOD_NOT_ACCEPTED",
    "S14_1_BINARY_GAMMA_TRANSFER_BLOCKED",
    "S14_1_GCP_BLOCKED",
    "S14_1_STEP14_2_NOT_EXECUTED",
    "S14_1_V4_ENGINE_EMPTY",
    "S14_1_LOG035_QMD_PRESENT"
  ),
  criterion = c(
    "all required v4 directories exist",
    "branch README exists",
    "baseline inventory has at least one row",
    "all inventoried files exist",
    "all captured hashes reproduce",
    "Phase 13 permits restricted development only",
    "Phase 13 did not authorize production",
    "binary package files are included in baseline",
    "frozen package application gate remains PASS",
    "governance prohibits package changes",
    "candidate cluster method remains unaccepted",
    "binary gamma .25 transfer is prohibited",
    "GCP access is prohibited",
    "execution stops after Step 14.1",
    "no v4 core/weight/DGP/evaluation R implementation exists",
    "log 035 QMD exists"
  ),
  observed = c(
    paste0(
      sum(dir.exists(file.path(v4_root, required_directories))),
      "/",
      length(required_directories)
    ),
    file.exists(file.path(v4_root, "README.md")),
    nrow(inventory),
    sum(inventory$exists),
    sum(actual_inventory_hash == inventory$sha256),
    phase13_receipt$decision,
    phase13_receipt$production_authorized,
    sum(inventory$inventory_class == "frozen_binary_package_source"),
    package_receipt$overall_pass,
    manifest$authorization_firewall$package_change_authorized,
    manifest$scientific_state$primary_candidate_accepted,
    manifest$authorization_firewall$binary_gamma_0_25_transfer_authorized,
    manifest$compute_policy$gcp_access_allowed,
    manifest$authority$execution_beyond_step_14_1_authorized,
    length(list.files(
      file.path(v4_root, "R"),
      recursive = TRUE,
      full.names = TRUE
    )),
    file.exists(project_path(
      "log/035_plan-v4-cluster-polytomous-development.qmd"
    ))
  ),
  pass = c(
    all(dir.exists(file.path(v4_root, required_directories))),
    file.exists(file.path(v4_root, "README.md")),
    nrow(inventory) > 0L,
    all(inventory$exists),
    identical(actual_inventory_hash, unname(inventory$sha256)),
    identical(
      phase13_receipt$decision,
      "PROCEED_RESTRICTED_ORDINAL_DEVELOPMENT"
    ),
    isFALSE(phase13_receipt$production_authorized),
    any(inventory$inventory_class == "frozen_binary_package_source"),
    isTRUE(package_receipt$overall_pass),
    isFALSE(manifest$authorization_firewall$package_change_authorized),
    isFALSE(manifest$scientific_state$primary_candidate_accepted),
    isFALSE(
      manifest$authorization_firewall$binary_gamma_0_25_transfer_authorized
    ),
    isFALSE(manifest$compute_policy$gcp_access_allowed),
    isFALSE(manifest$authority$execution_beyond_step_14_1_authorized),
    length(list.files(
      file.path(v4_root, "R"),
      recursive = TRUE,
      full.names = TRUE
    )) == 0L,
    file.exists(project_path(
      "log/035_plan-v4-cluster-polytomous-development.qmd"
    ))
  ),
  stringsAsFactors = FALSE
)

validation_path <- file.path(
  governance_root,
  "v4-step14-1-validation-checks-v1.csv"
)
utils::write.csv(checks, validation_path, row.names = FALSE, na = "")
stopifnot(all(checks$pass))

receipt <- list(
  schema_version =
    "paperA-v4-cluster-polytomous-step14-1-receipt-v1",
  generated_at_utc = created_at_utc,
  generated_at_local = created_at_local,
  status = "PASS_STEP14_1_FOUNDATION_READY",
  completed_step = "14.1",
  branch_status = "NONPRODUCTION_RESEARCH_ONLY",
  directory_count = length(required_directories),
  inventory = list(
    path = relative_path(inventory_path),
    rows = nrow(inventory),
    sha256 = sha256_file(inventory_path),
    missing = sum(!inventory$exists),
    hash_mismatch = sum(actual_inventory_hash != inventory$sha256)
  ),
  governance_manifest = list(
    path = relative_path(manifest_path),
    sha256 = sha256_file(manifest_path)
  ),
  validation = list(
    path = relative_path(validation_path),
    sha256 = sha256_file(validation_path),
    checks_total = nrow(checks),
    checks_passed = sum(checks$pass),
    checks_failed = sum(!checks$pass)
  ),
  log = list(
    qmd = "log/035_plan-v4-cluster-polytomous-development.qmd",
    html = "log/035_plan-v4-cluster-polytomous-development.html"
  ),
  source_crosswalk_status = "UNRESOLVED_PRODUCTION_BLOCKER",
  production_authorized = FALSE,
  package_change_authorized = FALSE,
  phase14_2_executed = FALSE,
  phase15_authorized = FALSE,
  terminal_state = "STOP_AFTER_STEP_14_1_V4_FOUNDATION",
  next_sequenced_step =
    "14.2 ESTIMAND_AND_SAMPLING_LAW_CONTRACT"
)

receipt_path <- file.path(
  governance_root,
  "v4-step14-1-foundation-receipt-v1.json"
)
jsonlite::write_json(
  receipt,
  receipt_path,
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null",
  digits = 16
)

message(
  "PASS: Step 14.1 governance built with ",
  nrow(inventory),
  " inventoried files and ",
  nrow(checks),
  "/",
  nrow(checks),
  " validation checks."
)
