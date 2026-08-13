#!/usr/bin/env Rscript
# Recompute the Phase 16 raw summaries and every Phase 17 draw-stream summary.
# This gate also checks raw manifests, task/cell receipts, batch identity, draw
# IDs, and frozen-data schemas.  It is independent of the exhibit layer.

.here <- local({
  fa <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(fa)) dirname(normalizePath(gsub("~+~", " ", sub("^--file=", "", fa[1]),
                                             fixed = TRUE), mustWork = FALSE)) else getwd()
})
source(file.path(dirname(.here), "common", "R", "paths.R"))
source(file.path(PATHS$root, "common", "R", "io.R"))

pass <- 0L; fail <- 0L
chk <- function(label, expr) {
  ok <- tryCatch({ force(expr); TRUE },
                 error = function(e) { message("       ", conditionMessage(e)); FALSE })
  cat(sprintf("%-6s %s\n", if (ok) "ok" else "FAIL", label))
  if (ok) pass <<- pass + 1L else fail <<- fail + 1L
}
same_num <- function(x, y, tol = 1e-12) {
  all((is.na(x) & is.na(y)) | (is.finite(x) & is.finite(y) & abs(x - y) <= tol))
}
file_sha <- function(path) digest::digest(file = path, algo = "sha256")
uncompressed_sha <- function(path) {
  if (!grepl("[.]gz$", path)) return(file_sha(path))
  con <- gzfile(path, open = "rb")
  on.exit(close(con), add = TRUE)
  digest::digest(readBin(con, what = "raw", n = 1e9), algo = "sha256",
                 serialize = FALSE)
}
uncompressed_size <- function(path) {
  if (!grepl("[.]gz$", path)) return(unname(file.info(path)$size))
  con <- gzfile(path, open = "rb")
  on.exit(close(con), add = TRUE)
  length(readBin(con, what = "raw", n = 1e9))
}

cat("\nraw numeric basis: Paper B\n", strrep("-", 72), "\n", sep = "")

# ---- Phase 16 ---------------------------------------------------------------
p16_manifest <- read_tier("confirmatory", "v4-phase16-confirmation-raw-manifest-v1.csv")
p16_reps <- sort(list.files(PATHS$conf_raw, "replications-v1[.]csv[.]gz$", full.names = TRUE))
p16_truth <- sort(list.files(PATHS$conf_raw, "truth-v1[.]csv$", full.names = TRUE))
p16_receipts <- sort(list.files(PATHS$conf_raw, "receipt-v1[.]json$", full.names = TRUE))

chk("Phase 16 has 24 complete raw cell triplets and 72 manifest rows", {
  stopifnot(length(p16_reps) == 24L, length(p16_truth) == 24L,
            length(p16_receipts) == 24L, nrow(p16_manifest) == 72L)
})

chk("Phase 16 raw manifest and receipts match every shipped byte stream", {
  for (i in seq_len(24L)) {
    id <- sprintf("P16-C%03d", i)
    rep_path <- grep(id, p16_reps, value = TRUE)
    truth_path <- grep(id, p16_truth, value = TRUE)
    receipt_path <- grep(id, p16_receipts, value = TRUE)
    rec <- jsonlite::read_json(receipt_path, simplifyVector = TRUE)
    stopifnot(rec$status == "PASS_CELL_COMPLETE", rec$cell_id == id,
              rec$cell_index == i, rec$replications == 400L,
              rec$method_rows == 3600L, rec$draws == 499L,
              rec$output$size_bytes == uncompressed_size(rep_path),
              rec$output$sha256 == uncompressed_sha(rep_path),
              rec$truth$sha256 == file_sha(truth_path))

    paths <- c(receipt_path, rep_path, truth_path)
    for (p in paths) {
      stem <- basename(p)
      if (grepl("[.]gz$", stem)) stem <- sub("[.]gz$", "", stem)
      z <- p16_manifest[basename(p16_manifest$project_relative_path) == stem, , drop = FALSE]
      stopifnot(nrow(z) == 1L,
                z$size_bytes == uncompressed_size(p),
                z$sha256 == uncompressed_sha(p))
    }
  }
})

p16 <- read_confirmatory_raw()
chk("Phase 16 raw rows have the exact schema, key, and domains", {
  stopifnot(identical(names(p16), c(
    "method_id", "base_method_id", "target_id", "candidate", "gamma_cluster",
    "width_multiplier", "point_estimate", "truth", "bias", "lower", "upper",
    "center", "interval_length", "se_equivalent", "cover", "defined_draws",
    "total_draws", "invalid_fraction", "status", "stage", "cell_id",
    "replication", "G", "N", "latent_icc", "size_mechanism",
    "discrimination_center", "regularity", "threshold_profile",
    "informative_slope", "minimum_cluster_size", "maximum_cluster_size",
    "size_effect_correlation", "sample_minimum_internal_cdf_gap",
    "sample_exact_knot_count", "replication_elapsed_seconds")),
    !anyDuplicated(p16[c("cell_id", "replication", "method_id")]),
    all(p16$stage == "confirmation"),
    all(p16$regularity %in% c("regular", "near_knot", "exact_knot")),
    all(p16$lower <= p16$upper),
    same_num(p16$center, (p16$lower + p16$upper) / 2),
    same_num(p16$interval_length, p16$upper - p16$lower),
    all(p16$cover %in% c(TRUE, FALSE)),
    all(p16$invalid_fraction >= 0 & p16$invalid_fraction <= 1),
    all((is.na(p16$defined_draws) & is.na(p16$total_draws)) |
          (is.finite(p16$defined_draws) & is.finite(p16$total_draws) &
             p16$defined_draws <= p16$total_draws)))
})

summarise_p16 <- function(d, by) {
  dplyr::summarise(
    dplyr::group_by(d, dplyr::across(dplyr::all_of(by))),
    replications = dplyr::n(), coverage = mean(cover),
    coverage_mcse = sqrt(coverage * (1 - coverage) / replications),
    mean_interval_length = mean(interval_length),
    median_interval_length = stats::median(interval_length),
    mean_bias = mean(bias), maximum_invalid_fraction = max(invalid_fraction),
    status_ok_fraction = mean(status == "OK"), .groups = "drop"
  )
}

cell_calc <- p16 |>
  dplyr::filter(regularity == "regular", candidate) |>
  dplyr::mutate(target = ifelse(target_id == "V4-TARGET-EQUAL-CLUSTER-v1",
                                "equal_cluster", "respondent")) |>
  summarise_p16(c("gamma_cluster", "method_id", "target", "cell_id"))
cell_lock <- read_tier("confirmatory", "v4-phase16-confirmation-cell-summary-v1.csv")
cell_cmp <- dplyr::inner_join(cell_calc, cell_lock,
  by = c("gamma_cluster", "method_id", "target", "cell_id"), suffix = c(".calc", ".lock"))

cmp_calc <- p16 |>
  dplyr::filter(!candidate) |>
  summarise_p16(c("regularity", "method_id", "target_id"))
cmp_lock <- read_tier("confirmatory", "v4-phase16-confirmation-comparator-summary-v1.csv")
cmp_cmp <- dplyr::inner_join(cmp_calc, cmp_lock,
  by = c("regularity", "method_id", "target_id"), suffix = c(".calc", ".lock"))

compare_summary <- function(d, expected_rows) {
  stopifnot(nrow(d) == expected_rows,
            d$replications.calc == d$replications.lock,
            same_num(d$coverage.calc, d$coverage.lock),
            same_num(d$coverage_mcse.calc, d$coverage_mcse.lock),
            same_num(d$mean_interval_length.calc, d$mean_interval_length.lock),
            same_num(d$median_interval_length.calc, d$median_interval_length.lock),
            same_num(d$mean_bias.calc, d$mean_bias.lock),
            same_num(d$maximum_invalid_fraction.calc, d$maximum_invalid_fraction.lock),
            same_num(d$status_ok_fraction.calc, d$status_ok_fraction.lock))
}
chk("all 64 regular candidate cell summaries reconstruct from raw rows",
    compare_summary(cell_cmp, 64L))
chk("all 15 comparator summaries reconstruct from raw rows",
    compare_summary(cmp_cmp, 15L))

# ---- Phase 17 ---------------------------------------------------------------
p17_manifest <- read_tier("empirical", "v4-phase17-raw-manifest-v1.csv")
p17_files <- sort(list.files(PATHS$emp_raw, full.names = TRUE))
chk("Phase 17 has 12 complete task triplets and 36 manifest rows", {
  stopifnot(length(p17_files) == 36L, nrow(p17_manifest) == 36L)
})
chk("Phase 17 raw manifest matches compressed shipped files", {
  for (p in p17_files) {
    z <- p17_manifest[basename(p17_manifest$project_relative_path) == basename(p), , drop = FALSE]
    stopifnot(nrow(z) == 1L, z$size_bytes == unname(file.info(p)$size),
              z$sha256 == file_sha(p))
  }
})

method_lock <- read_tier("results", "v4-phase17-method-summary-v1.csv")
stable_lock <- read_tier("results", "v4-phase17-quantile-stability-v1.csv")
q8 <- function(x) unname(stats::quantile(x, c(.025, .975), type = 8))
kG <- 1 - 1.5 / sqrt(CFG$frozen_contract$swmdk_lock$clusters)
task_results <- vector("list", 12L)
stability_results <- list()

chk("all 12 task receipts, draw IDs, batches, seeds, and identities reconcile", {
  for (i in seq_len(12L)) {
    id <- sprintf("P17-T%02d", i)
    receipt_path <- file.path(PATHS$emp_raw, paste0(id, "-receipt-v1.json"))
    draw_path <- file.path(PATHS$emp_raw, paste0(id, "-draws-v1.csv.gz"))
    batch_path <- file.path(PATHS$emp_raw, paste0(id, "-batch-manifest-v1.csv"))
    rec <- jsonlite::read_json(receipt_path, simplifyVector = TRUE)
    d <- read_draws(i)
    b <- read_locked_csv(batch_path)
    stopifnot(rec$status == "PASS_TASK_COMPLETE", rec$task_id == id,
              rec$task_index == i, rec$draws == 99999L, rec$batches == 50L,
              rec$defined_draws == 99999L, rec$invalid_fraction == 0,
              rec$dataset_digest_sha256 == CFG$frozen_contract$swmdk_lock$object_digest_sha256,
              rec$draw_output$size_bytes == file.info(draw_path)$size,
              rec$draw_output$sha256 == file_sha(draw_path),
              rec$batch_manifest$size_bytes == file.info(batch_path)$size,
              rec$batch_manifest$sha256 == file_sha(batch_path),
              identical(names(d), c("task_id", "scale", "method_key", "method_id",
                "target", "draw_id", "batch_id", "within_batch_draw", "seed", "H")),
              nrow(d) == 99999L, !anyDuplicated(d$draw_id),
              identical(d$draw_id, seq_len(99999L)),
              all(d$task_id == id), all(d$scale == rec$scale),
              all(d$method_key == rec$method_key), all(d$method_id == rec$method_id),
              all(d$target == rec$target), all(is.finite(d$H)),
              nrow(b) == 50L, identical(b$batch_id, seq_len(50L)),
              !anyDuplicated(b$seed), sum(b$draws) == 99999L,
              sum(b$defined_draws) == 99999L, all(b$invalid_fraction == 0))
    for (j in seq_len(50L)) {
      z <- d[d$batch_id == j, ]
      stopifnot(nrow(z) == b$draws[j], min(z$draw_id) == b$first_draw_id[j],
                max(z$draw_id) == b$last_draw_id[j],
                identical(z$within_batch_draw, seq_len(nrow(z))),
                all(z$seed == b$seed[j]))
    }

    qu <- q8(d$H); center <- mean(qu); len <- diff(qu); se <- stats::sd(d$H)
    raw <- method_lock[method_lock$scale == rec$scale &
                         method_lock$method_id == rec$method_id &
                         method_lock$interval_role == "raw_or_comparator", , drop = FALSE]
    stopifnot(nrow(raw) == 1L, same_num(raw$lower, qu[1]),
              same_num(raw$upper, qu[2]), same_num(raw$center, center),
              same_num(raw$interval_length, len), same_num(raw$se_equivalent, se),
              raw$defined_draws == 99999L, raw$total_draws == 99999L,
              raw$invalid_fraction == 0)
    task_results[[i]] <- c(lower = qu[1], upper = qu[2], sd = se)

    selected <- method_lock[method_lock$scale == rec$scale &
                              method_lock$base_method_id == rec$method_id &
                              method_lock$target_role == rec$target &
                              method_lock$interval_role == "phase16_confirmed_selected", , drop = FALSE]
    if (nrow(selected)) {
      cal <- center + kG * (qu - center)
      stopifnot(nrow(selected) == 1L, same_num(selected$lower, cal[1]),
                same_num(selected$upper, cal[2]), same_num(selected$center, center),
                same_num(selected$interval_length, diff(cal)),
                same_num(selected$se_equivalent, se))
      first <- q8(d$H[seq_len(49999L)])
      second <- q8(d$H[50000:99999])
      first <- mean(first) + kG * (first - mean(first))
      second <- mean(second) + kG * (second - mean(second))
      stability_results[[length(stability_results) + 1L]] <- data.frame(
        scale = rec$scale, target = rec$target, method_id = selected$method_id,
        first_lower = first[1], first_upper = first[2],
        second_lower = second[1], second_upper = second[2])
    }
  }
})

chk("all 12 raw intervals and four calibrated intervals come from the draws", {
  stopifnot(length(task_results) == 12L, all(vapply(task_results, length, integer(1)) == 3L),
            length(stability_results) == 4L)
})

stable_calc <- do.call(rbind, stability_results)
stable_calc$lower_absolute_difference <- abs(stable_calc$first_lower - stable_calc$second_lower)
stable_calc$upper_absolute_difference <- abs(stable_calc$first_upper - stable_calc$second_upper)
stable_calc$maximum_endpoint_difference <- pmax(stable_calc$lower_absolute_difference,
                                                 stable_calc$upper_absolute_difference)
stable_cmp <- dplyr::inner_join(stable_calc, stable_lock,
  by = c("scale", "target", "method_id"), suffix = c(".calc", ".lock"))
chk("all four split-half quantile-stability rows reconstruct from raw draws", {
  stopifnot(nrow(stable_cmp) == 4L,
            same_num(stable_cmp$first_lower.calc, stable_cmp$first_lower.lock),
            same_num(stable_cmp$first_upper.calc, stable_cmp$first_upper.lock),
            same_num(stable_cmp$second_lower.calc, stable_cmp$second_lower.lock),
            same_num(stable_cmp$second_upper.calc, stable_cmp$second_upper.lock),
            same_num(stable_cmp$lower_absolute_difference.calc,
                     stable_cmp$lower_absolute_difference.lock),
            same_num(stable_cmp$upper_absolute_difference.calc,
                     stable_cmp$upper_absolute_difference.lock),
            same_num(stable_cmp$maximum_endpoint_difference.calc,
                     stable_cmp$maximum_endpoint_difference.lock),
            stable_cmp$maximum_endpoint_difference.calc < stable_cmp$threshold,
            stable_cmp$pass)
})

cat(strrep("-", 72), "\n", sep = "")
cat(sprintf("%d passed, %d failed\n", pass, fail))
if (fail) quit(status = 1L)
cat("PASS  Phase 16 raw summaries and all Phase 17 draw streams reconcile\n")
