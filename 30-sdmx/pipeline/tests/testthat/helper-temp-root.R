# 30-sdmx/pipeline/tests/testthat/helper-temp-root.R
#
# testthat auto-sources every helper-*.R file before running any test file,
# so find_root(), make_temp_root() and edit_csv() are available to every
# test without an explicit source() call.

#' Find the stage folder (30-sdmx/).
#'
#' Walks up from the working directory to the first ancestor that holds
#' `pipeline/R/paths.R`.
#'
#' @return The stage folder's path.
find_root <- function() {
  dir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  repeat {
    if (file.exists(file.path(dir, "pipeline", "R", "paths.R"))) {
      return(dir)
    }
    parent <- dirname(dir)
    if (identical(parent, dir)) {
      stop("find_root: could not locate the 30-sdmx stage folder (no pipeline/R/paths.R found)", call. = FALSE)
    }
    dir <- parent
  }
}

# find_root() only needs base R, so it can run before pipeline/R/paths.R and
# io.R are sourced. make_temp_root() and edit_csv() below need them.
source(file.path(find_root(), "pipeline", "R", "paths.R"))
source(stage_path(find_root(), "code", "io.R"))

# The validator modules' shared findings helpers (.vc_finding, .vc_bind, ...),
# which every test that sources a validate_*.R module on its own needs.
source(stage_path(find_root(), "code", "validate_common.R"))

#' Copy parts of a stage into a fresh temporary stage.
#'
#' The copy is laid out like the repository, so the defaults of
#' pipeline/R/paths.R resolve inside it: the stage is `<tmp>/30-sdmx/`, the
#' dashboard content and assets go to `<tmp>/10-legacy-pipeline/data_dashboard/`,
#' the legacy plans to `<tmp>/20-excel-sdmx-csv/plans/` and `.docs` to
#' `<tmp>/.docs/`. Each name of `include` is a logical folder (a kind of
#' paths.R): `metadata` (which brings `plans` with it, as both lived under
#' metadata/ before the split), `plans`, `content`, `geo`, `assets`, `data`
#' (the data files only, not the metadata/ and geo/ under it), `sdmx` (the
#' output folder), `.docs` and `pipeline` (the code).
#'
#' @param root Source stage folder.
#' @param include Which logical folders to copy, if present.
#' @return The new stage folder's path (`<tmp>/30-sdmx`).
make_temp_root <- function(root, include = c("metadata", "content", "geo", "assets", "data")) {
  base <- tempfile(pattern = "afw360_root_")
  tmp <- file.path(base, "30-sdmx")
  dir.create(tmp, recursive = TRUE)
  # The destinations, pinned inside the copy even when an AFW360_*_DIR
  # environment variable moves a folder of the real stage.
  tp <- stage_paths(tmp, list(
    dashboard = file.path(base, "10-legacy-pipeline", "data_dashboard"),
    plans = file.path(base, "20-excel-sdmx-csv", "plans"),
    data_raw = file.path(base, "10-legacy-pipeline", "data_raw")
  ))
  if ("metadata" %in% include) include <- union(include, "plans")
  for (nm in include) {
    if (identical(nm, "pipeline")) {
      file.copy(file.path(root, "pipeline"), tmp, recursive = TRUE)
      next
    }
    kind <- if (identical(nm, ".docs")) "docs" else nm
    src <- stage_dir(root, kind)
    if (!dir.exists(src)) next
    dest <- stage_dir(tp, kind)
    dir.create(dest, recursive = TRUE, showWarnings = FALSE)
    if (identical(kind, "data")) {
      fs <- list.files(src, full.names = TRUE)
      fs <- fs[!dir.exists(fs)]
      file.copy(fs, dest)
    } else {
      file.copy(list.files(src, full.names = TRUE, all.files = FALSE), dest, recursive = TRUE)
    }
  }
  tmp
}

#' Skip the current test when the legacy plans are not loaded.
#'
#' TAB_PLAN.csv and LEGACY_*.csv live in 20-excel-sdmx-csv/plans/; the tests
#' that build required rows need them, so they are skipped when this stage
#' runs without the Excel stage next to it (or with AFW360_PLANS_DIR pointing
#' elsewhere).
#'
#' @param x A stage folder, or a `meta` list from [load_metadata()].
skip_without_plans <- function(x = find_root()) {
  has <- if (is.list(x) && !inherits(x, "stage_paths")) {
    !is.null(x$TAB_PLAN)
  } else {
    file.exists(stage_path(x, "plans", "TAB_PLAN.csv"))
  }
  testthat::skip_if_not(has, "the legacy plans (20-excel-sdmx-csv/plans/) are not present")
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
