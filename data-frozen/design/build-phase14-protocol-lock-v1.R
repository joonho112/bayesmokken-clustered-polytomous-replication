project_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
v4_root <- file.path(
  project_root,
  "codebase", "research", "v4", "cluster-polytomous"
)
protocol_root <- file.path(v4_root, "protocol")

stopifnot(
  requireNamespace("jsonlite", quietly = TRUE),
  requireNamespace("yaml", quietly = TRUE)
)

paths <- c(
  authority =
    "codebase/research/v4/cluster-polytomous/governance/v4-phase14-autonomous-authority-addendum-v1.json",
  estimand =
    "codebase/research/v4/cluster-polytomous/protocol/v4-estimand-and-sampling-contract-v1.yml",
  weights =
    "codebase/research/v4/cluster-polytomous/protocol/v4-weight-law-specification-v1.yml",
  feasibility =
    "codebase/research/v4/cluster-polytomous/protocol/v4-phase14-feasibility-protocol-v1.yml",
  design =
    "codebase/research/v4/cluster-polytomous/protocol/v4-phase14-pilot-design-v1.csv",
  source_crosswalk =
    "codebase/research/v4/cluster-polytomous/protocol/v4-original-source-crosswalk-schedule-v1.json"
)
absolute_paths <- setNames(file.path(project_root, paths), names(paths))
stopifnot(all(file.exists(absolute_paths)))

authority <- jsonlite::read_json(absolute_paths[["authority"]],
                                 simplifyVector = TRUE)
estimand <- yaml::read_yaml(absolute_paths[["estimand"]])
weights <- yaml::read_yaml(absolute_paths[["weights"]])
feasibility <- yaml::read_yaml(absolute_paths[["feasibility"]])
design <- utils::read.csv(absolute_paths[["design"]],
                          stringsAsFactors = FALSE)
crosswalk <- jsonlite::read_json(
  absolute_paths[["source_crosswalk"]],
  simplifyVector = TRUE
)

stopifnot(
  identical(authority$status, "AUTHORIZED_PHASE14_TO_G14_ONLY"),
  identical(authority$required_stop, "STOP_AT_G14_BEFORE_PHASE15"),
  identical(estimand$status, "FROZEN_FOR_PHASE14_FEASIBILITY"),
  identical(weights$status, "FROZEN_FOR_PHASE14_FEASIBILITY"),
  identical(feasibility$status, "FROZEN_PRE_OUTCOME"),
  identical(feasibility$design$scheduled_replications, 1080L),
  identical(feasibility$design$random_weight_draws_per_method, 199L),
  isFALSE(feasibility$design$tuning_permitted),
  isFALSE(feasibility$compute$gcp_allowed),
  nrow(design) == 18L,
  identical(sort(unique(design$G)), c(20L, 30L, 50L)),
  identical(sort(unique(design$latent_icc)), c(0.05, 0.17, 0.30)),
  identical(
    sort(unique(design$size_mechanism)),
    c("balanced", "informative", "swmdk_like")
  ),
  identical(
    sort(unique(design$regularity)),
    c("exact_knot", "near_knot", "regular")
  ),
  identical(
    crosswalk$status,
    "SCHEDULED_UNRESOLVED_PRODUCTION_BLOCKER"
  ),
  length(list.files(
    file.path(v4_root, "pilot"),
    pattern = "\\.(csv|json|rds)$",
    recursive = TRUE
  )) == 0L
)

hashes <- unname(tools::sha256sum(absolute_paths))
files <- data.frame(
  component = names(paths),
  project_relative_path = unname(paths),
  sha256 = hashes,
  size_bytes = as.numeric(file.info(absolute_paths)$size),
  stringsAsFactors = FALSE
)

receipt <- list(
  schema_version = "paperA-v4-phase14-protocol-lock-receipt-v1",
  generated_at_utc = format(
    Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"
  ),
  status = "PASS_FROZEN_PRE_OUTCOME",
  authority = "AUTHORIZED_PHASE14_TO_G14_ONLY",
  phase15_authorized = FALSE,
  protocol_files = files,
  design = list(
    cells = nrow(design),
    replications_per_cell =
      feasibility$design$replications_per_cell,
    scheduled_replications =
      feasibility$design$scheduled_replications,
    draws_per_method =
      feasibility$design$random_weight_draws_per_method,
    tuning_permitted = feasibility$design$tuning_permitted
  ),
  outputs_present_at_lock = 0L,
  source_crosswalk_status = crosswalk$status,
  terminal_rule = "STOP_AT_G14_BEFORE_PHASE15"
)

out <- file.path(
  protocol_root,
  "v4-phase14-protocol-lock-receipt-v1.json"
)
jsonlite::write_json(
  receipt, out, pretty = TRUE, auto_unbox = TRUE,
  digits = 16, null = "null"
)
message("PASS: Phase 14 protocol frozen before pilot outputs.")
