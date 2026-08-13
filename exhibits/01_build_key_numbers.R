# ============================================================================
# 01_build_key_numbers.R --- the Paper B manuscript number ledger.
# Reads ONLY locked v4 artifacts; one row per number appearing in text,
# tables, or figure annotations. Never edit key_numbers.csv by hand.
# ============================================================================

source("00_common.R")

rows <- list()
put <- function(key, value, source) {
  rows[[length(rows) + 1L]] <<- data.frame(
    key = key, value = format(value, digits = 15, scientific = FALSE),
    source = source, stringsAsFactors = FALSE
  )
}

# ---- phase 16 fresh confirmation -------------------------------------------
SRC16 <- "confirmatory/artifacts"
sel_ov <- p16_overall |> filter(gamma_cluster == -1.5)
raw_ov <- p16_overall |> filter(gamma_cluster == 0)
put("p16_resp_cov", sel_ov$coverage[sel_ov$target == "respondent"], SRC16)
put("p16_resp_mcse", sel_ov$coverage_mcse[sel_ov$target == "respondent"], SRC16)
put("p16_eqcl_cov", sel_ov$coverage[sel_ov$target == "equal_cluster"], SRC16)
put("p16_eqcl_mcse", sel_ov$coverage_mcse[sel_ov$target == "equal_cluster"], SRC16)
put("p16_resp_len", sel_ov$mean_interval_length[sel_ov$target == "respondent"], SRC16)
put("p16_eqcl_len", sel_ov$mean_interval_length[sel_ov$target == "equal_cluster"], SRC16)
put("p16_raw_resp_cov", raw_ov$coverage[raw_ov$target == "respondent"], SRC16)
put("p16_raw_eqcl_cov", raw_ov$coverage[raw_ov$target == "equal_cluster"], SRC16)
put("p16_raw_resp_len", raw_ov$mean_interval_length[raw_ov$target == "respondent"], SRC16)
put("p16_sel_raw_ratio",
    sel_ov$mean_interval_length[sel_ov$target == "respondent"] /
      raw_ov$mean_interval_length[raw_ov$target == "respondent"], SRC16)
put("p16_reps_per_target", unique(sel_ov$replications), SRC16)

# lanes (selected method)
for (i in seq_len(nrow(p16_lane))) {
  r <- p16_lane[i, ]
  put(paste0("p16_lane_", r$regularity, "_", r$target, "_cov"), r$coverage, SRC16)
  put(paste0("p16_lane_", r$regularity, "_", r$target, "_len"),
      r$mean_interval_length, SRC16)
}

# regular-lane comparators
creg <- p16_comp |> filter(regularity == "regular")
key_of <- c("V4-CMP-IID-RESP-BB-v1" = "iid",
            "V4-CMP-MOKKEN-TWOLEVEL-DELTA-v1" = "delta",
            "V4-CMP-ONE-STAGE-CLUSTER-BB-RESP-v1" = "onestage",
            "V4-CMP-TWO-STAGE-FREQ-BOOT-RESP-v1" = "freqboot",
            "V4-DIAG-WITHIN-STAGE-HBB-RESP-v1" = "within")
for (i in seq_len(nrow(creg))) {
  k <- key_of[[creg$method_id[i]]]
  put(paste0("p16_cmp_", k, "_cov"), creg$coverage[i], SRC16)
  put(paste0("p16_cmp_", k, "_len"), creg$mean_interval_length[i], SRC16)
}
# knot-lane comparator ranges (for text)
for (lane in c("exact_knot", "near_knot")) {
  cl <- p16_comp |> filter(regularity == lane)
  put(paste0("p16_cmp_iid_", lane, "_cov"),
      cl$coverage[cl$method_id == "V4-CMP-IID-RESP-BB-v1"], SRC16)
  put(paste0("p16_cmp_delta_", lane, "_cov"),
      cl$coverage[cl$method_id == "V4-CMP-MOKKEN-TWOLEVEL-DELTA-v1"], SRC16)
  put(paste0("p16_cmp_within_", lane, "_cov"),
      cl$coverage[cl$method_id == "V4-DIAG-WITHIN-STAGE-HBB-RESP-v1"], SRC16)
}
put("p16_sel_vs_delta_len_pct",
    100 * (sel_ov$mean_interval_length[sel_ov$target == "respondent"] /
             creg$mean_interval_length[creg$method_id == "V4-CMP-MOKKEN-TWOLEVEL-DELTA-v1"]),
    SRC16)
put("p16_sel_vs_freqboot_len_pct",
    100 * (sel_ov$mean_interval_length[sel_ov$target == "respondent"] /
             creg$mean_interval_length[creg$method_id == "V4-CMP-TWO-STAGE-FREQ-BOOT-RESP-v1"]),
    SRC16)

# selected cell-level extremes from the LOCKED cell-summary artifact.
# NOTE: that artifact covers the 16 regular decision cells only (the
# evaluator filters to the decision lane before summarizing); it must never
# be labeled as an all-cell quantity. All-lane extremes are derived from the
# raw replication rows below.
selc <- p16_cells |> filter(gamma_cluster == -1.5)
put("p16_cells_rows", nrow(p16_cells), SRC16)
put("p16_invalid_max", max(selc$maximum_invalid_fraction), SRC16)
# regular-lane-only min/max for the gate narrative
reg_ids <- p16_design$cell_id[p16_design$regularity == "regular"]
stopifnot(all(selc$cell_id %in% reg_ids))
put("p16_sel_regcell_cov_min", min(selc$coverage), SRC16)
put("p16_sel_regcell_cov_max", max(selc$coverage), SRC16)

# ---- all-lane cell table derived from the raw phase-16 replication rows ----
# The OSM promises every confirmation cell, so the 24-cell (48 cell-target)
# table is derived directly from the locked raw replication files and
# cross-checked against the locked regular-cell artifact before any use.
SRCRAW <- "confirmatory/aws-raw (derived, cross-checked)"
raw_files <- list.files(PATHS$conf_raw,
                        pattern = "^P16-C[0-9]+-replications-v1[.]csv[.]gz$",
                        full.names = TRUE)
stopifnot(length(raw_files) == 24L)
raw_rep <- do.call(rbind, lapply(raw_files, read_locked_csv_gz))
stopifnot(nrow(raw_rep) == 86400L)
sel_raw <- raw_rep |> filter(candidate, gamma_cluster == -1.5)
stopifnot(nrow(sel_raw) == 19200L, all(sel_raw$invalid_fraction == 0),
          all(sel_raw$total_draws == 499L))
tgt_lab <- c("V4-TARGET-RESPONDENT-WEIGHTED-v1" = "respondent",
             "V4-TARGET-EQUAL-CLUSTER-v1" = "equal_cluster")
allcell <- sel_raw |>
  mutate(target = tgt_lab[target_id]) |>
  group_by(cell_id, target, regularity) |>
  summarise(replications = dplyr::n(),
            coverage = mean(cover),
            coverage_mcse = sqrt(coverage * (1 - coverage) / dplyr::n()),
            mean_interval_length = mean(interval_length),
            .groups = "drop") |>
  arrange(cell_id, target)
stopifnot(nrow(allcell) == 48L, all(allcell$replications == 400L))
# Cross-check: the derived regular rows must reproduce the locked artifact.
xchk <- selc |>
  select(cell_id, target, coverage, mean_interval_length) |>
  inner_join(allcell |> filter(regularity == "regular") |>
               select(cell_id, target, coverage, mean_interval_length),
             by = c("cell_id", "target"), suffix = c("_lock", "_raw"))
stopifnot(nrow(xchk) == 32L,
          max(abs(xchk$coverage_lock - xchk$coverage_raw)) < 1e-12,
          max(abs(xchk$mean_interval_length_lock -
                    xchk$mean_interval_length_raw)) < 1e-9)
write.csv(allcell, file.path(PATHS$out_root, "derived_p16_allcell_summary.csv"), row.names = FALSE)
put("p16_allcell_rows", nrow(allcell), SRCRAW)
put("p16_sel_allcell_cov_min", min(allcell$coverage), SRCRAW)
put("p16_sel_allcell_cov_max", max(allcell$coverage), SRCRAW)
put("p16_sel_diagcell_cov_min",
    min(allcell$coverage[allcell$regularity != "regular"]), SRCRAW)

# ---- stage execution parameters read from the frozen protocols -------------
# (never typed by hand; phase 15 and phase 16 differ: 299/41 vs 499/51)
yml_num <- function(path, key) {
  line <- grep(paste0("^\\s*", key, ":"), readLines(path), value = TRUE)[1]
  as.numeric(sub(paste0("^\\s*", key, ":\\s*"), "", line))
}
p16_proto <- file.path(PATHS$confirmatory, "v4-phase16-confirmation-protocol-v1.yml")
p15_proto <- file.path(PATHS$design, "v4-phase15-development-validation-protocol-v1.yml")
put("p16_draws", yml_num(p16_proto, "random_weight_draws"), "phase16 protocol")
put("p16_truth_nodes", yml_num(p16_proto, "truth_nodes_per_dimension"),
    "phase16 protocol")
put("p15_draws", yml_num(p15_proto, "random_weight_draws"), "phase15 protocol")
put("p15_truth_nodes", yml_num(p15_proto, "nodes_per_dimension"),
    "phase15 protocol")
stopifnot(unique(sel_raw$total_draws) == yml_num(p16_proto, "random_weight_draws"))

# threshold-profile counts and near-knot offsets are stage-specific frozen
# design parameters (a phase-15 profile count/offset survived into phase-16
# prose in v2); parse them from the protocols so the verifier can bind them.
yml_block_keys <- function(path, block) {
  lines <- readLines(path)
  start <- grep(paste0("^\\s*", block, ":\\s*$"), lines)[1]
  indent <- nchar(sub("\\S.*$", "", lines[start]))
  n <- 0L
  for (i in seq(start + 1L, length(lines))) {
    li <- lines[i]
    if (!nzchar(trimws(li))) next
    ind <- nchar(sub("\\S.*$", "", li))
    if (ind <= indent) break
    if (grepl("^\\s*[A-Za-z0-9_]+:", li)) n <- n + 1L
  }
  n
}
yml_list_second <- function(path, key) {
  line <- grep(paste0("^\\s*", key, ":\\s*\\["), readLines(path), value = TRUE)[1]
  vals <- strsplit(gsub("^[^\\[]*\\[|\\].*$", "", line), ",")[[1]]
  as.numeric(trimws(vals))[2]
}
put("p15_threshold_profiles", yml_block_keys(p15_proto, "threshold_profiles"),
    "phase15 protocol")
put("p16_threshold_profiles", yml_block_keys(p16_proto, "threshold_profiles"),
    "phase16 protocol")
p15_lines <- readLines(p15_proto)
nk_train <- yml_list_second(p15_proto, "training")
nk_val <- yml_list_second(p15_proto, "validation")
put("p15_nearknot_offset_training", nk_train, "phase15 protocol")
put("p15_nearknot_offset_validation", nk_val, "phase15 protocol")
put("p16_nearknot_offset", yml_list_second(p16_proto, "near_knot_offsets"),
    "phase16 protocol")
stopifnot(yml_block_keys(p15_proto, "threshold_profiles") == 6L,
          yml_block_keys(p16_proto, "threshold_profiles") == 3L,
          nk_train == 2e-4, nk_val == 3.5e-4)

# subgroup coverage extremes (selected, by G and size mechanism)
subsel <- p16_sub |> filter(gamma_cluster == -1.5)
put("p16_min_G_group_cov",
    min(subsel$coverage[subsel$grouping_variable == "G"]), SRC16)
put("p16_min_sizemech_group_cov",
    min(subsel$coverage[subsel$grouping_variable != "G"]), SRC16)
put("p16_gates_total", nrow(p16_gates), SRC16)
put("p16_gates_passed", sum(p16_gates[[2]] == "TRUE" | p16_gates[[2]] == TRUE), SRC16)

# design facts
put("p16_design_cells", nrow(p16_design), "confirmatory design")
put("p16_design_regular", sum(p16_design$regularity == "regular"), "design")
put("p16_design_nearknot", sum(p16_design$regularity == "near_knot"), "design")
put("p16_design_exactknot", sum(p16_design$regularity == "exact_knot"), "design")
put("p16_G_min", min(p16_design$G), "design")
put("p16_G_max", max(p16_design$G), "design")
put("p16_icc_min", min(p16_design$latent_icc), "design")
put("p16_icc_max", max(p16_design$latent_icc), "design")

# ---- phase 15 development ---------------------------------------------------
SRC15 <- "development+validation artifacts"
put("p15_gamma_grid_n", length(unique(p15_dec$gamma_cluster)), SRC15)
put("p15_eligible_n", sum(p15_dec$eligible == "TRUE" | p15_dec$eligible == TRUE), SRC15)
sel15 <- p15_dec |> filter(gamma_cluster == -1.5)
alt15 <- p15_dec |> filter(gamma_cluster == -1.25)
put("p15_sel_train_resp_cov", sel15$respondent_coverage, SRC15)
put("p15_sel_train_resp_len", sel15$respondent_mean_interval_length, SRC15)
put("p15_alt_train_resp_len", alt15$respondent_mean_interval_length, SRC15)
put("p15_sel_vs_alt_len_pct",
    100 * (1 - sel15$respondent_mean_interval_length /
             alt15$respondent_mean_interval_length), SRC15)
val_sel <- p15_val |> filter(gamma_cluster == -1.5)
val_raw <- p15_val |> filter(gamma_cluster == 0)
put("p15_val_resp_cov", val_sel$coverage[val_sel$target == "respondent"], SRC15)
put("p15_val_eqcl_cov", val_sel$coverage[val_sel$target == "equal_cluster"], SRC15)
put("p15_val_raw_resp_cov", val_raw$coverage[val_raw$target == "respondent"], SRC15)
put("p15_val_raw_eqcl_cov", val_raw$coverage[val_raw$target == "equal_cluster"], SRC15)

# ---- phase 14 pilot ---------------------------------------------------------
SRC14 <- "pilot aggregate"
# respondent-target primary-HBB coverage across the three pilot lanes
# (the range quoted in the introduction/abstract; the equal-cluster
# sensitivity lanes span more widely and are keyed separately)
p14_resp_lane <- p14_agg |>
  filter(method_id == "V4-PRI-TWO-STAGE-HBB-RESP-v1", regularity != "all")
stopifnot(nrow(p14_resp_lane) == 3L)
put("p14_resp_lane_cov_min", min(p14_resp_lane$coverage), "pilot aggregate")
put("p14_resp_lane_cov_max", max(p14_resp_lane$coverage), "pilot aggregate")
p14_hbb_lane <- p14_agg |>
  filter(method_id %in% c("V4-PRI-TWO-STAGE-HBB-RESP-v1",
                          "V4-SENS-TWO-STAGE-HBB-CLUSTER-v1"),
         regularity != "all")
put("p14_hbb_lane_cov_min", min(p14_hbb_lane$coverage), "pilot aggregate")
put("p14_hbb_lane_cov_max", max(p14_hbb_lane$coverage), "pilot aggregate")

agg_all <- p14_agg |> filter(regularity == "all")
put("p14_raw_hbb_cov_all",
    agg_all$coverage[agg_all$method_id == "V4-PRI-TWO-STAGE-HBB-RESP-v1"], SRC14)
put("p14_iid_cov_all",
    agg_all$coverage[agg_all$method_id == "V4-CMP-IID-RESP-BB-v1"], SRC14)
put("p14_onestage_cov_all",
    agg_all$coverage[grepl("ONE-STAGE", agg_all$method_id)], SRC14)

# ---- phase 17 SWMDK ---------------------------------------------------------
SRC17 <- "empirical-swmdk/phase17"
km <- jsonlite::read_json(file.path(PATHS$empirical, "v4-phase17-key-metrics-v1.json"),
                          simplifyVector = TRUE)
put("swmdk_n", km$dataset$respondents, SRC17)
put("swmdk_G", km$dataset$clusters, SRC17)
put("swmdk_size_min", km$dataset$cluster_size_range[1], SRC17)
put("swmdk_size_max", km$dataset$cluster_size_range[2], SRC17)
put("swmdk_min_cat_count", km$dataset$minimum_fixed_category_count, SRC17)
put("swmdk_min_cat_mass", km$dataset$minimum_fixed_category_mass, SRC17)
put("swmdk_width_mult", km$method$width_multiplier_at_G_30, SRC17)
put("swmdk_split_half_max", km$method$maximum_split_half_endpoint_difference, SRC17)
put("swmdk_invalid_max", km$method$maximum_invalid_fraction, SRC17)
put("teacher_icc", km$teacher$ICC, SRC17)
put("teacher_resp_H", km$teacher$respondent_point_H, SRC17)
put("teacher_resp_lo", km$teacher$respondent_selected_interval[1], SRC17)
put("teacher_resp_hi", km$teacher$respondent_selected_interval[2], SRC17)
put("teacher_eqcl_H", km$teacher$equal_cluster_point_H, SRC17)
put("teacher_target_diff", km$teacher$target_difference, SRC17)
put("classmate_icc", p17_icc$ICC[p17_icc$scale == "classmate"], SRC17)
put("classmate_resp_H", km$classmate$respondent_point_H, SRC17)
put("classmate_resp_lo", km$classmate$respondent_selected_interval[1], SRC17)
put("classmate_resp_hi", km$classmate$respondent_selected_interval[2], SRC17)

sel17 <- p17_methods |> filter(interval_role == "phase16_confirmed_selected")
for (i in seq_len(nrow(sel17))) {
  r <- sel17[i, ]
  pre <- paste0("swmdk_", r$scale, "_", r$target_role)
  put(paste0(pre, "_H"), r$point_estimate, SRC17)
  put(paste0(pre, "_lo"), r$lower, SRC17)
  put(paste0(pre, "_hi"), r$upper, SRC17)
  put(paste0(pre, "_len"), r$interval_length, SRC17)
}
# 12 AWS computation tasks each generated 99,999 weight draws; the four
# selected intervals are deterministic k_G transforms of the raw HBB draw
# streams, so unique draws = 12 x 99,999.
draw_rows <- p17_methods |> filter(!is.na(total_draws))
stopifnot(all(draw_rows$total_draws == 99999L),
          nrow(draw_rows) == 16L)
put("swmdk_draws_per_task", 99999L, SRC17)
put("swmdk_tasks", 12L, SRC17)
put("swmdk_total_draws", 12L * 99999L, SRC17)
# comparator lengths (respondent, per scale)
cmp17 <- function(scale, pat) {
  d <- p17_methods |> filter(scale == !!scale, grepl(pat, method_id))
  d$interval_length[1]
}
put("swmdk_teacher_delta_len", cmp17("teacher", "TWOLEVEL-DELTA"), SRC17)
put("swmdk_classmate_delta_len", cmp17("classmate", "TWOLEVEL-DELTA"), SRC17)
put("swmdk_teacher_raw_len", cmp17("teacher", "^V4-PRI-TWO-STAGE-HBB"), SRC17)
put("swmdk_teacher_iid_len", cmp17("teacher", "IID-RESP-BB"), SRC17)
put("swmdk_classmate_iid_len", cmp17("classmate", "IID-RESP-BB"), SRC17)
tsel <- sel17 |> filter(scale == "teacher", target_role == "respondent")
csel <- sel17 |> filter(scale == "classmate", target_role == "respondent")
put("swmdk_sel_vs_delta_teacher_pct",
    100 * tsel$interval_length / cmp17("teacher", "TWOLEVEL-DELTA"), SRC17)
put("swmdk_sel_vs_delta_classmate_pct",
    100 * csel$interval_length / cmp17("classmate", "TWOLEVEL-DELTA"), SRC17)
# knots
kt <- p17_knots
put("swmdk_teacher_resp_exact_knots",
    as.integer(kt$exact_knot_count[kt$scale == "teacher" & kt$target == "respondent"]), SRC17)
put("swmdk_teacher_eqcl_exact_knots",
    as.integer(kt$exact_knot_count[kt$scale == "teacher" & kt$target == "equal_cluster"]), SRC17)
put("swmdk_classmate_eqcl_target_diff",
    num(kt$target_difference_from_respondent[kt$scale == "classmate" & kt$target == "equal_cluster"]), SRC17)

g17 <- read_locked_csv(file.path(PATHS$empirical, "v4-g17-gate-criteria-v1.csv"))
put("g17_total", nrow(g17), SRC17)
put("g17_passed", sum(g17$pass == "TRUE" | g17$pass == TRUE), SRC17)

# ---- phase 18 receipts ------------------------------------------------------
pm <- jsonlite::read_json(file.path(PATHS$p18_prod, "v4-step18-2-package-metrics-v1.json"),
                          simplifyVector = TRUE)
put("pkg_test_files", pm$package_tests$files, "phase18-production")
put("pkg_test_blocks", pm$package_tests$test_blocks, "phase18-production")
put("pkg_expectations", pm$package_tests$expectations, "phase18-production")
put("pkg_lp_fixtures", pm$transport_oracle$LP_fixtures, "phase18-production")
put("pkg_lp_maxdiff", pm$transport_oracle$maximum_absolute_difference, "phase18-production")
g18a <- jsonlite::read_json(
  file.path(PATHS$p18_review, "v4-g18a-final-decision-receipt-v1.json"),
  simplifyVector = TRUE)
put("g18a_gate_passed", g18a$blocking_gate$passed, "phase18-review")
put("g18a_crosswalks", g18a$original_sources$crosswalks_closed, "phase18-review")

# ---- write ------------------------------------------------------------------
ledger <- do.call(rbind, rows)
stopifnot(!anyDuplicated(ledger$key))
stopifnot(nrow(ledger) == CFG$exhibit_contract$key_numbers_rows)
dir.create(PATHS$out_root, showWarnings = FALSE, recursive = TRUE)
write.csv(ledger, KEY_PATH, row.names = FALSE)
message("key_numbers.csv written: ", nrow(ledger), " keys")
