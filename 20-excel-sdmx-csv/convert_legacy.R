#!/usr/bin/env Rscript
# pipeline/convert_legacy.R
#
# WP15 (Legacy converter): turns data_raw/tables/Tables_<ISO3>.xlsx into
# data/AFW360_HH_<ISO3>_<YEAR>_SURVEY.csv and its manifest, driven entirely by
# the LEGACY_LABELS, LEGACY_COLUMNS, LEGACY_OVERRIDES and SERIES_PLAN metadata
# plans, with the columns read from DSD_AFW360_HH.csv (DSD 0.3.0). The file is
# SDMX-CSV 2.1: STRUCTURE, STRUCTURE_ID, ACTION = R, then the 34 components.
# Every row carries FREQ = A, ESTIMATION = SURVEY and the country's
# LEGACY_CONVERSION source from SOURCES.csv; an empty cell is OBS_VALUE = NaN
# with OBS_STATUS = O. See .docs/transition.qmd and .docs/data-standard.qmd.
#
# Usage: Rscript pipeline/convert_legacy.R --root <dir> --country SEN|GNB|ALL [--timestamp <ISO8601>] [--out-root <dir>]

args <- commandArgs(trailingOnly = TRUE)

.arg <- function(args, flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) == 0 || idx[1] >= length(args)) {
    return(default)
  }
  args[idx[1] + 1]
}

USAGE <- paste(
  "Usage: Rscript pipeline/convert_legacy.R --root <dir> --country SEN|GNB|ALL",
  "[--timestamp <ISO8601>] [--out-root <dir>]"
)

root <- .arg(args, "--root", ".")
source(file.path(root, "pipeline", "R", "io.R"))
source(file.path(root, "pipeline", "R", "codes.R"))
source(file.path(root, "pipeline", "R", "constants.R"))
source(file.path(root, "pipeline", "R", "convert_tables.R"))
source(file.path(root, "pipeline", "R", "manifest.R"))

out_root <- cli_arg(args, "--out-root", root)
country_arg <- cli_arg(args, "--country")
timestamp_arg <- cli_arg(args, "--timestamp")

if (is.null(country_arg)) {
  stop(USAGE, call. = FALSE)
}

run_timestamp <- if (is.null(timestamp_arg)) {
  format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ")
} else {
  timestamp_arg
}

meta <- load_metadata(root)
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

countries_all <- sort(unique(meta$LEGACY_COLUMNS$ref_area))
if (identical(country_arg, "ALL")) {
  countries <- countries_all
} else if (country_arg %in% countries_all) {
  countries <- country_arg
} else {
  stop(USAGE, call. = FALSE)
}

metadata_version <- trimws(readLines(repo_path(root, "metadata", "VERSION"), warn = FALSE)[1])
estimation <- "SURVEY"
key_cols <- dsd_key_columns(meta)

for (country in countries) {
  workbook_path <- repo_path(root, "data_raw", "tables", sprintf("Tables_%s.xlsx", country))
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
  data_path <- repo_path(out_root, "data", file_name)
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
  manifest_path <- repo_path(out_root, "data", manifest_name)
  write_std_csv(manifest, manifest_path)

  cat(
    "convert_legacy: wrote ", data_path, " (", nrow(rows), " rows) and ", manifest_path, "\n",
    sep = ""
  )
}
