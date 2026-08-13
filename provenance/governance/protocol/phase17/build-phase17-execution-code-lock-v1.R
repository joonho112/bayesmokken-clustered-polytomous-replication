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

protocol_path <- file.path(
  protocol_root, "v4-phase17-swmdk-empirical-protocol-v1.yml"
)
protocol_lock_path <- file.path(
  protocol_root, "v4-phase17-protocol-lock-receipt-v1.json"
)
design_path <- file.path(
  protocol_root, "v4-phase17-task-design-v1.csv"
)
test_path <- file.path(test_root, "run-phase17-tests-v1.R")
test_receipt_path <- file.path(
  test_artifact_root, "v4-phase17-test-receipt-v1.json"
)
runner_path <- file.path(phase17_root, "run-phase17-task-v1.R")
launcher_path <- file.path(phase17_root, "run-phase17-aws-v1.sh")
evaluator_path <- file.path(
  phase17_root, "evaluate-phase17-swmdk-v1.R"
)
ordinal_h_path <- file.path(
  v4_root, "R", "core", "ordinal-h.R"
)
knot_path <- file.path(
  v4_root, "R", "core", "knot-diagnostics.R"
)
weight_path <- file.path(
  v4_root, "R", "weights", "cluster-weights.R"
)
interval_path <- file.path(
  v4_root, "R", "evaluation", "intervals-and-comparators.R"
)
calibration_path <- file.path(
  v4_root, "R", "evaluation", "phase15-calibration.R"
)

files <- c(
  protocol = protocol_path,
  protocol_lock = protocol_lock_path,
  task_design = design_path,
  test_runner = test_path,
  test_receipt = test_receipt_path,
  task_runner = runner_path,
  aws_launcher = launcher_path,
  frozen_evaluator = evaluator_path,
  ordinal_h = ordinal_h_path,
  knot_diagnostics = knot_path,
  cluster_weights = weight_path,
  intervals_and_comparators = interval_path,
  phase15_calibration = calibration_path
)
stopifnot(all(file.exists(files)))

protocol <- yaml::read_yaml(protocol_path)
protocol_lock <- jsonlite::read_json(
  protocol_lock_path, simplifyVector = TRUE
)
test_receipt <- jsonlite::read_json(
  test_receipt_path, simplifyVector = TRUE
)
parse(file = runner_path)
parse(file = evaluator_path)

empirical_outputs <- c(
  list.files(
    file.path(phase17_root, "aws-raw"),
    recursive = TRUE, full.names = TRUE
  ),
  list.files(
    file.path(phase17_root, "results"),
    recursive = TRUE, full.names = TRUE
  ),
  list.files(
    file.path(phase17_root, "artifacts"),
    recursive = TRUE, full.names = TRUE
  )
)
empirical_outputs <- empirical_outputs[
  file.exists(empirical_outputs)
]
stopifnot(
  identical(
    protocol$status,
    "FROZEN_PRE_PHASE17_EMPIRICAL_OUTCOME"
  ),
  identical(
    protocol_lock$status,
    "PASS_FROZEN_PRE_PHASE17_EMPIRICAL_OUTCOME"
  ),
  identical(test_receipt$status, "PASS"),
  test_receipt$tests_failed == 0L,
  test_receipt$empirical_output_count_at_test == 0L,
  length(empirical_outputs) == 0L,
  identical(protocol$compute$heavy_provider, "AWS_ONLY"),
  isFALSE(protocol$compute$gcp_allowed),
  isFALSE(protocol$phase18$authorized)
)

receipt <- list(
  schema_version =
    "paperA-v4-phase17-execution-code-lock-v1",
  generated_at_utc = format(
    Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"
  ),
  status = "PASS_CODE_LOCKED_PRE_EMPIRICAL_OUTCOME",
  files = lapply(files, function(path) {
    list(
      path = sub(paste0("^", project_root, "/"), "", path),
      size_bytes = as.numeric(file.info(path)$size),
      sha256 = unname(tools::sha256sum(path))
    )
  }),
  tests = list(
    status = test_receipt$status,
    passed = test_receipt$tests_passed,
    total = test_receipt$tests_total
  ),
  execution_output_count_at_code_lock =
    length(empirical_outputs),
  scheduled_random_weight_draws =
    protocol$precision$tasks *
      protocol$precision$draws_per_random_weight_task,
  heavy_provider = "AWS_ONLY",
  gcp_allowed = FALSE,
  phase18_authorized = FALSE,
  terminal_rule = "STOP_AT_G17_BEFORE_PHASE18"
)
out_path <- file.path(
  protocol_root, "v4-phase17-execution-code-lock-v1.json"
)
jsonlite::write_json(
  receipt, out_path, pretty = TRUE,
  auto_unbox = TRUE, digits = 16, null = "null"
)
message(
  "PASS_CODE_LOCKED_PRE_EMPIRICAL_OUTCOME: ",
  length(files), " files; empirical outputs = 0."
)
