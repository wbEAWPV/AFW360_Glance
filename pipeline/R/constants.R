# pipeline/R/constants.R
#
# Fixed identifiers shared by every pipeline script: the maintenance agency
# and dataflow ids, the SDMX-CSV 2.1 fixed columns and action, and the
# reserved sentinel and TBD codes.
#
# The component list is authoritative in metadata/structure/DSD_AFW360_HH.csv;
# code reads it through dsd_components(), data_columns() and
# dsd_key_columns() (pipeline/R/io.R). No column list is hard-coded here.

#' The SDMX maintenance agency of the dataflow and its structures.
AGENCY_ID <- "WB.AFW360"

#' The dataflow identifier used throughout the pipeline and its outputs.
DATAFLOW_ID <- "AFW360_HH"

#' The three fixed leading columns of an SDMX-CSV 2.1 data file, in order.
#' They are not DSD components.
SDMX_CSV_FIXED <- c("STRUCTURE", "STRUCTURE_ID", "ACTION")

#' The `ACTION` of every published row (SDMX-CSV 2.1 "replace"; D38).
ACTION_PUBLISHED <- "R"

#' The SDMX-CSV `STRUCTURE_ID` of the dataflow at a metadata version.
#'
#' @param version The content of `metadata/VERSION`, e.g. `"0.3.0"`.
#' @return `WB.AFW360:AFW360_HH(<version>)`.
structure_id <- function(version) {
  sprintf("%s:%s(%s)", AGENCY_ID, DATAFLOW_ID, version)
}

#' The reserved "total" sentinel code.
SENTINEL_TOTAL <- "_T"

#' The reserved "not applicable" sentinel code.
SENTINEL_NA <- "_Z"

#' The five reserved SDMX sentinels (standard, "The two sentinels"; D21).
#' No codelist code may start with `_`.
SENTINELS <- c("_T", "_Z", "_U", "_O", "_X")

#' The placeholder used in a required text column when a value cannot be
#' known from the inputs (.docs/data-standard.qmd).
TBD <- "TBD"
