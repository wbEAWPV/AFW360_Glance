# pipeline/R/io.R
#
# Shared I/O helpers for the AFW 360 pipeline: reading and writing the
# standard CSV format (.docs/data-standard.qmd), hashing, metadata loading and
# small command-line argument helpers.

#' Read a standard pipeline CSV.
#'
#' Returns every column as character. Strips a leading UTF-8 byte-order
#' mark, accepts both LF and CRLF line endings, and keeps an empty cell as
#' `""` rather than converting it to `NA`.
#'
#' @param path Path to the CSV file.
#' @return A tibble with every column of type character.
read_std_csv <- function(path) {
  df <- readr::read_csv(
    path,
    col_types = readr::cols(.default = readr::col_character()),
    na = character(0),
    trim_ws = FALSE,
    progress = FALSE,
    show_col_types = FALSE
  )
  df
}

#' Write a standard pipeline CSV.
#'
#' Follows the data standard (.docs/data-standard.qmd): UTF-8 without a byte-order mark, LF line
#' endings (even on Windows), one header row, `NA` written as an empty
#' string, and numeric columns formatted with [fmt_num()] (fixed notation,
#' no scientific notation, at most 10 decimals, no trailing zeros). Parent
#' directories are created as needed.
#'
#' @param df A data frame or tibble.
#' @param path Destination path.
#' @return `path`, invisibly.
write_std_csv <- function(df, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)

  out <- df
  for (nm in names(out)) {
    col <- out[[nm]]
    if (is.numeric(col)) {
      out[[nm]] <- fmt_num(col)
    } else {
      col <- as.character(col)
      col[is.na(col)] <- ""
      out[[nm]] <- col
    }
  }

  readr::write_csv(out, path, na = "", eol = "\n")
  invisible(path)
}

#' Format a number in fixed notation.
#'
#' Never returns scientific notation. Keeps at most 10 decimal places, and
#' trims trailing zeros and a trailing decimal point. `NA` becomes `""`.
#'
#' @param x A numeric vector.
#' @return A character vector.
fmt_num <- function(x) {
  out <- rep(NA_character_, length(x))
  keep <- !is.na(x)
  if (any(keep)) {
    s <- sprintf("%.10f", x[keep])
    s <- sub("0+$", "", s)
    s <- sub("\\.$", "", s)
    s[s == "-0"] <- "0"
    out[keep] <- s
  }
  out[!keep] <- ""
  out
}

#' SHA-256 hash of a file.
#'
#' @param path Path to the file.
#' @return A lower-case hex string.
sha256_file <- function(path) {
  digest::digest(file = path, algo = "sha256")
}

#' Load every metadata and content CSV under a repo root.
#'
#' Reads every `*.csv` found recursively under `<root>/metadata` and
#' `<root>/content` with [read_std_csv()], keyed by file stem (for example
#' `meta$CL_GEO`, `meta$SERIES_PLAN`, `meta$TEXT`). A folder that does not
#' exist is skipped silently.
#'
#' @param root Repo root.
#' @return A named list of tibbles.
load_metadata <- function(root) {
  dirs <- c(file.path(root, "metadata"), file.path(root, "content"))
  dirs <- dirs[dir.exists(dirs)]

  files <- character(0)
  if (length(dirs) > 0) {
    files <- unlist(lapply(
      dirs,
      list.files,
      pattern = "\\.csv$",
      recursive = TRUE,
      full.names = TRUE
    ))
  }

  meta <- list()
  for (f in files) {
    stem <- tools::file_path_sans_ext(basename(f))
    meta[[stem]] <- read_std_csv(f)
  }
  meta
}

#' Join path segments under a root.
#'
#' @param root Repo root.
#' @param ... Additional path segments.
#' @return A path string.
repo_path <- function(root, ...) {
  file.path(root, ...)
}

#' Read the value that follows a command-line flag.
#'
#' @param args A character vector, typically `commandArgs(trailingOnly = TRUE)`.
#' @param flag The flag to look for, e.g. `"--root"`.
#' @param default Value returned when `flag` is absent or has no following value.
#' @return A single string, or `default`.
cli_arg <- function(args, flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) == 0) {
    return(default)
  }
  i <- idx[1]
  if (i >= length(args)) {
    return(default)
  }
  args[i + 1]
}

#' Read every value that follows a repeatable command-line flag.
#'
#' @param args A character vector, typically `commandArgs(trailingOnly = TRUE)`.
#' @param flag The flag to look for, e.g. `"--data"`.
#' @return A character vector, possibly empty.
cli_args <- function(args, flag) {
  idx <- which(args == flag)
  if (length(idx) == 0) {
    return(character(0))
  }
  vals <- character(0)
  for (i in idx) {
    if (i < length(args)) {
      vals <- c(vals, args[i + 1])
    }
  }
  vals
}

#' Whether a command-line flag is present.
#'
#' @param args A character vector, typically `commandArgs(trailingOnly = TRUE)`.
#' @param flag The flag to look for, e.g. `"--verbose"`.
#' @return `TRUE` or `FALSE`.
cli_flag <- function(args, flag) {
  flag %in% args
}

#' The DSD component ids, in data-file order.
#'
#' Read from `metadata/structure/DSD_AFW360_HH.csv` (as loaded by
#' [load_metadata()] under the name `DSD_AFW360_HH`), ordered by `position`,
#' so no script hard-codes the column list. Every row is a component
#' (`component` is `dimension`, `time_dimension`, `measure` or `attribute`;
#' 34 in DSD 0.3.0). The three fixed SDMX-CSV columns (`STRUCTURE`,
#' `STRUCTURE_ID`, `ACTION`) are not DSD components and are not returned.
#'
#' @param meta A named list from [load_metadata()].
#' @return A character vector of component ids.
dsd_columns <- function(meta) {
  dsd <- meta$DSD_AFW360_HH
  if (is.null(dsd) || nrow(dsd) == 0) {
    stop("dsd_columns: metadata table DSD_AFW360_HH is missing or empty", call. = FALSE)
  }
  pos <- suppressWarnings(as.integer(dsd$position))
  if (anyNA(pos) || anyDuplicated(pos) > 0) {
    stop("dsd_columns: DSD_AFW360_HH.position must be unique integers", call. = FALSE)
  }
  if (!"component" %in% names(dsd)) {
    stop("dsd_columns: DSD_AFW360_HH lacks the column `component`", call. = FALSE)
  }
  dsd$id[order(pos)]
}

#' The key columns of the data file, in DSD order.
#'
#' The key is every DSD component whose `component` is `dimension` or
#' `time_dimension` (in DSD 0.3.0, the 18 dimensions `FREQ` through
#' `MEASURE_QUAL_5` plus `TIME_PERIOD`, 19 in all); measures and attributes
#' are not part of it.
#'
#' @param meta A named list from [load_metadata()].
#' @return A character vector of component ids.
dsd_key_columns <- function(meta) {
  dsd <- meta$DSD_AFW360_HH
  cols <- dsd_columns(meta)
  kind_of <- stats::setNames(dsd$component, dsd$id)
  cols[kind_of[cols] %in% c("dimension", "time_dimension")]
}

#' The DSD component ids, in data-file order.
#'
#' The same as [dsd_columns()]: the 34 components of DSD 0.3.0, from `FREQ`
#' to `OBS_COMMENT`, without the three fixed SDMX-CSV columns.
#'
#' @param meta A named list from [load_metadata()].
#' @return A character vector of component ids.
dsd_components <- function(meta) {
  dsd_columns(meta)
}

#' The columns of an SDMX-CSV 2.1 data file, in order.
#'
#' The three fixed columns ([SDMX_CSV_FIXED], from `constants.R`) followed
#' by [dsd_components()]: 37 columns in DSD 0.3.0.
#'
#' @param meta A named list from [load_metadata()].
#' @return A character vector of column names.
data_columns <- function(meta) {
  c(SDMX_CSV_FIXED, dsd_components(meta))
}

#' Write an SDMX-CSV 2.1 data file.
#'
#' Prepends the fixed columns `STRUCTURE = dataflow`,
#' `STRUCTURE_ID = structure_id(version)` and `ACTION` (default
#' [ACTION_PUBLISHED]) to the component columns of `df` (any fixed columns
#' already in `df` are replaced), then writes with [write_std_csv()]: UTF-8
#' without BOM, LF line endings, RFC 4180 quoting, `NA` as an empty cell.
#' A numeric `NaN` and the string `"NaN"` are both written literally as
#' `NaN`. `constants.R` must already be sourced.
#'
#' @param df A data frame with the DSD component columns, in order.
#' @param path Destination path.
#' @param version The metadata version (content of `metadata/VERSION`).
#' @param action The `ACTION` of every row. Default [ACTION_PUBLISHED].
#' @return `path`, invisibly.
write_sdmx_csv <- function(df, path, version, action = ACTION_PUBLISHED) {
  if (missing(version) || length(version) != 1 || is.na(version) || version == "") {
    stop("write_sdmx_csv: `version` must be a single non-empty string", call. = FALSE)
  }
  comp <- as.data.frame(df, stringsAsFactors = FALSE, check.names = FALSE)
  comp <- comp[setdiff(names(comp), SDMX_CSV_FIXED)]
  for (nm in names(comp)) {
    col <- comp[[nm]]
    if (is.numeric(col)) {
      s <- fmt_num(col)
      s[is.nan(col)] <- "NaN"
      comp[[nm]] <- s
    }
  }
  n <- nrow(comp)
  fixed <- data.frame(
    STRUCTURE = rep("dataflow", n),
    STRUCTURE_ID = rep(structure_id(version), n),
    ACTION = rep(action, n),
    stringsAsFactors = FALSE
  )
  out <- cbind(fixed, comp, stringsAsFactors = FALSE)
  write_std_csv(out, path)
}

#' Read an SDMX-CSV 2.1 data file.
#'
#' Reads with [read_std_csv()] (every column character, empty cells as
#' `""`, `NaN` kept as the string `"NaN"`), checks that the first three
#' columns are [SDMX_CSV_FIXED], that every `STRUCTURE` is `dataflow` and
#' every `STRUCTURE_ID` is `structure_id(version)`, and returns the
#' component columns only. `constants.R` must already be sourced.
#'
#' @param path Path to the data file.
#' @param version The expected metadata version (content of
#'   `metadata/VERSION`).
#' @return A tibble of the component columns, every column character.
read_sdmx_csv <- function(path, version) {
  df <- read_std_csv(path)
  nm <- names(df)
  if (length(nm) < 3 || !identical(nm[1:3], SDMX_CSV_FIXED)) {
    stop(
      "read_sdmx_csv: ", basename(path), " does not start with the columns ",
      paste(SDMX_CSV_FIXED, collapse = ","),
      call. = FALSE
    )
  }
  if (any(df$STRUCTURE != "dataflow")) {
    stop("read_sdmx_csv: ", basename(path), " has a STRUCTURE other than 'dataflow'", call. = FALSE)
  }
  expected <- structure_id(version)
  bad <- unique(df$STRUCTURE_ID[df$STRUCTURE_ID != expected])
  if (length(bad) > 0) {
    stop(
      "read_sdmx_csv: ", basename(path), " has STRUCTURE_ID '", bad[1],
      "', expected '", expected, "' (metadata/VERSION)",
      call. = FALSE
    )
  }
  df[setdiff(nm, SDMX_CSV_FIXED)]
}
