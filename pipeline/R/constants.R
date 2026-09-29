# pipeline/R/constants.R
#
# Fixed identifiers shared by every pipeline script: the dataflow id, the
# reserved sentinel and TBD codes, and the AFW360_HH data structure's
# column list.
#
# The column list is authoritative in metadata/structure/DSD_AFW360_HH.csv;
# code that has the metadata at hand reads it through dsd_columns() and
# dsd_key_columns() (pipeline/R/io.R). DSD_COLUMNS and KEY_COLUMNS below
# mirror DSD 0.2.0 for callers that have no metadata loaded (for example a
# hand-made test `meta`); test-plan.R checks that they still equal
# the DSD.
#' The dataflow identifier used throughout the pipeline and its outputs.
DATAFLOW_ID <- "AFW360_HH"

#' The reserved "total" sentinel code.
SENTINEL_TOTAL <- "_T"

#' The reserved "not applicable" sentinel code.
SENTINEL_NA <- "_Z"

#' The five reserved SDMX sentinels (standard, "The two sentinels"; D21).
#' No codelist code may start with `_`.
SENTINELS <- c("_T", "_Z", "_U", "_O", "_X")

#' The placeholder used in a required text column when a value cannot be
#' known from the inputs (COMMON.md section 4).
TBD <- "TBD"

#' The 31 columns of the AFW360_HH data structure (DSD 0.2.0), in order.
DSD_COLUMNS <- c(
  "DATAFLOW",
  "REF_AREA",
  "GEO",
  "TIME_PERIOD",
  "ESTIMATION",
  "INDICATOR",
  "SEX",
  "AGE",
  "URBANISATION",
  "COMP_BREAKDOWN_1",
  "COMP_BREAKDOWN_2",
  "COMP_BREAKDOWN_3",
  "COMP_BREAKDOWN_4",
  "COMP_BREAKDOWN_5",
  "MEASURE_QUAL_1",
  "MEASURE_QUAL_2",
  "MEASURE_QUAL_3",
  "MEASURE_QUAL_4",
  "MEASURE_QUAL_5",
  "SERIES_ID",
  "OBS_VALUE",
  "UNIT_MEASURE",
  "PRECISION",
  "OBS_STATUS",
  "STD_ERR",
  "CI_LOWER",
  "CI_UPPER",
  "N_OBS",
  "N_POP",
  "SOURCE_ID",
  "OBS_COMMENT"
)

#' The key columns of the AFW360_HH data structure: the first 19 of
#' [DSD_COLUMNS], from `DATAFLOW` to `MEASURE_QUAL_5`.
KEY_COLUMNS <- DSD_COLUMNS[1:19]
