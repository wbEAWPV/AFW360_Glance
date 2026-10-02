# 20-excel-sdmx-csv/tests/testthat/helper-temp-root.R
#
# testthat auto-sources every helper-*.R file before running any test file,
# so find_root(), make_temp_root(), copy_stage_code() and edit_csv() are
# available to every test without an explicit source() call.

#' Find the stage folder (20-excel-sdmx-csv/).
#'
#' Walks up from the working directory to the first ancestor that holds
#' `R/paths.R` and `plans/`.
#'
#' @return The stage folder's path.
find_root <- function() {
  dir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  repeat {
    if (file.exists(file.path(dir, "R", "paths.R")) && dir.exists(file.path(dir, "plans"))) {
      return(dir)
    }
    parent <- dirname(dir)
    if (identical(parent, dir)) {
      stop("find_root: could not locate the 20-excel-sdmx-csv stage folder (no R/paths.R)", call. = FALSE)
    }
    dir <- parent
  }
}

source(file.path(find_root(), "R", "paths.R"))
source(stage_path(find_root(), "code", "io.R"))

#' Copy parts of a stage into a fresh temporary stage.
#'
#' The copy is laid out like the repository, so the defaults of R/paths.R
#' resolve inside it: the stage is `<tmp>/20-excel-sdmx-csv/`, the standard
#' and data go to `<tmp>/30-sdmx/data/`, the legacy inputs to
#' `<tmp>/10-legacy-pipeline/data_raw/` and the dashboard files to
#' `<tmp>/10-legacy-pipeline/data_dashboard/`. Each name of `include` is a
#' logical folder (a kind of R/paths.R): `metadata` (which brings `plans`
#' with it, as both lived under metadata/ before the split), `plans`,
#' `data_raw`, `data` (the data files only), `geo`, `content`, `assets`.
#'
#' @param root Source stage folder.
#' @param include Which logical folders to copy, if present.
#' @return The new stage folder's path (`<tmp>/20-excel-sdmx-csv`).
make_temp_root <- function(root, include = c("metadata", "data")) {
  base <- tempfile(pattern = "afw360_root_")
  tmp <- file.path(base, "20-excel-sdmx-csv")
  dir.create(tmp, recursive = TRUE)
  # The destinations, pinned inside the copy even when an AFW360_*_DIR
  # environment variable moves a folder of the real stage.
  tp <- stage_paths(tmp, list(
    data_raw = file.path(base, "10-legacy-pipeline", "data_raw"),
    sdmx_stage = file.path(base, "30-sdmx"),
    dashboard = file.path(base, "10-legacy-pipeline", "data_dashboard")
  ))
  if ("metadata" %in% include) include <- union(include, "plans")
  for (kind in include) {
    src <- stage_dir(root, kind)
    if (!dir.exists(src)) next
    dest <- stage_dir(tp, kind)
    dir.create(dest, recursive = TRUE, showWarnings = FALSE)
    if (identical(kind, "data")) {
      fs <- list.files(src, full.names = TRUE)
      fs <- fs[!dir.exists(fs)]
      file.copy(fs, dest)
    } else {
      file.copy(list.files(src, full.names = TRUE), dest, recursive = TRUE)
    }
  }
  tmp
}

#' Copy the stage's code (the scripts and R/) into a temporary stage, so a
#' test can run a script of the copy with `--root` the copy.
copy_stage_code <- function(root, tmp) {
  file.copy(Sys.glob(file.path(root, "*.R")), tmp)
  file.copy(stage_dir(root, "code"), tmp, recursive = TRUE)
  invisible(tmp)
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
