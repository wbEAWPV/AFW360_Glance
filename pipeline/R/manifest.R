# pipeline/R/manifest.R
#
# Builds the `AFW360_HH_<ISO3>_<YEAR>_manifest.csv` sidecar for a converted
# data file (card WP15, "Manifest").

#' The manifest's 16 keys, in order.
MANIFEST_KEYS <- c(
  "dataflow", "dsd_version", "metadata_version", "ref_area", "time_period",
  "source_type", "survey_id", "precision", "file_name", "n_rows",
  "producer", "program", "software", "run_timestamp", "status", "notes"
)

#' Build a data file's manifest.
#'
#' `constants.R` must already be sourced (for [DATAFLOW_ID]).
#'
#' @param country The country code (`ref_area`).
#' @param time_period The survey year.
#' @param survey_id The survey identifier.
#' @param file_name The data file's base name.
#' @param n_rows The data file's row count.
#' @param metadata_version The content of `metadata/VERSION`.
#' @param run_timestamp The run's UTC timestamp, ISO 8601.
#' @return A data frame with columns `key`, `value`, in [MANIFEST_KEYS]
#'   order.
build_manifest <- function(country, time_period, survey_id, file_name, n_rows,
                            metadata_version, run_timestamp) {
  values <- c(
    dataflow = DATAFLOW_ID,
    dsd_version = metadata_version,
    metadata_version = metadata_version,
    ref_area = country,
    time_period = time_period,
    source_type = "SURVEY",
    survey_id = survey_id,
    precision = "ROUNDED_2DP",
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
