# pipeline/R/convert_tables.R
#
# Pure functions that turn a legacy workbook (data_raw/tables/Tables_<ISO3>.xlsx)
# into AFW360_HH rows, driven entirely by the LEGACY_LABELS, LEGACY_COLUMNS,
# LEGACY_OVERRIDES and SERIES_PLAN metadata plans (card WP15). This file holds
# no label, no column name and no country-specific rule of its own: every
# sheet name and label it needs comes from the plans, at run time.

#' Whether a value is blank: `NA`, or empty after trimming whitespace.
#'
#' @param x A character vector.
#' @return A logical vector, the same length as `x`.
is_blank <- function(x) {
  is.na(x) | trimws(x) == ""
}

#' The sheets the `"*"` wildcard in `LEGACY_LABELS.sheet` expands to.
#'
#' Computed from the distinct `sheet` values of `LEGACY_COLUMNS` rows with
#' `action == "MAP"` (card WP15, "Rules you need"). Never hardcoded, so an
#' edited plan is picked up automatically.
#'
#' @param legacy_columns The `LEGACY_COLUMNS` plan.
#' @return A sorted character vector of sheet names.
wildcard_sheets <- function(legacy_columns) {
  sort(unique(legacy_columns$sheet[legacy_columns$action == "MAP"]))
}

#' Read every sheet of a legacy workbook as text.
#'
#' @param path Path to the workbook.
#' @return A named list of tibbles, one per sheet, in the workbook's own
#'   sheet order.
read_legacy_workbook <- function(path) {
  sheets <- readxl::excel_sheets(path)
  out <- stats::setNames(vector("list", length(sheets)), sheets)
  for (sh in sheets) {
    out[[sh]] <- readxl::read_excel(path, sheet = sh, col_types = "text")
  }
  out
}

#' Reshape a workbook into one row per (sheet, label, column) cell.
#'
#' The first column of every sheet holds the row label; every other column
#' is a data column (card WP15, "Read").
#'
#' @param wb A named list of tibbles, as returned by [read_legacy_workbook()].
#' @return A data frame with columns `sheet`, `legacy_label`, `column`, `raw`.
melt_workbook <- function(wb) {
  parts <- list()
  for (sh in names(wb)) {
    df <- wb[[sh]]
    label_col <- names(df)[1]
    data_cols <- names(df)[-1]
    labels <- df[[label_col]]
    for (col in data_cols) {
      parts[[length(parts) + 1]] <- data.frame(
        sheet = sh,
        legacy_label = labels,
        column = col,
        raw = df[[col]],
        stringsAsFactors = FALSE
      )
    }
  }
  out <- do.call(rbind, parts)
  rownames(out) <- NULL
  out
}

#' Check that every workbook label and column is planned, and every planned
#' label and column is used.
#'
#' Stops with a clear message on any mismatch (card WP15, "Nothing is
#' dropped silently").
#'
#' @param country The country code (`ref_area`).
#' @param wb_long A long-format workbook, as returned by [melt_workbook()].
#' @param legacy_columns The `LEGACY_COLUMNS` plan.
#' @param legacy_labels The `LEGACY_LABELS` plan.
#' @return `TRUE`, invisibly.
validate_workbook_plan <- function(country, wb_long, legacy_columns, legacy_labels) {
  wc <- wildcard_sheets(legacy_columns)
  lc <- legacy_columns[legacy_columns$ref_area == country, ]

  wb_cols <- unique(wb_long[, c("sheet", "column")])
  for (i in seq_len(nrow(wb_cols))) {
    hit <- lc$sheet == wb_cols$sheet[i] & lc$column == wb_cols$column[i]
    if (sum(hit) != 1) {
      stop(
        "convert_tables: ", country, " sheet '", wb_cols$sheet[i],
        "' column '", wb_cols$column[i], "' has ", sum(hit),
        " LEGACY_COLUMNS row(s) (expected exactly 1)",
        call. = FALSE
      )
    }
  }
  for (i in seq_len(nrow(lc))) {
    hit <- wb_cols$sheet == lc$sheet[i] & wb_cols$column == lc$column[i]
    if (!any(hit)) {
      stop(
        "convert_tables: LEGACY_COLUMNS row (", country, ", '", lc$sheet[i],
        "', '", lc$column[i], "') matches nothing in the workbook",
        call. = FALSE
      )
    }
  }

  applies <- function(label_sheet, sh) {
    label_sheet == sh | (label_sheet == "*" & sh %in% wc)
  }

  wb_labels <- unique(wb_long[, c("sheet", "legacy_label")])
  for (i in seq_len(nrow(wb_labels))) {
    hit <- legacy_labels$legacy_label == wb_labels$legacy_label[i] &
      applies(legacy_labels$sheet, wb_labels$sheet[i])
    if (sum(hit) != 1) {
      stop(
        "convert_tables: ", country, " sheet '", wb_labels$sheet[i],
        "' label '", wb_labels$legacy_label[i], "' has ", sum(hit),
        " LEGACY_LABELS row(s) (expected exactly 1)",
        call. = FALSE
      )
    }
  }

  sheets_present <- unique(wb_long$sheet)
  for (i in seq_len(nrow(legacy_labels))) {
    ll_sheets <- if (legacy_labels$sheet[i] == "*") {
      intersect(wc, sheets_present)
    } else {
      intersect(legacy_labels$sheet[i], sheets_present)
    }
    if (length(ll_sheets) == 0) {
      next
    }
    hit <- FALSE
    for (sh in ll_sheets) {
      if (any(wb_labels$sheet == sh & wb_labels$legacy_label == legacy_labels$legacy_label[i])) {
        hit <- TRUE
        break
      }
    }
    if (!hit) {
      stop(
        "convert_tables: LEGACY_LABELS row ('", legacy_labels$sheet[i], "', '",
        legacy_labels$legacy_label[i], "') matches nothing in the ", country,
        " workbook",
        call. = FALSE
      )
    }
  }

  invisible(TRUE)
}

#' Parse a `DUPLICATE_OF`/`DERIVED` label's `assert_rule`.
#'
#' @param rule A string like `"EQUALS:<series_id>"` or
#'   `"ONE_MINUS:<series_id> tol=<x>"`.
#' @return A list with `op` (`"EQUALS"` or `"ONE_MINUS"`), `series_id` and
#'   `tol` (`0` when absent).
parse_assert_rule <- function(rule) {
  m <- regmatches(rule, regexec("^(EQUALS|ONE_MINUS):(\\S+?)(?: tol=([0-9.]+))?$", rule, perl = TRUE))[[1]]
  if (length(m) == 0) {
    stop("convert_tables: malformed assert_rule '", rule, "'", call. = FALSE)
  }
  tol <- if (is.na(m[4]) || m[4] == "") 0 else as.numeric(m[4])
  list(op = m[2], series_id = m[3], tol = tol)
}

#' Check every `DUPLICATE_OF`/`DERIVED` label's `assert_rule` against its
#' target `MAP` label's cells.
#'
#' Cells where either side is empty are skipped (card WP15, "Rules you
#' need"). Stops with a clear message on the first violation.
#'
#' @param country The country code.
#' @param wb_long A long-format workbook, as returned by [melt_workbook()].
#' @param legacy_labels The `LEGACY_LABELS` plan.
#' @param wc The wildcard sheets, as returned by [wildcard_sheets()].
#' @return `TRUE`, invisibly.
check_label_assertions <- function(country, wb_long, legacy_labels, wc) {
  targets <- legacy_labels[legacy_labels$action == "MAP", c("series_id", "legacy_label")]
  sheets_present <- unique(wb_long$sheet)

  assert_rows <- legacy_labels[legacy_labels$action %in% c("DUPLICATE_OF", "DERIVED"), ]
  for (i in seq_len(nrow(assert_rows))) {
    rule <- parse_assert_rule(assert_rows$assert_rule[i])
    tgt_label <- targets$legacy_label[targets$series_id == rule$series_id]
    if (length(tgt_label) != 1) {
      stop(
        "convert_tables: assert_rule '", assert_rows$assert_rule[i],
        "' names series_id '", rule$series_id, "' with ", length(tgt_label),
        " MAP label(s) (expected exactly 1)",
        call. = FALSE
      )
    }

    ll_sheets <- if (assert_rows$sheet[i] == "*") {
      intersect(wc, sheets_present)
    } else {
      intersect(assert_rows$sheet[i], sheets_present)
    }

    for (sh in ll_sheets) {
      src <- wb_long[wb_long$sheet == sh & wb_long$legacy_label == assert_rows$legacy_label[i], c("column", "raw")]
      tgt <- wb_long[wb_long$sheet == sh & wb_long$legacy_label == tgt_label, c("column", "raw")]
      merged <- merge(src, tgt, by = "column", suffixes = c("_src", "_tgt"))
      for (j in seq_len(nrow(merged))) {
        a <- merged$raw_src[j]
        b <- merged$raw_tgt[j]
        if (is_blank(a) || is_blank(b)) {
          next
        }
        av <- as.numeric(a)
        bv <- as.numeric(b)
        expected <- if (rule$op == "EQUALS") bv else (1 - bv)
        deviation <- av - expected
        if (abs(deviation) > rule$tol + 1e-9) {
          stop(
            "convert_tables: assert_rule violated for label '", assert_rows$legacy_label[i],
            "' (", country, ", sheet '", sh, "', column '", merged$column[j],
            "'): got ", av, ", expected ", expected,
            call. = FALSE
          )
        }
      }
    }
  }
  invisible(TRUE)
}

#' Order category codes by their variable's slot order and pad to five.
#'
#' Looks up each code's `var_code` in `cl_table` and each `var_code`'s
#' `slot_order` in `var_table`, then applies [slot_sort()] and
#' [fill_slots()].
#'
#' @param codes A character vector of category codes (breakdown or
#'   qualifier codes), possibly empty.
#' @param cl_table A codelist with `code` and `var_code` columns
#'   (`CL_COMP_BREAKDOWN` or `CL_QUALIFIER`).
#' @param var_table A variable list with `code` and `slot_order` columns
#'   (`CL_BRK_VAR` or `CL_QUAL_VAR`).
#' @param pad The sentinel used to fill empty slots.
#' @return A character vector of exactly 5 codes.
order_and_pad <- function(codes, cl_table, var_table, pad) {
  codes <- codes[!is.na(codes) & codes != ""]
  var_of <- stats::setNames(cl_table$var_code, cl_table$code)
  slot_order_of <- stats::setNames(var_table$slot_order, var_table$code)
  ordered <- slot_sort(codes, var_of, slot_order_of)
  fill_slots(ordered, n = 5, pad = pad)
}

#' Find the `LEGACY_OVERRIDES` rows that match a cell.
#'
#' `"*"` matches every value in `ref_area`, `column` and `legacy_label`;
#' `"*"` in `sheet` means the wildcard sheets (card WP15, "Overrides").
#'
#' @param overrides The `LEGACY_OVERRIDES` plan.
#' @param country,sheet,column,legacy_label The cell's coordinates.
#' @param wc The wildcard sheets, as returned by [wildcard_sheets()].
#' @return The matching rows of `overrides`.
match_overrides <- function(overrides, country, sheet, column, legacy_label, wc) {
  hit <- (overrides$ref_area == "*" | overrides$ref_area == country) &
    (overrides$sheet == sheet | (overrides$sheet == "*" & sheet %in% wc)) &
    (overrides$column == "*" | overrides$column == column) &
    (overrides$legacy_label == "*" | overrides$legacy_label == legacy_label)
  overrides[hit, ]
}

#' Build the AFW360_HH rows for one country.
#'
#' Pure function: takes the workbook and the metadata plans, returns the
#' rows as a data frame of [DSD_COLUMNS], one row per mapped, non-withheld
#' cell, unsorted. `constants.R` must already be sourced.
#'
#' @param country The country code (`ref_area`).
#' @param wb A named list of tibbles, as returned by [read_legacy_workbook()].
#' @param meta A named list of plan/codelist tibbles (as from
#'   `load_metadata()`): `LEGACY_LABELS`, `LEGACY_COLUMNS`,
#'   `LEGACY_OVERRIDES`, `SERIES_PLAN`, `SURVEYS`, `CL_INDICATOR`,
#'   `CL_BRK_VAR`, `CL_QUAL_VAR`, `CL_COMP_BREAKDOWN`, `CL_QUALIFIER`.
#' @return A data frame with the [DSD_COLUMNS] columns.
build_country_rows <- function(country, wb, meta) {
  legacy_labels <- meta$LEGACY_LABELS
  legacy_columns <- meta$LEGACY_COLUMNS
  overrides <- meta$LEGACY_OVERRIDES
  series_plan <- meta$SERIES_PLAN
  surveys <- meta$SURVEYS
  cl_indicator <- meta$CL_INDICATOR
  cl_brk_var <- meta$CL_BRK_VAR
  cl_qual_var <- meta$CL_QUAL_VAR
  cl_comp_breakdown <- meta$CL_COMP_BREAKDOWN
  cl_qualifier <- meta$CL_QUALIFIER

  wb_long <- melt_workbook(wb)
  validate_workbook_plan(country, wb_long, legacy_columns, legacy_labels)

  wc <- wildcard_sheets(legacy_columns)
  check_label_assertions(country, wb_long, legacy_labels, wc)

  sv <- surveys[surveys$ref_area == country, ]
  if (nrow(sv) != 1) {
    stop(
      "convert_tables: ", country, " has ", nrow(sv),
      " SURVEYS.csv row(s) (expected exactly 1)",
      call. = FALSE
    )
  }
  time_period <- sv$time_period[1]

  lc <- legacy_columns[legacy_columns$ref_area == country & legacy_columns$action == "MAP", ]

  stat_unit_of <- stats::setNames(cl_indicator$stat_unit, cl_indicator$code)
  indicator_of_series <- stats::setNames(series_plan$INDICATOR, series_plan$series_id)
  quals_of_series <- stats::setNames(series_plan$MEASURE_QUALS, series_plan$series_id)
  defining_of_series <- stats::setNames(series_plan$DEFINING_BREAKDOWN, series_plan$series_id)

  out <- list()
  for (i in seq_len(nrow(lc))) {
    sheet <- lc$sheet[i]
    column <- lc$column[i]
    if (!(sheet %in% names(wb))) {
      next
    }

    cells <- wb_long[wb_long$sheet == sheet & wb_long$column == column, ]
    for (j in seq_len(nrow(cells))) {
      legacy_label <- cells$legacy_label[j]
      raw <- cells$raw[j]

      ll <- legacy_labels[
        legacy_labels$legacy_label == legacy_label &
          (legacy_labels$sheet == sheet | (legacy_labels$sheet == "*" & sheet %in% wc)),
      ]
      if (nrow(ll) != 1) {
        stop(
          "convert_tables: ", country, " sheet '", sheet, "' label '", legacy_label,
          "' has ", nrow(ll), " LEGACY_LABELS row(s) (expected exactly 1)",
          call. = FALSE
        )
      }
      if (ll$action[1] != "MAP") {
        next
      }

      ov <- match_overrides(overrides, country, sheet, column, legacy_label, wc)
      if (any(ov$action == "WITHHOLD")) {
        next
      }

      series_id <- ll$series_id[1]
      scale <- as.numeric(ll$scale[1])
      indicator <- unname(indicator_of_series[series_id])
      if (is.na(indicator)) {
        stop(
          "convert_tables: series_id '", series_id, "' (label '", legacy_label,
          "') has no SERIES_PLAN row",
          call. = FALSE
        )
      }
      stat_unit <- unname(stat_unit_of[indicator])
      sex_age <- if (identical(stat_unit, "IND")) SENTINEL_TOTAL else SENTINEL_NA

      brk_codes <- c(lc$COMP_BREAKDOWN[i], unname(defining_of_series[series_id]))
      brk_codes <- brk_codes[!is.na(brk_codes) & brk_codes != ""]
      brk <- order_and_pad(brk_codes, cl_comp_breakdown, cl_brk_var, SENTINEL_TOTAL)

      qual_str <- unname(quals_of_series[series_id])
      qual_codes <- if (is.na(qual_str) || qual_str == "") character(0) else strsplit(qual_str, " ")[[1]]
      qual <- order_and_pad(qual_codes, cl_qualifier, cl_qual_var, SENTINEL_NA)

      comments <- ov$obs_comment[ov$action == "COMMENT"]
      if (is_blank(raw)) {
        obs_value <- ""
        obs_status <- "O"
        base_comment <- paste0(
          "LEGACY_EMPTY: empty cell in sheet '", sheet, "', column '", column, "'"
        )
        obs_comment <- paste(c(base_comment, comments), collapse = " | ")
      } else {
        obs_value <- fmt_num(round(as.numeric(raw) * scale, 10))
        obs_status <- "A"
        obs_comment <- paste(comments, collapse = " | ")
      }

      geo <- if (lc$GEO[i] == "") SENTINEL_TOTAL else lc$GEO[i]
      urb <- if (lc$URBANISATION[i] == "") SENTINEL_TOTAL else lc$URBANISATION[i]

      row <- stats::setNames(as.list(rep("", length(DSD_COLUMNS))), DSD_COLUMNS)
      row$DATAFLOW <- DATAFLOW_ID
      row$REF_AREA <- country
      row$GEO <- geo
      row$TIME_PERIOD <- time_period
      row$INDICATOR <- indicator
      row$SEX <- sex_age
      row$AGE <- sex_age
      row$URBANISATION <- urb
      row$COMP_BREAKDOWN_1 <- brk[1]
      row$COMP_BREAKDOWN_2 <- brk[2]
      row$COMP_BREAKDOWN_3 <- brk[3]
      row$COMP_BREAKDOWN_4 <- brk[4]
      row$COMP_BREAKDOWN_5 <- brk[5]
      row$MEASURE_QUAL_1 <- qual[1]
      row$MEASURE_QUAL_2 <- qual[2]
      row$MEASURE_QUAL_3 <- qual[3]
      row$MEASURE_QUAL_4 <- qual[4]
      row$MEASURE_QUAL_5 <- qual[5]
      row$OBS_VALUE <- obs_value
      row$OBS_STATUS <- obs_status
      row$OBS_COMMENT <- obs_comment

      out[[length(out) + 1]] <- as.data.frame(row, stringsAsFactors = FALSE)
    }
  }

  if (length(out) == 0) {
    empty_cols <- stats::setNames(replicate(length(DSD_COLUMNS), character(0), simplify = FALSE), DSD_COLUMNS)
    return(as.data.frame(empty_cols, stringsAsFactors = FALSE))
  }
  do.call(rbind, out)
}

#' Sort rows by the 18-column key, in C-locale radix order, and check that
#' the key is unique.
#'
#' @param df A data frame with the [DSD_COLUMNS] columns.
#' @return `df`, sorted, with row names reset.
finalize_rows <- function(df) {
  if (nrow(df) == 0) {
    return(df)
  }

  key_cols <- df[, KEY_COLUMNS]
  ord <- do.call(order, c(as.list(key_cols), list(method = "radix")))
  df <- df[ord, , drop = FALSE]
  rownames(df) <- NULL

  key_str <- do.call(paste, c(as.list(df[, KEY_COLUMNS]), list(sep = "|")))
  dups <- unique(key_str[duplicated(key_str)])
  if (length(dups) > 0) {
    stop(
      "convert_tables: ", length(dups), " duplicate key(s) in the output, e.g. '",
      dups[1], "'",
      call. = FALSE
    )
  }
  df
}
