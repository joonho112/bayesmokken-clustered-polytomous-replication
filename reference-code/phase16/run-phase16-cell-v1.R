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

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) {
  stop(
    "Usage: Rscript run-phase16-cell-v1.R <cell_id>",
    call. = FALSE
  )
}
cell_id <- args[1L]

project_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
v4_root <- file.path(
  project_root,
  "codebase", "research", "v4", "cluster-polytomous"
)
r_root <- file.path(v4_root, "R")
confirm_root <- file.path(v4_root, "confirmatory")
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
authority_path <- file.path(
  confirm_root, "v4-phase16-fresh-confirmation-authority-v1.json"
)

if (!file.exists(authority_path)) {
  stop(
    paste(
      "Phase 16 execution is blocked: fresh confirmation authority",
      "does not exist."
    ),
    call. = FALSE
  )
}
authority <- jsonlite::read_json(
  authority_path, simplifyVector = TRUE
)
if (!identical(
  authority$status,
  "AUTHORIZED_PHASE16_FRESH_CONFIRMATION"
)) {
  stop("Phase 16 authority status is not executable.", call. = FALSE)
}

source(file.path(r_root, "core", "ordinal-h.R"))
source(file.path(r_root, "core", "knot-diagnostics.R"))
source(file.path(r_root, "weights", "cluster-weights.R"))
source(file.path(r_root, "dgp", "clustered-ordinal-dgp.R"))
source(file.path(
  r_root, "dgp", "phase15-clustered-ordinal-dgp.R"
))
source(file.path(
  r_root, "evaluation", "intervals-and-comparators.R"
))
source(file.path(
  r_root, "evaluation", "phase15-calibration.R"
))

protocol <- yaml::read_yaml(protocol_path)
method_lock <- jsonlite::read_json(
  method_lock_path, simplifyVector = TRUE
)
design <- utils::read.csv(
  design_path, stringsAsFactors = FALSE
)
cell_index <- match(cell_id, design$cell_id)
if (is.na(cell_index)) {
  stop("Unknown Phase 16 cell_id: ", cell_id, call. = FALSE)
}
cell <- design[cell_index, , drop = FALSE]
stopifnot(
  identical(
    protocol$status,
    "FROZEN_PROTOCOL_READY_NOT_EXECUTED"
  ),
  identical(
    method_lock$status,
    "LOCKED_FOR_PHASE16_CONFIRMATION"
  ),
  method_lock$final_gamma_cluster ==
    protocol$method$gamma_cluster,
  isFALSE(protocol$compute$gcp_allowed),
  identical(protocol$compute$provider, "AWS_ONLY"),
  identical(
    unname(tools::sha256sum(protocol_path)),
    authority$protocol_sha256
  ),
  identical(
    unname(tools::sha256sum(method_lock_path)),
    authority$method_lock_sha256
  )
)

replications <- protocol$design$replications_per_cell
draws <- protocol$design$random_weight_draws
seed_base <- protocol$design$seed_base
gamma_evaluated <- sort(unique(c(
  0, protocol$method$gamma_cluster
)))
output_root <- file.path(confirm_root, "aws-raw")
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
output_path <- file.path(
  output_root, paste0(cell_id, "-replications-v1.csv")
)
truth_path <- file.path(
  output_root, paste0(cell_id, "-truth-v1.csv")
)
receipt_path <- file.path(
  output_root, paste0(cell_id, "-receipt-v1.json")
)
partial_path <- file.path(
  output_root, paste0(cell_id, "-partial-v1.rds")
)
if (file.exists(output_path) && file.exists(receipt_path)) {
  message("Completed output already exists: ", cell_id)
  quit(status = 0L)
}

truth_resp <- v4_phase15_truth(
  cell, "confirmation", "respondent",
  protocol$design$truth_nodes_per_dimension
)
truth_cluster <- v4_phase15_truth(
  cell, "confirmation", "cluster",
  protocol$design$truth_nodes_per_dimension
)
truth_table <- rbind(
  data.frame(
    cell_id = cell_id,
    stage = "confirmation",
    target = "respondent",
    H = truth_resp$H,
    numerator = truth_resp$numerator,
    denominator = truth_resp$denominator,
    minimum_pair_denominator =
      truth_resp$minimum_pair_denominator,
    minimum_internal_cdf_gap =
      truth_resp$knot$minimum_internal_cdf_gap,
    exact_knot_count = truth_resp$knot$exact_knot_count,
    near_knot_count = truth_resp$knot$near_knot_count,
    stringsAsFactors = FALSE
  ),
  data.frame(
    cell_id = cell_id,
    stage = "confirmation",
    target = "cluster",
    H = truth_cluster$H,
    numerator = truth_cluster$numerator,
    denominator = truth_cluster$denominator,
    minimum_pair_denominator =
      truth_cluster$minimum_pair_denominator,
    minimum_internal_cdf_gap =
      truth_cluster$knot$minimum_internal_cdf_gap,
    exact_knot_count = truth_cluster$knot$exact_knot_count,
    near_knot_count = truth_cluster$knot$near_knot_count,
    stringsAsFactors = FALSE
  )
)
utils::write.csv(truth_table, truth_path, row.names = FALSE, na = "")

as_comparator <- function(row, base_method_id = row$method_id) {
  row$base_method_id <- base_method_id
  row$candidate <- FALSE
  row$gamma_cluster <- NA_real_
  row$width_multiplier <- NA_real_
  row
}
safe_delta <- function(X, cluster, truth) {
  tryCatch(
    as_comparator(v4_mokken_twolevel_delta(X, cluster, truth)),
    error = function(error) {
      data.frame(
        method_id = "V4-CMP-MOKKEN-TWOLEVEL-DELTA-v1",
        target_id = "V4-TARGET-RESPONDENT-WEIGHTED-v1",
        point_estimate = NA_real_,
        truth = truth,
        bias = NA_real_,
        lower = NA_real_,
        upper = NA_real_,
        center = NA_real_,
        interval_length = NA_real_,
        se_equivalent = NA_real_,
        cover = FALSE,
        defined_draws = NA_integer_,
        total_draws = NA_integer_,
        invalid_fraction = 1,
        status = paste0("ERROR: ", conditionMessage(error)),
        base_method_id = "V4-CMP-MOKKEN-TWOLEVEL-DELTA-v1",
        candidate = FALSE,
        gamma_cluster = NA_real_,
        width_multiplier = NA_real_,
        stringsAsFactors = FALSE
      )
    }
  )
}
safe_weight_method <- function(X, supports, object, point_weights,
                               truth) {
  tryCatch(
    as_comparator(v4_evaluate_random_weight_method(
      X, supports, object, point_weights, truth
    )),
    error = function(error) {
      data.frame(
        method_id = object$metadata$law_id,
        target_id = object$metadata$target_id,
        point_estimate = NA_real_,
        truth = truth,
        bias = NA_real_,
        lower = NA_real_,
        upper = NA_real_,
        center = NA_real_,
        interval_length = NA_real_,
        se_equivalent = NA_real_,
        cover = FALSE,
        defined_draws = 0L,
        total_draws = draws,
        invalid_fraction = 1,
        status = paste0("ERROR: ", conditionMessage(error)),
        base_method_id = object$metadata$law_id,
        candidate = FALSE,
        gamma_cluster = NA_real_,
        width_multiplier = NA_real_,
        stringsAsFactors = FALSE
      )
    }
  )
}

rows <- if (file.exists(partial_path)) {
  readRDS(partial_path)
} else {
  list()
}
start_replication <- length(rows) + 1L
started_at <- Sys.time()
if (start_replication <= replications) {
  for (replication in start_replication:replications) {
    replication_start <- proc.time()[["elapsed"]]
    replication_seed <- seed_base +
      cell_index * 100000L + replication * 100L
    sample <- v4_phase15_simulate(
      cell, "confirmation", replication_seed
    )
    respondent_point_weights <- v4_point_weights(
      sample$cluster, "respondent"
    )
    cluster_point_weights <- v4_point_weights(
      sample$cluster, "cluster"
    )
    respondent_point <- v4_ordinal_h_point(
      sample$X, respondent_point_weights, sample$supports
    )$H
    cluster_point <- v4_ordinal_h_point(
      sample$X, cluster_point_weights, sample$supports
    )$H
    knot <- v4_knot_diagnostics(
      sample$X, respondent_point_weights, sample$supports
    )
    replication_id <- paste(
      cell_id, sprintf("R%03d", replication), sep = "-"
    )
    hbb_resp <- v4_two_stage_hbb_weights(
      sample$cluster, draws, replication_seed + 31L,
      "respondent", replication_id
    )
    hbb_cluster <- v4_two_stage_hbb_weights(
      sample$cluster, draws, replication_seed + 41L,
      "cluster", replication_id
    )
    resp_draws <- v4_ordinal_h_draws(
      sample$X, hbb_resp$weights, sample$supports
    )$H
    cluster_draws <- v4_ordinal_h_draws(
      sample$X, hbb_cluster$weights, sample$supports
    )$H
    candidate_rows <- rbind(
      v4_evaluate_gamma_candidates(
        resp_draws, respondent_point, truth_resp$H,
        cell$G, "respondent", gamma_evaluated
      ),
      v4_evaluate_gamma_candidates(
        cluster_draws, cluster_point, truth_cluster$H,
        cell$G, "cluster", gamma_evaluated
      )
    )

    iid <- v4_iid_bb_weights(
      sample$cluster, draws, replication_seed + 11L,
      replication_id
    )
    one_stage <- v4_one_stage_cluster_bb_weights(
      sample$cluster, draws, replication_seed + 21L,
      "respondent", replication_id
    )
    frequentist <- v4_two_stage_frequentist_weights(
      sample$cluster, draws, replication_seed + 51L,
      "respondent", replication_id
    )
    within <- v4_within_stage_hbb_weights(
      sample$cluster, draws, replication_seed + 61L,
      "respondent", replication_id
    )
    comparator_rows <- rbind(
      safe_weight_method(
        sample$X, sample$supports, iid,
        respondent_point_weights, truth_resp$H
      ),
      safe_weight_method(
        sample$X, sample$supports, one_stage,
        respondent_point_weights, truth_resp$H
      ),
      safe_weight_method(
        sample$X, sample$supports, frequentist,
        respondent_point_weights, truth_resp$H
      ),
      safe_weight_method(
        sample$X, sample$supports, within,
        respondent_point_weights, truth_resp$H
      ),
      safe_delta(sample$X, sample$cluster, truth_resp$H)
    )
    replication_rows <- rbind(candidate_rows, comparator_rows)
    replication_rows$stage <- "confirmation"
    replication_rows$cell_id <- cell_id
    replication_rows$replication <- replication
    replication_rows$G <- cell$G
    replication_rows$N <- nrow(sample$X)
    replication_rows$latent_icc <- cell$latent_icc
    replication_rows$size_mechanism <- cell$size_mechanism
    replication_rows$discrimination_center <-
      cell$discrimination_center
    replication_rows$regularity <- cell$regularity
    replication_rows$threshold_profile <-
      cell$threshold_profile
    replication_rows$informative_slope <-
      cell$informative_slope
    replication_rows$minimum_cluster_size <-
      min(sample$cluster_size)
    replication_rows$maximum_cluster_size <-
      max(sample$cluster_size)
    replication_rows$size_effect_correlation <-
      sample$size_effect_correlation
    replication_rows$sample_minimum_internal_cdf_gap <-
      knot$minimum_internal_cdf_gap
    replication_rows$sample_exact_knot_count <-
      knot$exact_knot_count
    replication_rows$replication_elapsed_seconds <-
      proc.time()[["elapsed"]] - replication_start
    rows[[replication]] <- replication_rows
    if (replication %% 10L == 0L ||
        replication == replications) {
      saveRDS(rows, partial_path)
    }
  }
}

output <- do.call(rbind, rows)
rownames(output) <- NULL
utils::write.csv(output, output_path, row.names = FALSE, na = "")
receipt <- list(
  schema_version = "paperA-v4-phase16-cell-receipt-v1",
  generated_at_utc = format(
    Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"
  ),
  status = "PASS_CELL_COMPLETE",
  stage = "confirmation",
  cell_id = cell_id,
  cell_index = cell_index,
  replications = replications,
  draws = draws,
  gamma_evaluated = gamma_evaluated,
  method_rows = nrow(output),
  status_ok_fraction = mean(output$status == "OK"),
  maximum_invalid_fraction =
    max(output$invalid_fraction, na.rm = TRUE),
  truth = list(
    path = sub(paste0("^", project_root, "/"), "", truth_path),
    sha256 = unname(tools::sha256sum(truth_path))
  ),
  output = list(
    path = sub(paste0("^", project_root, "/"), "", output_path),
    size_bytes = as.numeric(file.info(output_path)$size),
    sha256 = unname(tools::sha256sum(output_path))
  ),
  elapsed_seconds = as.numeric(
    difftime(Sys.time(), started_at, units = "secs")
  )
)
jsonlite::write_json(
  receipt, receipt_path, pretty = TRUE,
  auto_unbox = TRUE, digits = 16, null = "null"
)
if (file.exists(partial_path)) unlink(partial_path)
message(
  "PASS: confirmation ", cell_id, " completed with ",
  nrow(output), " rows."
)
