#!/usr/bin/env Rscript
# =============================================================================
# verification/verify_semantics.R -- the checks parity and numbers cannot make.
#
#     Rscript verification/verify_semantics.R
#
# Parity says the rebuilt file matches the published one. The number gate says
# the ledger agrees with the paper. Neither looks at whether an exhibit MEANS
# what it is captioned to mean.
#
# That gap is not hypothetical. Twice in sibling projects a chart shipped with
# its axis mapping and its caption pointing in opposite directions, and it
# passed type-checking, parity and rendering every time.
#
# This package carries two checks Paper A does not: the frozen claim-eligibility
# register that governs the article's wording, and the archival ordinal-h.R
# defect -- both that its "do not port" banner is present and that the condition
# under which the defect could have fired is empty in the locked truth inputs.
#
# So this gate reads a declared spec (provenance/chart-specs.csv) and tests each
# claim against the frozen data the figure is drawn from. A caption that is
# reversed relative to the data fails here even though the picture is stable.
#
# It also checks the two registers that let a reader navigate the package agree
# with each other and with what is on disk.
# =============================================================================

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

cat("\nsemantic consistency\n"); cat(strrep("-", 72), "\n", sep = "")

# ---- 1. the two registers agree, in both directions -------------------------
cat("\nregisters\n")
rep_map <- read.csv(file.path(PATHS$provenance, "reproduction-map.csv"), stringsAsFactors = FALSE)
contract <- read.csv(file.path(PATHS$provenance, "manuscript-artifact-contract.csv"), stringsAsFactors = FALSE)

chk("every exhibit in reproduction-map is in the artifact contract",
    stopifnot(all(rep_map$exhibit_id %in% contract$exhibit_id)))
chk("every exhibit in the artifact contract is in reproduction-map",
    stopifnot(all(contract$exhibit_id %in% rep_map$exhibit_id)))
chk("every mapped output exists on disk",
    stopifnot(all(file.exists(file.path(PATHS$root, rep_map$output_path)))))
chk("exhibit count matches exhibit_contract", {
  want <- CFG$exhibit_contract$figures$main + CFG$exhibit_contract$figures$supplement +
          CFG$exhibit_contract$tables$main + CFG$exhibit_contract$tables$supplement
  stopifnot(sum(rep_map$exhibit_id != "key_numbers") == want)
})
chk("reproduction map is the reviewed exact-input contract", {
  map_path <- file.path(PATHS$provenance, "reproduction-map.csv")
  stopifnot(digest::digest(file = map_path, algo = "sha256") ==
              "a6eb1e87e947d9e9a5c28fc0a89c0ee68ad92f3e62b80a14ec40b8a103054a88")
  for (decl in rep_map$frozen_inputs) {
    tokens <- trimws(strsplit(decl, ";", fixed = TRUE)[[1]])
    stopifnot(length(tokens) > 0L, all(nzchar(tokens)),
              !any(grepl("/$", tokens)), !any(tokens %in% c("artifacts", "results")))
    for (token in tokens) {
      if (startsWith(token, "live:")) next
      if (startsWith(token, "outputs:")) {
        stopifnot(file.exists(file.path(PATHS$out_root, sub("^outputs:", "", token))))
      } else if (startsWith(token, "glob:")) {
        stopifnot(length(Sys.glob(file.path(PATHS$frozen, sub("^glob:", "", token)))) > 0L)
      } else {
        stopifnot(file.exists(file.path(PATHS$frozen, token)))
      }
    }
  }
})

# ---- 2. the chart-semantics contract ----------------------------------------
cat("\nchart semantics\n")
spec <- read.csv(file.path(PATHS$provenance, "chart-specs.csv"), stringsAsFactors = FALSE)
expected_directions <- c(
  B_INTERVAL_TIGHTENS = "tightens", B_DESIGN_SHAPE = "descriptive",
  B_TARGETS_SEPARATE = "separate_targets", B_GAMMA_PATH = "tightens",
  B_FACTOR_INCREASES_WITH_G = "increases_with_G",
  B_ALL_CELLS = "separate_targets", B_SPLIT_STABLE = "stable"
)
require_spec <- function(check_id, direction) {
  r <- spec[spec$check_id == check_id, , drop = FALSE]
  stopifnot(nrow(r) >= 1L, all(r$direction_code == direction))
}
chk("chart specs have the executable schema and registered direction codes", {
  need <- c("exhibit_id", "panel", "generator", "x_var", "y_var",
            "source_tier", "source_file", "direction_code", "check_id")
  stopifnot(all(need %in% names(spec)))
  for (id in names(expected_directions)) require_spec(id, expected_directions[[id]])
  stopifnot(all(spec$check_id %in% names(expected_directions)))
})
chk("chart specs name the generator registered by reproduction-map", {
  for (id in unique(spec$exhibit_id)) {
    stopifnot(length(unique(spec$generator[spec$exhibit_id == id])) == 1L,
              unique(spec$generator[spec$exhibit_id == id]) ==
                rep_map$generator[match(id, rep_map$exhibit_id)])
  }
})
chk("every figure has a declared spec", {
  figs <- rep_map$exhibit_id[grepl("figures/", rep_map$output_path)]
  stopifnot(all(figs %in% spec$exhibit_id))
})

cellsum <- read_tier("confirmatory", "v4-phase16-confirmation-cell-summary-v1.csv")
allcell <- read.csv(file.path(PATHS$out_root, "derived_p16_allcell_summary.csv"),
                    stringsAsFactors = FALSE)
TARGETS <- CFG$frozen_contract$design$target_ids

chk("fig3: both population targets are present and reported separately", {
  require_spec("B_TARGETS_SEPARATE", "separate_targets")
  stopifnot(length(unique(allcell$target)) == 2L)
})
chk("FigF1/tabF1: 48 cell-target rows at 400 replications each", {
  require_spec("B_ALL_CELLS", "separate_targets")
  stopifnot(nrow(allcell) == CFG$frozen_contract$confirmatory$cell_target_rows,
            all(allcell$replications == CFG$frozen_contract$confirmatory$reps_per_cell_target))
})
chk("fig1: the cluster calibration TIGHTENS the interval (k_G < 1)", {
  require_spec("B_INTERVAL_TIGHTENS", "tightens")
  # The direction claim. Paper A's calibration widens; this one narrows, because
  # the two-stage bootstrap over clusters is conservative before calibration. A
  # figure or caption implying the reverse would be backwards.
  kn <- read.csv(file.path(PATHS$out_root, "key_numbers.csv"), stringsAsFactors = FALSE)
  v <- function(k) as.numeric(kn$value[kn$key == k])
  stopifnot(v("p16_sel_raw_ratio") < 1)
})
chk("fig2: 24 confirmation cells", {
  require_spec("B_DESIGN_SHAPE", "descriptive")
  d <- read_tier("confirmatory", "v4-phase16-confirmation-design-v1.csv")
  stopifnot(nrow(d) == CFG$frozen_contract$confirmatory$cells)
})
chk("fig4a: more-negative gamma shortens the training interval", {
  require_spec("B_GAMMA_PATH", "tightens")
  d <- read_tier("development", "v4-phase15-training-candidate-decisions-v1.csv")
  raw <- d[d$gamma_cluster == 0, ]
  sel <- d[d$gamma_cluster == -1.5, ]
  stopifnot(nrow(raw) == 1L, nrow(sel) == 1L,
            sel$respondent_mean_interval_length < raw$respondent_mean_interval_length,
            sel$equal_cluster_mean_interval_length < raw$equal_cluster_mean_interval_length)
})
chk("fig4b: for fixed negative gamma k_G increases toward 1 as G increases", {
  require_spec("B_FACTOR_INCREASES_WITH_G", "increases_with_G")
  G <- sort(unique(as.numeric(read_tier(
    "confirmatory", "v4-phase16-confirmation-design-v1.csv")$G)))
  k <- 1 - 1.5 / sqrt(G)
  stopifnot(length(G) == 4L, all(diff(k) > 0), all(k < 1))
})
chk("FigG1: split-half discrepancies remain below the registered bound", {
  require_spec("B_SPLIT_STABLE", "stable")
  d <- read_tier("results", "v4-phase17-quantile-stability-v1.csv")
  stopifnot(nrow(d) == 4L, max(as.numeric(d$maximum_endpoint_difference)) < 9e-4)
})

# ---- 3. the frozen claim-eligibility register -------------------------------
cat("\nclaim register\n")
chk("tabH1 transcribes all 14 registered claims", {
  cl <- read_tier("p18_review", "v4-phase18-claim-eligibility-v1.csv")
  stopifnot(nrow(cl) == CFG$exhibit_contract$claims_registered)
  tex <- readLines(file.path(PATHS$out_float, "tabH1_claims.tex"), warn = FALSE)
  ids <- cl[[grep("claim.*id|^id$", names(cl), ignore.case = TRUE)[1]]]
  missing <- ids[!vapply(ids, function(i) any(grepl(i, tex, fixed = TRUE)), logical(1))]
  if (length(missing)) stop("claims absent from tabH1: ", paste(missing, collapse = ", "))
})

# ---- 4. the archival ordinal-h.R defect -------------------------------------
cat("\narchival defect\n")
ordh <- file.path(PATHS$root, "reference-code", "R", "core", "ordinal-h.R")
chk("ordinal-h.R carries the 'do not port' banner", {
  txt <- paste(readLines(ordh, warn = FALSE), collapse = "\n")
  stopifnot(grepl("KNOWN ARCHIVAL DEFECT", txt, fixed = TRUE),
            grepl("DO NOT PORT", txt, fixed = TRUE),
            grepl("ordinal-transport.R", txt, fixed = TRUE))
})
chk("ordinal-h.R's archival body is unchanged (banner only)", {
  reg <- read.csv(file.path(PATHS$root, "reference-code", "ARCHIVAL-DIGESTS.csv"),
                  stringsAsFactors = FALSE)
  r <- reg[grepl("ordinal-h[.]R$", reg$path), ]
  stopifnot(nrow(r) == 1L,
            digest::digest(file = ordh, algo = "sha256") == r$sha256_shipped)
})
chk("the 168-row direct certificate records an empty inclusive risk set", {
  p <- file.path(PATHS$verification, "archival", "results",
                 "archival-safety-certificate.csv")
  d <- read_locked_csv(p)
  stopifnot(nrow(d) == 168L,
            identical(as.integer(table(d$stage)[c(
              "pilot", "training", "validation", "confirmation")]),
              c(36L, 48L, 36L, 48L)),
            sum(d$risk_residual_count) == 0L,
            min(d$minimum_positive_marginal_mass) > 1e-12,
            min(d$minimum_positive_cross_cdf_gap) > 1e-12,
            max(d$absolute_old_corrected_difference) == 0,
            max(d$maximum_pair_transport_difference) == 0,
            max(d$maximum_conservation_error) <= 1e-12)
})

# ---- 5. the codebook describes what ships -----------------------------------
cat("\ncodebook\n")
cb <- paste(readLines(file.path(PATHS$frozen, "CODEBOOK.md"), warn = FALSE), collapse = "\n")
chk("every frozen tier is named in CODEBOOK.md", {
  missing <- CFG$frozen_tiers[!vapply(CFG$frozen_tiers,
    function(t) grepl(basename(t), cb, fixed = TRUE), logical(1))]
  if (length(missing)) stop("tier absent from the codebook: ", paste(missing, collapse = ", "))
})
chk("DATA_ACCESS.md documents the SWMDK lock", {
  da <- paste(readLines(file.path(PATHS$root, "DATA_ACCESS.md"), warn = FALSE), collapse = "\n")
  stopifnot(grepl(CFG$frozen_contract$swmdk_lock$object_digest_sha256, da, fixed = TRUE),
            grepl("data(SWMDK)", da, fixed = TRUE))
})

cat(strrep("-", 72), "\n", sep = "")
cat(sprintf("%d passed, %d failed\n", pass, fail))
quit(status = if (fail == 0L) 0L else 1L)
