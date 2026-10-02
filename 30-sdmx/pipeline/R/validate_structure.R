# pipeline/R/validate_structure.R
#
# Validator module STRUCT: data file structure checks for the SDMX-CSV 2.1
# layout (plan section 2.3): the header (the three fixed columns STRUCTURE,
# STRUCTURE_ID, ACTION followed by the DSD components), the fixed columns'
# values, the file name and its agreement with the rows and the manifest,
# empty and duplicate keys (the DSD key, 19 columns in DSD 0.3.0), and the
# one-value-per-partial-key rule of the attributes attached to dimensions
# (STRUCT.ATTR_LEVEL). Depends on pipeline/R/io.R (dsd_columns(),
# dsd_key_columns()), constants.R (SDMX_CSV_FIXED, ACTION_PUBLISHED,
# structure_id()) and ctx.R (build_ctx()'s ctx$data / ctx$meta /
# ctx$version and the ctx_*() accessors). Each vc_* function takes the
# shared ctx and returns a tibble with columns check_id, severity, file,
# row_key, message (zero rows means pass).
#
# A data file whose header does not match is skipped by every check here
# except STRUCT.HEADER itself, so a header problem is reported exactly once
# (named columns would otherwise carry the wrong values and cascade into
# unrelated findings).

#' The data file's path relative to the root, forward slashes.
.struct_rel_file <- function(key) {
  paste0("data/", key, ".csv")
}

#' The expected header: SDMX_CSV_FIXED then the DSD components in order.
.struct_dsd_header <- function(ctx) {
  ctx_data_columns(ctx)
}

#' The data files whose header is the expected one and which have rows.
.struct_ok_files <- function(ctx) {
  expected <- .struct_dsd_header(ctx)
  keys <- names(ctx$data)
  if (length(keys) == 0) return(character(0))
  keys[vapply(keys, function(k) {
    df <- ctx$data[[k]]
    identical(names(df), expected) && nrow(df) > 0
  }, logical(1))]
}

#' STRUCT.HEADER: the header equals STRUCTURE, STRUCTURE_ID, ACTION followed
#' by the DSD components (37 columns in DSD 0.3.0), same names and order.
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
          "header does not match the SDMX-CSV 2.1 layout: expected [", paste(expected, collapse = ", "),
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

#' STRUCT.STRUCTURE: every row's STRUCTURE is `dataflow` and its
#' STRUCTURE_ID is `WB.AFW360:AFW360_HH(<VERSION>)`, VERSION being
#' `metadata/VERSION` (the STRUCTURE_ID part is skipped when that file is
#' missing).
vc_struct_structure <- function(ctx) {
  out <- list()
  expected_id <- if (is.na(ctx$version)) NA_character_ else structure_id(ctx$version)
  for (key in .struct_ok_files(ctx)) {
    df <- ctx$data[[key]]
    file <- .struct_rel_file(key)
    row_keys <- NULL
    st <- as.character(df$STRUCTURE)
    bad <- which(is.na(st) | st != "dataflow")
    if (length(bad) > 0) {
      row_keys <- ctx_row_keys(ctx, df)
      out[[length(out) + 1]] <- .vc_finding(
        "STRUCT.STRUCTURE", "ERROR", file, row_keys[bad],
        paste0("STRUCTURE '", st[bad], "' is not dataflow")
      )
    }
    if (!is.na(expected_id)) {
      sid <- as.character(df$STRUCTURE_ID)
      bad <- which(is.na(sid) | sid != expected_id)
      if (length(bad) > 0) {
        if (is.null(row_keys)) row_keys <- ctx_row_keys(ctx, df)
        out[[length(out) + 1]] <- .vc_finding(
          "STRUCT.STRUCTURE", "ERROR", file, row_keys[bad],
          paste0("STRUCTURE_ID '", sid[bad], "' is not ", expected_id, " (metadata/VERSION)")
        )
      }
    }
  }
  .vc_bind(out)
}

#' STRUCT.ACTION: every row's ACTION is `R` (replace; D38). `I` and `A` are
#' deprecated in SDMX-CSV 2.1 and the published files carry no `D` rows.
vc_struct_action <- function(ctx) {
  out <- list()
  for (key in .struct_ok_files(ctx)) {
    df <- ctx$data[[key]]
    act <- as.character(df$ACTION)
    bad <- which(is.na(act) | act != ACTION_PUBLISHED)
    if (length(bad) == 0) next
    out[[length(out) + 1]] <- .vc_finding(
      "STRUCT.ACTION", "ERROR", .struct_rel_file(key), ctx_row_keys(ctx, df)[bad],
      paste0("ACTION '", act[bad], "' is not ", ACTION_PUBLISHED)
    )
  }
  .vc_bind(out)
}

#' STRUCT.EMPTY_KEY: no key cell (of the DSD's key columns) is empty.
vc_struct_empty_key <- function(ctx) {
  out <- list()
  key_cols <- ctx_key_columns(ctx)
  for (key in .struct_ok_files(ctx)) {
    df <- ctx$data[[key]]
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

#' STRUCT.DUPLICATE_KEY: the key (19 columns in DSD 0.3.0) is unique.
vc_struct_duplicate_key <- function(ctx) {
  out <- list()
  n_key <- length(ctx_key_columns(ctx))
  for (key in .struct_ok_files(ctx)) {
    df <- ctx$data[[key]]
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

#' The attributes attached to dimensions: a named list, attribute id to the
#' dimension ids of its DSD `relationship` (attributes whose relationship
#' is `observation` or empty are left out).
.struct_partial_key_attributes <- function(ctx) {
  dsd <- ctx$meta$DSD_AFW360_HH
  if (is.null(dsd) || !all(c("id", "component", "relationship") %in% names(dsd))) return(list())
  att <- dsd[dsd$component == "attribute", , drop = FALSE]
  out <- list()
  for (i in seq_len(nrow(att))) {
    rel <- trimws(att$relationship[i])
    if (is.na(rel) || rel == "" || rel == "observation") next
    out[[att$id[i]]] <- strsplit(rel, "[[:space:]]+")[[1]]
  }
  out
}

#' STRUCT.ATTR_LEVEL: an attribute attached to a partial key (SERIES_ID per
#' INDICATOR and the ten breakdown and qualifier dimensions, UNIT_MEASURE
#' per REF_AREA and INDICATOR, as the DSD's `relationship` says) carries
#' exactly one value per partial key across all data files. One ERROR per
#' group with more than one distinct value; `file` is the first file (in
#' name order) holding the group, `row_key` is the attribute id followed by
#' the group's dimension values.
vc_struct_attr_level <- function(ctx) {
  out <- list()
  attrs <- .struct_partial_key_attributes(ctx)
  keys <- sort(.struct_ok_files(ctx), method = "radix")
  if (length(attrs) == 0 || length(keys) == 0) return(.vc_bind(out))
  for (a in names(attrs)) {
    dims <- attrs[[a]]
    parts <- lapply(keys, function(k) {
      df <- ctx$data[[k]]
      if (!all(c(dims, a) %in% names(df))) return(NULL)
      data.frame(
        group = do.call(paste, c(lapply(df[dims], as.character), sep = " ")),
        value = as.character(df[[a]]),
        file = .struct_rel_file(k),
        stringsAsFactors = FALSE
      )
    })
    all_rows <- do.call(rbind, parts[!vapply(parts, is.null, logical(1))])
    if (is.null(all_rows) || nrow(all_rows) == 0) next
    all_rows$value[is.na(all_rows$value)] <- ""
    uniq <- unique(all_rows[c("group", "value")])
    n_val <- table(uniq$group)
    bad_groups <- sort(names(n_val)[n_val > 1], method = "radix")
    for (g in bad_groups) {
      sub <- all_rows[all_rows$group == g, , drop = FALSE]
      vals <- sort(unique(sub$value), method = "radix")
      files <- sort(unique(sub$file), method = "radix")
      out[[length(out) + 1]] <- .vc_finding(
        "STRUCT.ATTR_LEVEL", "ERROR", files[1], paste(a, g),
        paste0(
          a, " has ", length(vals), " values [", paste(vals, collapse = ", "),
          "] for the partial key ", paste(dims, collapse = " "), " = ", g,
          " across ", paste(files, collapse = ", "), "; it must have exactly one"
        )
      )
    }
  }
  .vc_bind(out)
}
