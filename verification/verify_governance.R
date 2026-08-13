#!/usr/bin/env Rscript
# =============================================================================
# verification/verify_governance.R -- does the receipt chain close?
#
#     Rscript verification/verify_governance.R
#
# The governance tier claims that every rule was fixed before the outcome it
# governs existed. That claim is only as good as its references: each receipt
# names the SHA-256 of the authority it descends from, and a reference that
# resolves to nothing is a gap in the argument.
#
# This gate reads every SHA-256 in the v3 confirmatory governance JSON and
# requires each to resolve to one of:
#
#   1. a file this package ships (any file, anywhere in the package);
#   2. a governance file, via provenance/governance/DIGESTS.csv;
#   3. a file deliberately excluded, via provenance/excluded-digests.csv --
#      which carries a reason for every row;
#   4. the ARCHIVAL digest of a reference-code file, via
#      reference-code/ARCHIVAL-DIGESTS.csv, or the upstream digest of a
#      redacted file, via provenance/redactions.csv. Every file in either
#      register was modified for a documented reason, and both registers record
#      what the file was before -- which is exactly what keeps the chain
#      closable.
#
# WHERE THE BOUNDARY IS, AND WHY
#
# Receipt chains regress. The confirmatory run's receipts name the Phase 8 and
# Phase 10 authorities they inherit; those name their own predecessors; and so
# on back through the research programme. Chasing that to its root would pull
# several earlier studies into this package, none of which is an input to this
# paper's claims.
#
# So the gate is scoped: it verifies the references made by the **v3
# confirmatory** receipts. The direct ancestry those receipts name ships under
# provenance/governance/ancestry/ as context, and the references those ancestry
# files make in turn are out of scope -- they belong to the records of the
# studies that produced them. ANCESTRY_SCOPED below is that decision, in code,
# so it is visible rather than implied.
# =============================================================================

.here <- local({
  fa <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(fa)) dirname(normalizePath(gsub("~+~", " ", sub("^--file=", "", fa[1]),
                                             fixed = TRUE), mustWork = FALSE))
  else getwd()
})
source(file.path(dirname(.here), "common", "R", "paths.R"))
suppressPackageStartupMessages(library(digest))

# Files whose own outward references are out of scope (see the header note).
ANCESTRY_SCOPED <- "ancestry"

cat("\nreceipt-chain closure\n"); cat(strrep("-", 64), "\n", sep = "")

# ---- what we can resolve to -------------------------------------------------
known <- new.env(hash = TRUE, parent = emptyenv())
add <- function(h) assign(h, TRUE, envir = known)

for (f in list.files(PATHS$root, recursive = TRUE, full.names = TRUE, all.files = FALSE)) {
  if (file.exists(f) && !dir.exists(f)) add(digest(file = f, algo = "sha256"))
}
gov_dig <- read.csv(file.path(PATHS$governance, "DIGESTS.csv"), stringsAsFactors = FALSE)
invisible(lapply(gov_dig$sha256, add))
excl <- read.csv(file.path(PATHS$provenance, "excluded-digests.csv"), stringsAsFactors = FALSE)
invisible(lapply(excl$sha256, add))

# Reference code carries a nine-line "do not run this" banner, so its shipped
# digest differs from the archival one a receipt names. ARCHIVAL-DIGESTS.csv
# maps one to the other; without it the banner would silently break the chain.
arch <- read.csv(file.path(PATHS$root, "reference-code", "ARCHIVAL-DIGESTS.csv"),
                 stringsAsFactors = FALSE)
invisible(lapply(arch$sha256_archival, add))

# A few shipped files were edited before release for documented reasons -- see
# the register itself for what each one was and why. Their upstream digests are
# on record for the same reason the archival ones are.
red_path <- file.path(PATHS$provenance, "redactions.csv")
if (file.exists(red_path)) {
  red <- read.csv(red_path, stringsAsFactors = FALSE)
  invisible(lapply(red$sha256_upstream, add))
}

cat(sprintf("resolvable digests: %d total  (%d governance, %d exclusions, %d archival)\n",
            length(ls(known)), nrow(gov_dig), nrow(excl), nrow(arch)))

# ---- every reference in the in-scope receipts -------------------------------
files <- list.files(PATHS$governance, pattern = "[.]json$", recursive = TRUE,
                    full.names = TRUE)
in_scope <- files[!grepl(ANCESTRY_SCOPED, files, fixed = TRUE)]
out_scope <- setdiff(files, in_scope)

refs <- 0L; resolved <- 0L; dangling <- character()
for (f in in_scope) {
  txt <- readLines(f, warn = FALSE)
  hits <- regmatches(txt, gregexpr("\\b[0-9a-f]{64}\\b", txt))
  for (h in unlist(hits)) {
    refs <- refs + 1L
    if (!is.null(known[[h]])) resolved <- resolved + 1L
    else dangling <- c(dangling, paste0(basename(f), ": ", substr(h, 1, 16), "..."))
  }
}

cat(sprintf("in-scope receipts:  %d  (%d ancestry files out of scope)\n",
            length(in_scope), length(out_scope)))
cat(sprintf("references:         %d\n", refs))
cat(sprintf("resolved:           %d\n", resolved))
cat(sprintf("dangling:           %d\n", length(dangling)))
if (length(dangling)) for (d in unique(dangling)) cat("   ", d, "\n")

cat(strrep("-", 64), "\n", sep = "")
if (length(dangling) == 0L) {
  cat("PASS  the v3 confirmatory receipt chain closes\n")
  quit(status = 0L)
}
cat("FAIL  ", length(dangling), " reference(s) resolve to nothing\n", sep = "")
quit(status = 1L)
