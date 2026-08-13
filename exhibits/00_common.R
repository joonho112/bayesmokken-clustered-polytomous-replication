# ============================================================================
# exhibits/00_common.R -- shared infrastructure for the exhibit layer.
#
# Ported from the manuscript's figures-src suite. Two things changed and
# nothing else: the seven upstream artifact roots -- which lived inside the
# COMPANION paper's research tree -- became one frozen snapshot under
# data-frozen/, reached through common/R/paths.R; and reads go through
# common/R/io.R so every tier asserts its shape on load. No statistic is
# recomputed and no display decision is revised.
#
# The severance matters: the runnable exhibit/verification layer does not reach
# into the companion paper's research tree. Copied archival executable evidence
# may record upstream paths as provenance; verify_quarantine.py enforces the
# narrower runnable-code boundary.
#
# Run the whole layer with:
#     Rscript exhibits/00_build_all.R
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
  library(scales)
  library(patchwork)
})

# ---- the frozen snapshot ---------------------------------------------------
.this_file <- local({
  for (i in rev(seq_len(sys.nframe()))) {
    of <- tryCatch(get("ofile", envir = sys.frames()[[i]], inherits = FALSE),
                   error = function(e) NULL)
    if (is.character(of) && length(of) == 1L && nzchar(of)) {
      return(normalizePath(of, mustWork = FALSE))
    }
  }
  fa <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(fa)) {
    return(normalizePath(gsub("~+~", " ", sub("^--file=", "", fa[1]), fixed = TRUE),
                         mustWork = FALSE))
  }
  file.path(getwd(), "00_common.R")
})
source(file.path(dirname(dirname(.this_file)), "common", "R", "paths.R"))
source(file.path(PATHS$root, "common", "R", "io.R"))

FIG_MAIN <- PATHS$out_fig
FIG_OSM <- FIG_MAIN          # the arXiv build merged main and supplement
FLOAT_DIR <- PATHS$out_float
dir.create(FIG_MAIN, showWarnings = FALSE, recursive = TRUE)
dir.create(FLOAT_DIR, showWarnings = FALSE, recursive = TRUE)

# `read_locked_csv()`, `assert()` and `assert_close()` are in common/R/io.R.

# ---- key-number registry ---------------------------------------------------
KEY_PATH <- file.path(PATHS$out_root, "key_numbers.csv")
if (file.exists(KEY_PATH)) {
  key_numbers <- read_csv(KEY_PATH, show_col_types = FALSE)
  kn <- function(k) {
    v <- key_numbers$value[key_numbers$key == k]
    stopifnot(length(v) == 1L)
    suppressWarnings(as.numeric(v))
  }
} else {
  kn <- function(k) stop("outputs/key_numbers.csv missing -- run exhibits/01_build_key_numbers.R")
}

# ---- frozen constants ------------------------------------------------------
NOMINAL <- 0.95
GAMMA_CL <- -1.5
RESP_BAND <- c(0.935, 0.975)    # phase-16 respondent regular acceptance band
EQCL_BAND <- c(0.930, 0.980)    # phase-16 equal-cluster acceptance band

# ---- method registry -------------------------------------------------------
# Canonical display method: calibrated/raw HBB collapse the two target-specific
# ids; `target` stays a separate aesthetic wherever both appear.
METHODS <- tibble::tribble(
  ~method_key,       ~label,                          ~short,            ~color,
  "calibrated_hbb",  "Calibrated hierarchical BB (proposed)", "Calibrated HBB", "#0072B2",
  "raw_hbb",         "Raw hierarchical BB",           "Raw HBB",          "#56B4E9",
  "twolevel_delta",  "Two-level delta (analytic)",    "Two-level delta",  "#D55E00",
  "freq_boot",       "Two-stage cluster NPB",         "Two-stage NPB",    "#009E73",
  "one_stage",       "One-stage cluster BB",          "One-stage BB",     "#E69F00",
  "iid_bb",          "iid respondent BB (naive)",     "iid BB",           "#661100",
  "within_stage",    "Within-cluster HBB (diagnostic)", "Within-stage",   "#CC79A7"
)
METHODS$label <- factor(METHODS$label, levels = METHODS$label)
PAL_METHOD <- setNames(METHODS$color, as.character(METHODS$label))

method_key_of <- function(id) {
  dplyr::case_when(
    grepl("^V4-P15-HBB-(RESP|CLUSTER)-GN150", id) ~ "calibrated_hbb",
    grepl("^V4-P15-HBB-(RESP|CLUSTER)-G000", id) ~ "raw_hbb",
    grepl("^V4-PRI-TWO-STAGE-HBB", id) ~ "raw_hbb",
    grepl("^V4-SENS-TWO-STAGE-HBB", id) ~ "raw_hbb",
    grepl("MOKKEN-TWOLEVEL-DELTA", id) ~ "twolevel_delta",
    grepl("TWO-STAGE-FREQ-BOOT", id) ~ "freq_boot",
    grepl("ONE-STAGE-CLUSTER-BB", id) ~ "one_stage",
    grepl("IID-RESP-BB", id) ~ "iid_bb",
    grepl("WITHIN-STAGE-HBB", id) ~ "within_stage",
    TRUE ~ NA_character_
  )
}
method_label_of <- function(id) {
  k <- method_key_of(id)
  out <- METHODS$label[match(k, METHODS$method_key)]
  assert(!anyNA(out), paste("unknown method id:", paste(id[is.na(out)], collapse = ",")))
  out
}

LANES <- tibble::tribble(
  ~regularity,  ~lane_lab,
  "regular",    "Regular",
  "near_knot",  "Near knot",
  "exact_knot", "Exact knot"
)
LANES$lane_lab <- factor(LANES$lane_lab, levels = LANES$lane_lab)
METHODS$short_lab <- factor(
  ifelse(METHODS$method_key == "calibrated_hbb",
         paste0(METHODS$short, " (proposed)"), METHODS$short),
  levels = ifelse(METHODS$method_key == "calibrated_hbb",
                  paste0(METHODS$short, " (proposed)"), METHODS$short)
)
PAL_SHORT <- setNames(METHODS$color, as.character(METHODS$short_lab))

TARGETS <- tibble::tribble(
  ~target,          ~target_lab,
  "respondent",     "Respondent-weighted",
  "equal_cluster",  "Equal-cluster"
)

# ---- ink & theme (identical to Paper A) ------------------------------------
PAL <- list(
  ink = "#1A1A1A", ink2 = "#4D4D4D", ink3 = "#767676",
  grid = "grey90", band = "#EFF3F8",
  blue = "#0072B2", sky = "#56B4E9", green = "#009E73",
  orange = "#E69F00", vermillion = "#D55E00", purple = "#CC79A7",
  calibrated = "#0072B2", raw = "#56B4E9"
)
BASE_SIZE <- 8.3
BASE_FAMILY <- "Helvetica"

theme_pa <- function(base_size = BASE_SIZE) {
  theme_minimal(base_size = base_size, base_family = BASE_FAMILY) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = PAL$grid, linewidth = 0.28),
      axis.title = element_text(size = base_size, color = PAL$ink),
      axis.text = element_text(size = base_size - 0.6, color = PAL$ink2),
      axis.ticks = element_blank(),
      strip.text = element_text(size = base_size + 0.2, face = "bold",
                                color = PAL$ink, hjust = 0,
                                margin = margin(b = 3)),
      legend.title = element_text(size = base_size, color = PAL$ink),
      legend.text = element_text(size = base_size - 0.6, color = PAL$ink2),
      legend.key.height = unit(3.2, "mm"),
      legend.key.width = unit(3.2, "mm"),
      plot.margin = margin(2, 5, 2, 2),
      plot.title = element_blank(),
      plot.subtitle = element_blank(),
      plot.tag = element_text(size = base_size + 1.2, face = "bold",
                              family = BASE_FAMILY)
    )
}
theme_schematic <- function(base_size = BASE_SIZE) {
  theme_void(base_size = base_size, base_family = BASE_FAMILY) +
    theme(
      strip.text = element_text(size = base_size + 0.2, face = "bold",
                                color = PAL$ink, hjust = 0,
                                margin = margin(b = 3)),
      plot.margin = margin(2, 2, 2, 2),
      plot.title = element_blank(),
      plot.subtitle = element_blank(),
      plot.tag = element_text(size = base_size + 1.2, face = "bold",
                              family = BASE_FAMILY)
    )
}

dev_quartz_pdf <- function(filename, width, height, ...) {
  grDevices::quartz(file = filename, type = "pdf",
                    width = width, height = height, ...)
}
save_fig <- function(plot, name, width_mm, height_mm, dir = FIG_MAIN) {
  w <- width_mm / 25.4
  h <- height_mm / 25.4
  ggsave(file.path(dir, paste0(name, ".pdf")), plot, width = w, height = h,
         device = dev_quartz_pdf)
  ggsave(file.path(dir, paste0(name, ".png")), plot, width = w, height = h,
         dpi = 500, device = ragg::agg_png, bg = "white")
  message("wrote ", name, " (", width_mm, " x ", height_mm, " mm) -> ", dir)
}
MM_FULL <- 165
MM_MID <- 130
MM_SINGLE <- 85

# ---- canonical locked tables ----------------------------------------------
num <- function(x) as.numeric(x)

p16_cells <- read_locked_csv(file.path(PATHS$confirmatory, "v4-phase16-confirmation-cell-summary-v1.csv")) |>
  mutate(across(c(gamma_cluster, replications, coverage, coverage_mcse,
                  mean_interval_length, median_interval_length, mean_bias,
                  maximum_invalid_fraction, status_ok_fraction), num))
p16_lane <- read_locked_csv(file.path(PATHS$confirmatory, "v4-phase16-confirmation-lane-summary-v1.csv")) |>
  mutate(across(c(replications, coverage, coverage_mcse, mean_interval_length), num))
p16_overall <- read_locked_csv(file.path(PATHS$confirmatory, "v4-phase16-confirmation-overall-summary-v1.csv")) |>
  mutate(across(c(gamma_cluster, replications, coverage, coverage_mcse,
                  mean_interval_length), num))
p16_comp <- read_locked_csv(file.path(PATHS$confirmatory, "v4-phase16-confirmation-comparator-summary-v1.csv")) |>
  mutate(across(c(replications, coverage, coverage_mcse, mean_interval_length), num))
p16_sub <- read_locked_csv(file.path(PATHS$confirmatory, "v4-phase16-confirmation-subgroup-summary-v1.csv")) |>
  mutate(across(c(replications, coverage, coverage_mcse, mean_interval_length), num))
p16_design <- read_locked_csv(file.path(PATHS$confirmatory, "v4-phase16-confirmation-design-v1.csv")) |>
  mutate(G = as.integer(G), latent_icc = num(latent_icc),
         informative_slope = num(informative_slope))
p16_gates <- read_locked_csv(file.path(PATHS$confirmatory, "v4-phase16-confirmation-gate-checks-v1.csv"))

p15_cand <- read_locked_csv(file.path(PATHS$development, "v4-phase15-training-candidate-summary-v1.csv")) |>
  mutate(across(c(gamma_cluster, replications, coverage, coverage_mcse,
                  mean_interval_length), num))
p15_dec <- read_locked_csv(file.path(PATHS$development, "v4-phase15-training-candidate-decisions-v1.csv")) |>
  mutate(across(c(gamma_cluster, respondent_coverage, equal_cluster_coverage,
                  respondent_mean_interval_length,
                  equal_cluster_mean_interval_length,
                  minimum_G_group_coverage,
                  minimum_size_mechanism_group_coverage), num))
p15_val <- read_locked_csv(file.path(PATHS$validation, "v4-phase15-validation-overall-summary-v1.csv")) |>
  mutate(across(c(gamma_cluster, replications, coverage, coverage_mcse,
                  mean_interval_length), num))
p14_agg <- read_locked_csv(file.path(PATHS$pilot, "v4-phase14-pilot-aggregate-summary-v1.csv")) |>
  mutate(across(c(replications, coverage, coverage_mcse,
                  mean_interval_length), num))

p17_methods <- read_locked_csv(file.path(PATHS$emp_results, "v4-phase17-method-summary-v1.csv")) |>
  mutate(across(c(gamma_cluster, point_estimate, lower, upper, center,
                  interval_length, se_equivalent, defined_draws, total_draws,
                  invalid_fraction), num))
p17_icc <- read_locked_csv(file.path(PATHS$emp_results, "v4-phase17-icc-summary-v1.csv"))
p17_profile <- read_locked_csv(file.path(PATHS$emp_results, "v4-phase17-data-profile-v1.csv"))
p17_cats <- read_locked_csv(file.path(PATHS$emp_results, "v4-phase17-category-profile-v1.csv")) |>
  mutate(score = as.integer(score), count = as.integer(count), mass = num(mass))
p17_knots <- read_locked_csv(file.path(PATHS$emp_results, "v4-phase17-target-knot-diagnostics-v1.csv"))
p17_quant <- read_locked_csv(file.path(PATHS$emp_results, "v4-phase17-quantile-stability-v1.csv"))

claims18 <- read_locked_csv(file.path(PATHS$p18_review, "v4-phase18-claim-eligibility-v1.csv"))

# ---- structural sanity ------------------------------------------------------
assert(nrow(p16_design) == 24L, "phase16 design changed (expect 24 cells)")
assert(sum(p16_design$regularity == "regular") == 16L, "expect 16 regular cells")
assert(nrow(p16_comp) == 15L, "comparator summary changed (expect 15)")
assert(nrow(p17_methods) == 18L, "phase17 method summary changed (expect 18)")
assert(nrow(claims18) == 14L, "claim register changed (expect 14)")

fmt_h <- function(x, digits = 3) sub("^(-?)0\\.", "\\1.", formatC(x, format = "f", digits = digits))
