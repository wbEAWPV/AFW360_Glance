# pipeline/R/manifest.R
#
# Names a converted data file and builds its
# `AFW360_HH_<ISO3>_<YEAR>_<ESTIMATION>_manifest.csv` sidecar (card WP15,
# "Manifest"; standard v0.5, "Manifest").

#' The manifest's 16 keys, in order (metadata 0.2.0).
MANIFEST_KEYS <- c(
  "dataflow", "dsd_version", "metadata_version", "ref_area", "time_period",
  "estimation", "survey_id", "sources", "file_name", "n_rows",
  "producer", "program", "software", "run_timestamp", "status", "notes"
)

#' The base name of a data file.
#'
#' `constants.R` must already be sourced (for [DATAFLOW_ID]).
#'
#' @param country The country code (`REF_AREA`).
#' @param time_period The year (`TIME_PERIOD`).
#' @param estimation The estimation method (`ESTIMATION`), e.g. `"SURVEY"`.
#' @return `AFW360_HH_<REF_AREA>_<TIME_PERIOD>_<ESTIMATION>.csv`.
data_file_name <- function(country, time_period, estimation) {
  sprintf("%s_%s_%s_%s.csv", DATAFLOW_ID, country, time_period, estimation)
}

#' The base name of a data file's manifest.
#'
#' @param file_name The data file's base name, from [data_file_name()].
#' @return The same name with `_manifest` before `.csv`.
manifest_file_name <- function(file_name) {
  sub("\\.csv$", "_manifest.csv", file_name)
}

#' Build a data file's manifest.
#'
#' `constants.R` must already be sourced (for [DATAFLOW_ID]).
#'
#' @param country The country code (`ref_area`).
#' @param time_period The survey year.
#' @param estimation The file's `ESTIMATION` code.
#' @param survey_id The survey identifier.
#' @param source_ids The `SOURCE_ID` values of the file's rows; written as
#'   the distinct values, sorted, space-separated.
#' @param file_name The data file's base name.
#' @param n_rows The data file's row count.
#' @param metadata_version The content of `metadata/VERSION`.
#' @param run_timestamp The run's UTC timestamp, ISO 8601.
#' @return A data frame with columns `key`, `value`, in [MANIFEST_KEYS]
#'   order.
build_manifest <- function(country, time_period, estimation, survey_id, source_ids,
                            file_name, n_rows, metadata_version, run_timestamp) {
  source_ids <- source_ids[!is.na(source_ids) & source_ids != ""]
  sources <- paste(sort(unique(source_ids), method = "radix"), collapse = " ")
  values <- c(
    dataflow = DATAFLOW_ID,
    dsd_version = metadata_version,
    metadata_version = metadata_version,
    ref_area = country,
    time_period = time_period,
    estimation = estimation,
    survey_id = survey_id,
    sources = sources,
    file_name = file_name,
    n_rows = as.character(n_rows),
    producer = "AFW DIP/POV team",
    program = "pipeline/convert_legacy.R",
    software = paste0("R ", R.version$major, ".", R.version$minor),
    run_timestamp = run_timestamp,
    status = "DRAFT",
    notes = paste0("Legacy conversion of data_raw/tables/Tables_", country, ".xlsx")
  )
  data.frame(
    key = MANIFEST_KEYS,
    value = unname(values[MANIFEST_KEYS]),
    stringsAsFactors = FALSE
  )
}
