# pipeline/R/validate_structure.R
#
# WP11 validator module STRUCT: data file structure checks (header shape,
# empty key cells, duplicate keys). Depends on pipeline/R/io.R, constants.R
# (KEY_COLUMNS) and ctx.R (build_ctx()'s ctx$data / ctx$meta). Each vc_*
# function takes the shared ctx and returns a tibble with columns
# check_id, severity, file, row_key, message (zero rows means pass).
#
# A data file whose header does not match the DSD is skipped by every check
# here except STRUCT.HEADER itself, so a header problem is reported exactly
# once (STRUCT.HEADER.md gap: named columns would otherwise carry the wrong
# values and cascade into unrelated findings).

#' An empty findings tibble (the shared zero-row shape).
.vc_empty <- function() {
  tibble::tibble(
    check_id = character(0),
    severity = character(0),
    file = character(0),
    row_key = character(0),
    message = character(0)
  )
}

#' One findings row.
.vc_finding <- function(check_id, severity, file, row_key, message) {
  tibble::tibble(
    check_id = check_id,
    severity = severity,
    file = file,
    row_key = row_key,
    message = message
  )
}

#' Bind a list of findings tibbles, or return the empty shape.
.vc_bind <- function(out) {
  if (length(out) == 0) return(.vc_empty())
  dplyr::bind_rows(out)
}

#' The data file's path relative to the root, forward slashes.
.struct_rel_file <- function(key) {
  paste0("data/", key, ".csv")
}

#' The DSD's `id` column, ordered by `position`.
.struct_dsd_header <- function(ctx) {
  dsd <- ctx$meta$DSD_AFW360_HH
  dsd <- dsd[order(as.integer(dsd$position)), ]
  dsd$id
}

#' STRUCT.HEADER: the header equals the DSD's `id` column, same names/order.
vc_struct_header <- function(ctx) {
  out <- list()
  expected <- .struct_dsd_header(ctx)
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    actual <- names(df)
    if (!identical(actual, expected)) {
      out[[length(out) + 1]] <- .vc_finding(
        "STRUCT.HEADER", "ERROR", .struct_rel_file(key), "",
        paste0(
          "header does not match the DSD: expected [", paste(expected, collapse = ", "),
          "], found [", paste(actual, collapse = ", "), "]"
        )
      )
    }
  }
  .vc_bind(out)
}

#' STRUCT.EMPTY_KEY: no key cell (of the 18 KEY_COLUMNS) is empty.
vc_struct_empty_key <- function(ctx) {
  out <- list()
  expected <- .struct_dsd_header(ctx)
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (!identical(names(df), expected)) next
    file <- .struct_rel_file(key)
    for (i in seq_len(nrow(df))) {
      vals <- as.character(unlist(df[i, KEY_COLUMNS]))
      empty_cols <- KEY_COLUMNS[is.na(vals) | trimws(vals) == ""]
      if (length(empty_cols) > 0) {
        out[[length(out) + 1]] <- .vc_finding(
          "STRUCT.EMPTY_KEY", "ERROR", file, paste(vals, collapse = " "),
          paste0("empty key cell(s): ", paste(empty_cols, collapse = ", "))
        )
      }
    }
  }
  .vc_bind(out)
}

#' STRUCT.DUPLICATE_KEY: the 18-column key is unique.
vc_struct_duplicate_key <- function(ctx) {
  out <- list()
  expected <- .struct_dsd_header(ctx)
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (!identical(names(df), expected)) next
    if (nrow(df) == 0) next
    file <- .struct_rel_file(key)
    key_vals <- apply(as.matrix(df[KEY_COLUMNS]), 1, paste, collapse = " ")
    dup <- duplicated(key_vals) | duplicated(key_vals, fromLast = TRUE)
    for (rk in unique(key_vals[dup])) {
      out[[length(out) + 1]] <- .vc_finding(
        "STRUCT.DUPLICATE_KEY", "ERROR", file, rk, "duplicate 18-column key"
      )
    }
  }
  .vc_bind(out)
}
