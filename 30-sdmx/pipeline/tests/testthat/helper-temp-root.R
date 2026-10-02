# pipeline/tests/testthat/helper-temp-root.R
#
# testthat auto-sources every helper-*.R file before running any test file,
# so find_root(), make_temp_root() and edit_csv() are available to every
# test without an explicit source() call.

#' Find the repo root.
#'
#' Walks up from the working directory to the first ancestor that holds a
#' `pipeline` directory.
#'
#' @return The repo root path.
find_root <- function() {
  dir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  repeat {
    if (dir.exists(file.path(dir, "pipeline"))) {
      return(dir)
    }
    parent <- dirname(dir)
    if (identical(parent, dir)) {
      stop("find_root: could not locate a repo root (no 'pipeline' directory found)", call. = FALSE)
    }
    dir <- parent
  }
}

# find_root() only needs base R, so it can run before pipeline/R/io.R is
# sourced. make_temp_root() and edit_csv() below need read_std_csv() and
# write_std_csv().
source(file.path(find_root(), "pipeline", "R", "io.R"))

# The validator modules' shared findings helpers (.vc_finding, .vc_bind, ...),
# which every test that sources a validate_*.R module on its own needs.
source(file.path(find_root(), "pipeline", "R", "validate_common.R"))

#' Copy an existing root's top-level folders into a fresh temp directory.
#'
#' @param root Source repo root.
#' @param include Which top-level folders to copy, if present.
#' @return The new temp directory's path.
make_temp_root <- function(root, include = c("metadata", "content", "geo", "assets", "data")) {
  tmp <- tempfile(pattern = "afw360_root_")
  dir.create(tmp, recursive = TRUE)
  for (nm in include) {
    src <- file.path(root, nm)
    if (dir.exists(src)) {
      file.copy(src, tmp, recursive = TRUE)
    }
  }
  tmp
}

#' Read a CSV, transform it, and write it back through the standard I/O
#' helpers.
#'
#' @param path Path to a standard CSV.
#' @param fn A function taking and returning a tibble.
#' @return The edited tibble, invisibly.
edit_csv <- function(path, fn) {
  df <- read_std_csv(path)
  df <- fn(df)
  write_std_csv(df, path)
  invisible(df)
}
