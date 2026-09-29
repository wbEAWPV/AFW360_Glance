# pipeline/R/validate_structure.R
#
# Validator module STRUCT: data file structure checks (header shape, file
# name and its agreement with the rows and the manifest, the DATAFLOW
# constant, empty key cells, duplicate keys). Depends on pipeline/R/io.R
# (dsd_columns(), dsd_key_columns()), constants.R and ctx.R (build_ctx()'s
# ctx$data / ctx$meta and the ctx_*() accessors). Each vc_* function takes
# the shared ctx and returns a tibble with columns check_id, severity,
# file, row_key, message (zero rows means pass).
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

#' One findings row (or several, when the arguments are vectors).
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
  ctx_dsd_columns(ctx)
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

#' STRUCT.FILE_NAME: the file is named
#' `AFW360_HH_<REF_AREA>_<TIME_PERIOD>_<ESTIMATION>.csv`, and every row's
#' REF_AREA, TIME_PERIOD and ESTIMATION equal the name's and the
#' manifest's `ref_area`, `time_period` and `estimation`.
vc_struct_file_name <- function(ctx) {
  out <- list()
  expected <- .struct_dsd_header(ctx)
  cols <- c(ref_area = "REF_AREA", time_period = "TIME_PERIOD", estimation = "ESTIMATION")
  for (key in names(ctx$data)) {
    file <- .struct_rel_file(key)
    parsed <- ctx_parse_file_name(key)
    if (is.null(parsed)) {
      out[[length(out) + 1]] <- .vc_finding(
        "STRUCT.FILE_NAME", "ERROR", file, "",
        paste0(
          "file name '", key, ".csv' does not follow ",
          DATAFLOW_ID, "_<REF_AREA>_<TIME_PERIOD>_<ESTIMATION>.csv"
        )
      )
    }
    df <- ctx$data[[key]]
    if (!identical(names(df), expected) || nrow(df) == 0) next
    man <- ctx$manifests[[key]]
    row_keys <- NULL
    for (k in names(cols)) {
      col <- cols[[k]]
      vals <- as.character(df[[col]])
      targets <- character(0)
      if (!is.null(parsed)) targets <- c(targets, name = unname(parsed[[k]]))
      if (!is.null(man) && k %in% names(man)) targets <- c(targets, manifest = unname(man[[k]]))
      for (src in names(targets)) {
        bad <- which(vals != targets[[src]])
        if (length(bad) == 0) next
        if (is.null(row_keys)) row_keys <- ctx_row_keys(ctx, df)
        out[[length(out) + 1]] <- .vc_finding(
          "STRUCT.FILE_NAME", "ERROR", file, row_keys[bad],
          paste0(
            col, " '", vals[bad], "' differs from the ",
            if (src == "name") "file name's" else "manifest's", " '", targets[[src]], "'"
          )
        )
      }
    }
  }
  .vc_bind(out)
}

#' STRUCT.DATAFLOW: every row's DATAFLOW is the constant `AFW360_HH`.
vc_struct_dataflow <- function(ctx) {
  out <- list()
  expected <- .struct_dsd_header(ctx)
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (!identical(names(df), expected) || nrow(df) == 0) next
    vals <- as.character(df$DATAFLOW)
    bad <- which(vals != DATAFLOW_ID & trimws(vals) != "")
    if (length(bad) == 0) next
    out[[length(out) + 1]] <- .vc_finding(
      "STRUCT.DATAFLOW", "ERROR", .struct_rel_file(key), ctx_row_keys(ctx, df)[bad],
      paste0("DATAFLOW '", vals[bad], "' is not ", DATAFLOW_ID)
    )
  }
  .vc_bind(out)
}

#' STRUCT.EMPTY_KEY: no key cell (of the DSD's key columns) is empty.
vc_struct_empty_key <- function(ctx) {
  out <- list()
  expected <- .struct_dsd_header(ctx)
  key_cols <- ctx_key_columns(ctx)
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (!identical(names(df), expected) || nrow(df) == 0) next
    file <- .struct_rel_file(key)
    m <- as.matrix(df[key_cols])
    empty <- is.na(m) | trimws(m) == ""
    bad <- which(rowSums(empty) > 0)
    if (length(bad) == 0) next
    row_keys <- ctx_row_keys(ctx, df)[bad]
    msgs <- vapply(bad, function(i) {
      paste0("empty key cell(s): ", paste(key_cols[empty[i, ]], collapse = ", "))
    }, character(1))
    out[[length(out) + 1]] <- .vc_finding("STRUCT.EMPTY_KEY", "ERROR", file, row_keys, msgs)
  }
  .vc_bind(out)
}

#' STRUCT.DUPLICATE_KEY: the key (19 columns in DSD 0.2.0) is unique.
vc_struct_duplicate_key <- function(ctx) {
  out <- list()
  expected <- .struct_dsd_header(ctx)
  n_key <- length(ctx_key_columns(ctx))
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (!identical(names(df), expected)) next
    if (nrow(df) == 0) next
    file <- .struct_rel_file(key)
    key_vals <- ctx_row_keys(ctx, df)
    dup <- duplicated(key_vals) | duplicated(key_vals, fromLast = TRUE)
    for (rk in unique(key_vals[dup])) {
      out[[length(out) + 1]] <- .vc_finding(
        "STRUCT.DUPLICATE_KEY", "ERROR", file, rk, paste0("duplicate ", n_key, "-column key")
      )
    }
  }
  .vc_bind(out)
}
