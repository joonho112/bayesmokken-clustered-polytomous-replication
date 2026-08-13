#!/usr/bin/env Rscript
# =============================================================================
# verification/verify_reproduction.R -- did the build reproduce the paper's
# exhibits?
#
#     Rscript exhibits/00_build_all.R          # first
#     Rscript verification/verify_reproduction.R
#
# Compares outputs/ against verification/expected/exhibit-parity.csv, which
# holds digests taken from the PUBLISHED manuscript build -- not from this
# package. So a pass means the rebuild agrees with print, not merely with
# itself.
#
# TWO PARITY METHODS, AND WHY THEY DIFFER
#
# Floats and the ledger are compared byte for byte. LaTeX has no rendering
# tolerance: if a .tex file differs at all, something real changed, and stopping
# is the intended behaviour rather than a nuisance to normalize away.
#
# Figures are compared by page geometry plus the SHA-256 of a fixed-DPI raster
# render. PDF bytes are NOT usable here: quartz embeds a creation timestamp, so
# every figure's container changes on every run even when every pixel is
# identical. Rendering at a pinned resolution and hashing the pixels tests what
# a reader actually sees.
#
# KNOWN LIMIT. Raster identity depends on the Poppler build doing the
# rendering. A pixel mismatch on a different platform is more likely to be a
# renderer difference than a scientific one; check the geometry line first,
# then compare a rendered PNG by eye before concluding anything. This is stated
# in the guide's reproducibility chapter rather than papered over.
# =============================================================================

.here <- local({
  fa <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(fa)) dirname(normalizePath(gsub("~+~", " ", sub("^--file=", "", fa[1]),
                                             fixed = TRUE), mustWork = FALSE)) else getwd()
})
source(file.path(dirname(.here), "common", "R", "paths.R"))
suppressPackageStartupMessages(library(digest))

cfg <- yaml::read_yaml(PATHS$config)
DPI <- cfg$gates$render_dpi
EXPECTED_MANIFEST_SHA256 <- "041c13aef3bd408c5c2887e1d68679b3dd77491b1bdbd7412cd0405def10eebc"

render_digest <- function(pdf) {
  tmp <- tempfile()
  on.exit(unlink(paste0(tmp, ".png")), add = TRUE)
  ok <- system2("pdftoppm", c("-r", DPI, "-png", "-singlefile",
                              shQuote(pdf), shQuote(tmp)),
                stdout = FALSE, stderr = FALSE)
  if (ok != 0L || !file.exists(paste0(tmp, ".png"))) return(NA_character_)
  digest(file = paste0(tmp, ".png"), algo = "sha256")
}

page_geometry <- function(pdf) {
  out <- suppressWarnings(system2("pdfinfo", shQuote(pdf), stdout = TRUE, stderr = FALSE))
  line <- grep("^Page size:", out, value = TRUE)
  if (!length(line)) return(NA_character_)
  trimws(sub("^Page size:\\s*", "", line[1]))
}

manifest_path <- file.path(PATHS$expected, "exhibit-parity.csv")
manifest_digest <- digest(file = manifest_path, algo = "sha256")
if (!identical(manifest_digest, EXPECTED_MANIFEST_SHA256)) {
  cat("FAIL  immutable published-manuscript parity manifest changed\n")
  quit(status = 1L)
}
exp <- read.csv(manifest_path,
                stringsAsFactors = FALSE)
if (length(unique(exp$target_source)) != 1L ||
    !identical(unique(exp$target_source), "published manuscript build")) {
  cat("FAIL  parity target is not the published manuscript build\n")
  quit(status = 1L)
}

cat("\nexhibit reproduction\n")
cat("target: ", unique(exp$target_source), "\n", sep = "")
cat("render: ", DPI, " dpi\n", sep = "")
cat(strrep("-", 72), "\n", sep = "")

pass <- 0L; fail <- 0L; notes <- character()

for (i in seq_len(nrow(exp))) {
  r <- exp[i, ]
  f <- file.path(PATHS$root, r$output_path)
  if (!file.exists(f)) {
    cat(sprintf("%-6s %-26s %s\n", "MISS", r$exhibit_id, "not built"))
    fail <- fail + 1L; next
  }
  if (grepl("^byte", r$parity_method)) {
    got <- digest(file = f, algo = "sha256")
    ok <- identical(got, r$digest)
    cat(sprintf("%-6s %-26s %s\n", if (ok) "ok" else "FAIL", r$exhibit_id,
                if (ok) "byte-identical" else paste0("digest ", substr(got, 1, 12), "...")))
  } else {
    geo <- page_geometry(f)
    got <- render_digest(f)
    geo_ok <- identical(geo, r$geometry)
    pix_ok <- identical(got, r$digest)
    ok <- geo_ok && pix_ok
    msg <- if (ok) "geometry + pixels match"
           else if (!geo_ok) paste0("GEOMETRY ", geo, " != ", r$geometry)
           else "pixels differ (see the known-limit note in this file's header)"
    cat(sprintf("%-6s %-26s %s\n", if (ok) "ok" else "FAIL", r$exhibit_id, msg))
    if (!ok && geo_ok) notes <- c(notes, r$exhibit_id)
  }
  if (ok) pass <- pass + 1L else fail <- fail + 1L
}

# The ledger is not in expected/ (it has no counterpart under the manuscript's
# figures/ or floats/); its target is the manuscript's tools/key_numbers.csv,
# shipped here as expected/key_numbers-manuscript.csv.
led <- file.path(PATHS$out_root, "key_numbers.csv")
ref <- file.path(PATHS$expected, "key_numbers-manuscript.csv")
if (file.exists(led) && file.exists(ref)) {
  ok <- identical(digest(file = led, algo = "sha256"),
                  digest(file = ref, algo = "sha256"))
  cat(sprintf("%-6s %-26s %s\n", if (ok) "ok" else "FAIL", "key_numbers",
              if (ok) "byte-identical to the manuscript ledger" else "DIFFERS"))
  if (ok) pass <- pass + 1L else fail <- fail + 1L
} else {
  cat(sprintf("%-6s %-26s %s\n", "MISS", "key_numbers", "not built"))
  fail <- fail + 1L
}

cat(strrep("-", 72), "\n", sep = "")
cat(sprintf("%d / %d exhibits reproduce\n", pass, pass + fail))
if (length(notes)) {
  cat("\nPixels differed with matching geometry for: ",
      paste(notes, collapse = ", "), "\n",
      "That pattern usually means a different Poppler build, not a different\n",
      "figure. Render both to PNG and compare before concluding otherwise.\n", sep = "")
}
quit(status = if (fail == 0L) 0L else 1L)
