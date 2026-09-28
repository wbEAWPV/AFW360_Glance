#!/usr/bin/env Rscript
# pipeline/reconcile.R
#
# WP16 - Independent reconciliation tool. A second, independent path from
# data/AFW360_HH_<ISO3>_<YEAR>_SURVEY.csv back to data_raw/tables/Tables_<ISO3>.xlsx,
# built entirely from the legacy maps (never from the converter). Proves
# every source cell is accounted for exactly once, and every converted
# value matches its cell.
#
#   Rscript pipeline/reconcile.R --root . --out <report.md> [--csv <cells.csv>]
#
# Run from the repo root. Reconciles every country found in
# metadata/plans/LEGACY_COLUMNS.csv. Exits 0 only when every result is OK,
# there is no ORPHAN, and the class counts per country add up to the
# number of source cells. Exits 1 otherwise. Exits 2 when a data file is
# missing.

.args <- commandArgs(trailingOnly = TRUE)

.root_idx <- which(.args == "--root")
.root_raw <- if (length(.root_idx) >= 1) .args[.root_idx[1] + 1] else "."
root <- normalizePath(.root_raw, winslash = "/", mustWork = TRUE)

source(file.path(root, "pipeline", "R", "io.R"))
source(file.path(root, "pipeline", "R", "codes.R"))
source(file.path(root, "pipeline", "R", "reconcile.R"))

out_path <- cli_arg(.args, "--out", NULL)
csv_path <- cli_arg(.args, "--csv", NULL)

if (is.null(out_path)) {
  stop("pipeline/reconcile.R: --out <report.md> is required", call. = FALSE)
}

res <- reconcile(root)

md <- reconcile_report_md(res)
dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
writeLines(md, out_path, useBytes = TRUE)

if (!is.null(csv_path)) {
  csv_cols <- c(
    "ref_area", "sheet", "legacy_label", "column", "class", "result",
    "source_value", "data_value", "row_key"
  )
  write_std_csv(res$report_rows[, csv_cols], csv_path)
}

if (length(res$missing_files) > 0) {
  message(
    "pipeline/reconcile.R: missing data file(s):\n",
    paste0("  ", res$missing_files, collapse = "\n")
  )
  quit(status = 2, save = "no")
}

passed <- all(res$report_rows$result == "OK") && nrow(res$orphans) == 0
quit(status = if (passed) 0L else 1L, save = "no")
