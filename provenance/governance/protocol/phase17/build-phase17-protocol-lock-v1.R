project_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
v4_root <- file.path(
  project_root,
  "codebase", "research", "v4", "cluster-polytomous"
)
phase17_root <- file.path(
  v4_root, "empirical-swmdk", "phase17"
)
protocol_root <- file.path(phase17_root, "protocol")
authority_path <- file.path(
  v4_root, "governance",
  "v4-phase17-empirical-application-authority-v1.json"
)
protocol_path <- file.path(
  protocol_root, "v4-phase17-swmdk-empirical-protocol-v1.yml"
)
design_path <- file.path(
  protocol_root, "v4-phase17-task-design-v1.csv"
)
parent_path <- file.path(
  v4_root, "confirmatory", "artifacts",
  "v4-phase16-final-closure-receipt-v1.json"
)
method_lock_path <- file.path(
  v4_root, "validation", "artifacts",
  "v4-phase15-final-method-lock-v1.json"
)
out_path <- file.path(
  protocol_root, "v4-phase17-protocol-lock-receipt-v1.json"
)

stopifnot(
  requireNamespace("jsonlite", quietly = TRUE),
  requireNamespace("yaml", quietly = TRUE),
  requireNamespace("digest", quietly = TRUE),
  requireNamespace("mokken", quietly = TRUE),
  all(file.exists(c(
    authority_path, protocol_path, design_path,
    parent_path, method_lock_path
  )))
)
authority <- jsonlite::read_json(
  authority_path, simplifyVector = TRUE
)
protocol <- yaml::read_yaml(protocol_path)
design <- utils::read.csv(
  design_path, stringsAsFactors = FALSE
)
parent <- jsonlite::read_json(parent_path, simplifyVector = TRUE)
method_lock <- jsonlite::read_json(
  method_lock_path, simplifyVector = TRUE
)
data("SWMDK", package = "mokken", envir = environment())
dataset_hash <- digest::digest(SWMDK, algo = "sha256")
execution_outputs <- c(
  list.files(
    file.path(phase17_root, "aws-raw"),
    all.files = FALSE, recursive = TRUE, full.names = TRUE
  ),
  list.files(
    file.path(phase17_root, "results"),
    all.files = FALSE, recursive = TRUE, full.names = TRUE
  )
)
execution_outputs <- execution_outputs[file.exists(execution_outputs)]

expected_tasks <- expand.grid(
  scale = c("teacher", "classmate"),
  method_key = c(
    "hbb_respondent", "hbb_cluster", "iid",
    "one_stage", "two_stage_frequentist", "within_stage"
  ),
  stringsAsFactors = FALSE
)
observed_tasks <- design[, c("scale", "method_key")]
task_key <- function(x) paste(x$scale, x$method_key, sep = "|")
stopifnot(
  identical(
    authority$status,
    "AUTHORIZED_PHASE17_TO_G17_ONLY"
  ),
  authority$output_count_at_authorization == 0L,
  isFALSE(authority$phase18_authorized),
  identical(
    parent$decision,
    "CONFIRM_CLUSTER_POLYTOMOUS_METHOD"
  ),
  identical(
    parent$status,
    "PHASE16_CONFIRMATION_COMPLETE"
  ),
  identical(
    method_lock$status,
    "LOCKED_FOR_PHASE16_CONFIRMATION"
  ),
  method_lock$final_gamma_cluster == -1.5,
  identical(
    protocol$status,
    "FROZEN_PRE_PHASE17_EMPIRICAL_OUTCOME"
  ),
  identical(
    protocol$dataset$object_digest_sha256,
    dataset_hash
  ),
  nrow(SWMDK) == 639L,
  length(unique(SWMDK$classId)) == 30L,
  identical(as.integer(range(table(SWMDK$classId))), c(5L, 29L)),
  !anyNA(SWMDK[, unique(c(
    unlist(protocol$scales$teacher$items),
    unlist(protocol$scales$classmate$items)
  ))]),
  nrow(design) == 12L,
  !anyDuplicated(design$task_id),
  !anyDuplicated(design$task_index),
  setequal(task_key(observed_tasks), task_key(expected_tasks)),
  protocol$precision$draws_per_random_weight_task == 99999L,
  protocol$precision$batches_per_task == 50L,
  protocol$method$selected$gamma_cluster == -1.5,
  isFALSE(protocol$method$tuning_permitted),
  isFALSE(protocol$method$fallback_permitted),
  isFALSE(protocol$diagnostics$threshold_crossing_is_formal_decision),
  identical(protocol$compute$heavy_provider, "AWS_ONLY"),
  isFALSE(protocol$compute$gcp_allowed),
  isFALSE(protocol$phase18$authorized),
  length(execution_outputs) == 0L
)

files <- c(
  authority = authority_path,
  protocol = protocol_path,
  task_design = design_path,
  parent_phase16 = parent_path,
  method_lock = method_lock_path
)
receipt <- list(
  schema_version = "paperA-v4-phase17-protocol-lock-receipt-v1",
  generated_at_utc = format(
    Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"
  ),
  status = "PASS_FROZEN_PRE_PHASE17_EMPIRICAL_OUTCOME",
  dataset = list(
    object = "mokken::SWMDK",
    digest_sha256 = dataset_hash,
    respondents = nrow(SWMDK),
    clusters = length(unique(SWMDK$classId)),
    cluster_size_range =
      as.integer(range(table(SWMDK$classId)))
  ),
  scales = list(
    teacher = unlist(protocol$scales$teacher$items),
    classmate = unlist(protocol$scales$classmate$items)
  ),
  method = list(
    gamma_cluster = protocol$method$selected$gamma_cluster,
    respondent_method_id =
      protocol$method$selected$respondent_method_id,
    equal_cluster_method_id =
      protocol$method$selected$equal_cluster_method_id,
    tuning_permitted = FALSE
  ),
  precision = list(
    tasks = nrow(design),
    draws_per_task =
      protocol$precision$draws_per_random_weight_task,
    scheduled_draws = nrow(design) *
      protocol$precision$draws_per_random_weight_task,
    batch_size = protocol$precision$batch_size,
    seed_base = protocol$precision$seed_base
  ),
  files = lapply(files, function(path) {
    list(
      path = sub(paste0("^", project_root, "/"), "", path),
      size_bytes = as.numeric(file.info(path)$size),
      sha256 = unname(tools::sha256sum(path))
    )
  }),
  execution_output_count_at_lock = length(execution_outputs),
  phase18_authorized = FALSE,
  terminal_rule = "STOP_AT_G17_BEFORE_PHASE18"
)
jsonlite::write_json(
  receipt, out_path, pretty = TRUE,
  auto_unbox = TRUE, digits = 16, null = "null"
)
message(
  "PASS_FROZEN_PRE_PHASE17_EMPIRICAL_OUTCOME: ",
  receipt$precision$scheduled_draws,
  " random-weight draws scheduled; outputs = 0."
)
