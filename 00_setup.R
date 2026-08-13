#!/usr/bin/env Rscript
# =============================================================================
# 00_setup.R -- environment check.
#
# Reports what is missing and INSTALLS NOTHING. Run it first; it tells you
# whether the four build commands will work before you spend time on them.
#
#     Rscript 00_setup.R
#
# Works when invoked by absolute path from outside the clone. Exits 0 when the
# required contract in config.yml is met, 1 otherwise. Optional packages and
# packages are reported but never fail the check: they are needed only for the
# oracle lane. Release commands, including Quarto, are required.
# =============================================================================

suppressWarnings(suppressMessages({
  ok_yaml <- requireNamespace("yaml", quietly = TRUE)
}))
if (!ok_yaml) {
  cat("FAIL  the 'yaml' package is required to read config.yml\n",
      "      install.packages(\"yaml\")\n", sep = "")
  quit(status = 1L)
}

# commandArgs() encodes spaces in the script path as `~+~`, so decoding is
# mandatory before the first file() call whenever the clone sits under a path
# containing a space. paths.R carries the same decoder; this copy only
# bootstraps to it.
.self <- gsub("~+~", " ",
              sub("^--file=", "",
                  grep("^--file=", commandArgs(trailingOnly = FALSE),
                       value = TRUE)[1]),
              fixed = TRUE)
source(file.path(dirname(.self), "common", "R", "paths.R"))

cfg <- yaml::read_yaml(PATHS$config)

pad <- function(x, n = 40) formatC(x, width = -n, flag = " ")
line <- function(status, what, note = "") {
  cat(sprintf("%-6s%s%s\n", status, pad(what), note))
}

cat("\n", cfg$package$name, " ", cfg$package$version, "\n", sep = "")
cat(strrep("-", 72), "\n", sep = "")
cat("root: ", PATHS$root, "\n\n", sep = "")

failures <- 0L

# ---- R version --------------------------------------------------------------
r_min <- numeric_version(cfg$environment$r_min)
r_now <- getRversion()
if (r_now >= r_min) {
  line("OK", paste0("R >= ", r_min), as.character(r_now))
} else {
  line("FAIL", paste0("R >= ", r_min), paste("found", r_now))
  failures <- failures + 1L
}

# ---- required packages ------------------------------------------------------
cat("\nrequired packages\n")
for (p in cfg$environment$required) {
  if (requireNamespace(p, quietly = TRUE)) {
    line("OK", p, as.character(utils::packageVersion(p)))
  } else {
    line("FAIL", p, "install.packages()")
    failures <- failures + 1L
  }
}

# ---- platform and exercised dependency paths -------------------------------
required_os <- cfg$environment$required_os
current_os <- unname(Sys.info()[["sysname"]])
if (identical(current_os, required_os)) {
  line("OK", paste0("OS = ", required_os), current_os)
} else {
  line("FAIL", paste0("OS = ", required_os), paste("found", current_os))
  failures <- failures + 1L
}

json_ok <- tryCatch(
  identical(jsonlite::fromJSON('{"setup_smoke":true}')$setup_smoke, TRUE),
  error = function(e) FALSE
)
line(if (json_ok) "OK" else "FAIL", "jsonlite smoke", "parse locked-receipt JSON")
if (!json_ok) failures <- failures + 1L

pdf_smoke <- tempfile(fileext = ".pdf")
graphics_ok <- tryCatch({
  grDevices::quartz(file = pdf_smoke, type = "pdf", width = 2, height = 2)
  graphics::par(mar = rep(0, 4))
  graphics::plot.new()
  grDevices::dev.off()
  file.exists(pdf_smoke) && file.info(pdf_smoke)$size > 0L
}, error = function(e) {
  while (grDevices::dev.cur() > 1L) grDevices::dev.off()
  FALSE
})
unlink(pdf_smoke)
line(if (graphics_ok) "OK" else "FAIL", "quartz PDF smoke", "published figure device")
if (!graphics_ok) failures <- failures + 1L

# ---- optional packages ------------------------------------------------------
cat("\noptional packages (oracle lane only; absence is not an error)\n")
for (p in cfg$environment$optional) {
  if (requireNamespace(p, quietly = TRUE)) {
    line("OK", p, as.character(utils::packageVersion(p)))
  } else {
    line("skip", p, "oracle checks will report 'skipped'")
  }
}

# ---- command-line tools -----------------------------------------------------
have <- function(cmd) nzchar(Sys.which(cmd))
cat("\ncommand-line tools\n")
for (cmd in cfg$environment$commands$required) {
  if (have(cmd)) {
    line("OK", cmd, Sys.which(cmd))
  } else {
    line("FAIL", cmd, "needed for figure parity / disclosure scan")
    failures <- failures + 1L
  }
}
optional_commands <- cfg$environment$commands$optional
if (is.null(optional_commands)) optional_commands <- character()
for (cmd in optional_commands) {
  if (have(cmd)) line("OK", cmd, Sys.which(cmd)) else line("skip", cmd, "optional")
}

# ---- the frozen snapshot ----------------------------------------------------
cat("\nfrozen snapshot\n")
for (nm in cfg$frozen_tiers) {
  d <- file.path(PATHS$frozen, nm)
  n <- if (dir.exists(d)) length(list.files(d)) else -1L
  if (n > 0L) {
    line("OK", paste0("data-frozen/", nm), paste(n, "files"))
  } else if (n == 0L) {
    line("EMPTY", paste0("data-frozen/", nm), "not yet populated")
  } else {
    line("FAIL", paste0("data-frozen/", nm), "missing")
    failures <- failures + 1L
  }
}

cat(strrep("-", 72), "\n", sep = "")
if (failures == 0L) {
  cat("contract met. Next:\n",
      "  Rscript exhibits/00_build_all.R\n",
      "  Rscript verification/verify_reproduction.R\n", sep = "")
  quit(status = 0L)
} else {
  cat(failures, " requirement(s) unmet -- see FAIL above.\n", sep = "")
  quit(status = 1L)
}
