validate_transport_input <- function(scores, mass, name,
                                     mass_tol = 1e-12) {
  stopifnot(
    is.numeric(scores),
    is.numeric(mass),
    length(scores) == length(mass),
    length(scores) >= 1L,
    all(is.finite(scores)),
    all(is.finite(mass)),
    all(diff(scores) > 0),
    all(mass >= 0),
    abs(sum(mass) - 1) <= mass_tol
  )
  list(scores = scores, mass = mass / sum(mass), name = name)
}

transport_two_pointer <- function(x_scores, x_mass, y_scores, y_mass,
                                  mass_tol = 1e-12) {
  x <- validate_transport_input(x_scores, x_mass, "x", mass_tol)
  y <- validate_transport_input(y_scores, y_mass, "y", mass_tol)
  i <- 1L
  j <- 1L
  remaining_x <- x$mass
  remaining_y <- y$mass
  value <- 0
  moved_total <- 0
  path <- list()
  step <- 0L
  simultaneous_knots <- 0L
  while (i <= length(x$scores) && j <= length(y$scores)) {
    if (remaining_x[i] == 0) {
      i <- i + 1L
      next
    }
    if (remaining_y[j] == 0) {
      j <- j + 1L
      next
    }
    moved <- min(remaining_x[i], remaining_y[j])
    step <- step + 1L
    path[[step]] <- data.frame(
      step = step,
      x_index = i,
      y_index = j,
      x_score = x$scores[i],
      y_score = y$scores[j],
      mass = moved,
      contribution = moved * x$scores[i] * y$scores[j]
    )
    value <- value + moved * x$scores[i] * y$scores[j]
    moved_total <- moved_total + moved
    x_done <- remaining_x[i] <= remaining_y[j]
    y_done <- remaining_y[j] <= remaining_x[i]
    remaining_x[i] <- if (x_done) 0 else remaining_x[i] - moved
    remaining_y[j] <- if (y_done) 0 else remaining_y[j] - moved
    if (x_done && y_done) {
      simultaneous_knots <- simultaneous_knots + 1L
    }
    if (x_done) i <- i + 1L
    if (y_done) j <- j + 1L
  }
  path <- if (length(path)) do.call(rbind, path) else data.frame()
  stopifnot(
    abs(moved_total - 1) <= mass_tol,
    all(remaining_x == 0),
    all(remaining_y == 0)
  )
  mu_x <- sum(x$scores * x$mass)
  mu_y <- sum(y$scores * y$mass)
  list(
    maximum_product = value,
    maximum_covariance = value - mu_x * mu_y,
    mean_x = mu_x,
    mean_y = mu_y,
    path = path,
    moved_total = moved_total,
    simultaneous_knots = simultaneous_knots,
    zero_mass_x = which(x$mass == 0),
    zero_mass_y = which(y$mass == 0),
    complexity_bound = length(x$scores) + length(y$scores) - 1L
  )
}
