###Active Layer Thickness Solver###


# ---------- Utilities ----------
#Creates a safe exponent to prevent overflow 
safe_exp <- function(x, clip = 700) {
  # Prevent Inf from overflow; exp(> ~709) overflows in double precision.
  x <- pmin(x, clip)
  x <- pmax(x, -clip)
  exp(x)
}

# Finds intervals where a function (f(z)) changes sign across a specified grid
bracket_sign_changes <- function(f, zmin, zmax, n_grid) {
  # Generate grid and evaluate function
  z_grid <- seq(zmin, zmax, length.out = n_grid)
  f_vals <- f(z_grid)
  # Check for sign changes and account for values at exactly 0
  f_signs <- sign(f_vals)
  # Find where signs differ 
  idx <- which(f_signs[-1] * f_signs[-length(f_signs)] < 0)  # sign changes
  # Return early if no crossings found
  if (!length(idx))
    return(list(intervals = list(), z_grid = z_grid, f_vals = f_vals))
  # Matrix-to-list conversion for intervals
  int_matrix <- rbind(z_grid[idx], z_grid[idx+1])
  intervals <- lapply(idx, function(i) c(z_grid[i], z_grid[i + 1]))
  names(intervals) <- NULL
  list(intervals = intervals, z_grid = z_grid, f_vals = f_vals)
}

#Find a single root (0) of a function (f) within a specified interval (a,b) and with a high tolerance (tol)
refine_root <- function(f, a, b, tol = 1e-10) {
  uniroot(f, interval = c(a, b), tol = tol)$root
}

# Plot helper
plot_solver_view <- function(f, z_search, roots = NULL, sat_intervals = NULL,
                             title = "Inequality region: f(z) < 0") {
  zmin <- z_search[1]; zmax <- z_search[2]
  z_seq <- seq(zmin, zmax, length.out = 2000)
  vals  <- vapply(z_seq, f, numeric(1))
  plot(z_seq, vals, type = "l", lwd = 2, col = "steelblue",
       xlab = "z", ylab = "f(z)",
       main = title)
  abline(h = 0, col = "gray50", lty = 2)
  if (!is.null(roots) && length(roots) > 0) {
    abline(v = roots, col = "tomato", lwd = 2, lty = 3)
  }
  if (!is.null(sat_intervals) && nrow(sat_intervals) > 0) {
    yr <- range(vals, 0)
    for (i in seq_len(nrow(sat_intervals))) {
      rect(sat_intervals[i, 1], yr[1], sat_intervals[i, 2], yr[2],
           col = rgb(0.1, 0.7, 0.2, 0.15), border = NA)
    }
    legend("topright", bty = "n",
           legend = c("f(z)", "roots", "f(z) < 0"),
           col = c("steelblue", "tomato", rgb(0.1,0.7,0.2,0.15)),
           lwd = c(2, 2, NA), lty = c(1, 3, NA), pch = c(NA, NA, 15))
  }
}

# ---------- Main solver ----------
ALT_Solver <- function(Ts, A, month, p,
                       k, d,b, #change based on peatland type of site
                       z_search = c(0, 200),   # choose a physically plausible range
                       grid_ppp = 25,          # grid points per period (>= 20 recommended)
                       overresolve = 1.2,      # multiplier to densify the grid
                       tol = 1e-10,
                       verbose = TRUE,
                       plot_check = TRUE) {
  stopifnot(length(z_search) == 2, z_search[1] < z_search[2])
  
  # Define f(z)
  phase0 <- (pi * month / 6) + p   # constant portion of phase
  f <- function(z) {
    # guard against overflow with safe_exp
    term1 <- Ts * safe_exp(-k * z)
    term2 <- (A / b) * safe_exp(-z / d) * sin(phase0 - z / d)
    term1 - term2 - 273.15
  }
  
  zmin <- z_search[1]; zmax <- z_search[2]
  
  # Oscillation period in z due to the sine term: period_z = 2*pi*d
  period_z <- 2 * pi * d
  if (verbose) message(sprintf("Period in z ≈ %.6g (2πd).", period_z))
  
  # Choose grid size to properly resolve oscillations:
  # grid spacing ~ period_z / grid_ppp
  L <- zmax - zmin
  base_n <- max(2000L, ceiling(L / (period_z / grid_ppp)))
  n_grid <- as.integer(ceiling(base_n * overresolve))
  if (verbose) message(sprintf("Using n_grid = %d (~%.3g points per period).",
                               n_grid, n_grid * (period_z / L)))
  
  # Step 1: bracket all sign changes
  br <- bracket_sign_changes(f, zmin, zmax, n_grid = n_grid)
  intervals <- br$intervals
  
  # If none found, check if entire range satisfies or violates
  if (length(intervals) == 0) {
    f_left  <- f(zmin)
    f_right <- f(zmax)
    if (verbose) message(sprintf("No sign change detected. f(zmin)=%.6g, f(zmax)=%.6g", f_left, f_right))
    if (f_left < 0 && f_right < 0) {
      if (verbose) message("Inequality holds over the entire search interval.")
      if (plot_check) plot_solver_view(f, z_search, roots = NULL,
                                       sat_intervals = matrix(z_search, ncol = 2, byrow = TRUE),
                                       title = "f(z) < 0 across entire range")
      return(list(intervals = matrix(z_search, ncol = 2, byrow = TRUE),
                  roots = numeric(0),
                  grid = list(z = br$z_grid, f = br$f_vals)))
    } else {
      if (verbose) message("Inequality not satisfied on the search interval (with current grid).")
      if (plot_check) plot_solver_view(f, z_search, roots = NULL, sat_intervals = NULL,
                                       title = "No sign change detected")
      return(list(intervals = matrix(numeric(0), ncol = 2),
                  roots = numeric(0),
                  grid = list(z = br$z_grid, f = br$f_vals)))
    }
  }
  
  # Step 2: refine every root with uniroot
  roots <- vapply(intervals, function(iv) refine_root(f, iv[1], iv[2], tol = tol), numeric(1))
  roots <- sort(unique(roots))
  
  # Step 3: determine sub-intervals where f(z) < 0
  edges <- c(zmin, roots, zmax)
  sat <- list()
  for (i in seq_len(length(edges) - 1L)) {
    a <- edges[i]; b_ <- edges[i + 1L]
    mid <- 0.5 * (a + b_)
    val <- f(mid)
    if (val < 0) {
      sat[[length(sat) + 1L]] <- c(a, b_)
    }
  }
  
  if (length(sat) == 0) {
    if (verbose) message("No sub-intervals where f(z) < 0 (with current grid).")
    if (plot_check) plot_solver_view(f, z_search, roots = roots, sat_intervals = NULL)
    return(list(intervals = matrix(numeric(0), ncol = 2),
                roots = roots,
                grid = list(z = br$z_grid, f = br$f_vals)))
  }
  
  intervals_mat <- do.call(rbind, sat)
  
  if (verbose) {
    message(sprintf("Found %d root(s) and %d interval(s) where f(z) < 0.",
                    length(roots), nrow(intervals_mat)))
    apply(intervals_mat, 1, function(r)
      message(sprintf("  z in [%.6g, %.6g]", r[1], r[2])))
  }
  
  if (plot_check) {
    plot_solver_view(f, z_search, roots = roots, sat_intervals = intervals_mat)
  }
  
  list(intervals = intervals_mat,
       roots = roots,
       grid = list(z = br$z_grid, f = br$f_vals),
       meta = list(period_z = period_z, n_grid = n_grid))
}
