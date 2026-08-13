paper_root <- normalizePath(".", mustWork = TRUE)
stopifnot(
  requireNamespace("mokken", quietly = TRUE),
  requireNamespace("digest", quietly = TRUE)
)
data("SWMDK", package = "mokken", envir = environment())

source_hash <- digest::digest(SWMDK, algo = "sha256")
stopifnot(
  identical(
    source_hash,
    "e1257ff16f821ef3cf6c5eed88a91ae2ffa5a067e12603f32c02660d47270797"
  ),
  identical(dim(SWMDK), c(639L, 14L)),
  length(unique(SWMDK[, 1L])) == 30L
)

assignment <- mokken::aisp(
  SWMDK[, -1L],
  lowerbound = 0.30,
  test.Hi = TRUE,
  type.z = "WB",
  level.two.var = SWMDK[, 1L]
)
assignment <- as.integer(assignment[, 1L])
expected_assignment <- c(1, 1, 1, 1, 1, 1, 0, 2, 2, 2, 2, 0, 2)
expected_assignment <- as.integer(expected_assignment)
stopifnot(identical(assignment, expected_assignment))

teacher <- SWMDK[, 1:7, drop = FALSE]
classmate <- SWMDK[, c(1, 9:12, 14), drop = FALSE]
invisible(utils::capture.output(
  teacher_h <- mokken::coefH(
    teacher[, -1L], level.two.var = teacher[, 1L], ci = .95
  )
))
invisible(utils::capture.output(
  classmate_h <- mokken::coefH(
    classmate[, -1L],
    level.two.var = classmate[, 1L],
    ci = .95
  )
))
teacher_icc <- mokken::ICC(teacher)
classmate_icc <- mokken::ICC(classmate)

scale_summary <- data.frame(
  scale = c("teacher", "classmate"),
  item_ids = c("Item1|Item2|Item3|Item4|Item5|Item6",
               "Item8|Item9|Item10|Item11|Item13"),
  n = c(nrow(teacher), nrow(classmate)),
  H_displayed = c(as.numeric(teacher_h$H[[1L]]),
                  as.numeric(classmate_h$H[[1L]])),
  SE_displayed = c(as.numeric(gsub("[()]", "", teacher_h$H[[2L]])),
                   as.numeric(gsub("[()]", "", classmate_h$H[[2L]]))),
  SE_from_covH = c(sqrt(teacher_h$covH[1L, 1L]),
                   sqrt(classmate_h$covH[1L, 1L])),
  ICC = c(teacher_icc$scaleICC$ICC, classmate_icc$scaleICC$ICC),
  F = c(teacher_icc$scaleICC$F, classmate_icc$scaleICC$F),
  df1 = c(teacher_icc$scaleICC$df1, classmate_icc$scaleICC$df1),
  df2 = c(teacher_icc$scaleICC$df2, classmate_icc$scaleICC$df2),
  p_value = c(teacher_icc$scaleICC$p.value,
              classmate_icc$scaleICC$p.value)
)
stopifnot(
  identical(scale_summary$H_displayed, c(0.620, 0.592)),
  max(abs(
    scale_summary$SE_from_covH -
      c(0.0256092325049504, 0.0253145717630435)
  )) < 1e-14,
  identical(scale_summary$ICC, c(0.169, 0.183)),
  identical(scale_summary$F, c(5.305, 5.746))
)

assignment_table <- data.frame(
  item = colnames(SWMDK)[-1L],
  lowerbound = 0.30,
  scale = assignment
)
utils::write.csv(
  scale_summary,
  file.path(
    paper_root, "codebase", "oracles", "koopman", "fixtures",
    "koopman-scale-summary.csv"
  ),
  row.names = FALSE
)
utils::write.csv(
  assignment_table,
  file.path(
    paper_root, "codebase", "oracles", "koopman", "fixtures",
    "koopman-t-aisp-assignment.csv"
  ),
  row.names = FALSE
)
cat(sprintf(
  "SWMDK_PROVENANCE_PASS hash=%s assignment=%s\n",
  source_hash, paste(assignment, collapse = ",")
))
