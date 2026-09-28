# pipeline/R/io.R
#
# Shared I/O helpers for the AFW 360 pipeline: reading and writing the
# standard CSV format (COMMON.md section 3), hashing, metadata loading and
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
#' Follows COMMON.md section 3: UTF-8 without a byte-order mark, LF line
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

#' The data file columns, in DSD order.
#'
#' Read from `metadata/structure/DSD_AFW360_HH.csv` (as loaded by
#' [load_metadata()] under the name `DSD_AFW360_HH`), ordered by `position`,
#' so no script hard-codes the column list.
#'
#' @param meta A named list from [load_metadata()].
#' @return A character vector of column ids.
dsd_columns <- function(meta) {
  dsd <- meta$DSD_AFW360_HH
  if (is.null(dsd) || nrow(dsd) == 0) {
    stop("dsd_columns: metadata table DSD_AFW360_HH is missing or empty", call. = FALSE)
  }
  pos <- suppressWarnings(as.integer(dsd$position))
  if (anyNA(pos) || anyDuplicated(pos) > 0) {
    stop("dsd_columns: DSD_AFW360_HH.position must be unique integers", call. = FALSE)
  }
  dsd$id[order(pos)]
}

#' The key columns of the data file, in DSD order.
#'
#' The key is every DSD column whose `role` is `constant`, `breakdown`,
#' `reference` or `qualifier` (in DSD 0.2.0, the 19 columns `DATAFLOW`
#' through `MEASURE_QUAL_5`); attributes and the measure are not part of it.
#'
#' @param meta A named list from [load_metadata()].
#' @return A character vector of column ids.
dsd_key_columns <- function(meta) {
  dsd <- meta$DSD_AFW360_HH
  cols <- dsd_columns(meta)
  role_of <- stats::setNames(dsd$role, dsd$id)
  cols[role_of[cols] %in% c("constant", "breakdown", "reference", "qualifier")]
}
