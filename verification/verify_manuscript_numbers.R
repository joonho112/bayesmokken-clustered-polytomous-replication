#!/usr/bin/env Rscript
# =============================================================================
# verification/verify_manuscript_numbers.R -- does the REBUILT ledger agree
# with the paper?
#
#     Rscript exhibits/00_build_all.R
#     Rscript verification/verify_manuscript_numbers.R
#
# PASS 1 -- ledger integrity. The ledger this package rebuilds from
# data-frozen/ must be byte-identical to the one the manuscript verified
# against. The SHA-256 below is the constant the manuscript's own
# tools/verify_numbers.R carries, copied verbatim.
#
# PASS 2 -- the manuscript's concordance predicates, re-expressed against the
# REBUILT ledger rather than the shipped one. A check run against the ledger it
# came from proves only self-consistency.
#
# WHAT IS AND IS NOT TESTED HERE
#
# The manuscript's verifier runs 69 checks, each with two halves: a predicate
# over ledger values, and a grep for an exact string in the .tex sources. This
# package holds the ledger but not the manuscript, so it tests the ledger-scope
# predicates. The needle half of each, and the manuscript's claim-boundary audit
# (six phrases the article never asserts outside a negation), run in the
# manuscript directory where the text lives.
#
# The predicates were extracted from the manuscript's verifier with R's own
# parser rather than transcribed, so a copying error cannot put the package and
# the manuscript out of step.
# =============================================================================

.here <- local({
  fa <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(fa)) dirname(normalizePath(gsub("~+~", " ", sub("^--file=", "", fa[1]),
                                             fixed = TRUE), mustWork = FALSE)) else getwd()
})
source(file.path(dirname(.here), "common", "R", "paths.R"))
suppressPackageStartupMessages(library(digest))
cfg <- yaml::read_yaml(PATHS$config)

LEDGER_SHA256 <- "6a42e7352e455ff060f05fdbec72d51c9327d488aa1d0f335ea46c57403d1c67"

KEY_PATH <- file.path(PATHS$out_root, "key_numbers.csv")
if (!file.exists(KEY_PATH)) {
  cat("FAIL  outputs/key_numbers.csv missing -- run exhibits/00_build_all.R first\n")
  quit(status = 1L)
}

cat("\nmanuscript number concordance\n")
cat(strrep("-", 72), "\n", sep = "")

have <- digest(file = KEY_PATH, algo = "sha256")
ok1 <- identical(have, LEDGER_SHA256)
cat(sprintf("PASS1 ledger integrity: sha256 %s (%s)\n",
            substr(have, 1, 16), if (ok1) "match" else "MISMATCH"))

key_numbers <- read.csv(KEY_PATH, stringsAsFactors = FALSE)
row_count_ok <- nrow(key_numbers) == cfg$exhibit_contract$key_numbers_rows
cat(sprintf("PASS1b ledger row contract: %d rows (%s)\n", nrow(key_numbers),
            if (row_count_ok) "match" else "MISMATCH"))
kn <- function(k) {
  v <- key_numbers$value[key_numbers$key == k]
  if (length(v) != 1L) stop("ledger key not found or not unique: ", k, call. = FALSE)
  suppressWarnings(as.numeric(v))
}
fmt_h <- function(x, digits = 3) sub("^(-?)0\\.", "\\1.", formatC(x, format = "f", digits = digits))
pct1 <- function(x) formatC(100 * x, format = "f", digits = 1)

checks <- list()
chk <- function(id, cond) {
  checks[[length(checks) + 1L]] <<- data.frame(id = id, pass = isTRUE(cond),
                                               stringsAsFactors = FALSE)
}

# NOTE. The manuscript's verifier keeps its PASS-1 stanza below the 'PASS 2'
# marker, so the extraction picked it up along with the checks. It is removed
# here: it re-derives KEY_PATH from an undecoded --file= argument (which breaks
# on any path containing a space) and re-defines kn(), fmt_h() and pct1()
# against the manuscript's own ledger rather than the rebuilt one. The header
# above already establishes all of those against outputs/key_numbers.csv.

chk("p16-resp-sim", fmt_h(kn("p16_resp_cov"), 4) == ".9736")
chk("p16-eqcl-sim", fmt_h(kn("p16_eqcl_cov"), 4) == ".9738")
chk("p16-both-abstract", fmt_h(kn("p16_resp_cov"), 3) == ".974" && 
    fmt_h(kn("p16_eqcl_cov"), 3) == ".974")
chk("p16-reglane-abstract", kn("p16_design_regular") == 16)
chk("p16-raw-sim", fmt_h(kn("p16_raw_resp_cov"), 4) == ".9975" && 
    abs(kn("p16_raw_eqcl_cov") - 0.99625) < 1e-12)
chk("p16-raw-tab2-resp", fmt_h(kn("p16_raw_resp_cov"), 4) == 
    ".9975" && sprintf("%.4f", kn("p16_raw_resp_len")) == "0.1167")
chk("p16-raw-tab2-eqcl", abs(kn("p16_raw_eqcl_cov") - 0.99625) < 
    1e-12)
chk("p16-ratio-sim", sprintf("%.1f", 100 * kn("p16_sel_raw_ratio")) == 
    "75.1")
chk("p16-ratio-abstract", round(100 * kn("p16_sel_raw_ratio")) == 
    75)
chk("p16-allcellspan-sim", fmt_h(kn("p16_sel_allcell_cov_min"), 
    3) == ".925" && fmt_h(kn("p16_sel_allcell_cov_max"), 3) == 
    ".995")
chk("p16-regmin-sim", fmt_h(kn("p16_sel_regcell_cov_min"), 3) == 
    ".930")
chk("p16-diagmin-sim", fmt_h(kn("p16_sel_diagcell_cov_min"), 
    3) == ".925" && fmt_h(kn("p16_sel_allcell_cov_min"), 3) == 
    ".925")
# Re-rooted onto the REBUILT float rather than the manuscript's copy, which
# makes the check stronger: it now confirms this package's own tabF1 carries all
# 48 cell-target rows.
chk("p16-tabF1-rows", length(grep("^P16-C", readLines(file.path(PATHS$out_float,
    "tabF1_cells.tex")))) == 48L)
chk("p15-draws-method", kn("p15_draws") == 299)
chk("p16-draws-sim", kn("p16_draws") == 499)
chk("p16-draws-tab2", kn("p16_draws") == 499)
chk("p16-nodes-sim", kn("p16_truth_nodes") == 51)
chk("p15-nodes-osmD", kn("p15_truth_nodes") == 41)
chk("p16-nodes-osmD", kn("p16_truth_nodes") == 51)
chk("iid-reg-sim", fmt_h(kn("p16_cmp_iid_cov"), 3) == ".915")
chk("iid-knot-sim", fmt_h(kn("p16_cmp_iid_exact_knot_cov"), 3) == 
    ".880")
chk("iid-abstract", fmt_h(kn("p16_cmp_iid_cov"), 3) == ".915")
chk("onestage-sim", fmt_h(kn("p16_cmp_onestage_cov"), 3) == ".926")
chk("within-sim", fmt_h(kn("p16_cmp_within_cov"), 3) == ".896")
chk("freqboot-sim", fmt_h(kn("p16_cmp_freqboot_cov"), 3) == ".990")
chk("freqboot-len-sim", round(100 * (kn("p16_cmp_freqboot_len")/kn("p16_resp_len") - 
    1)) == 15)
chk("delta-sim", fmt_h(kn("p16_cmp_delta_cov"), 3) == ".981" && 
    sprintf("%.1f", 100 * (kn("p16_cmp_delta_len")/kn("p16_resp_len") - 
        1)) == "7.1")
chk("delta-abstract", fmt_h(kn("p16_cmp_delta_cov"), 3) == ".981" && 
    round(100 * (kn("p16_cmp_delta_len")/kn("p16_resp_len") - 
        1)) == 7)
chk("G-subgroup-sim", fmt_h(min(kn("p16_min_G_group_cov"), 1), 
    3) == ".951" || fmt_h(kn("p16_min_G_group_cov"), 4) == ".9506")
chk("mech-subgroup-sim", fmt_h(kn("p16_min_sizemech_group_cov"), 
    4) == ".9675")
chk("gates-sim", kn("p16_gates_passed") == 7 && kn("p16_gates_total") == 
    7)
chk("profiles-sim", kn("p16_threshold_profiles") == 3)
chk("profiles-sim-six", kn("p15_threshold_profiles") == 6)
chk("profiles-osmD", kn("p15_threshold_profiles") == 6)
chk("profiles-osmD-confirm", kn("p16_threshold_profiles") == 
    3)
chk("nearknot-osmD", kn("p15_nearknot_offset_training") == 2e-04 && 
    kn("p15_nearknot_offset_validation") == 0.00035 && kn("p16_nearknot_offset") == 
    5e-04)
chk("disc-lane", kn("p16_design_regular") == 16)
chk("disc-974", fmt_h(kn("p16_resp_cov"), 3) == ".974" && fmt_h(kn("p16_eqcl_cov"), 
    3) == ".974")
chk("knotlane-sim", fmt_h(kn("p16_lane_exact_knot_respondent_cov"), 
    3) == ".955" && fmt_h(kn("p16_lane_near_knot_respondent_cov"), 
    3) == ".968")
chk("grid-method", kn("p15_gamma_grid_n") == 6)
chk("eligible-method", kn("p15_eligible_n") == 2)
chk("sel-shorter-method", sprintf("%.1f", kn("p15_sel_vs_alt_len_pct")) == 
    "6.3")
chk("heldout-method", fmt_h(kn("p15_val_resp_cov"), 4) == ".9718" && 
    fmt_h(kn("p15_val_eqcl_cov"), 4) == ".9722")
chk("fallback-method", fmt_h(kn("p15_val_raw_resp_cov"), 4) == 
    ".9949" && fmt_h(kn("p15_val_raw_eqcl_cov"), 4) == ".9968")
pilot_ok <- fmt_h(kn("p14_resp_lane_cov_min"), 3) == ".992" && 
    fmt_h(kn("p14_resp_lane_cov_max"), 3) == ".997" && fmt_h(kn("p14_hbb_lane_cov_min"), 
    3) == ".989" && kn("p14_hbb_lane_cov_max") == 1
chk("pilot-intro", pilot_ok)
chk("pilot-abstract", pilot_ok)
chk("pilot-theory", pilot_ok)
chk("pilot-method", pilot_ok)
chk("pilot-method-alltarget", pilot_ok)
chk("pilot-osmE-target", pilot_ok)
chk("pilot-osmE-eqcl", pilot_ok)
chk("pilot-osmE", fmt_h(kn("p14_raw_hbb_cov_all"), 3) == ".994")
chk("swmdk-teacher-emp", fmt_h(kn("teacher_resp_H"), 4) == ".6199")
chk("swmdk-teacher-ci-emp", fmt_h(kn("teacher_resp_lo"), 4) == 
    ".5728" && fmt_h(kn("teacher_resp_hi"), 4) == ".6692")
chk("swmdk-classmate-emp", fmt_h(kn("classmate_resp_H"), 4) == 
    ".5923" && fmt_h(kn("classmate_resp_lo"), 4) == ".5431" && 
    fmt_h(kn("classmate_resp_hi"), 4) == ".6408")
chk("swmdk-abstract", fmt_h(kn("teacher_resp_lo"), 3) == ".573" && 
    fmt_h(kn("teacher_resp_hi"), 3) == ".669")
chk("swmdk-eqcl-emp", fmt_h(kn("swmdk_teacher_equal_cluster_H"), 
    4) == ".6223" && fmt_h(kn("swmdk_classmate_equal_cluster_H"), 
    4) == ".5829")
chk("swmdk-targetdiff-emp", fmt_h(kn("teacher_target_diff"), 
    4) == ".0024" && fmt_h(kn("swmdk_classmate_eqcl_target_diff"), 
    4) == "-.0094")
chk("swmdk-kG-emp", fmt_h(kn("swmdk_width_mult"), 4) == ".7261")
chk("swmdk-vs-delta-emp", sprintf("%.1f", kn("swmdk_sel_vs_delta_teacher_pct")) == 
    "96.0" && sprintf("%.1f", kn("swmdk_sel_vs_delta_classmate_pct")) == 
    "98.5")
chk("swmdk-draws-emp", kn("swmdk_total_draws") == 1199988)
chk("swmdk-icc-emp", fmt_h(kn("teacher_icc"), 3) == ".169" && 
    fmt_h(kn("classmate_icc"), 3) == ".183")
chk("swmdk-g17-emp", kn("g17_passed") == 14)
chk("swmdk-splithalf-emp", kn("swmdk_split_half_max") < 9e-04)
chk("swmdk-catmass-emp", fmt_h(kn("swmdk_min_cat_mass"), 4) == 
    ".0031")
chk("swmdk-knots-emp", kn("swmdk_teacher_resp_exact_knots") == 
    2 && kn("swmdk_teacher_eqcl_exact_knots") == 0)
chk("pkg-suite-method", kn("pkg_expectations") == 791 && kn("pkg_test_files") == 
    24)
chk("lp-oracle-osmB", kn("pkg_lp_maxdiff") < 1.5e-12)
chk("g18a-sim", kn("g18a_gate_passed") == 13 && kn("g18a_crosswalks") == 
    3)

res <- do.call(rbind, checks)
fails <- res[!res$pass, , drop = FALSE]
check_count_ok <- nrow(res) == cfg$exhibit_contract$manuscript_checks
cat(sprintf("PASS2 ledger predicates: %d checks, %d failed\n", nrow(res), nrow(fails)))
cat(sprintf("PASS2b predicate-count contract: expected %d (%s)\n",
            cfg$exhibit_contract$manuscript_checks,
            if (check_count_ok) "match" else "MISMATCH"))
if (nrow(fails)) print(fails, row.names = FALSE)

cat(strrep("-", 72), "\n", sep = "")
if (!ok1 || !row_count_ok || !check_count_ok || nrow(fails)) {
  cat("FAIL  ledger integrity ", if (ok1) "ok" else "MISMATCH",
      ", ", nrow(fails), " predicate failure(s)\n", sep = "")
  quit(status = 1L)
}
cat("PASS  ", nrow(res), " / ", nrow(res),
    " ledger predicates hold on the rebuilt ledger\n", sep = "")
quit(status = 0L)
