# pipeline/R/validate_coverage.R
#
# Coverage checks (WP12): that a data file holds exactly the rows the plan
# requires, once withheld legacy cells (decision D5) are subtracted, and
# that its manifest is present, complete and agrees with the file and with
# SURVEYS.csv.
#
# Depends on pipeline/R/plan.R for required_rows() (itself needing
# pipeline/R/codes.R and pipeline/R/constants.R), and on `ctx` built by
# build_ctx() (pipeline/R/ctx.R), which needs pipeline/R/io.R, and on
# pipeline/R/manifest.R for MANIFEST_KEYS. Callers source those before
# this file; this file does not source anything itself.
#
# Standard v0.5: the required rows are those of the file's ESTIMATION
# (a SERIES_PLAN country row over the ALL row, NOT_PRODUCED left out; see
# required_rows()), and the manifest's estimation, n_rows, file_name and
# sources must agree with the file.
#
# Findings format (word for word the same on WP11-WP14): a tibble with
# columns check_id, severity, file, row_key, message. `file` is the path
# to the data file relative to the root, with forward slashes. `row_key`
# is the key-column values (19 in DSD 0.2.0) joined by one space for a data row, empty
# for a whole-file finding, or `key=<name>` / `survey_id=<value>` for a
# finding about one manifest key or SURVEYS.csv row. More than 20
# findings for one check_id/file pair are capped to the first 20 in
# row_key order, plus one SUMMARY finding (.vc_apply_cap() in
# pipeline/R/validate_common.R, which callers source before this file).

# The key columns come from the DSD (ctx_key_columns(), pipeline/R/ctx.R:
# the 19 columns DATAFLOW .. MEASURE_QUAL_5 in DSD 0.2.0), and the manifest
# keys from MANIFEST_KEYS (pipeline/R/manifest.R, which the caller sources),
# so neither list is repeated here.

#' The manifest keys every manifest must carry.
.vc_manifest_keys <- function() {
  if (exists("MANIFEST_KEYS")) return(MANIFEST_KEYS)
  stop("validate_coverage.R: source pipeline/R/manifest.R first (MANIFEST_KEYS)", call. = FALSE)
}

#' The ref_area, time_period and estimation a data file covers: the
#' manifest's, falling back to the file name's (NA when neither has it).
.vc_file_scope <- function(ctx, key) {
  man <- ctx$manifests[[key]]
  parsed <- ctx_parse_file_name(key)
  pick <- function(k) {
    v <- .vc_manifest_value(man, k)
    if ((is.na(v) || !nzchar(v)) && !is.null(parsed)) v <- unname(parsed[[k]])
    v
  }
  list(
    ref_area = pick("ref_area"),
    time_period = pick("time_period"),
    estimation = ctx_file_estimation(ctx, key)
  )
}

#' Whether a scope from [.vc_file_scope()] is complete.
.vc_scope_ok <- function(sc) {
  all(vapply(sc, function(v) !is.na(v) && nzchar(v), logical(1)))
}

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
withheld_rows <- function(meta, ref_area, time_period, estimation = "SURVEY") {
  comp_cols <- c(
    "COMP_BREAKDOWN_1", "COMP_BREAKDOWN_2", "COMP_BREAKDOWN_3",
    "COMP_BREAKDOWN_4", "COMP_BREAKDOWN_5"
  )

  req <- required_rows(meta, ref_area, time_period, estimation)
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

#' COVER.FILE_MISSING: for every SURVEYS.csv row, a SURVEY data file and
#' its manifest exist under `data/` for that country and year (standard,
#' "Validation checks" > "Coverage"). A missing file is a WARN, not an
#' ERROR, because metadata precedes data. One finding per SURVEYS row, with
#' `file` the expected data file and an empty `row_key`. The check looks
#' at the files on disk, whichever files this run loads; it is skipped with
#' `--metadata-only` and when `--data` names the files to validate.
#'
#' @param ctx The list from [build_ctx()].
#' @return A findings tibble.
vc_cover_file_missing <- function(ctx) {
  out <- list()
  if (isTRUE(ctx$opts$metadata_only) || isTRUE(ctx$opts$data_selected)) {
    return(.vc_bind(out))
  }
  surveys <- ctx$meta$SURVEYS
  if (is.null(surveys) || nrow(surveys) == 0 || !all(c("ref_area", "time_period") %in% names(surveys))) {
    return(.vc_bind(out))
  }
  pairs <- unique(data.frame(ref_area = surveys$ref_area, time_period = surveys$time_period, stringsAsFactors = FALSE))
  for (i in seq_len(nrow(pairs))) {
    stem <- paste0(DATAFLOW_ID, "_", pairs$ref_area[i], "_", pairs$time_period[i], "_SURVEY")
    data_rel <- paste0("data/", stem, ".csv")
    man_rel <- paste0("data/", stem, "_manifest.csv")
    has_data <- file.exists(file.path(ctx$root, data_rel))
    has_man <- file.exists(file.path(ctx$root, man_rel))
    if (has_data && has_man) next
    missing <- c(if (!has_data) data_rel, if (!has_man) man_rel)
    out[[length(out) + 1]] <- data.frame(
      check_id = "COVER.FILE_MISSING", severity = "WARN", file = data_rel, row_key = "",
      message = sprintf(
        "SURVEYS.csv has a survey for %s %s, but %s %s missing.",
        pairs$ref_area[i], pairs$time_period[i], paste(missing, collapse = " and "),
        if (length(missing) == 1) "is" else "are"
      ),
      stringsAsFactors = FALSE
    )
  }
  .vc_bind(out)
}

#' COVER.MISSING: an expected row is absent from the data file.
#'
#' @param ctx The list from [build_ctx()].
#' @return A findings tibble.
vc_cover_missing <- function(ctx) {
  out <- list()
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    sc <- .vc_file_scope(ctx, key)
    if (!.vc_scope_ok(sc)) next
    ref_area <- sc$ref_area
    time_period <- sc$time_period
    estimation <- sc$estimation
    key_cols <- ctx_key_columns(ctx)

    req <- required_rows(ctx$meta, ref_area, time_period, estimation)
    if (nrow(req) == 0) next
    withheld <- withheld_rows(ctx$meta, ref_area, time_period, estimation)

    expected_key <- .vc_row_key(req, key_cols)
    withheld_key <- .vc_row_key(withheld, key_cols)
    expected_key <- setdiff(expected_key, withheld_key)

    actual_key <- .vc_row_key(df, key_cols)
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
    sc <- .vc_file_scope(ctx, key)
    if (!.vc_scope_ok(sc)) next
    ref_area <- sc$ref_area
    time_period <- sc$time_period
    estimation <- sc$estimation
    key_cols <- ctx_key_columns(ctx)

    req <- required_rows(ctx$meta, ref_area, time_period, estimation)
    required_key <- .vc_row_key(req, key_cols)
    actual_key <- .vc_row_key(df, key_cols)

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
    sc <- .vc_file_scope(ctx, key)
    if (!.vc_scope_ok(sc)) next
    ref_area <- sc$ref_area
    time_period <- sc$time_period
    estimation <- sc$estimation
    key_cols <- ctx_key_columns(ctx)

    withheld <- withheld_rows(ctx$meta, ref_area, time_period, estimation)
    if (nrow(withheld) == 0) next
    withheld_key <- .vc_row_key(withheld, key_cols)
    actual_key <- .vc_row_key(df, key_cols)

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

    missing_keys <- setdiff(.vc_manifest_keys(), names(man))
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

    if (!("estimation" %in% missing_keys)) {
      declared <- trimws(man[["estimation"]])
      est_codes <- ctx$meta$CL_ESTIMATION$code
      problems <- character(0)
      if (!is.null(est_codes) && !(declared %in% est_codes)) {
        problems <- c(problems, sprintf("is not a CL_ESTIMATION code"))
      }
      parsed <- ctx_parse_file_name(key)
      if (!is.null(parsed) && !identical(declared, unname(parsed[["estimation"]]))) {
        problems <- c(problems, sprintf("disagrees with the file name's %s", parsed[["estimation"]]))
      }
      if ("ESTIMATION" %in% names(df) && nrow(df) > 0) {
        actual <- unique(df$ESTIMATION)
        if (length(actual) == 1 && !identical(actual, declared)) {
          problems <- c(problems, sprintf("disagrees with the file's %s", actual))
        }
      }
      if (length(problems) > 0) {
        out[[length(out) + 1]] <- data.frame(
          check_id = "COVER.MANIFEST", severity = "ERROR", file = file,
          row_key = "key=estimation",
          message = sprintf("Manifest estimation (%s) %s.", declared, paste(problems, collapse = "; ")),
          stringsAsFactors = FALSE
        )
      }
    }

    # `sources` lists the distinct SOURCE_ID values of the file. A value the
    # file uses but the manifest does not list is CODES.SOURCE_ID's finding;
    # here, a listed value the file does not use.
    if (!("sources" %in% missing_keys) && "SOURCE_ID" %in% names(df)) {
      listed <- strsplit(trimws(man[["sources"]]), "\\s+")[[1]]
      listed <- listed[nzchar(listed)]
      unused <- setdiff(listed, unique(df$SOURCE_ID))
      if (length(unused) > 0) {
        out[[length(out) + 1]] <- data.frame(
          check_id = "COVER.MANIFEST", severity = "ERROR", file = file,
          row_key = "key=sources",
          message = sprintf(
            "Manifest sources lists %s, which no row of the file carries.",
            paste(unused, collapse = " ")
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
    # A model-based file's TIME_PERIOD is the year it refers to, not its base
    # survey's (standard, "Manifest"), so only a SURVEY file's time_period
    # must equal the survey's.
    is_survey_file <- identical(ctx_file_estimation(ctx, key), "SURVEY")
    if (is_survey_file && "time_period" %in% names(man) &&
        !identical(match_rows$time_period[1], man[["time_period"]])) {
      mismatch <- TRUE
    }
    if (mismatch) {
      out[[length(out) + 1]] <- data.frame(
        check_id = "COVER.SURVEY", severity = "ERROR", file = file,
        row_key = paste0("survey_id=", sid),
        message = if (is_survey_file) {
          "SURVEYS.csv row's ref_area or time_period differs from the manifest."
        } else {
          "SURVEYS.csv row's ref_area differs from the manifest."
        },
        stringsAsFactors = FALSE
      )
    }
  }
  .vc_bind(out)
}
