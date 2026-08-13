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
    "codebase/research/v4/cluster-polytomous/governance/v4-phase15-autonomous-authority-addendum-v1.json",
  parent_gate =
    "codebase/research/v4/cluster-polytomous/artifacts/v4-g14-decision-receipt-v1.json",
  protocol =
    "codebase/research/v4/cluster-polytomous/protocol/v4-phase15-development-validation-protocol-v1.yml",
  training_design =
    "codebase/research/v4/cluster-polytomous/protocol/v4-phase15-training-design-v1.csv",
  validation_design =
    "codebase/research/v4/cluster-polytomous/protocol/v4-phase15-validation-design-v1.csv"
)
absolute <- setNames(file.path(project_root, paths), names(paths))
stopifnot(all(file.exists(absolute)))

authority <- jsonlite::read_json(
  absolute[["authority"]], simplifyVector = TRUE
)
parent <- jsonlite::read_json(
  absolute[["parent_gate"]], simplifyVector = TRUE
)
protocol <- yaml::read_yaml(absolute[["protocol"]])
training <- utils::read.csv(
  absolute[["training_design"]], stringsAsFactors = FALSE
)
validation <- utils::read.csv(
  absolute[["validation_design"]], stringsAsFactors = FALSE
)

design_key <- function(data) {
  paste(
    data$G, data$latent_icc, data$discrimination_center,
    data$threshold_profile, sep = "|"
  )
}

training_output_count <- length(list.files(
  file.path(v4_root, "development"),
  pattern = "\\.(csv|json|rds)$",
  recursive = TRUE
))
validation_output_count <- length(list.files(
  file.path(v4_root, "validation"),
  pattern = "\\.(csv|json|rds)$",
  recursive = TRUE
))

stopifnot(
  identical(authority$status, "AUTHORIZED_PHASE15_ONLY"),
  identical(
    authority$required_stop,
    "STOP_AT_PHASE16_PROTOCOL_READY_BEFORE_CONFIRMATION"
  ),
  identical(
    parent$decision,
    "PROCEED_TO_CLUSTER_POLYTOMOUS_DEVELOPMENT"
  ),
  isFALSE(parent$phase15_authorized),
  identical(protocol$status, "FROZEN_PRE_TRAINING_OUTCOME"),
  isFALSE(protocol$interval_candidates$binary_gamma_0_25_inherited),
  isFALSE(protocol$compute$gcp_allowed),
  identical(protocol$compute$heavy_provider, "AWS_ONLY"),
  nrow(training) == 24L,
  nrow(validation) == 18L,
  !any(design_key(validation) %in% design_key(training)),
  length(intersect(training$cell_id, validation$cell_id)) == 0L,
  protocol$training$seed_base != protocol$validation$seed_base,
  protocol$training$scheduled_replications == 2880L,
  protocol$validation$scheduled_replications == 3240L,
  training_output_count == 0L,
  validation_output_count == 0L
)

files <- data.frame(
  component = names(paths),
  project_relative_path = unname(paths),
  size_bytes = as.numeric(file.info(absolute)$size),
  sha256 = unname(tools::sha256sum(absolute)),
  stringsAsFactors = FALSE
)
receipt <- list(
  schema_version = "paperA-v4-phase15-protocol-lock-receipt-v1",
  generated_at_utc = format(
    Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"
  ),
  status = "PASS_FROZEN_PRE_TRAINING_OUTCOME",
  authority = authority$status,
  parent_gate = parent$decision,
  files = files,
  training = list(
    cells = nrow(training),
    scheduled_replications =
      protocol$training$scheduled_replications,
    draws = protocol$training$random_weight_draws,
    outputs_present_at_lock = training_output_count
  ),
  validation = list(
    cells = nrow(validation),
    scheduled_replications =
      protocol$validation$scheduled_replications,
    draws = protocol$validation$random_weight_draws,
    outputs_present_at_lock = validation_output_count,
    conditions_disjoint = TRUE,
    seeds_disjoint = TRUE
  ),
  gamma_candidates =
    unlist(protocol$interval_candidates$gamma_cluster),
  phase16_confirmation_authorized = FALSE,
  terminal_rule =
    "STOP_AT_PHASE16_PROTOCOL_READY_BEFORE_CONFIRMATION"
)
out <- file.path(
  protocol_root, "v4-phase15-protocol-lock-receipt-v1.json"
)
jsonlite::write_json(
  receipt, out, pretty = TRUE, auto_unbox = TRUE,
  digits = 16, null = "null"
)
message(
  "PASS: Phase 15 protocol frozen with 0 training and 0 validation outputs."
)
