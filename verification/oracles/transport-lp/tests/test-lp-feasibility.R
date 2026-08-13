script_arg <- grep("^--file=", commandArgs(), value = TRUE)
test_dir <- if (length(script_arg)) {
  dirname(normalizePath(sub("^--file=", "", script_arg[[1]])))
} else {
  normalizePath(getwd())
}
oracle_dir <- normalizePath(file.path(test_dir, ".."))
source(file.path(oracle_dir, "solve-transport-lp.R"))
source(file.path(oracle_dir, "two-pointer-reference.R"))

split_number <- function(x) as.numeric(strsplit(x, ";", fixed = TRUE)[[1]])
fixtures <- read.csv(
  file.path(oracle_dir, "fixtures", "lp-hand-values.csv"),
  stringsAsFactors = FALSE
)

for (row in seq_len(nrow(fixtures))) {
  x_scores <- split_number(fixtures$x_scores[row])
  x_mass <- split_number(fixtures$x_mass[row])
  y_scores <- split_number(fixtures$y_scores[row])
  y_mass <- split_number(fixtures$y_mass[row])
  lp <- transport_lp_oracle(x_scores, x_mass, y_scores, y_mass)
  pointer <- transport_two_pointer(x_scores, x_mass, y_scores, y_mass)
  stopifnot(
    lp$status == 0L,
    lp$minimum_cell >= -1e-12,
    lp$maximum_marginal_residual <= 1e-10,
    abs(lp$objective_residual) <= 1e-10,
    abs(lp$maximum_product -
          fixtures$expected_maximum_product[row]) <= 1e-10,
    abs(lp$maximum_covariance -
          fixtures$expected_maximum_covariance[row]) <= 1e-10,
    abs(lp$maximum_product - pointer$maximum_product) <= 1e-10
  )
}

invalid <- try(
  transport_lp_oracle(c(0, 1), c(0.4, 0.4), c(0, 1), c(0.5, 0.5)),
  silent = TRUE
)
stopifnot(inherits(invalid, "try-error"))

unequal <- transport_lp_oracle(
  c(0, 1, 2), c(0.8, 0.1, 0.1),
  c(0, 1, 2), c(0.1, 0.1, 0.8)
)
binary <- transport_lp_oracle(
  c(0, 1), c(0.75, 0.25),
  c(0, 1), c(0.5, 0.5)
)
declared <- transport_lp_oracle(
  c(0, 1, 3), c(0.25, 0.5, 0.25),
  c(0, 2, 3), c(0.25, 0.5, 0.25)
)
indices <- transport_lp_oracle(
  c(0, 1, 2), c(0.25, 0.5, 0.25),
  c(0, 1, 2), c(0.25, 0.5, 0.25)
)
stopifnot(
  abs(unequal$maximum_product - 0.6) <= 1e-10,
  abs(unequal$maximum_covariance - 0.09) <= 1e-10,
  abs(binary$maximum_covariance - 0.125) <= 1e-10,
  abs(declared$maximum_product - 3.25) <= 1e-10,
  abs(declared$maximum_covariance - 1.0625) <= 1e-10,
  abs(indices$maximum_product - 1.5) <= 1e-10,
  abs(indices$maximum_covariance - 0.5) <= 1e-10
)

message(
  "PASS: ", nrow(fixtures),
  " hand-value fixtures, 3 counterexamples, and LP feasibility checks"
)
