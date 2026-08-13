script_arg <- grep("^--file=", commandArgs(), value = TRUE)
oracle_dir <- if (length(script_arg)) {
  dirname(normalizePath(gsub("~+~", " ", sub("^--file=", "", script_arg[[1]]),
                               fixed = TRUE)))
} else {
  normalizePath(getwd())
}
source(file.path(oracle_dir, "solve-transport-lp.R"))
source(file.path(oracle_dir, "two-pointer-reference.R"))

compositions <- function(total, parts) {
  if (parts == 1L) return(matrix(total, nrow = 1L))
  pieces <- lapply(0:total, function(first) {
    tail <- compositions(total - first, parts - 1L)
    cbind(first, tail)
  })
  do.call(rbind, pieces)
}

selected_masses <- function(categories, denominator = 4L,
                            maximum = 12L) {
  grid <- compositions(denominator, categories) / denominator
  keep <- unique(round(seq(1, nrow(grid), length.out = min(
    maximum, nrow(grid)
  ))))
  grid[keep, , drop = FALSE]
}

score_vector <- function(categories, variant) {
  if (variant == "consecutive") return(seq.int(0, categories - 1L))
  if (variant == "gapped") {
    return(cumsum(c(0, rep(c(1, 2), length.out = categories - 1L))))
  }
  stop("Unknown score variant")
}

records <- list()
record_id <- 0L
for (kx in 2:5) {
  for (ky in 2:5) {
    x_grid <- selected_masses(kx)
    y_grid <- selected_masses(ky)
    for (variant in c("consecutive", "gapped")) {
      x_scores <- score_vector(kx, variant)
      y_scores <- score_vector(ky, variant)
      for (ix in seq_len(nrow(x_grid))) {
        for (iy in seq_len(nrow(y_grid))) {
          record_id <- record_id + 1L
          x_mass <- x_grid[ix, ]
          y_mass <- y_grid[iy, ]
          lp <- transport_lp_oracle(x_scores, x_mass, y_scores, y_mass)
          pointer <- transport_two_pointer(
            x_scores, x_mass, y_scores, y_mass
          )
          discrepancy <- abs(
            lp$maximum_product - pointer$maximum_product
          )
          records[[record_id]] <- data.frame(
            case_id = sprintf(
              "kx%02d-ky%02d-%s-x%02d-y%02d",
              kx, ky, variant, ix, iy
            ),
            seed = record_id,
            kx = kx,
            ky = ky,
            score_variant = variant,
            x_mass_id = ix,
            y_mass_id = iy,
            x_mass = paste(x_mass, collapse = ";"),
            y_mass = paste(y_mass, collapse = ";"),
            two_pointer_value = pointer$maximum_product,
            lp_value = lp$maximum_product,
            absolute_discrepancy = discrepancy,
            maximum_marginal_residual = lp$maximum_marginal_residual,
            objective_residual = abs(lp$objective_residual),
            lp_status = lp$status,
            pass = (
              discrepancy <= 1e-10 &&
                lp$maximum_marginal_residual <= 1e-10 &&
                abs(lp$objective_residual) <= 1e-10
            ),
            stringsAsFactors = FALSE
          )
        }
      }
    }
  }
}

detail <- do.call(rbind, records)
groups <- split(
  detail,
  interaction(
    detail$kx, detail$ky, detail$score_variant,
    drop = TRUE, lex.order = TRUE
  )
)
summary <- do.call(rbind, lapply(groups, function(group) {
  data.frame(
    kx = group$kx[1],
    ky = group$ky[1],
    score_variant = group$score_variant[1],
    cases = nrow(group),
    passed = sum(group$pass),
    failed = sum(!group$pass),
    maximum_absolute_discrepancy = max(group$absolute_discrepancy),
    maximum_marginal_residual = max(group$maximum_marginal_residual),
    maximum_objective_residual = max(group$objective_residual),
    stringsAsFactors = FALSE
  )
}))
summary <- summary[order(
  summary$kx, summary$ky, summary$score_variant
), ]
failures <- detail[!detail$pass, ]

results_dir <- file.path(oracle_dir, "results")
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
write.csv(
  summary,
  file.path(results_dir, "exhaustive-grid-summary.csv"),
  row.names = FALSE
)
write.csv(
  failures,
  file.path(results_dir, "exhaustive-grid-failures.csv"),
  row.names = FALSE
)

cat(
  "cases=", nrow(detail),
  " failed=", nrow(failures),
  " max_discrepancy=", format(max(detail$absolute_discrepancy), digits = 16),
  " max_marginal_residual=",
  format(max(detail$maximum_marginal_residual), digits = 16),
  "\n",
  sep = ""
)
if (nrow(failures)) quit(status = 1L)
