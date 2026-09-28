# pipeline/R/validate_coverage.R
#
# Coverage checks (WP12): that a data file holds exactly the rows the plan
# requires, once withheld legacy cells (decision D5) are subtracted, and
# that its manifest is present, complete and agrees with the file and with
# SURVEYS.csv.
#
# Depends on pipeline/R/plan.R for required_rows() (itself needing
# pipeline/R/codes.R and pipeline/R/constants.R), and on `ctx` built by
# build_ctx() (pipeline/R/ctx.R), which needs pipeline/R/io.R. Callers
# source those before this file; this file does not source anything
# itself (.docs/transition.qmd).
#
# Findings format (word for word the same on WP11-WP14): a tibble with
# columns check_id, severity, file, row_key, message. `file` is the path
# to the data file relative to the root, with forward slashes. `row_key`
# is the 18 key-column values joined by one space for a data row, empty
# for a whole-file finding, or `key=<name>` / `survey_id=<value>` for a
# finding about one manifest key or SURVEYS.csv row. More than 20
# findings for one check_id/file pair are capped to the first 20 in
# row_key order, plus one SUMMARY finding (see .vc_apply_cap() below).

# The 18 KEY_COLUMNS, in their contract order (seeds/csv_headers.csv,
# AFW360_HH_<ISO3>_<YEAR>.csv, positions 1-18). required_rows() returns
# these plus series_id and cut_id; the standard data file carries these
# plus OBS_VALUE .. OBS_COMMENT (positions 19-26).
.VC_KEY_COLS <- c(
  "DATAFLOW", "REF_AREA", "GEO", "TIME_PERIOD", "INDICATOR", "SEX", "AGE",
  "URBANISATION", "COMP_BREAKDOWN_1", "COMP_BREAKDOWN_2", "COMP_BREAKDOWN_3",
  "COMP_BREAKDOWN_4", "COMP_BREAKDOWN_5", "MEASURE_QUAL_1", "MEASURE_QUAL_2",
  "MEASURE_QUAL_3", "MEASURE_QUAL_4", "MEASURE_QUAL_5"
)

# The 16 manifest keys (seeds/csv_headers.csv,
# AFW360_HH_<ISO3>_<YEAR>_manifest.csv; WP08.md step 4).
.VC_MANIFEST_KEYS <- c(
  "dataflow", "dsd_version", "metadata_version", "ref_area", "time_period",
  "source_type", "survey_id", "precision", "file_name", "n_rows",
  "producer", "program", "software", "run_timestamp", "status", "notes"
)

#' One manifest value, or `NA` when the key is absent.
#'
#' @param man A named character vector (a `ctx$manifests[[key]]` entry).
#' @param k The key to read.
#' @return A single string, or `NA_character_`.
.vc_manifest_value <- function(man, k) {
  if (is.null(man) || !(k %in% names(man))) {
    return(NA_character_)
  }
  unname(man[[k]])
}

#' Build the findings row_key for each row of a data frame.
#'
#' @param df A data frame holding (a subset of) `cols`.
#' @param cols The key columns to join, in order.
#' @return A character vector, one entry per row of `df`.
.vc_row_key <- function(df, cols) {
  cols <- cols[cols %in% names(df)]
  if (length(cols) == 0 || nrow(df) == 0) {
    return(character(0))
  }
  do.call(paste, c(df[cols], sep = " "))
}

#' The findings `file` value for a data key.
#'
#' @param key A `ctx$data` / `ctx$manifests` list name (the file's stem).
#' @return `"data/<key>.csv"`.
.vc_file_path <- function(key) paste0("data/", key, ".csv")

#' An empty findings frame, with the right columns and types.
.vc_empty <- function() {
  data.frame(
    check_id = character(0), severity = character(0), file = character(0),
    row_key = character(0), message = character(0),
    stringsAsFactors = FALSE
  )
}

#' Cap findings at 20 per check_id/file pair (WP12.md "Findings format").
#'
#' @param findings A findings data frame, any number of rows.
#' @return `findings`, with each check_id/file group cut to its first 20
#'   rows in row_key order plus one SUMMARY row when it had more.
.vc_apply_cap <- function(findings) {
  if (nrow(findings) == 0) {
    return(findings)
  }
  group_key <- paste(findings$check_id, findings$file, sep = "")
  groups <- split(seq_len(nrow(findings)), group_key)
  groups <- groups[order(names(groups), method = "radix")]
  parts <- vector("list", length(groups))
  for (i in seq_along(groups)) {
    grp <- findings[groups[[i]], , drop = FALSE]
    grp <- grp[order(grp$row_key, method = "radix"), , drop = FALSE]
    n <- nrow(grp)
    if (n > 20) {
      kept <- grp[seq_len(20), , drop = FALSE]
      summary_row <- kept[1, , drop = FALSE]
      summary_row$row_key <- ""
      summary_row$message <- sprintf("SUMMARY: %d findings in total, 20 shown", n)
      grp <- rbind(kept, summary_row)
    }
    parts[[i]] <- grp
  }
  result <- do.call(rbind, parts)
  rownames(result) <- NULL
  result
}

#' Bind a list of findings frames into one findings tibble.
#'
#' @param parts A list of data frames (as built by the `vc_*` functions),
#'   possibly empty or with empty members.
#' @return A tibble with zero or more findings, capped (`.vc_apply_cap()`).
.vc_bind <- function(parts) {
  parts <- parts[vapply(parts, function(x) !is.null(x) && nrow(x) > 0, logical(1))]
  if (length(parts) == 0) {
    return(dplyr::as_tibble(.vc_empty()))
  }
  result <- do.call(rbind, parts)
  rownames(result) <- NULL
  dplyr::as_tibble(.vc_apply_cap(result))
}

#' Compute the withheld rows for a country and time period (decision D5).
#'
#' Translates each `action = WITHHOLD` row of `meta$LEGACY_OVERRIDES` into
#' the required rows it removes, via `meta$LEGACY_LABELS` (label ->
#' series_id) and `meta$LEGACY_COLUMNS` (sheet, column -> cut_id and the
#' GEO / URBANISATION / COMP_BREAKDOWN code that selects the one row of
#' that cut). See WP12.md "Withheld cells" for the full rule. Stops with
#' an error when a (label, column) pair matches zero or several rows.
#'
#' @param meta A named list from [load_metadata()], holding at least
#'   `LEGACY_OVERRIDES`, `LEGACY_LABELS`, `LEGACY_COLUMNS`, and everything
#'   [required_rows()] needs.
#' @param ref_area A country code, e.g. `"GNB"`.
#' @param time_period A time period string, e.g. `"2021"`.
#' @return A data frame with the same columns as [required_rows()]
#'   (the 18 key columns plus series_id and cut_id), one row per withheld
#'   required row, deduplicated. Zero rows when nothing is withheld.
withheld_rows <- function(meta, ref_area, time_period) {
  comp_cols <- c(
    "COMP_BREAKDOWN_1", "COMP_BREAKDOWN_2", "COMP_BREAKDOWN_3",
    "COMP_BREAKDOWN_4", "COMP_BREAKDOWN_5"
  )

  req <- required_rows(meta, ref_area, time_period)
  overrides <- meta$LEGACY_OVERRIDES

  if (is.null(overrides) || nrow(overrides) == 0) {
    return(req[0, , drop = FALSE])
  }
  overrides <- overrides[
    overrides$action == "WITHHOLD" & overrides$ref_area == ref_area, ,
    drop = FALSE
  ]
  if (nrow(overrides) == 0) {
    return(req[0, , drop = FALSE])
  }

  labels <- meta$LEGACY_LABELS
  columns <- meta$LEGACY_COLUMNS
  out <- list()

  for (i in seq_len(nrow(overrides))) {
    ov <- overrides[i, ]
    sheets <- if (identical(ov$sheet, "*")) c("National", "ADM 1", "ZAE") else ov$sheet

    for (sheet in sheets) {
      if (identical(ov$legacy_label, "*")) {
        lab_rows <- labels[
          labels$action == "MAP" & (labels$sheet == sheet | labels$sheet == "*"), ,
          drop = FALSE
        ]
      } else {
        lab_rows <- labels[
          labels$legacy_label == ov$legacy_label & labels$action == "MAP" &
            (labels$sheet == sheet | labels$sheet == "*"), ,
          drop = FALSE
        ]
      }
      series_ids <- unique(lab_rows$series_id)
      series_ids <- series_ids[nzchar(series_ids)]

      if (identical(ov$column, "*")) {
        col_rows <- columns[
          columns$ref_area == ov$ref_area & columns$sheet == sheet &
            columns$action == "MAP", ,
          drop = FALSE
        ]
      } else {
        col_rows <- columns[
          columns$ref_area == ov$ref_area & columns$sheet == sheet &
            columns$column == ov$column & columns$action == "MAP", ,
          drop = FALSE
        ]
      }

      for (sid in series_ids) {
        # A series absent from the required-row universe entirely (for
        # example because a test fixture narrowed SERIES_PLAN) is simply
        # not applicable here; only a series that IS required, but whose
        # cut/column match still fails, is a metadata error worth
        # stopping on.
        if (!any(req$series_id == sid)) next

        for (j in seq_len(nrow(col_rows))) {
          colrow <- col_rows[j, ]
          cut_id <- colrow$cut_id
          series_req <- req[req$series_id == sid & req$cut_id == cut_id, , drop = FALSE]

          if (identical(cut_id, "TOTAL")) {
            matched <- series_req
          } else {
            code <- if (nzchar(colrow$GEO)) {
              colrow$GEO
            } else if (nzchar(colrow$URBANISATION)) {
              colrow$URBANISATION
            } else {
              colrow$COMP_BREAKDOWN
            }
            geo_hit <- series_req$GEO == code
            urb_hit <- series_req$URBANISATION == code
            comp_hit <- Reduce(`|`, lapply(comp_cols, function(cc) series_req[[cc]] == code))
            matched <- series_req[geo_hit | urb_hit | comp_hit, , drop = FALSE]
          }

          if (nrow(matched) != 1) {
            stop(sprintf(
              paste(
                "withheld_rows: override ref_area=%s sheet=%s legacy_label=%s",
                "column=%s (series_id=%s, cut_id=%s) matched %d required rows,",
                "expected exactly 1"
              ),
              ov$ref_area, sheet, ov$legacy_label, colrow$column, sid, cut_id, nrow(matched)
            ), call. = FALSE)
          }
          out[[length(out) + 1]] <- matched
        }
      }
    }
  }

  if (length(out) == 0) {
    return(req[0, , drop = FALSE])
  }
  result <- do.call(rbind, out)
  result <- result[!duplicated(result[names(req)]), , drop = FALSE]
  rownames(result) <- NULL
  result
}

#' COVER.MISSING: an expected row is absent from the data file.
#'
#' @param ctx The list from [build_ctx()].
#' @return A findings tibble.
vc_cover_missing <- function(ctx) {
  out <- list()
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    man <- ctx$manifests[[key]]
    ref_area <- .vc_manifest_value(man, "ref_area")
    time_period <- .vc_manifest_value(man, "time_period")
    if (is.na(ref_area) || is.na(time_period) || !nzchar(ref_area) || !nzchar(time_period)) {
      next
    }

    req <- required_rows(ctx$meta, ref_area, time_period)
    if (nrow(req) == 0) next
    withheld <- withheld_rows(ctx$meta, ref_area, time_period)

    expected_key <- .vc_row_key(req, .VC_KEY_COLS)
    withheld_key <- .vc_row_key(withheld, .VC_KEY_COLS)
    expected_key <- setdiff(expected_key, withheld_key)

    actual_key <- .vc_row_key(df, .VC_KEY_COLS)
    missing_key <- setdiff(expected_key, actual_key)

    if (length(missing_key) > 0) {
      out[[length(out) + 1]] <- data.frame(
        check_id = "COVER.MISSING", severity = "ERROR", file = .vc_file_path(key),
        row_key = missing_key,
        message = "Required row is absent from the data file.",
        stringsAsFactors = FALSE
      )
    }
  }
  .vc_bind(out)
}

#' COVER.EXTRA: a row is not in the required set.
#'
#' @param ctx The list from [build_ctx()].
#' @return A findings tibble.
vc_cover_extra <- function(ctx) {
  out <- list()
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (nrow(df) == 0) next
    man <- ctx$manifests[[key]]
    ref_area <- .vc_manifest_value(man, "ref_area")
    time_period <- .vc_manifest_value(man, "time_period")
    if (is.na(ref_area) || is.na(time_period) || !nzchar(ref_area) || !nzchar(time_period)) {
      next
    }

    req <- required_rows(ctx$meta, ref_area, time_period)
    required_key <- .vc_row_key(req, .VC_KEY_COLS)
    actual_key <- .vc_row_key(df, .VC_KEY_COLS)

    extra_idx <- which(!(actual_key %in% required_key))
    if (length(extra_idx) > 0) {
      out[[length(out) + 1]] <- data.frame(
        check_id = "COVER.EXTRA", severity = "ERROR", file = .vc_file_path(key),
        row_key = actual_key[extra_idx],
        message = "Row is not part of the required set for this country and period.",
        stringsAsFactors = FALSE
      )
    }
  }
  .vc_bind(out)
}

#' COVER.WITHHELD_PRESENT: a withheld row is present.
#'
#' @param ctx The list from [build_ctx()].
#' @return A findings tibble.
vc_cover_withheld_present <- function(ctx) {
  out <- list()
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (nrow(df) == 0) next
    man <- ctx$manifests[[key]]
    ref_area <- .vc_manifest_value(man, "ref_area")
    time_period <- .vc_manifest_value(man, "time_period")
    if (is.na(ref_area) || is.na(time_period) || !nzchar(ref_area) || !nzchar(time_period)) {
      next
    }

    withheld <- withheld_rows(ctx$meta, ref_area, time_period)
    if (nrow(withheld) == 0) next
    withheld_key <- .vc_row_key(withheld, .VC_KEY_COLS)
    actual_key <- .vc_row_key(df, .VC_KEY_COLS)

    present_idx <- which(actual_key %in% withheld_key)
    if (length(present_idx) > 0) {
      out[[length(out) + 1]] <- data.frame(
        check_id = "COVER.WITHHELD_PRESENT", severity = "ERROR", file = .vc_file_path(key),
        row_key = actual_key[present_idx],
        message = "Row is present although decision D5 withholds it.",
        stringsAsFactors = FALSE
      )
    }
  }
  .vc_bind(out)
}

#' COVER.MANIFEST: the manifest is missing, incomplete, or disagrees with
#' the file it describes.
#'
#' @param ctx The list from [build_ctx()].
#' @return A findings tibble.
vc_cover_manifest <- function(ctx) {
  out <- list()
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    man <- ctx$manifests[[key]]
    file <- .vc_file_path(key)

    if (is.null(man) || length(man) == 0) {
      out[[length(out) + 1]] <- data.frame(
        check_id = "COVER.MANIFEST", severity = "ERROR", file = file, row_key = "",
        message = "No manifest file found for this data file.",
        stringsAsFactors = FALSE
      )
      next
    }

    missing_keys <- setdiff(.VC_MANIFEST_KEYS, names(man))
    if (length(missing_keys) > 0) {
      out[[length(out) + 1]] <- data.frame(
        check_id = "COVER.MANIFEST", severity = "ERROR", file = file,
        row_key = paste0("key=", missing_keys),
        message = "Manifest is missing this key.",
        stringsAsFactors = FALSE
      )
    }

    if (!("n_rows" %in% missing_keys)) {
      declared <- suppressWarnings(as.integer(trimws(man[["n_rows"]])))
      if (is.na(declared) || declared != nrow(df)) {
        out[[length(out) + 1]] <- data.frame(
          check_id = "COVER.MANIFEST", severity = "ERROR", file = file,
          row_key = "key=n_rows",
          message = sprintf(
            "Manifest n_rows (%s) disagrees with the file's %d rows.",
            man[["n_rows"]], nrow(df)
          ),
          stringsAsFactors = FALSE
        )
      }
    }

    if (!("file_name" %in% missing_keys)) {
      expected_name <- paste0(key, ".csv")
      if (!identical(trimws(man[["file_name"]]), expected_name)) {
        out[[length(out) + 1]] <- data.frame(
          check_id = "COVER.MANIFEST", severity = "ERROR", file = file,
          row_key = "key=file_name",
          message = sprintf(
            "Manifest file_name (%s) disagrees with %s.",
            man[["file_name"]], expected_name
          ),
          stringsAsFactors = FALSE
        )
      }
    }

    if (!("ref_area" %in% missing_keys) && "REF_AREA" %in% names(df) && nrow(df) > 0) {
      actual_ref_areas <- unique(df$REF_AREA)
      if (length(actual_ref_areas) == 1 && !identical(actual_ref_areas, man[["ref_area"]])) {
        out[[length(out) + 1]] <- data.frame(
          check_id = "COVER.MANIFEST", severity = "ERROR", file = file,
          row_key = "key=ref_area",
          message = sprintf(
            "Manifest ref_area (%s) disagrees with the file's %s.",
            man[["ref_area"]], actual_ref_areas
          ),
          stringsAsFactors = FALSE
        )
      }
    }

    if (!("time_period" %in% missing_keys) && "TIME_PERIOD" %in% names(df) && nrow(df) > 0) {
      actual_periods <- unique(df$TIME_PERIOD)
      if (length(actual_periods) == 1 && !identical(actual_periods, man[["time_period"]])) {
        out[[length(out) + 1]] <- data.frame(
          check_id = "COVER.MANIFEST", severity = "ERROR", file = file,
          row_key = "key=time_period",
          message = sprintf(
            "Manifest time_period (%s) disagrees with the file's %s.",
            man[["time_period"]], actual_periods
          ),
          stringsAsFactors = FALSE
        )
      }
    }
  }
  .vc_bind(out)
}

#' COVER.SURVEY: the manifest's survey_id is not in SURVEYS.csv, or that
#' row's ref_area or time_period differs from the manifest's.
#'
#' @param ctx The list from [build_ctx()].
#' @return A findings tibble.
vc_cover_survey <- function(ctx) {
  out <- list()
  surveys <- ctx$meta$SURVEYS
  for (key in names(ctx$data)) {
    man <- ctx$manifests[[key]]
    if (is.null(man) || length(man) == 0 || !("survey_id" %in% names(man))) next
    sid <- man[["survey_id"]]
    if (!nzchar(trimws(sid))) next
    file <- .vc_file_path(key)

    match_rows <- NULL
    if (!is.null(surveys) && "survey_id" %in% names(surveys)) {
      match_rows <- surveys[surveys$survey_id == sid, , drop = FALSE]
    }

    if (is.null(match_rows) || nrow(match_rows) == 0) {
      out[[length(out) + 1]] <- data.frame(
        check_id = "COVER.SURVEY", severity = "ERROR", file = file,
        row_key = paste0("survey_id=", sid),
        message = "SURVEYS.csv has no row for this manifest survey_id.",
        stringsAsFactors = FALSE
      )
      next
    }

    mismatch <- FALSE
    if ("ref_area" %in% names(man) && !identical(match_rows$ref_area[1], man[["ref_area"]])) {
      mismatch <- TRUE
    }
    if ("time_period" %in% names(man) && !identical(match_rows$time_period[1], man[["time_period"]])) {
      mismatch <- TRUE
    }
    if (mismatch) {
      out[[length(out) + 1]] <- data.frame(
        check_id = "COVER.SURVEY", severity = "ERROR", file = file,
        row_key = paste0("survey_id=", sid),
        message = "SURVEYS.csv row's ref_area or time_period differs from the manifest.",
        stringsAsFactors = FALSE
      )
    }
  }
  .vc_bind(out)
}
