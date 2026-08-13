#!/usr/bin/env Rscript
# =============================================================================
# verification/build_expected.R -- (RE)GENERATE THE PARITY TARGET.
#
#     Rscript verification/build_expected.R --i-mean-it --from-published DIR
#
# +-------------------------------------------------------------------------+
# | THIS OVERWRITES WHAT verify_reproduction.R CHECKS AGAINST.              |
# |                                                                         |
# | This tool accepts only a separately supplied published-manuscript build. |
# | Package outputs are never a legal parity source.                         |
# +-------------------------------------------------------------------------+
#
# The parity target itself is the PUBLISHED manuscript's exhibits, not this
# package's output. `expected/` records digests of the published files where
# they are available, so a rebuild is checked against print rather than against
# itself.
# =============================================================================

if (!("--i-mean-it" %in% commandArgs(trailingOnly = TRUE))) {
  cat("\nRefusing to overwrite the parity target.\n",
      "Re-run with --i-mean-it if that is genuinely what you want, and record\n",
      "the reason in a phase log.\n\n", sep = "")
  quit(status = 2L)
}

.here <- local({
  fa <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(fa)) dirname(normalizePath(gsub("~+~", " ", sub("^--file=", "", fa[1]),
                                             fixed = TRUE), mustWork = FALSE)) else getwd()
})
source(file.path(dirname(.here), "common", "R", "paths.R"))
suppressPackageStartupMessages(library(digest))

cfg <- yaml::read_yaml(PATHS$config)
DPI <- cfg$gates$render_dpi

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
  out <- system2("pdfinfo", shQuote(pdf), stdout = TRUE, stderr = FALSE)
  line <- grep("^Page size:", out, value = TRUE)
  if (!length(line)) return(NA_character_)
  trimws(sub("^Page size:\\s*", "", line[1]))
}

# Where the parity target comes from.
#
#   --from-published <dir>   digest the PUBLISHED manuscript's exhibits. This is
#                            the correct source and the one the shipped
#                            expected/ was built from. <dir> must hold
#                            figures/ and floats/.
args <- commandArgs(trailingOnly = TRUE)
i <- match("--from-published", args)
if (is.na(i) || length(args) <= i) {
  cat("\nRefusing to build a self-referential parity target.\n",
      "Supply --from-published DIR, where DIR is a separately preserved\n",
      "published manuscript build containing figures/ and floats/.\n\n", sep = "")
  quit(status = 2L)
}
PUB <- normalizePath(args[i + 1L], mustWork = TRUE)
if (!dir.exists(file.path(PUB, "figures")) || !dir.exists(file.path(PUB, "floats"))) {
  stop("--from-published must contain figures/ and floats/", call. = FALSE)
}
SOURCE_LABEL <- "published manuscript build"

resolve <- function(output_path) {
  # outputs/figures/x.pdf -> <pub>/figures/x.pdf ; outputs/floats/x.tex -> <pub>/floats/x.tex
  file.path(PUB, sub("^outputs/", "", output_path))
}

map <- read.csv(file.path(PATHS$provenance, "reproduction-map.csv"),
                stringsAsFactors = FALSE)

rows <- lapply(seq_len(nrow(map)), function(i) {
  r <- map[i, ]
  f <- resolve(r$output_path)
  if (!file.exists(f)) {
    # key_numbers.csv has no counterpart in the manuscript's figures/floats
    # dirs; its parity target is tools/key_numbers.csv, checked separately by
    # verify_manuscript_numbers.R.
    return(NULL)
  }
  if (grepl("^byte", r$parity_method)) {
    data.frame(exhibit_id = r$exhibit_id, output_path = r$output_path,
               parity_method = r$parity_method,
               geometry = NA_character_,
               digest = digest(file = f, algo = "sha256"),
               target_source = SOURCE_LABEL,
               stringsAsFactors = FALSE)
  } else {
    data.frame(exhibit_id = r$exhibit_id, output_path = r$output_path,
               parity_method = r$parity_method,
               geometry = page_geometry(f),
               digest = render_digest(f),
               target_source = SOURCE_LABEL,
               stringsAsFactors = FALSE)
  }
})
exp <- do.call(rbind, rows)
out <- file.path(PATHS$expected, "exhibit-parity.csv")
write.csv(exp, out, row.names = FALSE)
cat("wrote ", out, ": ", nrow(exp), " exhibits at ", DPI, " dpi\n",
    "target source: ", SOURCE_LABEL, "\n", sep = "")
