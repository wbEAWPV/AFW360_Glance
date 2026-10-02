#!/usr/bin/env Rscript
# 20-excel-sdmx-csv/reconcile.R
#
# WP16 - Independent reconciliation tool. A second, independent path from
# the published data/AFW360_HH_<ISO3>_<YEAR>_SURVEY.csv (SDMX-CSV 2.1,
# 30-sdmx/data/) back to data_raw/tables/Tables_<ISO3>.xlsx (the frozen
# legacy inputs), built entirely from the legacy maps (never from the
# converter). Proves every source cell is accounted for exactly once, and
# every converted value matches its cell. Locations: R/paths.R
# (--sdmx-dir points at another SDMX stage, for example a rebuild).
#
#   Rscript reconcile.R --out <report.md> [--csv <cells.csv>] [--root <dir>]
#
# Run from 20-excel-sdmx-csv/. Reconciles every country found in
# plans/LEGACY_COLUMNS.csv. Exits 0 only when every result is OK,
# there is no ORPHAN, and the class counts per country add up to the
# number of source cells. Exits 1 otherwise. Exits 2 when a data file is
# missing.

.args <- commandArgs(trailingOnly = TRUE)

.script_dir <- function() {
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
  dirname(normalizePath(f, winslash = "/", mustWork = TRUE))
}
source(file.path(.script_dir(), "R", "paths.R"))
paths <- stage_paths_from_args(.args, default_root = .script_dir())

source(stage_path(paths, "code", "codes.R"))
source(stage_path(paths, "code", "reconcile.R"))

# Own flag reader (the tool shares no helpers with the pipeline).
.flag_value <- function(flag) {
  i <- which(.args == flag)
  if (length(i) == 0 || i[1] >= length(.args)) return(NULL)
  .args[i[1] + 1]
}
out_path <- .flag_value("--out")
csv_path <- .flag_value("--csv")

if (is.null(out_path)) {
  stop("reconcile.R: --out <report.md> is required", call. = FALSE)
}

res <- reconcile(paths)

md <- reconcile_report_md(res)
dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
writeLines(md, out_path, useBytes = TRUE)

if (!is.null(csv_path)) {
  csv_cols <- c(
    "ref_area", "sheet", "legacy_label", "column", "class", "result",
    "source_value", "data_value", "row_key"
  )
  cells_out <- as.data.frame(res$report_rows[, csv_cols])
  cells_out[] <- lapply(cells_out, function(x) { x <- as.character(x); x[is.na(x)] <- ""; x })
  dir.create(dirname(csv_path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(cells_out, csv_path, na = "", eol = "
")
}

if (length(res$missing_files) > 0) {
  message(
    "reconcile.R: missing data file(s):\n",
    paste0("  ", res$missing_files, collapse = "\n")
  )
  quit(status = 2, save = "no")
}

passed <- all(res$report_rows$result == "OK") && nrow(res$orphans) == 0
quit(status = if (passed) 0L else 1L, save = "no")
