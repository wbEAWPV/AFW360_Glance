#!/usr/bin/env Rscript
# 20-excel-sdmx-csv/convert_legacy.R
#
# WP15 (Legacy converter): turns data_raw/tables/Tables_<ISO3>.xlsx (the
# frozen legacy inputs, 10-legacy-pipeline/data_raw/) into
# AFW360_HH_<ISO3>_<YEAR>_SURVEY.csv and its manifest under the output
# folder's data/, driven entirely by the LEGACY_LABELS, LEGACY_COLUMNS and
# LEGACY_OVERRIDES plans of this stage (plans/) and the standard's
# SERIES_PLAN, with the columns read from DSD_AFW360_HH.csv (DSD 0.3.0; the
# standard is read from 30-sdmx/data/metadata/). The file is SDMX-CSV 2.1:
# STRUCTURE, STRUCTURE_ID, ACTION = R, then the 34 components. Every row
# carries FREQ = A, ESTIMATION = SURVEY and the country's LEGACY_CONVERSION
# source from SOURCES.csv; an empty cell is OBS_VALUE = NaN with
# OBS_STATUS = O. The plans are checked first (R/plans_check.R); an ERROR
# stops the run. publish.R copies the output to 30-sdmx/data/. See
# .docs/transition.qmd and .docs/data-standard.qmd. Locations: R/paths.R.
#
# Usage (from 20-excel-sdmx-csv/):
#   Rscript convert_legacy.R --country SEN|GNB|ALL [--timestamp <ISO8601>]
#     [--out-root <dir>] [--root <dir>] [--legacy-dir <dir>] [--sdmx-dir <dir>]
# --out-root is the output folder (default output/); the files go to its data/.

args <- commandArgs(trailingOnly = TRUE)

USAGE <- paste(
  "Usage: Rscript convert_legacy.R --country SEN|GNB|ALL",
  "[--timestamp <ISO8601>] [--out-root <dir>] [--root <dir>]"
)

.script_dir <- function() {
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
  dirname(normalizePath(f, winslash = "/", mustWork = TRUE))
}
source(file.path(.script_dir(), "R", "paths.R"))
paths <- stage_paths_from_args(args, default_root = .script_dir())

source(stage_path(paths, "code", "io.R"))
source(stage_path(paths, "code", "codes.R"))
source(stage_path(paths, "code", "constants.R"))
source(stage_path(paths, "code", "convert_tables.R"))
source(stage_path(paths, "code", "manifest.R"))
source(stage_path(paths, "code", "plans_check.R"))

country_arg <- cli_arg(args, "--country")
timestamp_arg <- cli_arg(args, "--timestamp")

if (is.null(country_arg)) {
  stop(USAGE, call. = FALSE)
}
out_root <- stage_out_root(args, paths)

run_timestamp <- if (is.null(timestamp_arg)) {
  format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ")
} else {
  timestamp_arg
}

meta <- load_metadata(paths)
required_tables <- c(
  "DSD_AFW360_HH", "LEGACY_LABELS", "LEGACY_COLUMNS", "LEGACY_OVERRIDES",
  "SERIES_PLAN", "SURVEYS", "SOURCES", "CL_AREA", "CL_INDICATOR", "CL_BRK_VAR",
  "CL_QUAL_VAR", "CL_COMP_BREAKDOWN", "CL_QUALIFIER"
)
missing_tables <- setdiff(required_tables, names(meta))
if (length(missing_tables) > 0) {
  stop(
    "convert_legacy: missing metadata table(s): ", paste(missing_tables, collapse = ", "),
    call. = FALSE
  )
}

plan_findings <- plans_check(paths, meta)
plan_errors <- plan_findings[plan_findings$severity == "ERROR", , drop = FALSE]
if (nrow(plan_errors) > 0) {
  for (i in seq_len(nrow(plan_errors))) {
    message(sprintf(
      "%s %s %s: %s", plan_errors$check_id[i], plan_errors$file[i],
      plan_errors$row_key[i], plan_errors$message[i]
    ))
  }
  stop("convert_legacy: the plans under plans/ have ", nrow(plan_errors), " error(s)", call. = FALSE)
}

countries_all <- sort(unique(meta$LEGACY_COLUMNS$ref_area))
if (identical(country_arg, "ALL")) {
  countries <- countries_all
} else if (country_arg %in% countries_all) {
  countries <- country_arg
} else {
  stop(USAGE, call. = FALSE)
}

metadata_version <- trimws(readLines(stage_path(paths, "metadata", "VERSION"), warn = FALSE)[1])
estimation <- "SURVEY"
key_cols <- dsd_key_columns(meta)

for (country in countries) {
  workbook_path <- stage_path(paths, "data_raw", "tables", sprintf("Tables_%s.xlsx", country))
  wb <- read_legacy_workbook(workbook_path)
  rows <- build_country_rows(country, wb, meta, estimation = estimation)
  rows <- finalize_rows(rows, key_cols)
  if (!identical(names(rows), dsd_components(meta))) {
    stop("convert_legacy: the rows' columns differ from DSD_AFW360_HH", call. = FALSE)
  }

  sv <- meta$SURVEYS[meta$SURVEYS$ref_area == country, ]
  if (nrow(sv) != 1) {
    stop(
      "convert_legacy: ", country, " has ", nrow(sv),
      " SURVEYS.csv row(s) (expected exactly 1)",
      call. = FALSE
    )
  }
  time_period <- sv$time_period[1]
  survey_id <- sv$survey_id[1]

  file_name <- data_file_name(country, time_period, estimation)
  data_path <- output_path(out_root, "data", file_name)
  write_sdmx_csv(rows, data_path, metadata_version)
  written <- names(read_std_csv(data_path))
  if (!identical(written, data_columns(meta))) {
    stop("convert_legacy: ", file_name, " columns differ from data_columns()", call. = FALSE)
  }

  manifest <- build_manifest(
    country = country,
    time_period = time_period,
    estimation = estimation,
    survey_id = survey_id,
    source_ids = rows$SOURCE_ID,
    file_name = file_name,
    n_rows = nrow(rows),
    metadata_version = metadata_version,
    run_timestamp = run_timestamp
  )
  manifest_name <- manifest_file_name(file_name)
  manifest_path <- output_path(out_root, "data", manifest_name)
  write_std_csv(manifest, manifest_path)

  cat(
    "convert_legacy: wrote ", data_path, " (", nrow(rows), " rows) and ", manifest_path, "\n",
    sep = ""
  )
}
