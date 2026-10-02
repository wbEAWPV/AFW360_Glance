# 20-excel-sdmx-csv/R/plans_check.R
#
# Checks of the legacy plans under plans/ (TAB_PLAN.csv, LEGACY_LABELS.csv,
# LEGACY_COLUMNS.csv, LEGACY_OVERRIDES.csv) against their register
# plans/PLAN_COLUMNS.csv and against the standard's metadata they point
# into (30-sdmx/data/metadata/, R/paths.R). These are the META checks the
# SDMX stage ran on them while they lived under metadata/plans/: header
# shape, required columns, references, TBD tracking. convert_legacy.R
# refuses to run on plans with an ERROR, and tests/testthat/test-plans.R
# runs the check on the committed plans.
#
# Depends on io.R (read_std_csv(), load_metadata()), constants.R (TBD) and
# paths.R.

# The column(s) that identify a row of each plan, for the row_key.
.PLANS_KEY_MAP <- list(
  LEGACY_LABELS = c("legacy_label", "sheet"),
  LEGACY_COLUMNS = c("ref_area", "sheet", "column"),
  LEGACY_OVERRIDES = c("ref_area", "sheet", "column", "legacy_label"),
  TAB_PLAN = c("cut_id", "ref_area"),
  PLAN_COLUMNS = c("file", "column")
)

# References from a plan into the standard (or into another plan):
# source stem, source column, target stem, target column.
.PLANS_REFERENCES <- data.frame(
  src = c("LEGACY_LABELS", "LEGACY_COLUMNS", "LEGACY_COLUMNS", "LEGACY_COLUMNS", "LEGACY_COLUMNS"),
  src_col = c("series_id", "GEO", "URBANISATION", "COMP_BREAKDOWN", "cut_id"),
  tgt = c("SERIES_PLAN", "CL_GEO", "CL_URBANISATION", "CL_COMP_BREAKDOWN", "TAB_PLAN"),
  tgt_col = c("series_id", "code", "code", "code", "cut_id"),
  stringsAsFactors = FALSE
)

.plans_finding <- function(check_id, severity, file, row_key, message) {
  data.frame(
    check_id = check_id, severity = severity, file = file, row_key = row_key,
    message = message, stringsAsFactors = FALSE
  )
}

.plans_row_key <- function(stem, df, i) {
  cols <- .PLANS_KEY_MAP[[stem]]
  cols <- cols[cols %in% names(df)]
  if (length(cols) == 0) cols <- names(df)[1]
  vals <- as.character(unlist(df[i, cols]))
  paste(paste0(cols, "=", vals), collapse = " ")
}

#' Check the legacy plans.
#'
#' @param root The stage folder, or a `stage_paths` object.
#' @param meta The tables, as from [load_metadata()] (default: loaded from
#'   `root`): the plans and the standard's metadata.
#' @return A data frame of findings (check_id, severity, file, row_key,
#'   message), sorted; zero rows when the plans are clean. Check ids:
#'   PLANS.MISSING (a file of the register is absent, or a plan CSV has no
#'   register rows), PLANS.HEADER, PLANS.REQUIRED, PLANS.REFERENCE and
#'   PLANS.TBD (WARN on a DRAFT row, ERROR otherwise).
plans_check <- function(root, meta = load_metadata(root)) {
  out <- list()
  add <- function(...) out[[length(out) + 1]] <<- .plans_finding(...)
  plan_dir <- stage_dir(root, "plans")
  reg <- meta$PLAN_COLUMNS
  if (is.null(reg)) {
    add("PLANS.MISSING", "ERROR", "plans/PLAN_COLUMNS.csv", "", "the register of the plans is missing")
    return(do.call(rbind, out))
  }
  on_disk <- sort(list.files(plan_dir, pattern = "[.]csv$"), method = "radix")
  for (f in setdiff(on_disk, unique(reg$file))) {
    add("PLANS.MISSING", "ERROR", paste0("plans/", f), "", "plan CSV has no rows in PLAN_COLUMNS.csv")
  }
  for (f in unique(reg$file)) {
    stem <- tools::file_path_sans_ext(f)
    rel <- paste0("plans/", f)
    df <- meta[[stem]]
    if (is.null(df) || !file.exists(file.path(plan_dir, f))) {
      add("PLANS.MISSING", "ERROR", rel, "", "file listed in PLAN_COLUMNS.csv is missing from plans/")
      next
    }
    spec <- reg[reg$file == f, , drop = FALSE]
    spec <- spec[order(as.integer(spec$position), method = "radix"), , drop = FALSE]
    if (!identical(names(df), spec$column)) {
      add("PLANS.HEADER", "ERROR", rel, "", paste0(
        "header does not match PLAN_COLUMNS.csv: expected [", paste(spec$column, collapse = ", "),
        "], found [", paste(names(df), collapse = ", "), "]"
      ))
    }
    req <- spec$column[spec$status == "R"]
    req <- req[req %in% names(df)]
    for (i in seq_len(nrow(df))) {
      if (length(req) > 0) {
        vals <- as.character(unlist(df[i, req]))
        miss <- req[is.na(vals) | trimws(vals) == ""]
        if (length(miss) > 0) {
          add("PLANS.REQUIRED", "ERROR", rel, .plans_row_key(stem, df, i),
            paste0("required column(s) empty: ", paste(miss, collapse = ", ")))
        }
      }
      if ("status" %in% names(df)) {
        vals <- as.character(unlist(df[i, ]))
        tbd <- names(df)[!is.na(vals) & vals == TBD]
        if (length(tbd) > 0) {
          sev <- if (!is.na(df$status[i]) && df$status[i] == "DRAFT") "WARN" else "ERROR"
          add("PLANS.TBD", sev, rel, .plans_row_key(stem, df, i),
            paste0("TBD in column(s): ", paste(tbd, collapse = ", ")))
        }
      }
    }
  }
  for (k in seq_len(nrow(.PLANS_REFERENCES))) {
    r <- .PLANS_REFERENCES[k, ]
    df <- meta[[r$src]]
    tgt <- meta[[r$tgt]]
    if (is.null(df) || nrow(df) == 0 || !(r$src_col %in% names(df))) next
    rel <- paste0("plans/", r$src, ".csv")
    if (is.null(tgt) || !(r$tgt_col %in% names(tgt))) {
      add("PLANS.REFERENCE", "ERROR", rel, "", paste0(
        r$src_col, " cannot be checked: ", r$tgt, ".", r$tgt_col, " is not loaded"
      ))
      next
    }
    for (i in seq_len(nrow(df))) {
      val <- trimws(df[[r$src_col]][i])
      if (is.na(val) || val == "" || val %in% c("_T", "_Z")) next
      if (!(val %in% tgt[[r$tgt_col]])) {
        add("PLANS.REFERENCE", "ERROR", rel, .plans_row_key(r$src, df, i), paste0(
          r$src_col, " references unknown ", r$tgt, ".", r$tgt_col, ": ", val
        ))
      }
    }
  }
  if (length(out) == 0) {
    return(.plans_finding(character(0), character(0), character(0), character(0), character(0)))
  }
  res <- do.call(rbind, out)
  res[order(res$check_id, res$file, res$row_key, method = "radix"), , drop = FALSE]
}
