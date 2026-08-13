validate_transport_lp_input <- function(scores, mass, name,
                                        mass_tol = 1e-12) {
  if (!is.numeric(scores) || !is.numeric(mass)) {
    stop(name, " scores and mass must be numeric", call. = FALSE)
  }
  if (length(scores) != length(mass) || length(scores) < 1L) {
    stop(name, " scores and mass must have equal positive length",
         call. = FALSE)
  }
  if (any(!is.finite(scores)) || any(!is.finite(mass))) {
    stop(name, " scores and mass must be finite", call. = FALSE)
  }
  if (length(scores) > 1L && any(diff(scores) <= 0)) {
    stop(name, " scores must be strictly increasing", call. = FALSE)
  }
  if (any(mass < 0)) {
    stop(name, " mass must be nonnegative", call. = FALSE)
  }
  if (abs(sum(mass) - 1) > mass_tol) {
    stop(name, " mass must sum to one within mass_tol", call. = FALSE)
  }
  list(scores = scores, mass = mass / sum(mass), name = name)
}

transport_lp_oracle <- function(x_scores, x_mass, y_scores, y_mass,
                                mass_tol = 1e-12) {
  if (!requireNamespace("lpSolve", quietly = TRUE)) {
    stop("The independent LP oracle requires package 'lpSolve'",
         call. = FALSE)
  }
  x <- validate_transport_lp_input(x_scores, x_mass, "x", mass_tol)
  y <- validate_transport_lp_input(y_scores, y_mass, "y", mass_tol)
  nx <- length(x$scores)
  ny <- length(y$scores)
  cell_index <- function(a, b) a + (b - 1L) * nx

  objective <- numeric(nx * ny)
  for (b in seq_len(ny)) {
    for (a in seq_len(nx)) {
      objective[cell_index(a, b)] <- x$scores[a] * y$scores[b]
    }
  }

  constraint_matrix <- matrix(0, nrow = nx + ny, ncol = nx * ny)
  for (a in seq_len(nx)) {
    constraint_matrix[a, cell_index(a, seq_len(ny))] <- 1
  }
  for (b in seq_len(ny)) {
    constraint_matrix[nx + b, cell_index(seq_len(nx), b)] <- 1
  }
  rhs <- c(x$mass, y$mass)

  fit <- lpSolve::lp(
    direction = "max",
    objective.in = objective,
    const.mat = constraint_matrix,
    const.dir = rep("=", length(rhs)),
    const.rhs = rhs,
    all.int = FALSE
  )
  if (fit$status != 0L) {
    stop("LP oracle failed with status ", fit$status, call. = FALSE)
  }

  plan <- matrix(fit$solution, nrow = nx, ncol = ny)
  row_residual <- rowSums(plan) - x$mass
  column_residual <- colSums(plan) - y$mass
  primal_value <- sum(plan * outer(x$scores, y$scores))
  mu_x <- sum(x$scores * x$mass)
  mu_y <- sum(y$scores * y$mass)

  list(
    status = fit$status,
    maximum_product = primal_value,
    maximum_covariance = primal_value - mu_x * mu_y,
    mean_x = mu_x,
    mean_y = mu_y,
    plan = plan,
    row_residual = row_residual,
    column_residual = column_residual,
    maximum_marginal_residual = max(abs(c(
      row_residual, column_residual
    ))),
    minimum_cell = min(plan),
    solver_objective = fit$objval,
    objective_residual = primal_value - fit$objval
  )
}
