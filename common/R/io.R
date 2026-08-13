# =============================================================================
# common/R/io.R -- typed readers for the frozen snapshot.
#
# Exhibit code reads frozen CSV/JSON inputs through this file. Named raw readers
# assert their declared dimensions; verification/verify_numeric_basis.R adds
# exact schemas, manifest/receipt hashes, key/domain constraints, and full
# Phase 16/17 raw-to-result reconciliation. Generic read_tier() intentionally
# asserts existence only, so documentation must not claim a universal schema
# check that the function does not perform.
#
# Two traps this file exists to avoid, both of which have cost a sibling package
# real work:
#
#   * `data.table::fread()` handed a .gz path DECOMPRESSES IT IN PLACE, silently
#     mutating the frozen snapshot. The compressed tiers are read through
#     gzfile() connections here and nowhere else.
#
#   * SWMDK is never copied into this package (D-5). It is loaded from the
#     'mokken' package at run time and checked against a locked digest, so the
#     reader for it lives here too rather than in a generator.
#
# =============================================================================

if (!exists("PATHS")) {
  stop("source common/R/paths.R before common/R/io.R", call. = FALSE)
}

CFG <- yaml::read_yaml(PATHS$config)

# ---- assertion vocabulary ---------------------------------------------------
assert <- function(cond, msg) {
  if (!isTRUE(cond)) stop("contract violation: ", msg, call. = FALSE)
  invisible(TRUE)
}

assert_close <- function(x, y, tol = 1e-9,
                         msg = "value drifted from the frozen contract") {
  assert(is.finite(x) && is.finite(y) && abs(x - y) <= tol,
         paste0(msg, " (", format(x, digits = 17), " vs ",
                format(y, digits = 17), ")"))
}

#' Assert a data frame's row count against a config.yml contract path.
#'
#' @param d      the data frame
#' @param keys   character vector naming the path into frozen_contract,
#'               e.g. c("confirmatory", "family_metrics_rows")
assert_rows <- function(d, keys, what = deparse(substitute(d))) {
  expected <- CFG$frozen_contract
  for (k in keys) {
    assert(!is.null(expected[[k]]),
           paste0("no contract at frozen_contract$", paste(keys, collapse = "$")))
    expected <- expected[[k]]
  }
  assert(nrow(d) == expected,
         paste0(what, ": expected ", expected, " rows, read ", nrow(d)))
  invisible(d)
}

assert_cols <- function(d, cols, what = deparse(substitute(d))) {
  miss <- setdiff(cols, names(d))
  assert(length(miss) == 0L,
         paste0(what, ": missing column(s) ", paste(miss, collapse = ", ")))
  invisible(d)
}

# ---- primitives -------------------------------------------------------------

#' Parse C99 hex floats (and ordinary decimals) without losing a bit.
hx <- function(x) {
  vapply(as.character(x), function(s) {
    v <- suppressWarnings(as.numeric(s))
    if (is.na(v) && !is.na(s) && nzchar(s)) {
      stop("unparseable numeric: ", s, call. = FALSE)
    }
    v
  }, numeric(1), USE.NAMES = FALSE)
}

#' Read a locked CSV exactly as written.
#'
#' Some locked files carry duplicated metadata headers (the SF04 truth lock
#' repeats `schema_version`). The files are immutable, so the first occurrence
#' is kept -- which is what Python's csv.DictReader also resolves to.
read_locked_csv <- function(path) {
  assert(file.exists(path), paste("missing frozen file:", path))
  d <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  d[, !duplicated(names(d)), drop = FALSE]
}

#' Read a gzipped locked CSV through a connection.
#'
#' Never hand the path to fread(); see the header note.
read_locked_csv_gz <- function(path) {
  assert(file.exists(path), paste("missing frozen file:", path))
  con <- gzfile(path, open = "rt")
  on.exit(close(con), add = TRUE)
  d <- utils::read.csv(con, stringsAsFactors = FALSE, check.names = FALSE)
  d[, !duplicated(names(d)), drop = FALSE]
}

#' Bind the 24 gzipped Phase 16 replication files.
#'
#' 01_build_key_numbers.R derives the 48-row all-cell summary from these and
#' cross-checks it against the locked regular-cell artifact at 1e-12.
read_confirmatory_raw <- function() {
  files <- sort(list.files(PATHS$conf_raw, pattern = "replications-v1[.]csv[.]gz$",
                           full.names = TRUE))
  assert(length(files) == CFG$frozen_contract$confirmatory$cells,
         paste0("confirmatory-raw: expected ",
                CFG$frozen_contract$confirmatory$cells, " files, found ",
                length(files)))
  parts <- lapply(files, read_locked_csv_gz)
  assert(length(unique(lapply(parts, names))) == 1L,
         "confirmatory-raw: files do not share one header")
  out <- do.call(rbind, parts)
  assert_rows(out, c("confirmatory", "raw_replication_rows"),
              what = "confirmatory-raw")
  out
}

# ---- tier readers -----------------------------------------------------------
# One reader per tier, each asserting its shape before returning.

#' A locked artifact from a named tier.
read_tier <- function(tier, name) {
  dir <- switch(tier,
                design       = PATHS$design,
                pilot        = PATHS$pilot,
                development  = PATHS$development,
                validation   = PATHS$validation,
                confirmatory = PATHS$confirmatory,
                empirical    = PATHS$empirical,
                results      = PATHS$emp_results,
                p18_review   = PATHS$p18_review,
                p18_prod     = PATHS$p18_prod,
                stop("unknown tier: ", tier, call. = FALSE))
  path <- file.path(dir, name)
  if (grepl("[.]json$", name)) {
    assert(file.exists(path), paste("missing frozen file:", path))
    return(jsonlite::read_json(path, simplifyVector = TRUE))
  }
  read_locked_csv(path)
}

#' The SWMDK application data, loaded from the `mokken` package.
#'
#' D-5: no responses ship with this package. SWMDK is distributed inside
#' `mokken`, which is why `mokken` is a REQUIRED dependency here and optional in
#' the companion Paper A package.
#'
#' The Phase 17 protocol locked the object's digest and dimensions before the
#' application ran; this reader asserts them on every load, so a `mokken`
#' release that changed the data would fail here rather than silently produce
#' different numbers.
read_swmdk <- function(strict = TRUE) {
  assert(requireNamespace("mokken", quietly = TRUE),
         "the 'mokken' package is required: SWMDK is distributed inside it")
  assert(requireNamespace("digest", quietly = TRUE), "the 'digest' package is required")
  e <- new.env()
  utils::data("SWMDK", package = "mokken", envir = e)
  d <- e$SWMDK
  lock <- CFG$frozen_contract$swmdk_lock

  assert(nrow(d) == lock$respondents,
         paste0("SWMDK: expected ", lock$respondents, " respondents, got ", nrow(d)))
  assert(length(unique(d[[lock$cluster_id]])) == lock$clusters,
         paste0("SWMDK: expected ", lock$clusters, " clusters"))

  # The digest is of the data.frame as loaded. as.matrix() gives a different
  # value; the lock records which one it means.
  got <- digest::digest(d, algo = "sha256")
  if (!identical(got, lock$object_digest_sha256)) {
    msg <- paste0(
      "SWMDK digest does not match the Phase 17 lock.\n",
      "  locked : ", lock$object_digest_sha256, " (mokken ", lock$package_version_at_lock, ")\n",
      "  loaded : ", got, " (mokken ",
      as.character(utils::packageVersion("mokken")), ")\n",
      "This means the installed mokken ships different data from the one the ",
      "application ran on. That is a finding about the data source, not a ",
      "packaging error -- report it rather than working around it.")
    if (strict) stop(msg, call. = FALSE) else warning(msg, call. = FALSE)
  }
  d
}

#' The 12 Phase 17 draw streams, or one of them.
read_draws <- function(task = NULL) {
  files <- sort(list.files(PATHS$emp_raw, pattern = "draws-v1[.]csv[.]gz$",
                           full.names = TRUE))
  assert(length(files) == CFG$frozen_contract$empirical$tasks,
         paste0("expected ", CFG$frozen_contract$empirical$tasks,
                " draw streams, found ", length(files)))
  if (!is.null(task)) {
    f <- grep(sprintf("P17-T%02d-", task), files, value = TRUE)
    assert(length(f) == 1L, paste("no unique draw stream for task", task))
    d <- read_locked_csv_gz(f)
    assert(nrow(d) == CFG$frozen_contract$empirical$draws_per_task,
           paste0("task ", task, ": expected ",
                  CFG$frozen_contract$empirical$draws_per_task, " draws, got ", nrow(d)))
    return(d)
  }
  lapply(files, read_locked_csv_gz)
}
