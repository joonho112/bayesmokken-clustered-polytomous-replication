# ============================================================================
# 99_verify_manuscript_numbers.R --- Paper B pre-submission number audit.
# PASS 1: re-derive the ledger from locked artifacts; confirm zero drift.
# PASS 2: a CURATED concordance audit --- each registered headline string in
#         the .tex sources is matched against its ledger value, with the
#         estimand/stage label included in the needle wherever a label swap
#         is possible. This audits the registered claims; it is not an
#         exhaustive inventory of every numeral in the manuscript.
# Rules (post external-review hardening): no check may use an unconditional
# `cond = TRUE`; target-specific values carry their target label in the
# needle; stage parameters (draws, nodes) come from frozen protocols.
# Nonzero exit on any failure.
# ============================================================================

source("00_common.R")
stopifnot(file.exists(KEY_PATH))

# ---- PASS 1 -----------------------------------------------------------------
old <- read.csv(KEY_PATH, stringsAsFactors = FALSE)
tmp <- tempfile(fileext = ".csv")
builder <- readLines("01_build_key_numbers.R")
builder <- gsub('write.csv(ledger, KEY_PATH, row.names = FALSE)',
                sprintf('write.csv(ledger, "%s", row.names = FALSE)', tmp),
                builder, fixed = TRUE)
writeLines(builder, con = (tf <- tempfile(fileext = ".R")))
env <- new.env(); sys.source(tf, envir = env)
new <- read.csv(tmp, stringsAsFactors = FALSE)
m <- merge(old, new, by = "key")
drift <- max(abs(as.numeric(m$value.x) - as.numeric(m$value.y)))
ok1 <- identical(sort(old$key), sort(new$key)) && drift < 1e-9
cat(sprintf("PASS1 ledger: %d keys, same set = %s, max drift = %.3g\n",
            nrow(m), identical(sort(old$key), sort(new$key)), drift))

# ---- PASS 2 -----------------------------------------------------------------
tex <- function(path) {
  x <- paste(readLines(file.path("..", path), warn = FALSE), collapse = " ")
  gsub("[[:space:]]+", " ", x)
}
SRC <- list(
  intro = tex("sections/01_introduction.tex"),
  theory = tex("sections/03_theory.tex"),
  method = tex("sections/04_method.tex"),
  sim = tex("sections/06_simulation.tex"),
  emp = tex("sections/07_empirical.tex"),
  disc = tex("sections/08_discussion.tex"),
  abstract = tex("frontmatter/abstract.tex"),
  tab2 = tex("floats/tab2_confirmation.tex"),
  tab3 = tex("floats/tab3_swmdk.tex"),
  tabF1 = tex("online-supplemental-materials/floats/tabF1_cells.tex"),
  osmB = tex("online-supplemental-materials/appendices/appendix_B.tex"),
  osmD = tex("online-supplemental-materials/appendices/appendix_D.tex"),
  osmE = tex("online-supplemental-materials/appendices/appendix_E.tex"),
  osmF = tex("online-supplemental-materials/appendices/appendix_F.tex"),
  osmG = tex("online-supplemental-materials/appendices/appendix_G.tex"),
  osmH = tex("online-supplemental-materials/appendices/appendix_H.tex")
)
checks <- list()
# No default condition (round-2 hardening): every check must supply an
# explicit predicate binding the needle to ledger/protocol values, and
# target/lane/stage qualifiers belong in the needle itself.
chk <- function(id, where, needle, cond) {
  found <- grepl(needle, SRC[[where]], fixed = TRUE)
  checks[[length(checks) + 1L]] <<- data.frame(id = id, where = where,
                                               needle = needle,
                                               pass = found && isTRUE(cond))
}

# primary coverage
chk("p16-resp-sim", "sim", "$.9736$ (respondent; MCSE $.0020$)",
    fmt_h(kn("p16_resp_cov"), 4) == ".9736")
chk("p16-eqcl-sim", "sim", "$.9738$ (equal-cluster; $.0020$)",
    fmt_h(kn("p16_eqcl_cov"), 4) == ".9738")
chk("p16-both-abstract", "abstract", "covered $.974$ for both targets",
    fmt_h(kn("p16_resp_cov"), 3) == ".974" &&
      fmt_h(kn("p16_eqcl_cov"), 3) == ".974")
chk("p16-reglane-abstract", "abstract", "16-cell regular decision lane",
    kn("p16_design_regular") == 16)
# Raw-HBB values are target-labeled; both the prose and the generated
# table rows are checked with their labels attached (a positional swap in
# Table 2 escaped the v1 audit).
chk("p16-raw-sim", "sim", "$.9975$ (respondent) and $.9962$ (equal-cluster)",
    fmt_h(kn("p16_raw_resp_cov"), 4) == ".9975" &&
      abs(kn("p16_raw_eqcl_cov") - 0.99625) < 1e-12)
chk("p16-raw-tab2-resp", "tab2",
    "respondent & .9975 (.0006) & 0.1167",
    fmt_h(kn("p16_raw_resp_cov"), 4) == ".9975" &&
      sprintf("%.4f", kn("p16_raw_resp_len")) == "0.1167")
chk("p16-raw-tab2-eqcl", "tab2",
    "equal-cluster & .9962 (.0008) & 0.1211",
    abs(kn("p16_raw_eqcl_cov") - 0.99625) < 1e-12)
chk("p16-ratio-sim", "sim", "$75.1\\%$ of raw",
    sprintf("%.1f", 100 * kn("p16_sel_raw_ratio")) == "75.1")
chk("p16-ratio-abstract", "abstract", "75\\% of the raw width",
    round(100 * kn("p16_sel_raw_ratio")) == 75)
# All-cell range comes from the raw-row-derived summary (48 cell-target
# groups over all 24 cells); .930 is the REGULAR-lane minimum only.
chk("p16-allcellspan-sim", "sim", "$.925$--$.995$",
    fmt_h(kn("p16_sel_allcell_cov_min"), 3) == ".925" &&
      fmt_h(kn("p16_sel_allcell_cov_max"), 3) == ".995")
chk("p16-regmin-sim", "sim", "regular-lane minimum $.930$",
    fmt_h(kn("p16_sel_regcell_cov_min"), 3) == ".930")
chk("p16-diagmin-sim", "sim",
    "the all-lane minimum, $.925$, occurs in a near-knot diagnostic cell",
    fmt_h(kn("p16_sel_diagcell_cov_min"), 3) == ".925" &&
      fmt_h(kn("p16_sel_allcell_cov_min"), 3) == ".925")
chk("p16-tabF1-rows", "tabF1", "P16-C003",
    length(grep("^P16-C",
                readLines(file.path("..", "online-supplemental-materials",
                                    "floats", "tabF1_cells.tex")))) == 48L)
# Stage execution parameters are protocol-derived, never typed: phase 15
# ran 299 draws / 41 nodes, phase 16 ran 499 draws / 51 nodes.
chk("p15-draws-method", "method", "$B = 299$",
    kn("p15_draws") == 299)
chk("p16-draws-sim", "sim", "$B = 499$",
    kn("p16_draws") == 499)
chk("p16-draws-tab2", "tab2", "499 weight draws per replication",
    kn("p16_draws") == 499)
chk("p16-nodes-sim", "sim", "51 nodes per dimension",
    kn("p16_truth_nodes") == 51)
chk("p15-nodes-osmD", "osmD", "41 nodes per dimension",
    kn("p15_truth_nodes") == 41)
chk("p16-nodes-osmD", "osmD", "51 in the fresh confirmation",
    kn("p16_truth_nodes") == 51)

# comparators
chk("iid-reg-sim", "sim", "covers $.915$ on the regular lane",
    fmt_h(kn("p16_cmp_iid_cov"), 3) == ".915")
chk("iid-knot-sim", "sim", "$.880$ in the exact-knot lane",
    fmt_h(kn("p16_cmp_iid_exact_knot_cov"), 3) == ".880")
chk("iid-abstract", "abstract", "covered $.915$",
    fmt_h(kn("p16_cmp_iid_cov"), 3) == ".915")
chk("onestage-sim", "sim", "($.926$)",
    fmt_h(kn("p16_cmp_onestage_cov"), 3) == ".926")
chk("within-sim", "sim", "($.896$)",
    fmt_h(kn("p16_cmp_within_cov"), 3) == ".896")
chk("freqboot-sim", "sim", "covers $.990$",
    fmt_h(kn("p16_cmp_freqboot_cov"), 3) == ".990")
chk("freqboot-len-sim", "sim", "$15\\%$ longer",
    round(100 * (kn("p16_cmp_freqboot_len") / kn("p16_resp_len") - 1)) == 15)
chk("delta-sim", "sim", "covers $.981$ at $7.1\\%$ greater length",
    fmt_h(kn("p16_cmp_delta_cov"), 3) == ".981" &&
      sprintf("%.1f", 100 * (kn("p16_cmp_delta_len") / kn("p16_resp_len") - 1)) == "7.1")
chk("delta-abstract", "abstract", "$.981$ at 7\\% greater length",
    fmt_h(kn("p16_cmp_delta_cov"), 3) == ".981" &&
      round(100 * (kn("p16_cmp_delta_len") / kn("p16_resp_len") - 1)) == 7)

# subgroups + gates
chk("G-subgroup-sim", "sim", "from $.951$ at $\\Gclust = 22$ to $.989$",
    fmt_h(min(kn("p16_min_G_group_cov"), 1), 3) == ".951" ||
      fmt_h(kn("p16_min_G_group_cov"), 4) == ".9506")
chk("mech-subgroup-sim", "sim", "from $.9675$ upward",
    fmt_h(kn("p16_min_sizemech_group_cov"), 4) == ".9675")
chk("gates-sim", "sim", "All seven gates passed",
    kn("p16_gates_passed") == 7 && kn("p16_gates_total") == 7)
# stage identity: phase-16 prose must carry phase-16 design parameters
chk("profiles-sim", "sim", "three fresh threshold profiles frozen for this stage",
    kn("p16_threshold_profiles") == 3)
chk("profiles-sim-six", "sim", "disjoint from the six used in development",
    kn("p15_threshold_profiles") == 6)
chk("profiles-osmD", "osmD", "development and held-out validation use six",
    kn("p15_threshold_profiles") == 6)
chk("profiles-osmD-confirm", "osmD",
    "the fresh confirmation uses three \\emph{confirm} variants",
    kn("p16_threshold_profiles") == 3)
chk("nearknot-osmD", "osmD",
    "$2 \\times 10^{-4}$ in training, $3.5 \\times 10^{-4}$ in validation, $5 \\times 10^{-4}$ in the confirmation",
    kn("p15_nearknot_offset_training") == 2e-4 &&
      kn("p15_nearknot_offset_validation") == 3.5e-4 &&
      kn("p16_nearknot_offset") == 5e-4)
chk("disc-lane", "disc",
    "held its frozen bands on the fresh confirmation's 16-cell regular decision lane",
    kn("p16_design_regular") == 16)
chk("disc-974", "disc", "$.974$ coverage for both targets",
    fmt_h(kn("p16_resp_cov"), 3) == ".974" &&
      fmt_h(kn("p16_eqcl_cov"), 3) == ".974")
chk("knotlane-sim", "sim", "$.955$--$.968$",
    fmt_h(kn("p16_lane_exact_knot_respondent_cov"), 3) == ".955" &&
      fmt_h(kn("p16_lane_near_knot_respondent_cov"), 3) == ".968")

# development chronology
chk("grid-method", "method", "\\{0, -.5, -.75, -1, -1.25, -1.5\\}",
    kn("p15_gamma_grid_n") == 6)
chk("eligible-method", "method", "Exactly two candidates survived",
    kn("p15_eligible_n") == 2)
chk("sel-shorter-method", "method", "$6.3\\%$ shorter",
    sprintf("%.1f", kn("p15_sel_vs_alt_len_pct")) == "6.3")
chk("heldout-method", "method", "covered $.9718$ (respondent) and $.9722$",
    fmt_h(kn("p15_val_resp_cov"), 4) == ".9718" &&
      fmt_h(kn("p15_val_eqcl_cov"), 4) == ".9722")
chk("fallback-method", "method", "($.9949$ and $.9968$",
    fmt_h(kn("p15_val_raw_resp_cov"), 4) == ".9949" &&
      fmt_h(kn("p15_val_raw_eqcl_cov"), 4) == ".9968")
# Pilot overcoverage range: respondent-target primary-HBB lanes,
# .9917/.9944/.9972 -> quoted as .992--.997 (a hand-typed "99.5%--99.7%"
# passed the v1 audit through an unconditional literal check).
pilot_ok <- fmt_h(kn("p14_resp_lane_cov_min"), 3) == ".992" &&
  fmt_h(kn("p14_resp_lane_cov_max"), 3) == ".997" &&
  fmt_h(kn("p14_hbb_lane_cov_min"), 3) == ".989" &&
  kn("p14_hbb_lane_cov_max") == 1
chk("pilot-intro", "intro", "$.992$--$.997$ across the primary-target pilot lanes",
    pilot_ok)
chk("pilot-abstract", "abstract",
    "($.992$--$.997$ across the pilot's primary-target lanes)", pilot_ok)
chk("pilot-theory", "theory",
    "covered $.992$--$.997$ across primary-target lanes", pilot_ok)
chk("pilot-method", "method",
    "covered $.992$--$.997$ across the primary (respondent) target's lanes",
    pilot_ok)
chk("pilot-method-alltarget", "method",
    "$.989$--$1.000$ over all target--lane combinations", pilot_ok)
chk("pilot-osmE-target", "osmE",
    "$.992$--$.997$ by lane on the primary respondent target", pilot_ok)
chk("pilot-osmE-eqcl", "osmE",
    "$.989$--$1.000$ on the equal-cluster sensitivity lanes", pilot_ok)
chk("pilot-osmE", "osmE", "coverage was $.994$ overall",
    fmt_h(kn("p14_raw_hbb_cov_all"), 3) == ".994")

# SWMDK
chk("swmdk-teacher-emp", "emp", "$\\Hhat = .6199$",
    fmt_h(kn("teacher_resp_H"), 4) == ".6199")
chk("swmdk-teacher-ci-emp", "emp", "$[.5728, .6692]$",
    fmt_h(kn("teacher_resp_lo"), 4) == ".5728" &&
      fmt_h(kn("teacher_resp_hi"), 4) == ".6692")
chk("swmdk-classmate-emp", "emp", "$\\Hhat = .5923$, CI $[.5431, .6408]$",
    fmt_h(kn("classmate_resp_H"), 4) == ".5923" &&
      fmt_h(kn("classmate_resp_lo"), 4) == ".5431" &&
      fmt_h(kn("classmate_resp_hi"), 4) == ".6408")
chk("swmdk-abstract", "abstract", "$[.573, .669]$",
    fmt_h(kn("teacher_resp_lo"), 3) == ".573" &&
      fmt_h(kn("teacher_resp_hi"), 3) == ".669")
chk("swmdk-eqcl-emp", "emp", "$.6223$ and $.5829$",
    fmt_h(kn("swmdk_teacher_equal_cluster_H"), 4) == ".6223" &&
      fmt_h(kn("swmdk_classmate_equal_cluster_H"), 4) == ".5829")
chk("swmdk-targetdiff-emp", "emp", "$+.0024$ and $-.0094$",
    fmt_h(kn("teacher_target_diff"), 4) == ".0024" &&
      fmt_h(kn("swmdk_classmate_eqcl_target_diff"), 4) == "-.0094")
chk("swmdk-kG-emp", "emp", "1 - 1.5/\\sqrt{30} = .7261",
    fmt_h(kn("swmdk_width_mult"), 4) == ".7261")
chk("swmdk-vs-delta-emp", "emp", "($96.0\\%$ and $98.5\\%$",
    sprintf("%.1f", kn("swmdk_sel_vs_delta_teacher_pct")) == "96.0" &&
      sprintf("%.1f", kn("swmdk_sel_vs_delta_classmate_pct")) == "98.5")
chk("swmdk-draws-emp", "emp", "1{,}199{,}988 draws",
    kn("swmdk_total_draws") == 1199988)
chk("swmdk-icc-emp", "emp", "$.169$ (teacher) and $.183$",
    fmt_h(kn("teacher_icc"), 3) == ".169" &&
      fmt_h(kn("classmate_icc"), 3) == ".183")
chk("swmdk-g17-emp", "emp", "All 14 blocking application-gate criteria passed",
    kn("g17_passed") == 14)
chk("swmdk-splithalf-emp", "emp", "within $.0009$",
    kn("swmdk_split_half_max") < 0.0009)
chk("swmdk-catmass-emp", "emp", "smallest category mass $.0031$",
    fmt_h(kn("swmdk_min_cat_mass"), 4) == ".0031")
chk("swmdk-knots-emp", "emp", "minimum internal CDF gap $0$",
    kn("swmdk_teacher_resp_exact_knots") == 2 &&
      kn("swmdk_teacher_eqcl_exact_knots") == 0)

# package + reviews
chk("pkg-suite-method", "method", "791 expectations across 24 files",
    kn("pkg_expectations") == 791 && kn("pkg_test_files") == 24)
chk("lp-oracle-osmB", "osmB", "1.4\\times10^{-12}",
    kn("pkg_lp_maxdiff") < 1.5e-12)
chk("g18a-sim", "sim", "13 of 13",
    kn("g18a_gate_passed") == 13 && kn("g18a_crosswalks") == 3)

res <- do.call(rbind, checks)
fails <- res[!res$pass, , drop = FALSE]
cat(sprintf("PASS2 manuscript: %d checks, %d failed\n", nrow(res), nrow(fails)))
if (nrow(fails)) print(fails, row.names = FALSE)
if (!ok1 || nrow(fails)) stop("NUMBER VERIFICATION FAILED") else
  cat("ALL NUMBER CHECKS PASSED\n")
