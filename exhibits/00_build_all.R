#!/usr/bin/env Rscript
# =============================================================================
# exhibits/00_build_all.R -- rebuild every exhibit in the paper.
#
#     Rscript exhibits/00_build_all.R
#
# Writes 7 figures (PDF + PNG) to outputs/figures/, 8 LaTeX floats to
# outputs/floats/, and the 144-key ledger to outputs/key_numbers.csv. Then check
# it reproduced:
#
#     Rscript verification/verify_reproduction.R
#
# ORDER MATTERS, and here it matters twice. 01_build_key_numbers.R must run
# first because it writes the ledger every other generator asserts its displayed
# values against, and 00_common.R refuses to define kn() without it. It ALSO
# derives outputs/derived_p16_allcell_summary.csv from the 86,400 raw Phase 16
# replication rows -- cross-checked against the locked regular-cell artifact at
# 1e-12 -- and both 07_tables.R and 08_osm_figures.R read that file. Running
# them before it fails outright rather than silently.
#
# This script rebuilds. It does not verify, and it is not idempotent in the
# sense that matters: quartz PDF output embeds a creation timestamp, so the PDF
# bytes change on every run even when every pixel is identical. That is why
# figure parity is checked by page geometry plus a fixed-DPI render hash rather
# than by PDF bytes -- see verification/verify_reproduction.R.
# =============================================================================

.this_file <- local({
  fa <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(fa)) {
    return(normalizePath(gsub("~+~", " ", sub("^--file=", "", fa[1]), fixed = TRUE),
                         mustWork = FALSE))
  }
  file.path(getwd(), "00_build_all.R")
})
EXH <- dirname(.this_file)

GENERATORS <- c(
  "01_build_key_numbers.R",   # the ledger -- must be first; also writes
                              # outputs/derived_p16_allcell_summary.csv, which
                              # 07_tables.R and 08_osm_figures.R both consume
  "01_fig1_concept.R",        # Figure 1
  "02_fig2_design.R",         # Figure 2
  "03_fig3_coverage.R",       # Figure 3
  "04_fig4_calibration.R",    # Figure 4
  "05_fig5_swmdk.R",          # Figure 5
  "07_tables.R",              # 8 floats
  "08_osm_figures.R"          # FigF1, FigG1
)

old_wd <- getwd()
setwd(EXH)
on.exit(setwd(old_wd), add = TRUE)

cat("\nrebuilding the exhibit layer\n")
cat(strrep("-", 64), "\n", sep = "")

timings <- data.frame(generator = character(), seconds = numeric(),
                      status = character(), stringsAsFactors = FALSE)
failed <- character()

for (g in GENERATORS) {
  t0 <- proc.time()[["elapsed"]]
  ok <- tryCatch({
    # Each generator sources 00_common.R itself, so each runs in its own
    # environment and cannot leak state into the next.
    callr_env <- new.env(parent = globalenv())
    sys.source(g, envir = callr_env)
    TRUE
  }, error = function(e) {
    message("  ", conditionMessage(e))
    FALSE
  })
  dt <- proc.time()[["elapsed"]] - t0
  timings <- rbind(timings, data.frame(generator = g, seconds = round(dt, 1),
                                       status = if (ok) "ok" else "FAILED",
                                       stringsAsFactors = FALSE))
  cat(sprintf("%-6s %-26s %6.1fs\n", if (ok) "ok" else "FAIL", g, dt))
  if (!ok) failed <- c(failed, g)
}

cat(strrep("-", 64), "\n", sep = "")

source(file.path(dirname(EXH), "common", "R", "paths.R"))
n_fig <- length(list.files(PATHS$out_fig, pattern = "[.]pdf$"))
n_png <- length(list.files(PATHS$out_fig, pattern = "[.]png$"))
n_tex <- length(list.files(PATHS$out_float, pattern = "[.]tex$"))
cfg <- yaml::read_yaml(PATHS$config)
want_fig <- cfg$exhibit_contract$figures$main + cfg$exhibit_contract$figures$supplement
want_tex <- cfg$exhibit_contract$tables$main + cfg$exhibit_contract$tables$supplement

# The rebuilt PNGs are the single source for the public guide. Keep the source
# assets synchronized here; the release gate renders Quarto and hash-compares
# all three representations (outputs, docs/assets, docs/_book/assets).
docs_assets <- file.path(PATHS$root, "docs", "assets")
dir.create(docs_assets, showWarnings = FALSE, recursive = TRUE)
pngs <- list.files(PATHS$out_fig, pattern = "[.]png$", full.names = TRUE)
if (!all(file.copy(pngs, docs_assets, overwrite = TRUE))) {
  stop("failed to synchronize rebuilt PNGs into docs/assets", call. = FALSE)
}

cat(sprintf("figures  %2d pdf / %2d png   (contract %d)\n", n_fig, n_png, want_fig))
cat(sprintf("floats   %2d tex             (contract %d)\n", n_tex, want_tex))
cat(sprintf("guide     %2d png synchronized from outputs\n", length(pngs)))
cat(sprintf("total    %.1fs\n", sum(timings$seconds)))

bad <- length(failed) > 0L || n_fig != want_fig || n_tex != want_tex
if (bad) {
  if (length(failed)) cat("\nFAILED: ", paste(failed, collapse = ", "), "\n", sep = "")
  if (n_fig != want_fig) cat("figure count does not match the contract\n")
  if (n_tex != want_tex) cat("float count does not match the contract\n")
  quit(status = 1L)
}
cat("\nall ", nrow(timings), " generators ok. Next:\n",
    "  Rscript verification/verify_reproduction.R\n", sep = "")
quit(status = 0L)
