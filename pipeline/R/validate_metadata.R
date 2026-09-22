# pipeline/R/validate_metadata.R
#
# WP11 validator module META: checks of the metadata and content CSVs
# themselves (header shape against metadata/structure/COLUMNS.csv, required
# columns, code syntax, code uniqueness, cross-file references, TBD
# tracking and slot_order ties). Depends on pipeline/R/io.R, constants.R,
# codes.R (is_valid_code(), TBD) and ctx.R. ctx$meta is a named list of
# tibbles keyed by file stem (load_metadata()); this module rebuilds the
# stem -> relative-path map itself because build_ctx() does not carry it.

#' stem -> "metadata/.../FILE.csv" or "content/.../FILE.csv", forward
#' slashes, for every CSV under `<root>/metadata` and `<root>/content`.
.meta_all_files_rel <- function(root) {
  out <- character(0)
  for (d in c("metadata", "content")) {
    full_d <- file.path(root, d)
    if (!dir.exists(full_d)) next
    fs <- list.files(full_d, pattern = "\\.csv$", recursive = TRUE, full.names = FALSE)
    if (length(fs) == 0) next
    rels <- gsub("\\\\", "/", file.path(d, fs))
    names(rels) <- tools::file_path_sans_ext(basename(fs))
    out <- c(out, rels)
  }
  out
}

#' The column(s) that identify a row, per file stem; falls back to "code"
#' when present, else the first column.
.META_KEY_MAP <- list(
  SERIES_PLAN = "series_id",
  LEGACY_LABELS = c("legacy_label", "sheet"),
  LEGACY_COLUMNS = c("ref_area", "sheet", "column"),
  LEGACY_OVERRIDES = c("ref_area", "sheet", "column", "legacy_label"),
  TAB_PLAN = c("cut_id", "ref_area"),
  FIGURES = "figure_id",
  GEO_SOURCES = "source_id",
  SURVEYS = "survey_id",
  TEXT = c("slot", "ref_area", "time_period", "order"),
  COLUMNS = c("file", "column"),
  DSD_AFW360_HH = "id",
  CL_GEO_SCHEME = c("ref_area", "code")
)

.meta_key_cols <- function(stem, df) {
  cols <- .META_KEY_MAP[[stem]]
  if (!is.null(cols)) {
    cols <- cols[cols %in% names(df)]
    if (length(cols) > 0) return(cols)
  }
  if ("code" %in% names(df)) return("code")
  names(df)[1]
}

.meta_row_key <- function(stem, df, i) {
  cols <- .meta_key_cols(stem, df)
  vals <- as.character(unlist(df[i, cols]))
  paste(paste0(cols, "=", vals), collapse = " ")
}

#' META.HEADER: each file listed in COLUMNS.csv that exists has exactly
#' those columns, in order.
vc_meta_header <- function(ctx) {
  out <- list()
  cols <- ctx$meta$COLUMNS
  if (is.null(cols)) return(.vc_empty())
  file_map <- .meta_all_files_rel(ctx$root)
  for (f in unique(cols$file)) {
    stem <- tools::file_path_sans_ext(f)
    df <- ctx$meta[[stem]]
    if (is.null(df)) next
    spec <- cols[cols$file == f, ]
    spec <- spec[order(as.integer(spec$position)), ]
    expected <- spec$column
    actual <- names(df)
    if (!identical(actual, expected)) {
      out[[length(out) + 1]] <- .vc_finding(
        "META.HEADER", "ERROR", unname(file_map[stem]), "",
        paste0(
          "header does not match COLUMNS.csv: expected [", paste(expected, collapse = ", "),
          "], found [", paste(actual, collapse = ", "), "]"
        )
      )
    }
  }
  .vc_bind(out)
}

#' META.REQUIRED: every R column is filled.
vc_meta_required <- function(ctx) {
  out <- list()
  cols <- ctx$meta$COLUMNS
  if (is.null(cols)) return(.vc_empty())
  file_map <- .meta_all_files_rel(ctx$root)
  for (f in unique(cols$file)) {
    stem <- tools::file_path_sans_ext(f)
    df <- ctx$meta[[stem]]
    if (is.null(df)) next
    spec <- cols[cols$file == f, ]
    req_cols <- spec$column[spec$status == "R"]
    req_cols <- req_cols[req_cols %in% names(df)]
    if (length(req_cols) == 0 || nrow(df) == 0) next
    rel <- unname(file_map[stem])
    for (i in seq_len(nrow(df))) {
      vals <- as.character(unlist(df[i, req_cols]))
      missing_cols <- req_cols[is.na(vals) | trimws(vals) == ""]
      if (length(missing_cols) > 0) {
        out[[length(out) + 1]] <- .vc_finding(
          "META.REQUIRED", "ERROR", rel, .meta_row_key(stem, df, i),
          paste0("required column(s) empty: ", paste(missing_cols, collapse = ", "))
        )
      }
    }
  }
  .vc_bind(out)
}

#' META.CODE_SYNTAX: the code column of every CL_* file passes the code
#' pattern, and no code starts with `_T` or `_Z` (is_valid_code() already
#' enforces both).
vc_meta_code_syntax <- function(ctx) {
  out <- list()
  file_map <- .meta_all_files_rel(ctx$root)
  for (stem in names(ctx$meta)) {
    if (!grepl("^CL_", stem)) next
    df <- ctx$meta[[stem]]
    if (!("code" %in% names(df)) || nrow(df) == 0) next
    rel <- unname(file_map[stem])
    bad_idx <- which(!is_valid_code(df$code))
    for (i in bad_idx) {
      out[[length(out) + 1]] <- .vc_finding(
        "META.CODE_SYNTAX", "ERROR", rel, .meta_row_key(stem, df, i),
        paste0("code '", df$code[i], "' fails the code pattern or starts with a reserved sentinel")
      )
    }
  }
  .vc_bind(out)
}

#' META.CODE_UNIQUE: codes are unique within a file. CL_GEO_SCHEME is
#' unique on ref_area plus code.
vc_meta_code_unique <- function(ctx) {
  out <- list()
  file_map <- .meta_all_files_rel(ctx$root)
  for (stem in names(ctx$meta)) {
    if (!grepl("^CL_", stem)) next
    df <- ctx$meta[[stem]]
    if (!("code" %in% names(df)) || nrow(df) == 0) next
    rel <- unname(file_map[stem])
    if (stem == "CL_GEO_SCHEME" && "ref_area" %in% names(df)) {
      key_cols <- c("ref_area", "code")
      keys <- paste(df$ref_area, df$code)
    } else {
      key_cols <- "code"
      keys <- df$code
    }
    dup <- duplicated(keys) | duplicated(keys, fromLast = TRUE)
    seen <- character(0)
    for (i in which(dup)) {
      rk <- paste(paste0(key_cols, "=", as.character(unlist(df[i, key_cols]))), collapse = " ")
      if (rk %in% seen) next
      seen <- c(seen, rk)
      out[[length(out) + 1]] <- .vc_finding(
        "META.CODE_UNIQUE", "ERROR", rel, rk, "duplicate code within file"
      )
    }
  }
  .vc_bind(out)
}

#' META.REFERENCE: every reference listed on the card resolves.
vc_meta_reference <- function(ctx) {
  out <- list()
  file_map <- .meta_all_files_rel(ctx$root)
  meta <- ctx$meta

  check_field <- function(src_stem, src_col, tgt_stem, tgt_col, multi = FALSE, skip = c("_T", "_Z")) {
    df <- meta[[src_stem]]
    tgt <- meta[[tgt_stem]]
    if (is.null(df) || is.null(tgt)) return(invisible())
    if (!(src_col %in% names(df)) || !(tgt_col %in% names(tgt))) return(invisible())
    if (nrow(df) == 0) return(invisible())
    target_codes <- tgt[[tgt_col]]
    rel <- unname(file_map[src_stem])
    for (i in seq_len(nrow(df))) {
      val <- trimws(df[[src_col]][i])
      if (is.na(val) || val == "") next
      toks <- if (multi) strsplit(val, "\\s+")[[1]] else val
      toks <- setdiff(toks, skip)
      bad <- toks[!(toks %in% target_codes)]
      if (length(bad) > 0) {
        out[[length(out) + 1]] <<- .vc_finding(
          "META.REFERENCE", "ERROR", rel, .meta_row_key(src_stem, df, i),
          paste0(
            src_col, " references unknown ", tgt_stem, ".", tgt_col, ": ",
            paste(bad, collapse = ", ")
          )
        )
      }
    }
  }

  # Self-references: replaced_by and parent, generic over every file that
  # has a "code" column.
  for (stem in names(meta)) {
    df <- meta[[stem]]
    if (!("code" %in% names(df))) next
    if ("replaced_by" %in% names(df)) check_field(stem, "replaced_by", stem, "code")
    if ("parent" %in% names(df)) check_field(stem, "parent", stem, "code")
  }

  check_field("CL_COMP_BREAKDOWN", "var_code", "CL_BRK_VAR", "code")
  check_field("CL_QUALIFIER", "var_code", "CL_QUAL_VAR", "code")
  check_field("CL_GEO", "source_id", "GEO_SOURCES", "source_id")
  check_field("CL_GEO", "scheme", "CL_GEO_SCHEME", "code")
  check_field("CL_GEO_SCHEME", "nests_in", "CL_GEO_SCHEME", "code")
  check_field("CL_QUAL_VAR", "requires", "CL_QUAL_VAR", "code", multi = TRUE)
  check_field("CL_BRK_VAR", "requires_qual", "CL_QUAL_VAR", "code", multi = TRUE)
  check_field("CL_QUALIFIER", "valid_with", "CL_QUALIFIER", "code", multi = TRUE)
  check_field("CL_INDICATOR", "theme", "CL_THEME", "code")
  check_field("CL_INDICATOR", "stat_unit", "CL_STAT_UNIT", "code")
  check_field("CL_INDICATOR", "statistic", "CL_STATISTIC", "code")
  check_field("CL_INDICATOR", "weight", "CL_WEIGHT", "code")
  check_field("CL_INDICATOR", "unit_measure", "CL_UNIT", "code")
  check_field("SERIES_PLAN", "INDICATOR", "CL_INDICATOR", "code")
  check_field("SERIES_PLAN", "MEASURE_QUALS", "CL_QUALIFIER", "code", multi = TRUE)
  check_field("SERIES_PLAN", "DEFINING_BREAKDOWN", "CL_COMP_BREAKDOWN", "code")
  check_field("LEGACY_LABELS", "series_id", "SERIES_PLAN", "series_id")
  check_field("LEGACY_COLUMNS", "GEO", "CL_GEO", "code")
  check_field("LEGACY_COLUMNS", "URBANISATION", "CL_URBANISATION", "code")
  check_field("LEGACY_COLUMNS", "COMP_BREAKDOWN", "CL_COMP_BREAKDOWN", "code")
  check_field("LEGACY_COLUMNS", "cut_id", "TAB_PLAN", "cut_id")

  .vc_bind(out)
}

#' META.TBD: `TBD` gives WARN on a DRAFT row, ERROR on any other row.
#' Applies only to files that carry a `status` column.
vc_meta_tbd <- function(ctx) {
  out <- list()
  cols <- ctx$meta$COLUMNS
  if (is.null(cols)) return(.vc_empty())
  file_map <- .meta_all_files_rel(ctx$root)
  for (f in unique(cols$file)) {
    stem <- tools::file_path_sans_ext(f)
    df <- ctx$meta[[stem]]
    if (is.null(df) || !("status" %in% names(df)) || nrow(df) == 0) next
    rel <- unname(file_map[stem])
    check_cols <- names(df)
    for (i in seq_len(nrow(df))) {
      vals <- as.character(unlist(df[i, check_cols]))
      tbd_cols <- check_cols[!is.na(vals) & vals == TBD]
      if (length(tbd_cols) == 0) next
      sev <- if (!is.na(df$status[i]) && df$status[i] == "DRAFT") "WARN" else "ERROR"
      out[[length(out) + 1]] <- .vc_finding(
        "META.TBD", sev, rel, .meta_row_key(stem, df, i),
        paste0("TBD in column(s): ", paste(tbd_cols, collapse = ", "))
      )
    }
  }
  .vc_bind(out)
}

#' META.SLOT_ORDER_TIE: a repeated slot_order gives WARN.
vc_meta_slot_order_tie <- function(ctx) {
  out <- list()
  file_map <- .meta_all_files_rel(ctx$root)
  for (stem in names(ctx$meta)) {
    df <- ctx$meta[[stem]]
    if (!("slot_order" %in% names(df)) || nrow(df) == 0) next
    rel <- unname(file_map[stem])
    dup <- duplicated(df$slot_order) | duplicated(df$slot_order, fromLast = TRUE)
    seen <- character(0)
    for (v in unique(df$slot_order[dup])) {
      if (v %in% seen) next
      seen <- c(seen, v)
      out[[length(out) + 1]] <- .vc_finding(
        "META.SLOT_ORDER_TIE", "WARN", rel, paste0("slot_order=", v), "repeated slot_order"
      )
    }
  }
  .vc_bind(out)
}
