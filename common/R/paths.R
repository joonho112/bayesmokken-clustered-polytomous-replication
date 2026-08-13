# =============================================================================
# common/R/paths.R -- the only file in this package that resolves where the
# package lives.
#
# It contains no absolute path itself. The root is found by walking up from the
# calling script until a `.replication-root` marker file appears, so every entry
# point works when invoked by absolute path from outside the clone:
#
#     Rscript "/some/where/bayesmokken-scalability-replication/00_setup.R"
#
# This matters whenever the clone sits under a path containing a space, which
# is common enough to be the default assumption. Anything that assumes the
# working directory, or that splits a path on whitespace, breaks silently.
#
# Nothing else in the package may hardcode a path. If you need a new location,
# add it to the block at the bottom of this file.
# =============================================================================

#' Recover a real path from R's `--file=` argument.
#'
#' commandArgs() encodes every space in the script path as `~+~`. If this
#' package is cloned anywhere whose path contains a space -- "My Documents",
#' "Google Drive", a project folder with a space in its name -- an absolute
#' invocation arrives as ".../My~+~Documents/..." and every subsequent file()
#' call fails on a path that does not exist. Decode before use, always.
script_arg_path <- function(arg) {
  gsub("~+~", " ", sub("^--file=", "", arg), fixed = TRUE)
}

#' Where is this file being read from?
#'
#' Three ways in, and all three must work:
#'   1. `Rscript /abs/path/exhibits/00_build_all.R` -- the path arrives as
#'      `--file=` on the command line;
#'   2. `source("/abs/path/common/R/paths.R")` -- the path is `ofile` in the
#'      source() frame, which is how the verification harness loads it;
#'   3. an interactive session with the package as the working directory.
this_file_dir <- function() {
  # `ofile` FIRST, and the order matters. It is the path of the file currently
  # being source()d -- that is, of this file -- so it is right even when the
  # caller lives somewhere else entirely. `--file=` is the path of whatever
  # script R was launched with, which for an external caller (a check script, a
  # cold-start rehearsal driver) points at the wrong tree and resolves to the
  # wrong package, or to no package at all.
  for (i in rev(seq_len(sys.nframe()))) {
    ofile <- tryCatch(get("ofile", envir = sys.frames()[[i]],
                          inherits = FALSE),
                      error = function(e) NULL)
    if (is.character(ofile) && length(ofile) == 1L && nzchar(ofile)) {
      return(dirname(normalizePath(ofile, mustWork = FALSE)))
    }
  }
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg)) {
    return(dirname(normalizePath(script_arg_path(file_arg[1]),
                                 mustWork = FALSE)))
  }
  getwd()
}

find_replication_root <- function(start = NULL) {
  if (is.null(start)) start <- this_file_dir()
  dir <- normalizePath(start, mustWork = FALSE)
  repeat {
    if (file.exists(file.path(dir, ".replication-root"))) return(dir)
    parent <- dirname(dir)
    if (identical(parent, dir)) {
      stop("could not find .replication-root above: ", start, call. = FALSE)
    }
    dir <- parent
  }
}

ROOT <- find_replication_root()

# ---- the directory contract -------------------------------------------------
# Every path the package uses is derived here. `file.path` handles the space in
# the enclosing directory name; never paste these into a shell string without
# shQuote().

PATHS <- list(
  root        = ROOT,
  config      = file.path(ROOT, "config.yml"),

  frozen      = file.path(ROOT, "data-frozen"),
  design      = file.path(ROOT, "data-frozen", "design"),
  pilot       = file.path(ROOT, "data-frozen", "pilot"),
  development = file.path(ROOT, "data-frozen", "development"),
  validation  = file.path(ROOT, "data-frozen", "validation"),
  confirmatory= file.path(ROOT, "data-frozen", "confirmatory"),
  conf_raw    = file.path(ROOT, "data-frozen", "confirmatory-raw"),
  empirical   = file.path(ROOT, "data-frozen", "empirical", "artifacts"),
  emp_results = file.path(ROOT, "data-frozen", "empirical", "results"),
  emp_raw     = file.path(ROOT, "data-frozen", "empirical", "aws-raw"),
  p18_review  = file.path(ROOT, "data-frozen", "phase18", "review"),
  p18_prod    = file.path(ROOT, "data-frozen", "phase18", "production"),

  exhibits    = file.path(ROOT, "exhibits"),
  out_fig     = file.path(ROOT, "outputs", "figures"),
  out_float   = file.path(ROOT, "outputs", "floats"),
  out_root    = file.path(ROOT, "outputs"),

  provenance  = file.path(ROOT, "provenance"),
  governance  = file.path(ROOT, "provenance", "governance"),
  verification= file.path(ROOT, "verification"),
  expected    = file.path(ROOT, "verification", "expected"),
  docs        = file.path(ROOT, "docs")
)

path_of <- function(key, ...) {
  if (!key %in% names(PATHS)) {
    stop("unknown path key: ", key, call. = FALSE)
  }
  file.path(PATHS[[key]], ...)
}
