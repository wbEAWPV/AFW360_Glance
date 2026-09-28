# pipeline/R/reconcile.R
#
# WP16 - Independent reconciliation tool. A second, independent path from
# the standard data files (data/AFW360_HH_<ISO3>_<YEAR>_SURVEY.csv) back to the
# legacy workbooks (data_raw/tables/Tables_<ISO3>.xlsx). It shares no code
# with the converter: every key here is built straight from the legacy
# maps (metadata/plans/LEGACY_*.csv, metadata/plans/SERIES_PLAN.csv) and
# the small codelists, never from a converter helper.
#
# Three pure functions, used by pipeline/reconcile.R (the CLI):
#   source_cells(root)   -- every (country, sheet, label, column) cell,
#                            classified as skipped / duplicate / derived /
#                            withheld / converted.
#   expected_rows(root)  -- the 19-column key, series and precision, and the
#                            expected value for every converted or withheld
#                            cell.
#   reconcile(root)      -- compares expected_rows() against the data
#                            files on disk and returns the full result.

.reconcile_key_cols <- c(
  "DATAFLOW", "REF_AREA", "GEO", "TIME_PERIOD", "ESTIMATION", "INDICATOR",
  "SEX", "AGE", "URBANISATION",
  paste0("COMP_BREAKDOWN_", 1:5),
  paste0("MEASURE_QUAL_", 1:5)
)

.reconcile_sheets_star <- c("National", "ADM 1", "ZAE")

# Every legacy conversion is a direct survey estimate (standard v0.5, D17).
.reconcile_estimation <- "SURVEY"

#' The data file a country's legacy conversion is expected in.
#'
#' @param root Repo root.
#' @param ref_area,time_period The country and year.
#' @return `<root>/data/AFW360_HH_<ref_area>_<time_period>_SURVEY.csv`.
.reconcile_data_path <- function(root, ref_area, time_period) {
  repo_path(
    root, "data",
    paste0("AFW360_HH_", ref_area, "_", time_period, "_", .reconcile_estimation, ".csv")
  )
}

#' Match rows of a wildcard-keyed table (LEGACY_OVERRIDES) against cells.
#'
#' @param table_ref_area,table_sheet,table_column,table_label Single
#'   values from one row of LEGACY_OVERRIDES ("*" means "matches
#'   everything"; "*" in `table_sheet` means the three main sheets).
#' @param ref_area,sheet,column,label Character vectors, one per cell.
#' @return A logical vector, one per cell.
.reconcile_match_wildcard <- function(table_ref_area, table_sheet, table_column,
                                       table_label, ref_area, sheet, column, label) {
  ra_ok <- (ref_area == table_ref_area) | (table_ref_area == "*")
  sh_ok <- (sheet == table_sheet) |
    (table_sheet == "*" & sheet %in% .reconcile_sheets_star)
  col_ok <- (column == table_column) | (table_column == "*")
  lbl_ok <- (label == table_label) | (table_label == "*")
  ra_ok & sh_ok & col_ok & lbl_ok
}

#' Every source cell, classified.
#'
#' A source cell is (ref_area, sheet, legacy_label, column), for every
#' sheet a workbook has (`readxl::excel_sheets()`) and every data column
#' (every column but the first) and every non-blank indicator row.
#'
#' @param root Repo root.
#' @return A tibble: ref_area, sheet, legacy_label, column, raw_value
#'   (character, "" when blank), class (skipped/duplicate/derived/
#'   withheld/converted), lbl_action, series_id, scale, duplicate_of,
#'   assert_rule (from LEGACY_LABELS), GEO, URBANISATION, COMP_BREAKDOWN
#'   (from LEGACY_COLUMNS), comment_override (LEGACY_OVERRIDES obs_comment
#'   when a COMMENT override matches, else NA).
source_cells <- function(root) {
  meta <- load_metadata(root)
  legacy_columns <- meta$LEGACY_COLUMNS
  legacy_labels <- meta$LEGACY_LABELS
  legacy_overrides <- meta$LEGACY_OVERRIDES

  ref_areas <- sort(unique(legacy_columns$ref_area))

  cell_frames <- list()
  for (ra in ref_areas) {
    path <- repo_path(root, "data_raw", "tables", paste0("Tables_", ra, ".xlsx"))
    sheets <- readxl::excel_sheets(path)
    for (sh in sheets) {
      df <- readxl::read_excel(path, sheet = sh, col_types = "text")
      if (ncol(df) < 2) next
      label_raw <- df[[1]]
      keep <- !is.na(label_raw) & trimws(label_raw) != ""
      df <- df[keep, , drop = FALSE]
      labels <- trimws(df[[1]])
      data_cols <- names(df)[-1]
      if (length(labels) == 0 || length(data_cols) == 0) next

      n_lab <- length(labels)
      n_col <- length(data_cols)
      column_rep <- rep(data_cols, each = n_lab)
      label_rep <- rep(labels, times = n_col)
      raw_rep <- unlist(df[data_cols], use.names = FALSE)
      raw_rep_trim <- trimws(raw_rep)
      raw_rep_trim[is.na(raw_rep)] <- ""

      cell_frames[[paste(ra, sh)]] <- tibble::tibble(
        ref_area = ra,
        sheet = sh,
        legacy_label = label_rep,
        column = column_rep,
        raw_value = raw_rep_trim
      )
    }
  }
  cells <- dplyr::bind_rows(cell_frames)

  # Column class, GEO/URBANISATION/COMP_BREAKDOWN, from LEGACY_COLUMNS.
  col_idx <- match(
    paste(cells$ref_area, cells$sheet, cells$column),
    paste(legacy_columns$ref_area, legacy_columns$sheet, legacy_columns$column)
  )
  if (anyNA(col_idx)) {
    bad <- unique(paste(cells$ref_area, cells$sheet, cells$column)[is.na(col_idx)])
    stop(
      "source_cells: column(s) not found in LEGACY_COLUMNS: ",
      paste(utils::head(bad, 5), collapse = "; "), call. = FALSE
    )
  }
  cells$col_action <- legacy_columns$action[col_idx]
  cells$GEO <- legacy_columns$GEO[col_idx]
  cells$URBANISATION <- legacy_columns$URBANISATION[col_idx]
  cells$COMP_BREAKDOWN <- legacy_columns$COMP_BREAKDOWN[col_idx]

  # Label class, series_id, scale, duplicate_of, assert_rule, from
  # LEGACY_LABELS. sheet "*" means National/ADM 1/ZAE; "Departement" is
  # its own bucket.
  bucket <- ifelse(cells$sheet == "Departement", "Departement", "*")
  lbl_idx <- match(
    paste(cells$legacy_label, bucket),
    paste(legacy_labels$legacy_label, legacy_labels$sheet)
  )
  if (anyNA(lbl_idx)) {
    bad <- unique(paste(cells$legacy_label, bucket)[is.na(lbl_idx)])
    stop(
      "source_cells: label(s) not found in LEGACY_LABELS: ",
      paste(utils::head(bad, 5), collapse = "; "), call. = FALSE
    )
  }
  cells$lbl_action <- legacy_labels$action[lbl_idx]
  cells$series_id <- legacy_labels$series_id[lbl_idx]
  cells$scale <- legacy_labels$scale[lbl_idx]
  cells$duplicate_of <- legacy_labels$duplicate_of[lbl_idx]
  cells$assert_rule <- legacy_labels$assert_rule[lbl_idx]

  # LEGACY_OVERRIDES: WITHHOLD and COMMENT, wildcard-matched.
  withheld_match <- rep(FALSE, nrow(cells))
  comment_override <- rep(NA_character_, nrow(cells))
  for (i in seq_len(nrow(legacy_overrides))) {
    ov <- legacy_overrides[i, ]
    m <- .reconcile_match_wildcard(
      ov$ref_area, ov$sheet, ov$column, ov$legacy_label,
      cells$ref_area, cells$sheet, cells$column, cells$legacy_label
    )
    if (identical(ov$action, "WITHHOLD")) {
      withheld_match <- withheld_match | m
    } else if (identical(ov$action, "COMMENT")) {
      comment_override[m] <- ov$obs_comment
    }
  }
  cells$comment_override <- comment_override

  cells$class <- dplyr::case_when(
    cells$col_action == "SKIP" ~ "skipped",
    cells$lbl_action == "SKIP" ~ "skipped",
    cells$lbl_action == "DUPLICATE_OF" ~ "duplicate",
    cells$lbl_action == "DERIVED" ~ "derived",
    cells$lbl_action == "MAP" & withheld_match ~ "withheld",
    cells$lbl_action == "MAP" & !withheld_match ~ "converted",
    TRUE ~ NA_character_
  )
  if (anyNA(cells$class)) {
    stop(
      "source_cells: ", sum(is.na(cells$class)),
      " cell(s) could not be classified (unexpected LEGACY_LABELS.action)",
      call. = FALSE
    )
  }

  cells
}

#' The 19-column key and expected value for every converted or withheld
#' cell.
#'
#' @param root Repo root.
#' @return A tibble with one row per converted/withheld source cell:
#'   identity columns (ref_area, sheet, legacy_label, column, class,
#'   raw_value, scale), the 19 key columns, `row_key` (the 19 columns
#'   pasted with "|"), `SERIES_ID` (the label's series), `PRECISION`
#'   (`0.01 x scale`, the workbook's two decimals in base units), `OBS_VALUE`,
#'   `OBS_STATUS`, and `comment_mode` / `OBS_COMMENT_EXPECTED` (comment_mode
#'   is "OVERRIDE", "LEGACY_EMPTY" or "NONE").
expected_rows <- function(root) {
  meta <- load_metadata(root)
  cells <- source_cells(root)
  rows <- cells[cells$class %in% c("converted", "withheld"), , drop = FALSE]
  rows <- rows[order(rows$ref_area, rows$sheet, rows$column, rows$legacy_label), ]

  sp <- meta$SERIES_PLAN
  cl_ind <- meta$CL_INDICATOR
  surveys <- meta$SURVEYS
  var_of_brk <- stats::setNames(meta$CL_COMP_BREAKDOWN$var_code, meta$CL_COMP_BREAKDOWN$code)
  slot_order_of_brk <- stats::setNames(meta$CL_BRK_VAR$slot_order, meta$CL_BRK_VAR$code)
  var_of_qual <- stats::setNames(meta$CL_QUALIFIER$var_code, meta$CL_QUALIFIER$code)
  slot_order_of_qual <- stats::setNames(meta$CL_QUAL_VAR$slot_order, meta$CL_QUAL_VAR$code)
  time_of <- stats::setNames(surveys$time_period, surveys$ref_area)
  stat_unit_of <- stats::setNames(cl_ind$stat_unit, cl_ind$code)

  n <- nrow(rows)
  if (n == 0) {
    return(tibble::tibble(
      ref_area = character(0), sheet = character(0), legacy_label = character(0),
      column = character(0), class = character(0), raw_value = character(0),
      scale = character(0), DATAFLOW = character(0), REF_AREA = character(0),
      GEO = character(0), URBANISATION = character(0), SEX = character(0),
      AGE = character(0), TIME_PERIOD = character(0), ESTIMATION = character(0),
      INDICATOR = character(0),
      COMP_BREAKDOWN_1 = character(0), COMP_BREAKDOWN_2 = character(0),
      COMP_BREAKDOWN_3 = character(0), COMP_BREAKDOWN_4 = character(0),
      COMP_BREAKDOWN_5 = character(0), MEASURE_QUAL_1 = character(0),
      MEASURE_QUAL_2 = character(0), MEASURE_QUAL_3 = character(0),
      MEASURE_QUAL_4 = character(0), MEASURE_QUAL_5 = character(0),
      SERIES_ID = character(0), PRECISION = character(0),
      OBS_VALUE = character(0), OBS_STATUS = character(0),
      comment_mode = character(0), OBS_COMMENT_EXPECTED = character(0),
      row_key = character(0)
    ))
  }

  sp_idx <- match(rows$series_id, sp$series_id)
  if (anyNA(sp_idx)) {
    stop(
      "expected_rows: series_id not found in SERIES_PLAN: ",
      paste(unique(rows$series_id[is.na(sp_idx)]), collapse = ", "), call. = FALSE
    )
  }
  INDICATOR <- sp$INDICATOR[sp_idx]
  MEASURE_QUALS <- sp$MEASURE_QUALS[sp_idx]
  DEFINING_BREAKDOWN <- sp$DEFINING_BREAKDOWN[sp_idx]

  REF_AREA <- rows$ref_area
  GEO <- ifelse(is.na(rows$GEO) | rows$GEO == "", "_T", rows$GEO)
  URBANISATION <- ifelse(is.na(rows$URBANISATION) | rows$URBANISATION == "", "_T", rows$URBANISATION)
  TIME_PERIOD <- unname(time_of[REF_AREA])
  ESTIMATION <- rep(.reconcile_estimation, n)

  stat_unit <- unname(stat_unit_of[INDICATOR])
  SEX <- ifelse(!is.na(stat_unit) & stat_unit == "IND", "_T", "_Z")
  AGE <- SEX

  brk_mat <- matrix("_T", nrow = n, ncol = 5)
  qual_mat <- matrix("_Z", nrow = n, ncol = 5)
  for (i in seq_len(n)) {
    brk_codes <- c(rows$COMP_BREAKDOWN[i], DEFINING_BREAKDOWN[i])
    brk_codes <- brk_codes[!is.na(brk_codes) & brk_codes != ""]
    if (length(brk_codes) > 0) {
      brk_codes <- slot_sort(brk_codes, var_of_brk, slot_order_of_brk)
      brk_mat[i, ] <- fill_slots(brk_codes, n = 5, pad = "_T")
    }
    qual_codes <- strsplit(MEASURE_QUALS[i], " ", fixed = TRUE)[[1]]
    qual_codes <- qual_codes[!is.na(qual_codes) & qual_codes != ""]
    if (length(qual_codes) > 0) {
      qual_codes <- slot_sort(qual_codes, var_of_qual, slot_order_of_qual)
      qual_mat[i, ] <- fill_slots(qual_codes, n = 5, pad = "_Z")
    }
  }
  colnames(brk_mat) <- paste0("COMP_BREAKDOWN_", 1:5)
  colnames(qual_mat) <- paste0("MEASURE_QUAL_", 1:5)

  raw_value <- rows$raw_value
  is_empty <- raw_value == ""
  raw_num <- suppressWarnings(as.numeric(raw_value))
  scale_num <- suppressWarnings(as.numeric(rows$scale))
  obs_value_num <- ifelse(is_empty, NA_real_, raw_num * scale_num)

  OBS_VALUE <- ifelse(is_empty, "", fmt_num(obs_value_num))
  scale_or_one <- ifelse(is.na(rows$scale) | trimws(rows$scale) == "", 1, scale_num)
  PRECISION <- fmt_num(0.01 * scale_or_one)
  SERIES_ID <- rows$series_id
  OBS_STATUS <- ifelse(is_empty, "O", "A")

  comment_mode <- ifelse(
    !is.na(rows$comment_override), "OVERRIDE",
    ifelse(is_empty, "LEGACY_EMPTY", "NONE")
  )
  legacy_empty_comment <- paste0(
    "LEGACY_EMPTY: ", rows$ref_area, " ", rows$sheet, " ", rows$column,
    " \"", rows$legacy_label, "\""
  )
  OBS_COMMENT_EXPECTED <- dplyr::case_when(
    comment_mode == "OVERRIDE" ~ rows$comment_override,
    comment_mode == "LEGACY_EMPTY" ~ legacy_empty_comment,
    TRUE ~ ""
  )

  DATAFLOW <- rep("AFW360_HH", n)
  key_parts <- cbind(
    DATAFLOW, REF_AREA, GEO, TIME_PERIOD, ESTIMATION, INDICATOR, SEX, AGE,
    URBANISATION, brk_mat, qual_mat
  )
  row_key <- apply(key_parts, 1, paste, collapse = "|")

  out <- tibble::tibble(
    ref_area = rows$ref_area, sheet = rows$sheet, legacy_label = rows$legacy_label,
    column = rows$column, class = rows$class, raw_value = rows$raw_value,
    scale = rows$scale,
    DATAFLOW = DATAFLOW, REF_AREA = REF_AREA, GEO = GEO, URBANISATION = URBANISATION,
    SEX = SEX, AGE = AGE, TIME_PERIOD = TIME_PERIOD, ESTIMATION = ESTIMATION,
    INDICATOR = INDICATOR
  )
  out <- dplyr::bind_cols(out, tibble::as_tibble(brk_mat), tibble::as_tibble(qual_mat))
  out$SERIES_ID <- SERIES_ID
  out$PRECISION <- PRECISION
  out$OBS_VALUE <- OBS_VALUE
  out$OBS_STATUS <- OBS_STATUS
  out$comment_mode <- comment_mode
  out$OBS_COMMENT_EXPECTED <- OBS_COMMENT_EXPECTED
  out$row_key <- row_key
  out
}

#' Compare expected_rows() against the data files on disk.
#'
#' @param root Repo root.
#' @return A list: `report_rows` (one row per source cell: ref_area,
#'   sheet, legacy_label, column, class, result, source_value, data_value,
#'   row_key), `orphans` (data rows with no source cell: ref_area,
#'   row_key, obs_value), `missing_files` (paths of data files that do not
#'   exist), `class_counts` and `result_counts` (per ref_area x sheet).
reconcile <- function(root) {
  meta <- load_metadata(root)
  cells <- source_cells(root)
  erows <- expected_rows(root)
  surveys <- meta$SURVEYS
  legacy_labels <- meta$LEGACY_LABELS
  time_of <- stats::setNames(surveys$time_period, surveys$ref_area)

  ref_areas <- sort(unique(cells$ref_area))
  data_frames <- list()
  missing_files <- character(0)
  for (ra in ref_areas) {
    tp <- unname(time_of[ra])
    path <- .reconcile_data_path(root, ra, tp)
    if (!file.exists(path)) {
      missing_files <- c(missing_files, path)
      next
    }
    d <- read_std_csv(path)
    missing_cols <- setdiff(
      c(.reconcile_key_cols, "SERIES_ID", "PRECISION", "OBS_VALUE", "OBS_STATUS", "OBS_COMMENT"),
      names(d)
    )
    if (length(missing_cols) > 0) {
      stop(
        "reconcile: ", path, " is missing column(s): ",
        paste(missing_cols, collapse = ", "), call. = FALSE
      )
    }
    key_mat <- as.matrix(d[.reconcile_key_cols])
    d$row_key <- apply(key_mat, 1, paste, collapse = "|")
    d$.ref_area <- ra
    data_frames[[ra]] <- d
  }
  data_all <- if (length(data_frames) > 0) dplyr::bind_rows(data_frames) else NULL

  key_index <- if (!is.null(data_all) && nrow(data_all) > 0) {
    split(seq_len(nrow(data_all)), data_all$row_key)
  } else {
    list()
  }

  n <- nrow(erows)
  result <- rep("OK", n)
  data_value <- rep("", n)
  for (i in seq_len(n)) {
    ra <- erows$ref_area[i]
    if (ra %in% sub("^.*AFW360_HH_([A-Z]+)_.*$", "\\1", missing_files)) next
    idx <- key_index[[erows$row_key[i]]]
    n_match <- length(idx)
    if (erows$class[i] == "withheld") {
      if (n_match == 0) {
        result[i] <- "OK"
      } else {
        result[i] <- "WITHHELD_PRESENT"
        data_value[i] <- data_all$OBS_VALUE[idx[1]]
      }
      next
    }
    # converted
    if (n_match == 0) {
      result[i] <- "MISSING_ROW"
      next
    }
    if (n_match > 1) {
      result[i] <- "DUPLICATE_ROW"
      data_value[i] <- paste(data_all$OBS_VALUE[idx], collapse = " ")
      next
    }
    drow <- data_all[idx[1], ]
    data_value[i] <- drow$OBS_VALUE
    # The row names the label's series, and carries the workbook's rounding
    # unit (0.01 x scale) whether or not the cell holds a value.
    ok_series <- identical(drow$SERIES_ID, erows$SERIES_ID[i])
    drow_prec <- suppressWarnings(as.numeric(drow$PRECISION))
    ok_prec <- !is.na(drow_prec) &&
      abs(drow_prec - as.numeric(erows$PRECISION[i])) <= 1e-9 * max(1, abs(drow_prec))
    ok <- TRUE
    if (erows$OBS_VALUE[i] == "") {
      ok <- identical(trimws(drow$OBS_VALUE), "") &&
        identical(drow$OBS_STATUS, "O") &&
        grepl("^LEGACY_EMPTY:", drow$OBS_COMMENT)
    } else {
      dv <- suppressWarnings(as.numeric(drow$OBS_VALUE))
      scale_num <- suppressWarnings(as.numeric(erows$scale[i]))
      raw_num <- suppressWarnings(as.numeric(erows$raw_value[i]))
      ok_val <- !is.na(dv) && !is.na(scale_num) && !is.na(raw_num) &&
        round(dv / scale_num, 2) == round(raw_num, 2)
      ok_comment <- TRUE
      if (erows$comment_mode[i] == "OVERRIDE") {
        ok_comment <- identical(drow$OBS_COMMENT, erows$OBS_COMMENT_EXPECTED[i])
      }
      ok <- ok_val && ok_comment
    }
    if (!(ok && ok_series && ok_prec)) result[i] <- "MISMATCH"
  }

  # duplicate / derived: assert_rule evaluation.
  map_cells <- cells[cells$lbl_action == "MAP", , drop = FALSE]
  map_num <- ifelse(
    map_cells$raw_value == "", NA_real_,
    suppressWarnings(as.numeric(map_cells$raw_value)) * suppressWarnings(as.numeric(map_cells$scale))
  )
  map_key <- paste(map_cells$ref_area, map_cells$sheet, map_cells$column, map_cells$legacy_label, sep = "\t")
  map_value <- stats::setNames(map_num, map_key)

  series_to_label <- stats::setNames(
    legacy_labels$legacy_label[legacy_labels$action == "MAP"],
    legacy_labels$series_id[legacy_labels$action == "MAP"]
  )

  dd_cells <- cells[cells$class %in% c("duplicate", "derived"), , drop = FALSE]
  dd_result <- rep("OK", nrow(dd_cells))
  dd_data_value <- rep("", nrow(dd_cells))
  rule_re <- "^(EQUALS|ONE_MINUS):(\\S+)(\\s+tol=([0-9.]+))?$"
  for (i in seq_len(nrow(dd_cells))) {
    rule <- dd_cells$assert_rule[i]
    m <- regmatches(rule, regexec(rule_re, rule))[[1]]
    if (length(m) == 0) {
      dd_result[i] <- "ASSERT_FAIL"
      next
    }
    op <- m[2]
    ref_series <- m[3]
    tol <- if (nzchar(m[5])) as.numeric(m[5]) else 0
    ref_label <- if (ref_series %in% names(series_to_label)) {
      unname(series_to_label[[ref_series]])
    } else {
      NA_character_
    }
    if (is.na(ref_label)) {
      ref_val <- NA_real_
    } else {
      key <- paste(dd_cells$ref_area[i], dd_cells$sheet[i], dd_cells$column[i], ref_label, sep = "\t")
      ref_val <- unname(map_value[key])
      if (length(ref_val) == 0) ref_val <- NA_real_
    }
    own_raw <- dd_cells$raw_value[i]
    own_num <- if (own_raw == "") NA_real_ else suppressWarnings(as.numeric(own_raw))
    if (is.na(own_num) && is.na(ref_val)) {
      next
    }
    if (is.na(own_num) || is.na(ref_val)) {
      dd_result[i] <- "ASSERT_FAIL"
      next
    }
    implied <- if (op == "EQUALS") ref_val else (1 - ref_val)
    dd_data_value[i] <- fmt_num(implied)
    deviation <- own_num - implied
    if (abs(deviation) > tol + 1e-9) dd_result[i] <- "ASSERT_FAIL"
  }

  skipped_cells <- cells[cells$class == "skipped", , drop = FALSE]

  report_rows <- dplyr::bind_rows(
    tibble::tibble(
      ref_area = skipped_cells$ref_area, sheet = skipped_cells$sheet,
      legacy_label = skipped_cells$legacy_label, column = skipped_cells$column,
      class = skipped_cells$class, result = "OK",
      source_value = skipped_cells$raw_value, data_value = "", row_key = ""
    ),
    tibble::tibble(
      ref_area = dd_cells$ref_area, sheet = dd_cells$sheet,
      legacy_label = dd_cells$legacy_label, column = dd_cells$column,
      class = dd_cells$class, result = dd_result,
      source_value = dd_cells$raw_value, data_value = dd_data_value, row_key = ""
    ),
    tibble::tibble(
      ref_area = erows$ref_area, sheet = erows$sheet,
      legacy_label = erows$legacy_label, column = erows$column,
      class = erows$class, result = result,
      source_value = erows$raw_value, data_value = data_value, row_key = erows$row_key
    )
  )
  report_rows <- report_rows[order(
    report_rows$ref_area, report_rows$sheet, report_rows$column, report_rows$legacy_label
  ), ]

  expected_keys <- unique(erows$row_key)
  if (!is.null(data_all) && nrow(data_all) > 0) {
    orphan_mask <- !(data_all$row_key %in% expected_keys)
    orphans <- tibble::tibble(
      ref_area = data_all$.ref_area[orphan_mask],
      row_key = data_all$row_key[orphan_mask],
      obs_value = data_all$OBS_VALUE[orphan_mask]
    )
  } else {
    orphans <- tibble::tibble(ref_area = character(0), row_key = character(0), obs_value = character(0))
  }

  class_counts <- as.data.frame(table(
    ref_area = cells$ref_area, sheet = cells$sheet, class = cells$class
  ), stringsAsFactors = FALSE)
  class_counts <- class_counts[class_counts$Freq > 0, ]

  result_counts <- as.data.frame(table(
    ref_area = report_rows$ref_area, sheet = report_rows$sheet, result = report_rows$result
  ), stringsAsFactors = FALSE)
  result_counts <- result_counts[result_counts$Freq > 0, ]

  list(
    report_rows = report_rows,
    orphans = orphans,
    missing_files = missing_files,
    class_counts = class_counts,
    result_counts = result_counts
  )
}

#' Render the Markdown reconciliation report.
#'
#' @param res The list returned by [reconcile()].
#' @return A character vector of lines.
reconcile_report_md <- function(res) {
  lines <- c("# Reconciliation report", "")

  if (length(res$missing_files) > 0) {
    lines <- c(lines, "## Missing data files", "")
    lines <- c(lines, paste0("- ", res$missing_files))
    lines <- c(lines, "")
  }

  lines <- c(lines, "## Class counts (per country and sheet)", "")
  cc <- res$class_counts[order(res$class_counts$ref_area, res$class_counts$sheet, res$class_counts$class), ]
  for (i in seq_len(nrow(cc))) {
    lines <- c(lines, sprintf(
      "- %s / %s: %s = %d", cc$ref_area[i], cc$sheet[i], cc$class[i], cc$Freq[i]
    ))
  }
  lines <- c(lines, "")

  lines <- c(lines, "## Result counts (per country and sheet)", "")
  rc <- res$result_counts[order(res$result_counts$ref_area, res$result_counts$sheet, res$result_counts$result), ]
  for (i in seq_len(nrow(rc))) {
    lines <- c(lines, sprintf(
      "- %s / %s: %s = %d", rc$ref_area[i], rc$sheet[i], rc$result[i], rc$Freq[i]
    ))
  }
  if (nrow(res$orphans) > 0) {
    orphan_counts <- as.data.frame(table(ref_area = res$orphans$ref_area), stringsAsFactors = FALSE)
    for (i in seq_len(nrow(orphan_counts))) {
      lines <- c(lines, sprintf("- %s / (data file): ORPHAN = %d", orphan_counts$ref_area[i], orphan_counts$Freq[i]))
    }
  }
  lines <- c(lines, "")

  lines <- c(lines, "## First problems of each kind", "")
  problem_kinds <- c("MISMATCH", "MISSING_ROW", "DUPLICATE_ROW", "WITHHELD_PRESENT", "ASSERT_FAIL")
  for (kind in problem_kinds) {
    sub <- res$report_rows[res$report_rows$result == kind, , drop = FALSE]
    if (nrow(sub) == 0) next
    lines <- c(lines, paste0("### ", kind, " (", nrow(sub), ")"), "")
    sub <- utils::head(sub, 10)
    for (i in seq_len(nrow(sub))) {
      lines <- c(lines, sprintf(
        "- %s / %s / %s / `%s`: source=%s data=%s key=%s",
        sub$ref_area[i], sub$sheet[i], sub$legacy_label[i], sub$column[i],
        sub$source_value[i], sub$data_value[i], sub$row_key[i]
      ))
    }
    lines <- c(lines, "")
  }
  if (nrow(res$orphans) > 0) {
    lines <- c(lines, paste0("### ORPHAN (", nrow(res$orphans), ")"), "")
    sub <- utils::head(res$orphans, 10)
    for (i in seq_len(nrow(sub))) {
      lines <- c(lines, sprintf("- %s: obs_value=%s key=%s", sub$ref_area[i], sub$obs_value[i], sub$row_key[i]))
    }
    lines <- c(lines, "")
  }

  passed <- length(res$missing_files) == 0 &&
    all(res$report_rows$result == "OK") &&
    nrow(res$orphans) == 0
  lines <- c(lines, if (passed) "RECONCILIATION: PASS" else "RECONCILIATION: FAIL")
  lines
}
