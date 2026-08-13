# ============================================================================
# 07_tables.R --- generated LaTeX tables (main + OSM) for Paper B.
# Main: floats/tab2_confirmation.tex, floats/tab3_swmdk.tex
# OSM:  tabE1 training decisions, tabE2 held-out validation,
#       tabF1 regular cells (selected), tabF2 comparator lanes,
#       tabG1 category profile, tabH1 claim register.
# All numbers from locked artifacts; ledger-asserted where registered.
# ============================================================================

source("00_common.R")
# The published arXiv floats carry presentational changes the journal build did
# not: adjustbox wrappers that shrink wide bodies to the combined build's 6-in
# measure, one cross-reference retargeted because the combined build has no
# separate supplement, and rebalanced column widths in the claim register. Each
# is self-documented in the float header it produces, and none touches a value,
# a column or a note. They are emitted here so this package reproduces the
# floats the paper actually prints (decision D-8). See log 009.

# The arXiv build merged main and supplement, so both float sets land in one
# directory here.
FLOATS <- FLOAT_DIR
OSM_FLOATS <- FLOAT_DIR
dir.create(FLOATS, showWarnings = FALSE, recursive = TRUE)
dir.create(OSM_FLOATS, showWarnings = FALSE, recursive = TRUE)
wl <- function(path, lines) { writeLines(lines, path); message("wrote ", path) }
esc <- function(x) gsub("_", "\\\\_", x)

# ---------------------------------------------------------------------------
# Table 2 --- confirmation summary: methods x lanes
# ---------------------------------------------------------------------------
fmt_cov <- function(cov, mcse) sprintf("%s (%s)", fmt_h(cov, 4), fmt_h(mcse, 4))

sel_rows <- p16_lane |>
  mutate(key = paste(regularity, target)) |>
  (\(d) {
    tibble::tibble(
      label = c("Calibrated HBB --- respondent target",
                "Calibrated HBB --- equal-cluster target"),
      target = c("respondent", "equal_cluster"),
      reg_cov = vapply(target, function(t)
        fmt_cov(d$coverage[d$key == paste("regular", t)],
                d$coverage_mcse[d$key == paste("regular", t)]), ""),
      reg_len = vapply(target, function(t)
        sprintf("%.4f", d$mean_interval_length[d$key == paste("regular", t)]), ""),
      near_cov = vapply(target, function(t)
        fmt_cov(d$coverage[d$key == paste("near_knot", t)],
                d$coverage_mcse[d$key == paste("near_knot", t)]), ""),
      exact_cov = vapply(target, function(t)
        fmt_cov(d$coverage[d$key == paste("exact_knot", t)],
                d$coverage_mcse[d$key == paste("exact_knot", t)]), "")
    )
  })()

# Raw-HBB rows are joined BY TARGET, never by artifact row order: the locked
# overall summary lists equal_cluster before respondent, and a positional
# bind swaps the estimands. Each value is asserted against the ledger.
raw_r <- p16_overall |> filter(gamma_cluster == 0)
raw_pick <- function(tgt, col) {
  v <- raw_r[[col]][raw_r$target == tgt]
  stopifnot(length(v) == 1L)
  v
}
stopifnot(
  abs(raw_pick("respondent", "coverage") - kn("p16_raw_resp_cov")) < 1e-12,
  abs(raw_pick("equal_cluster", "coverage") - kn("p16_raw_eqcl_cov")) < 1e-12,
  abs(raw_pick("respondent", "mean_interval_length") -
        kn("p16_raw_resp_len")) < 1e-12
)
raw_rows <- tibble::tibble(
  label = c("Raw HBB ($\\gcal=0$) --- respondent",
            "Raw HBB ($\\gcal=0$) --- equal-cluster"),
  reg_cov = c(fmt_cov(raw_pick("respondent", "coverage"),
                      raw_pick("respondent", "coverage_mcse")),
              fmt_cov(raw_pick("equal_cluster", "coverage"),
                      raw_pick("equal_cluster", "coverage_mcse"))),
  reg_len = c(sprintf("%.4f", raw_pick("respondent", "mean_interval_length")),
              sprintf("%.4f", raw_pick("equal_cluster", "mean_interval_length"))),
  near_cov = "---", exact_cov = "---"
)

cmp_lab <- c("V4-CMP-MOKKEN-TWOLEVEL-DELTA-v1" = "Two-level delta (analytic)",
             "V4-CMP-TWO-STAGE-FREQ-BOOT-RESP-v1" = "Two-stage cluster NPB",
             "V4-CMP-ONE-STAGE-CLUSTER-BB-RESP-v1" = "One-stage cluster BB",
             "V4-CMP-IID-RESP-BB-v1" = "iid respondent BB (naive)",
             "V4-DIAG-WITHIN-STAGE-HBB-RESP-v1" = "Within-cluster HBB (diagnostic)")
cmp_rows <- p16_comp |>
  mutate(lane = regularity) |>
  select(method_id, lane, coverage, coverage_mcse, mean_interval_length) |>
  pivot_wider(names_from = lane,
              values_from = c(coverage, coverage_mcse, mean_interval_length)) |>
  mutate(label = cmp_lab[method_id]) |>
  arrange(match(method_id, names(cmp_lab))) |>
  transmute(label,
            reg_cov = fmt_cov(coverage_regular, coverage_mcse_regular),
            reg_len = sprintf("%.4f", mean_interval_length_regular),
            near_cov = fmt_cov(coverage_near_knot, coverage_mcse_near_knot),
            exact_cov = fmt_cov(coverage_exact_knot, coverage_mcse_exact_knot))

assert_close(as.numeric(sub(" .*", "", sub("^\\.", "0.", sel_rows$reg_cov[1]))),
             round(kn("p16_resp_cov"), 4), tol = 5e-5,
             msg = "tab2 selected coverage drifted")

tab2 <- c(
  "%% Table 2 --- generated by figures-src/07_tables.R from the locked",
  "%% phase-16 lane/overall/comparator summaries. Do not edit by hand.",
  "\\begin{table}[!htbp]",
  "\\caption{Fresh-Confirmation Coverage and Length by Regularity Lane}",
  "\\label{tab:confirmation}",
  "\\begin{apatable}",
  "\\centering",
  "\\setlength{\\tabcolsep}{4.5pt}",
  "\\footnotesize",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{tabular}{lcccc}",
  "\\toprule",
  " & \\multicolumn{2}{c}{Regular lane (decision)} & Near knot & Exact knot \\\\",
  "\\cmidrule(lr){2-3}\\cmidrule(lr){4-4}\\cmidrule(lr){5-5}",
  "Interval procedure & Coverage (MCSE) & Length & Coverage (MCSE) & Coverage (MCSE) \\\\",
  "\\midrule",
  sprintf("%s & %s & %s & %s & %s \\\\",
          c(sel_rows$label, raw_rows$label, cmp_rows$label),
          c(sel_rows$reg_cov, raw_rows$reg_cov, cmp_rows$reg_cov),
          c(sel_rows$reg_len, raw_rows$reg_len, cmp_rows$reg_len),
          c(sel_rows$near_cov, raw_rows$near_cov, cmp_rows$near_cov),
          c(sel_rows$exact_cov, raw_rows$exact_cov, cmp_rows$exact_cov)),
  "\\bottomrule",
  "\\end{tabular}",
  "\\end{adjustbox}",
  "\\end{apatable}",
  paste0(
    "\\tablenote{Fresh, untouched confirmation: 16 regular cells (6,400 ",
    "scheduled replications per target), 4 near-knot and 4 exact-knot ",
    "diagnostic cells (1,600 each), 400 replications per cell, ",
    format(kn("p16_draws"), big.mark = ","), " weight ",
    "draws per replication. Coverage is unconditional; no interval in the ",
    "table produced an invalid replication (maximum invalid fraction 0). ",
    "The frozen decision bands apply to the regular lane only: [.935, ",
    ".975] for the respondent target and [.93, .98] for the equal-cluster ",
    "target. The raw hierarchical BB was evaluated on the decision lane; ",
    "comparators (respondent target; the iid BB addresses the ",
    "working-independence respondent target) were evaluated on all three ",
    "lanes. HBB = hierarchical Bayesian bootstrap; NPB = nonparametric ",
    "bootstrap; MCSE = Monte Carlo standard error.}"
  ),
  "\\end{table}"
)
wl(file.path(FLOATS, "tab2_confirmation.tex"), tab2)

# ---------------------------------------------------------------------------
# Table 3 --- SWMDK application summary
# ---------------------------------------------------------------------------
s17 <- p17_methods |> filter(interval_role == "phase16_confirmed_selected")
g <- function(scale, target) s17 |> filter(scale == !!scale, target_role == target)
iv <- function(r) sprintf("[%s, %s]", fmt_h(r$lower, 4), fmt_h(r$upper, 4))

tt <- g("teacher", "respondent"); te <- g("teacher", "equal_cluster")
ct <- g("classmate", "respondent"); ce <- g("classmate", "equal_cluster")
raw_t <- p17_methods |> filter(scale == "teacher", grepl("^V4-PRI", method_id))
raw_c <- p17_methods |> filter(scale == "classmate", grepl("^V4-PRI", method_id))
del_t <- p17_methods |> filter(scale == "teacher", grepl("DELTA", method_id))
del_c <- p17_methods |> filter(scale == "classmate", grepl("DELTA", method_id))

tab3 <- c(
  "%% Table 3 --- generated by figures-src/07_tables.R from the locked",
  "%% phase-17 method summary and key metrics. Do not edit by hand, with the",
  "%% single documented exception recorded in notes/build-notes-v2.md: the",
  "%% note's pointer \"Appendix G of the online supplement\" became \\cref{app:swmdk},",
  "%% because the combined build has no separate supplement. No value changed.",
  "\\begin{table}[!htbp]",
  "\\caption{SWMDK Application: Selected Intervals, Targets, and Reference Comparators}",
  "\\label{tab:swmdk}",
  "\\begin{apatable}",
  "\\centering",
  "\\setlength{\\tabcolsep}{6pt}",
  "\\small",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{tabular}{lcccc}",
  "\\toprule",
  " & \\multicolumn{2}{c}{Well-being with teachers} & \\multicolumn{2}{c}{Well-being with classmates} \\\\",
  "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}",
  " & Respondent & Equal-cluster & Respondent & Equal-cluster \\\\",
  "\\midrule",
  sprintf("Point estimate $\\Hhat$ & %s & %s & %s & %s \\\\",
          fmt_h(tt$point_estimate, 4), fmt_h(te$point_estimate, 4),
          fmt_h(ct$point_estimate, 4), fmt_h(ce$point_estimate, 4)),
  sprintf("Calibrated 95\\%% CI & %s & %s & %s & %s \\\\",
          iv(tt), iv(te), iv(ct), iv(ce)),
  sprintf("Interval length & %s & %s & %s & %s \\\\",
          fmt_h(tt$interval_length, 4), fmt_h(te$interval_length, 4),
          fmt_h(ct$interval_length, 4), fmt_h(ce$interval_length, 4)),
  "\\midrule",
  sprintf("Raw HBB 95\\%% interval & \\multicolumn{2}{c}{%s} & \\multicolumn{2}{c}{%s} \\\\",
          iv(raw_t[1, ]), iv(raw_c[1, ])),
  sprintf("Two-level delta 95\\%% interval & \\multicolumn{2}{c}{%s} & \\multicolumn{2}{c}{%s} \\\\",
          iv(del_t[1, ]), iv(del_c[1, ])),
  sprintf("Selected / raw length & \\multicolumn{2}{c}{%s} & \\multicolumn{2}{c}{%s} \\\\",
          fmt_h(tt$interval_length / raw_t$interval_length[1], 4),
          fmt_h(ct$interval_length / raw_c$interval_length[1], 4)),
  sprintf("Selected / two-level delta length & \\multicolumn{2}{c}{%s} & \\multicolumn{2}{c}{%s} \\\\",
          fmt_h(tt$interval_length / del_t$interval_length[1], 4),
          fmt_h(ct$interval_length / del_c$interval_length[1], 4)),
  "\\midrule",
  sprintf("Intraclass correlation & \\multicolumn{2}{c}{%s} & \\multicolumn{2}{c}{%s} \\\\",
          fmt_h(kn("teacher_icc"), 3), fmt_h(kn("classmate_icc"), 3)),
  sprintf("Exact cumulative knots (resp.; eq.-cl.) & \\multicolumn{2}{c}{2; 0} & \\multicolumn{2}{c}{2; 0} \\\\"),
  "\\bottomrule",
  "\\end{tabular}",
  "\\end{adjustbox}",
  "\\end{apatable}",
  paste0(
    "\\tablenote{Fixed prespecified scales (teacher: Items 1--6; ",
    "classmate: Items 8, 9, 10, 11, 13); 639 pupils in $G = 30$ classrooms; ",
    "99,999 weight draws per task with zero invalid draws; the calibrated ",
    "interval multiplies each raw half-width by ",
    "$\\kG = 1 - 1.5/\\sqrt{30} = .7261$ about a fixed midpoint. ",
    "Raw HBB and two-level delta rows are respondent-target reference ",
    "comparators. Exact-knot counts are diagnostic disclosures of the ",
    "weighted-marginal transport path (\\cref{app:swmdk}), not error ",
    "flags. No threshold-based scale classification ",
    "is performed. CI = confidence interval; HBB = hierarchical Bayesian ",
    "bootstrap.}"
  ),
  "\\end{table}"
)
wl(file.path(FLOATS, "tab3_swmdk.tex"), tab3)

# ---------------------------------------------------------------------------
# OSM tabE1 --- training gamma decisions
# ---------------------------------------------------------------------------
d <- p15_dec |> arrange(desc(gamma_cluster))
tabE1 <- c(
  "%% OSM training decisions --- generated by 07_tables.R.",
  "\\begin{table}[H]",
  "\\caption{Training-Stage Candidate Decisions Across the Frozen $\\gcal$ Grid}",
  "\\label{tab:training}",
  "\\centering",
  "\\small",
  "\\begin{tabular}{rccccccc}",
  "\\toprule",
  "$\\gcal$ & \\multicolumn{2}{c}{Coverage} & \\multicolumn{2}{c}{Mean length} & Min $G$ & Min mech. & Eligible \\\\",
  "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}",
  " & Resp. & Eq.-cl. & Resp. & Eq.-cl. & group & group & \\\\",
  "\\midrule",
  sprintf("$%.2f$ & %s & %s & %s & %s & %s & %s & %s \\\\",
          d$gamma_cluster,
          fmt_h(d$respondent_coverage, 4), fmt_h(d$equal_cluster_coverage, 4),
          fmt_h(d$respondent_mean_interval_length, 4),
          fmt_h(d$equal_cluster_mean_interval_length, 4),
          fmt_h(d$minimum_G_group_coverage, 3),
          fmt_h(d$minimum_size_mechanism_group_coverage, 3),
          ifelse(d$eligible %in% c(TRUE, "TRUE"), "yes", "no")),
  "\\bottomrule",
  "\\end{tabular}",
  "\\end{table}"
)
wl(file.path(OSM_FLOATS, "tabE1_training.tex"), tabE1)

# ---------------------------------------------------------------------------
# OSM tabE2 --- held-out validation
# ---------------------------------------------------------------------------
v <- p15_val |> arrange(desc(gamma_cluster), target)
tabE2 <- c(
  "%% OSM held-out validation --- generated by 07_tables.R.",
  "\\begin{table}[H]",
  "\\caption{Held-Out Validation of the Locked Candidate (18 Disjoint Cells)}",
  "\\label{tab:validation}",
  "\\centering",
  "\\small",
  "\\begin{tabular}{llccc}",
  "\\toprule",
  "Method role & Target & Coverage (MCSE) & Mean length & Invalid \\\\",
  "\\midrule",
  sprintf("%s & %s & %s & %s & %s \\\\",
          ifelse(v$gamma_cluster == -1.5, "Selected ($\\gcal=-1.5$)",
                 "Raw ($\\gcal=0$)"),
          esc(v$target),
          fmt_cov(v$coverage, v$coverage_mcse),
          fmt_h(v$mean_interval_length, 4),
          fmt_h(as.numeric(v$maximum_invalid_fraction), 3)),
  "\\bottomrule",
  "\\end{tabular}",
  "\\end{table}"
)
wl(file.path(OSM_FLOATS, "tabE2_validation.tex"), tabE2)

# ---------------------------------------------------------------------------
# OSM tabF1 --- selected method, all 24 cells x 2 targets.
# Source: the derived all-lane summary built by 01_build_key_numbers.R from
# the raw phase-16 replication rows and cross-checked there against the
# locked regular-cell artifact. (The locked cell-summary artifact itself
# carries only the 16 regular decision cells and must not feed this table.)
# ---------------------------------------------------------------------------
fc <- readr::read_csv(file.path(PATHS$out_root, "derived_p16_allcell_summary.csv"),
                      show_col_types = FALSE) |>
  left_join(p16_design |> select(cell_id, G, latent_icc), by = "cell_id") |>
  arrange(cell_id, target)
stopifnot(nrow(fc) == 48L,
          abs(min(fc$coverage) - kn("p16_sel_allcell_cov_min")) < 1e-12,
          abs(max(fc$coverage) - kn("p16_sel_allcell_cov_max")) < 1e-12)
tabF1 <- c(
  "%% OSM cell table --- generated by 07_tables.R.",
  "{\\small",
  "\\setlength{\\tabcolsep}{4.5pt}",
  "\\begin{longtable}{llrrcrrr}",
  "\\caption{Calibrated HBB: All Confirmation Cells by Target}",
  "\\label{tab:cellsF1} \\\\",
  "\\toprule",
  "Cell & Target & $G$ & ICC & Lane & Coverage & MCSE & Length \\\\",
  "\\midrule",
  "\\endfirsthead",
  "\\toprule",
  "Cell & Target & $G$ & ICC & Lane & Coverage & MCSE & Length \\\\",
  "\\midrule",
  "\\endhead",
  sprintf("%s & %s & %d & %s & %s & %s & %s & %s \\\\",
          esc(fc$cell_id), esc(fc$target), fc$G, fmt_h(fc$latent_icc, 2),
          esc(fc$regularity), fmt_h(fc$coverage, 4),
          fmt_h(fc$coverage_mcse, 4), fmt_h(fc$mean_interval_length, 4)),
  "\\bottomrule",
  "\\end{longtable}",
  "}"
)
wl(file.path(OSM_FLOATS, "tabF1_cells.tex"), tabF1)

# ---------------------------------------------------------------------------
# OSM tabF2 --- comparator lanes (full)
# ---------------------------------------------------------------------------
f2 <- p16_comp |> arrange(match(method_id, names(cmp_lab)), regularity)
tabF2 <- c(
  "%% OSM comparator table --- generated by 07_tables.R.",
  "\\begin{table}[H]",
  "\\caption{Comparator Procedures by Regularity Lane (Respondent Target)}",
  "\\label{tab:comparatorsF2}",
  "\\centering",
  "\\small",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{tabular}{llccc}",
  "\\toprule",
  "Procedure & Lane & Coverage (MCSE) & Mean length & Invalid \\\\",
  "\\midrule",
  sprintf("%s & %s & %s & %s & %s \\\\",
          cmp_lab[f2$method_id], esc(f2$regularity),
          fmt_cov(f2$coverage, f2$coverage_mcse),
          fmt_h(f2$mean_interval_length, 4),
          fmt_h(as.numeric(f2$maximum_invalid_fraction), 3)),
  "\\bottomrule",
  "\\end{tabular}",
  "\\end{adjustbox}",
  "\\end{table}"
)
wl(file.path(OSM_FLOATS, "tabF2_comparators.tex"), tabF2)

# ---------------------------------------------------------------------------
# OSM tabG1 --- SWMDK category profile
# ---------------------------------------------------------------------------
cg <- p17_cats |> arrange(scale, item, score)
tabG1 <- c(
  "%% OSM category profile --- generated by 07_tables.R.",
  "{\\small",
  "\\setlength{\\tabcolsep}{5pt}",
  "\\begin{longtable}{llrrr}",
  "\\caption{SWMDK Fixed-Item Category Profile}",
  "\\label{tab:categories} \\\\",
  "\\toprule",
  "Scale & Item & Score & Count & Mass \\\\",
  "\\midrule",
  "\\endfirsthead",
  "\\toprule",
  "Scale & Item & Score & Count & Mass \\\\",
  "\\midrule",
  "\\endhead",
  sprintf("%s & %s & %d & %d & %s \\\\",
          esc(cg$scale), esc(cg$item), cg$score, cg$count, fmt_h(cg$mass, 4)),
  "\\bottomrule",
  "\\end{longtable}",
  "}"
)
wl(file.path(OSM_FLOATS, "tabG1_categories.tex"), tabG1)

# ---------------------------------------------------------------------------
# OSM tabH1 --- claim register transcription
# ---------------------------------------------------------------------------
cl <- claims18
tabH1 <- c(
  "%% OSM claim register --- generated by 07_tables.R from",
  "%% v4-phase18-claim-eligibility-v1.csv.",
  "%% Column widths rebalanced for the combined build's 6-in measure: the v1",
  "%% supplement overfilled the status column by up to 21.8 pt on its longest",
  "%% status words. No cell content changed.",
  "{\\footnotesize",
  "\\setlength{\\tabcolsep}{4pt}",
  "\\begin{longtable}{p{0.07\\textwidth}p{0.40\\textwidth}p{0.29\\textwidth}>{\\raggedright\\arraybackslash}p{0.16\\textwidth}}",
  "\\caption{The Frozen Claim-Eligibility Register Governing This Article}",
  "\\label{tab:claims} \\\\",
  "\\toprule",
  "ID & Claim & Boundary & Status \\\\",
  "\\midrule",
  "\\endfirsthead",
  "\\toprule",
  "ID & Claim & Boundary & Status \\\\",
  "\\midrule",
  "\\endhead",
  sprintf("%s & %s & %s & %s \\\\[2pt]",
          esc(cl$claim_id), esc(cl$claim), esc(cl$boundary),
          esc(gsub("_", " ", cl$eligibility))),
  "\\bottomrule",
  "\\end{longtable}",
  "}"
)
wl(file.path(OSM_FLOATS, "tabH1_claims.tex"), tabH1)

message("all tables written")
