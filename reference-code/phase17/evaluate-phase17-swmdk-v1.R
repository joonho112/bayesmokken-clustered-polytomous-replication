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
r_root <- file.path(v4_root, "R")
phase17_root <- file.path(
  v4_root, "empirical-swmdk", "phase17"
)
protocol_root <- file.path(phase17_root, "protocol")
raw_root <- file.path(phase17_root, "aws-raw")
result_root <- file.path(phase17_root, "results")
artifact_root <- file.path(phase17_root, "artifacts")
dir.create(result_root, recursive = TRUE, showWarnings = FALSE)
dir.create(artifact_root, recursive = TRUE, showWarnings = FALSE)

source(file.path(r_root, "core", "ordinal-h.R"))
source(file.path(r_root, "core", "knot-diagnostics.R"))
source(file.path(r_root, "weights", "cluster-weights.R"))
source(file.path(
  r_root, "evaluation", "intervals-and-comparators.R"
))
source(file.path(
  r_root, "evaluation", "phase15-calibration.R"
))

protocol_path <- file.path(
  protocol_root, "v4-phase17-swmdk-empirical-protocol-v1.yml"
)
lock_path <- file.path(
  protocol_root, "v4-phase17-protocol-lock-receipt-v1.json"
)
design_path <- file.path(
  protocol_root, "v4-phase17-task-design-v1.csv"
)
authority_path <- file.path(
  v4_root, "governance",
  "v4-phase17-empirical-application-authority-v1.json"
)
parent_path <- file.path(
  v4_root, "confirmatory", "artifacts",
  "v4-phase16-final-closure-receipt-v1.json"
)
method_lock_path <- file.path(
  v4_root, "validation", "artifacts",
  "v4-phase15-final-method-lock-v1.json"
)
baseline_path <- file.path(
  v4_root, "governance", "v4-source-and-freeze-inventory-v1.csv"
)
crosswalk_path <- file.path(
  v4_root, "protocol",
  "v4-original-source-crosswalk-schedule-v1.json"
)

protocol <- yaml::read_yaml(protocol_path)
lock <- jsonlite::read_json(lock_path, simplifyVector = TRUE)
authority <- jsonlite::read_json(
  authority_path, simplifyVector = TRUE
)
parent <- jsonlite::read_json(parent_path, simplifyVector = TRUE)
method_lock <- jsonlite::read_json(
  method_lock_path, simplifyVector = TRUE
)
design <- utils::read.csv(
  design_path, stringsAsFactors = FALSE
)
baseline <- utils::read.csv(
  baseline_path, stringsAsFactors = FALSE
)
crosswalk <- jsonlite::read_json(
  crosswalk_path, simplifyVector = TRUE
)
stopifnot(
  identical(
    protocol$status,
    "FROZEN_PRE_PHASE17_EMPIRICAL_OUTCOME"
  ),
  identical(
    lock$status,
    "PASS_FROZEN_PRE_PHASE17_EMPIRICAL_OUTCOME"
  ),
  identical(
    authority$status,
    "AUTHORIZED_PHASE17_TO_G17_ONLY"
  ),
  identical(
    parent$decision,
    "CONFIRM_CLUSTER_POLYTOMOUS_METHOD"
  ),
  method_lock$final_gamma_cluster ==
    protocol$method$selected$gamma_cluster,
  isFALSE(protocol$phase18$authorized),
  isFALSE(authority$phase18_authorized)
)

data("SWMDK", package = "mokken", envir = environment())
dataset_hash <- digest::digest(SWMDK, algo = "sha256")
scales <- list(
  teacher = unlist(protocol$scales$teacher$items),
  classmate = unlist(protocol$scales$classmate$items)
)
cluster <- SWMDK$classId
supports_for <- function(X) {
  out <- rep(list(1:5), ncol(X))
  names(out) <- colnames(X)
  out
}

receipt_files <- list.files(
  raw_root,
  pattern = "^P17-T[0-9]{2}-receipt-v1\\.json$",
  full.names = TRUE
)
draw_files <- list.files(
  raw_root,
  pattern = "^P17-T[0-9]{2}-draws-v1\\.csv\\.gz$",
  full.names = TRUE
)
batch_manifest_files <- list.files(
  raw_root,
  pattern = "^P17-T[0-9]{2}-batch-manifest-v1\\.csv$",
  full.names = TRUE
)
stopifnot(
  length(receipt_files) == 12L,
  length(draw_files) == 12L,
  length(batch_manifest_files) == 12L
)
receipts <- lapply(
  receipt_files, jsonlite::read_json, simplifyVector = TRUE
)
receipt_task_ids <- vapply(
  receipts, `[[`, character(1), "task_id"
)
hash_pass <- vapply(receipts, function(receipt) {
  draw_path <- file.path(
    project_root, receipt$draw_output$path
  )
  manifest_path <- file.path(
    project_root, receipt$batch_manifest$path
  )
  identical(
    unname(tools::sha256sum(draw_path)),
    receipt$draw_output$sha256
  ) && identical(
    unname(tools::sha256sum(manifest_path)),
    receipt$batch_manifest$sha256
  )
}, logical(1))
receipt_complete <- vapply(receipts, function(receipt) {
  identical(receipt$status, "PASS_TASK_COMPLETE") &&
    receipt$draws ==
      protocol$precision$draws_per_random_weight_task &&
    receipt$batches == protocol$precision$batches_per_task
}, logical(1))

draws_by_task <- setNames(vector("list", nrow(design)), design$task_id)
for (task_id in design$task_id) {
  receipt <- receipts[[match(task_id, receipt_task_ids)]]
  draws_by_task[[task_id]] <- utils::read.csv(
    file.path(project_root, receipt$draw_output$path),
    stringsAsFactors = FALSE
  )
}

point_rows <- list()
diagnostic_rows <- list()
category_rows <- list()
icc_rows <- list()
for (scale_index in seq_along(scales)) {
  scale_name <- names(scales)[scale_index]
  items <- scales[[scale_name]]
  X <- as.matrix(SWMDK[, items])
  supports <- supports_for(X)
  respondent_weights <- v4_point_weights(
    cluster, "respondent"
  )
  cluster_weights <- v4_point_weights(cluster, "cluster")
  respondent_point <- v4_ordinal_h_point(
    X, respondent_weights, supports
  )$H
  cluster_point <- v4_ordinal_h_point(
    X, cluster_weights, supports
  )$H
  respondent_knot <- v4_knot_diagnostics(
    X, respondent_weights, supports
  )
  cluster_knot <- v4_knot_diagnostics(
    X, cluster_weights, supports
  )
  diagnostic_rows[[scale_index]] <- rbind(
    data.frame(
      scale = scale_name,
      target = "respondent",
      point_H = respondent_point,
      target_difference_from_respondent = 0,
      minimum_internal_cdf_gap =
        respondent_knot$minimum_internal_cdf_gap,
      exact_knot_count = respondent_knot$exact_knot_count,
      near_knot_count = respondent_knot$near_knot_count,
      stringsAsFactors = FALSE
    ),
    data.frame(
      scale = scale_name,
      target = "equal_cluster",
      point_H = cluster_point,
      target_difference_from_respondent =
        cluster_point - respondent_point,
      minimum_internal_cdf_gap =
        cluster_knot$minimum_internal_cdf_gap,
      exact_knot_count = cluster_knot$exact_knot_count,
      near_knot_count = cluster_knot$near_knot_count,
      stringsAsFactors = FALSE
    )
  )
  icc <- mokken::ICC(
    SWMDK[, c("classId", items)]
  )$scaleICC
  icc_rows[[scale_index]] <- data.frame(
    scale = scale_name,
    ICC = icc$ICC,
    F = icc$F,
    df1 = icc$df1,
    df2 = icc$df2,
    p_value = icc$p.value,
    stringsAsFactors = FALSE
  )
  categories <- do.call(rbind, lapply(items, function(item) {
    count <- table(factor(SWMDK[[item]], levels = 1:5))
    data.frame(
      scale = scale_name,
      item = item,
      score = 1:5,
      count = as.integer(count),
      mass = as.integer(count) / nrow(SWMDK),
      stringsAsFactors = FALSE
    )
  }))
  category_rows[[scale_index]] <- categories
}
diagnostics <- do.call(rbind, diagnostic_rows)
icc_summary <- do.call(rbind, icc_rows)
category_profile <- do.call(rbind, category_rows)
rownames(diagnostics) <- NULL
rownames(icc_summary) <- NULL
rownames(category_profile) <- NULL

raw_method_rows <- list()
selected_rows <- list()
stability_rows <- list()
raw_row_index <- 0L
selected_row_index <- 0L
stability_index <- 0L
gamma <- protocol$method$selected$gamma_cluster
G <- length(unique(cluster))
for (task_index in seq_len(nrow(design))) {
  task <- design[task_index, , drop = FALSE]
  draws <- draws_by_task[[task$task_id]]
  H_draws <- draws$H
  diagnostic <- diagnostics[
    diagnostics$scale == task$scale, , drop = FALSE
  ]
  point_target <- if (task$target == "equal_cluster") {
    "equal_cluster"
  } else {
    "respondent"
  }
  point <- diagnostic$point_H[
    diagnostic$target == point_target
  ]
  interval <- v4_raw_interval(
    H_draws, point,
    level = protocol$method$selected$level,
    quantile_type =
      protocol$method$selected$quantile_type,
    minimum_defined_fraction = 1 -
      protocol$precision$maximum_invalid_fraction
  )
  raw_row_index <- raw_row_index + 1L
  raw_method_rows[[raw_row_index]] <- data.frame(
    scale = task$scale,
    method_id = task$method_id,
    base_method_id = task$method_id,
    target_id = if (task$target == "equal_cluster") {
      "V4-TARGET-EQUAL-CLUSTER-v1"
    } else if (task$target == "respondent") {
      "V4-TARGET-RESPONDENT-WEIGHTED-v1"
    } else {
      "WORKING-INDEPENDENCE-RESPONDENT"
    },
    target_role = task$target,
    interval_role = "raw_or_comparator",
    gamma_cluster = 0,
    point_estimate = point,
    lower = interval$lower,
    upper = interval$upper,
    center = interval$center,
    interval_length = interval$length,
    se_equivalent = interval$se_equivalent,
    defined_draws = interval$defined_draws,
    total_draws = interval$total_draws,
    invalid_fraction = interval$invalid_fraction,
    status = interval$status,
    interpretation =
      "RANDOM_WEIGHT_POSTERIOR_FUNCTIONAL_INTERVAL",
    stringsAsFactors = FALSE
  )

  if (task$method_key %in% c(
    "hbb_respondent", "hbb_cluster"
  )) {
    calibrated <- v4_calibrated_interval_from_raw(
      interval$lower, interval$upper, G, gamma
    )
    selected_row_index <- selected_row_index + 1L
    selected_rows[[selected_row_index]] <- data.frame(
      scale = task$scale,
      method_id = if (task$method_key == "hbb_respondent") {
        protocol$method$selected$respondent_method_id
      } else {
        protocol$method$selected$equal_cluster_method_id
      },
      base_method_id = task$method_id,
      target_id = if (task$method_key == "hbb_respondent") {
        "V4-TARGET-RESPONDENT-WEIGHTED-v1"
      } else {
        "V4-TARGET-EQUAL-CLUSTER-v1"
      },
      target_role = task$target,
      interval_role = "phase16_confirmed_selected",
      gamma_cluster = gamma,
      point_estimate = point,
      lower = calibrated[["lower"]],
      upper = calibrated[["upper"]],
      center = calibrated[["center"]],
      interval_length = calibrated[["length"]],
      se_equivalent = interval$se_equivalent,
      defined_draws = interval$defined_draws,
      total_draws = interval$total_draws,
      invalid_fraction = interval$invalid_fraction,
      status = interval$status,
      interpretation =
        "CONFIRMED_RANDOM_WEIGHT_POSTERIOR_FUNCTIONAL_INTERVAL",
      stringsAsFactors = FALSE
    )
    split_id <- draws$draw_id <= floor(nrow(draws) / 2)
    split_intervals <- lapply(
      list(first = H_draws[split_id], second = H_draws[!split_id]),
      function(value) {
        raw <- v4_raw_interval(
          value, point,
          level = protocol$method$selected$level,
          quantile_type =
            protocol$method$selected$quantile_type
        )
        v4_calibrated_interval_from_raw(
          raw$lower, raw$upper, G, gamma
        )
      }
    )
    difference <- abs(
      split_intervals$first[c("lower", "upper")] -
        split_intervals$second[c("lower", "upper")]
    )
    stability_index <- stability_index + 1L
    stability_rows[[stability_index]] <- data.frame(
      scale = task$scale,
      target = task$target,
      method_id =
        selected_rows[[selected_row_index]]$method_id,
      first_lower = split_intervals$first[["lower"]],
      first_upper = split_intervals$first[["upper"]],
      second_lower = split_intervals$second[["lower"]],
      second_upper = split_intervals$second[["upper"]],
      lower_absolute_difference = difference[["lower"]],
      upper_absolute_difference = difference[["upper"]],
      maximum_endpoint_difference = max(difference),
      threshold = protocol$precision$
        split_half_endpoint_stability_threshold,
      pass = max(difference) <=
        protocol$precision$
          split_half_endpoint_stability_threshold,
      stringsAsFactors = FALSE
    )
  }
}
method_summary <- rbind(
  do.call(rbind, selected_rows),
  do.call(rbind, raw_method_rows)
)

delta_rows <- list()
for (scale_index in seq_along(scales)) {
  scale_name <- names(scales)[scale_index]
  X <- as.matrix(SWMDK[, scales[[scale_name]]])
  point <- diagnostics$point_H[
    diagnostics$scale == scale_name &
      diagnostics$target == "respondent"
  ]
  delta <- v4_mokken_twolevel_delta(X, cluster, point)
  delta_rows[[scale_index]] <- data.frame(
    scale = scale_name,
    method_id = delta$method_id,
    base_method_id = delta$method_id,
    target_id = delta$target_id,
    target_role = "respondent",
    interval_role = "analytic_comparator",
    gamma_cluster = NA_real_,
    point_estimate = delta$point_estimate,
    lower = delta$lower,
    upper = delta$upper,
    center = delta$center,
    interval_length = delta$interval_length,
    se_equivalent = delta$se_equivalent,
    defined_draws = NA_integer_,
    total_draws = NA_integer_,
    invalid_fraction = delta$invalid_fraction,
    status = delta$status,
    interpretation = "TWO_LEVEL_DELTA_WALD_COMPARATOR",
    stringsAsFactors = FALSE
  )
}
method_summary <- rbind(
  method_summary, do.call(rbind, delta_rows)
)
rownames(method_summary) <- NULL
stability <- do.call(rbind, stability_rows)
rownames(stability) <- NULL

cluster_sizes <- as.integer(table(cluster))
data_profile <- data.frame(
  field = c(
    "dataset", "digest_sha256", "respondents", "clusters",
    "cluster_size_min", "cluster_size_q1",
    "cluster_size_median", "cluster_size_mean",
    "cluster_size_q3", "cluster_size_max",
    "fixed_scale_missing_values",
    "minimum_fixed_category_count",
    "minimum_fixed_category_mass"
  ),
  value = c(
    "mokken::SWMDK", dataset_hash, nrow(SWMDK),
    length(unique(cluster)), min(cluster_sizes),
    unname(stats::quantile(cluster_sizes, .25)),
    stats::median(cluster_sizes), mean(cluster_sizes),
    unname(stats::quantile(cluster_sizes, .75)),
    max(cluster_sizes),
    sum(is.na(SWMDK[, unique(unlist(scales))])),
    min(category_profile$count),
    min(category_profile$mass)
  ),
  stringsAsFactors = FALSE
)

method_path <- file.path(
  result_root, "v4-phase17-method-summary-v1.csv"
)
diagnostic_path <- file.path(
  result_root, "v4-phase17-target-knot-diagnostics-v1.csv"
)
icc_path <- file.path(
  result_root, "v4-phase17-icc-summary-v1.csv"
)
category_path <- file.path(
  result_root, "v4-phase17-category-profile-v1.csv"
)
profile_path <- file.path(
  result_root, "v4-phase17-data-profile-v1.csv"
)
stability_path <- file.path(
  result_root, "v4-phase17-quantile-stability-v1.csv"
)
utils::write.csv(method_summary, method_path, row.names = FALSE)
utils::write.csv(diagnostics, diagnostic_path, row.names = FALSE)
utils::write.csv(icc_summary, icc_path, row.names = FALSE)
utils::write.csv(category_profile, category_path, row.names = FALSE)
utils::write.csv(data_profile, profile_path, row.names = FALSE)
utils::write.csv(stability, stability_path, row.names = FALSE)

selected <- method_summary[
  method_summary$interval_role ==
    "phase16_confirmed_selected",
  ,
  drop = FALSE
]
raw_hbb <- method_summary[
  method_summary$method_id %in% c(
    protocol$method$raw_base$respondent_method_id,
    protocol$method$raw_base$equal_cluster_method_id
  ),
  ,
  drop = FALSE
]
expected_point <- c(
  teacher = protocol$scales$teacher$expected_point_H,
  classmate = protocol$scales$classmate$expected_point_H
)
respondent_diag <- diagnostics[
  diagnostics$target == "respondent", , drop = FALSE
]
point_difference <- max(abs(
  respondent_diag$point_H -
    expected_point[respondent_diag$scale]
))
delta_summary <- method_summary[
  method_summary$method_id ==
    "V4-CMP-MOKKEN-TWOLEVEL-DELTA-v1",
  ,
  drop = FALSE
]
delta_difference <- max(abs(
  delta_summary$point_estimate -
    expected_point[delta_summary$scale]
))
selected_raw_match <- merge(
  selected,
  raw_hbb[, c(
    "scale", "target_role", "interval_length"
  )],
  by = c("scale", "target_role"),
  suffixes = c("_selected", "_raw")
)
required_method_ids <- c(
  protocol$method$selected$respondent_method_id,
  protocol$method$selected$equal_cluster_method_id,
  protocol$method$raw_base$respondent_method_id,
  protocol$method$raw_base$equal_cluster_method_id,
  unlist(protocol$comparators$random_weight),
  unlist(protocol$comparators$analytic)
)

baseline_hash <- unname(tools::sha256sum(
  file.path(project_root, baseline$project_relative_path)
))
underlying_evidence <- c(
  authority_path, protocol_path, lock_path, design_path,
  parent_path, method_lock_path,
  file.path(phase17_root, "run-phase17-task-v1.R"),
  file.path(phase17_root, "run-phase17-aws-v1.sh"),
  file.path(phase17_root, "evaluate-phase17-swmdk-v1.R"),
  receipt_files, draw_files, batch_manifest_files,
  method_path, diagnostic_path, icc_path, category_path,
  profile_path, stability_path, baseline_path, crosswalk_path
)
stopifnot(all(file.exists(underlying_evidence)))
evidence_manifest <- data.frame(
  project_relative_path = sub(
    paste0("^", project_root, "/"), "", underlying_evidence
  ),
  size_bytes = as.numeric(file.info(underlying_evidence)$size),
  sha256 = unname(tools::sha256sum(underlying_evidence)),
  stringsAsFactors = FALSE
)
evidence_manifest_path <- file.path(
  artifact_root, "v4-phase17-evidence-manifest-v1.csv"
)
utils::write.csv(
  evidence_manifest, evidence_manifest_path, row.names = FALSE
)

disclosure_complete <- all(c(
  nrow(data_profile) == 13L,
  nrow(icc_summary) == 2L,
  nrow(category_profile) == 55L,
  nrow(diagnostics) == 4L,
  all(is.finite(icc_summary$ICC)),
  any(diagnostics$exact_knot_count > 0L),
  min(category_profile$count) == 2L
))
interpretation_complete <- all(
  nzchar(method_summary$interpretation)
) && isFALSE(
  protocol$diagnostics$threshold_crossing_is_formal_decision
)
gate_checks <- c(
  parent_phase16_confirmed =
    identical(
      parent$decision,
      "CONFIRM_CLUSTER_POLYTOMOUS_METHOD"
    ),
  dataset_and_scale_provenance_match =
    identical(
      dataset_hash,
      protocol$dataset$object_digest_sha256
    ) &&
      point_difference < 1e-10 &&
      nrow(SWMDK) == 639L &&
      length(unique(cluster)) == 30L,
  all_12_tasks_complete =
    length(receipts) == 12L &&
      setequal(receipt_task_ids, design$task_id) &&
      all(receipt_complete),
  all_raw_draw_and_receipt_hashes_match = all(hash_pass),
  maximum_invalid_fraction_at_most_0_001 =
    max(vapply(
      receipts, `[[`, numeric(1), "invalid_fraction"
    )) <= protocol$precision$maximum_invalid_fraction,
  point_H_concordance_below_1e_10 =
    max(point_difference, delta_difference) < 1e-10,
  selected_intervals_finite_ordered_and_contain_point =
    all(is.finite(unlist(selected[, c(
      "lower", "upper", "point_estimate"
    )]))) &&
      all(selected$lower < selected$upper) &&
      all(selected$lower <= selected$point_estimate) &&
      all(selected$point_estimate <= selected$upper),
  selected_intervals_shorter_than_raw =
    all(
      selected_raw_match$interval_length_selected <
        selected_raw_match$interval_length_raw
    ),
  selected_split_half_endpoint_difference_at_most_0_005 =
    all(stability$pass),
  both_targets_and_all_comparators_reported =
    all(required_method_ids %in% method_summary$method_id) &&
      all(c("respondent", "equal_cluster") %in%
            selected$target_role),
  cluster_sparse_ICC_and_knot_disclosures_complete =
    disclosure_complete,
  interpretation_and_no_threshold_decision_labels_present =
    interpretation_complete,
  protected_source_baseline_intact =
    all(baseline_hash == baseline$sha256),
  evidence_manifest_complete =
    nrow(evidence_manifest) == length(underlying_evidence) &&
      all(file.exists(file.path(
        project_root,
        evidence_manifest$project_relative_path
      )))
)
gate <- data.frame(
  gate_id = sprintf("G17-B%02d", seq_along(gate_checks)),
  criterion = names(gate_checks),
  observed = c(
    parent$decision,
    paste(dataset_hash, point_difference, sep = ";"),
    paste(sum(receipt_complete), "of 12"),
    paste(sum(hash_pass), "of 12"),
    max(vapply(
      receipts, `[[`, numeric(1), "invalid_fraction"
    )),
    max(point_difference, delta_difference),
    all(gate_checks[
      "selected_intervals_finite_ordered_and_contain_point"
    ]),
    max(
      selected_raw_match$interval_length_selected /
        selected_raw_match$interval_length_raw
    ),
    max(stability$maximum_endpoint_difference),
    paste(length(unique(method_summary$method_id)), "method IDs"),
    disclosure_complete,
    interpretation_complete,
    all(baseline_hash == baseline$sha256),
    nrow(evidence_manifest)
  ),
  threshold = c(
    "CONFIRM_CLUSTER_POLYTOMOUS_METHOD",
    "hash match; point difference < 1e-10",
    "12/12",
    "12/12",
    "<= 0.001",
    "< 1e-10",
    "TRUE",
    "< 1",
    paste0(
      "<= ",
      protocol$precision$
        split_half_endpoint_stability_threshold
    ),
    "both targets and all prespecified comparators",
    "complete",
    "complete; threshold decision FALSE",
    "all protected hashes match",
    "all required evidence files present"
  ),
  pass = unname(gate_checks),
  blocking = TRUE,
  stringsAsFactors = FALSE
)
gate_path <- file.path(
  artifact_root, "v4-g17-gate-criteria-v1.csv"
)
utils::write.csv(gate, gate_path, row.names = FALSE)

stop_failure <- any(!gate$pass[1:6])
decision_value <- if (all(gate$pass)) {
  protocol$gate_G17$pass_decision
} else if (stop_failure) {
  protocol$gate_G17$stop_decision
} else {
  protocol$gate_G17$repair_decision
}
receipt <- list(
  schema_version = "paperA-v4-phase17-g17-decision-v1",
  generated_at_utc = format(
    Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"
  ),
  decision = decision_value,
  status = if (all(gate$pass)) {
    "PHASE17_EMPIRICAL_APPLICATION_COMPLETE"
  } else {
    "PHASE17_GATE_NOT_PASSED"
  },
  dataset = list(
    object = "mokken::SWMDK",
    digest_sha256 = dataset_hash,
    respondents = nrow(SWMDK),
    clusters = length(unique(cluster)),
    cluster_size_range =
      as.integer(range(table(cluster)))
  ),
  execution = list(
    tasks = length(receipts),
    draws_per_task =
      protocol$precision$draws_per_random_weight_task,
    total_random_weight_draws = sum(vapply(
      receipts, `[[`, numeric(1), "draws"
    )),
    raw_download_complete_before_evaluation = TRUE,
    maximum_invalid_fraction = max(vapply(
      receipts, `[[`, numeric(1), "invalid_fraction"
    ))
  ),
  method = list(
    gamma_cluster = method_lock$final_gamma_cluster,
    respondent_method_id =
      method_lock$final_respondent_method_id,
    equal_cluster_method_id =
      method_lock$final_equal_cluster_method_id
  ),
  gate = list(
    passed = sum(gate$pass),
    total = nrow(gate),
    failed = sum(!gate$pass),
    path = sub(paste0("^", project_root, "/"), "", gate_path),
    sha256 = unname(tools::sha256sum(gate_path))
  ),
  outputs = list(
    method_summary = list(
      path = sub(paste0("^", project_root, "/"), "", method_path),
      sha256 = unname(tools::sha256sum(method_path))
    ),
    target_diagnostics = list(
      path = sub(
        paste0("^", project_root, "/"), "", diagnostic_path
      ),
      sha256 = unname(tools::sha256sum(diagnostic_path))
    ),
    evidence_manifest = list(
      path = sub(
        paste0("^", project_root, "/"),
        "", evidence_manifest_path
      ),
      files = nrow(evidence_manifest),
      sha256 = unname(tools::sha256sum(
        evidence_manifest_path
      ))
    )
  ),
  interpretation = list(
    primary =
      "respondent-weighted cluster-superpopulation posterior-functional interval",
    sensitivity = "equal-cluster posterior-functional interval",
    formal_threshold_decision = FALSE,
    exact_knot_claim = "diagnostic empirical disclosure only",
    source_crosswalk_status = crosswalk$status
  ),
  phase18_authorized = FALSE,
  terminal_state = "STOP_AT_G17_BEFORE_PHASE18"
)
receipt_path <- file.path(
  artifact_root, "v4-g17-decision-receipt-v1.json"
)
jsonlite::write_json(
  receipt, receipt_path, pretty = TRUE,
  auto_unbox = TRUE, digits = 16, null = "null"
)
message(
  decision_value, ": ", receipt$gate$passed,
  "/", receipt$gate$total, " G17 gates passed."
)
if (!all(gate$pass)) {
  print(gate[!gate$pass, ])
  quit(status = 1L)
}
