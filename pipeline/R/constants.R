# pipeline/R/constants.R
#
# Fixed identifiers shared by every pipeline script: the dataflow id, the
# reserved sentinel and TBD codes, and the AFW360_HH data structure's
# column list.

#' The dataflow identifier used throughout the pipeline and its outputs.
DATAFLOW_ID <- "AFW360_HH"

#' The reserved "total" sentinel code.
SENTINEL_TOTAL <- "_T"

#' The reserved "not applicable" sentinel code.
SENTINEL_NA <- "_Z"

#' The placeholder used in a required text column when a value cannot be
#' known from the inputs (COMMON.md section 4).
TBD <- "TBD"

#' The 26 columns of the AFW360_HH data structure, in order.
DSD_COLUMNS <- c(
  "DATAFLOW",
  "REF_AREA",
  "GEO",
  "TIME_PERIOD",
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
  "OBS_VALUE",
  "OBS_STATUS",
  "STD_ERR",
  "CI_LOWER",
  "CI_UPPER",
  "N_OBS",
  "N_POP",
  "OBS_COMMENT"
)

#' The key columns of the AFW360_HH data structure: the first 18 of
#' [DSD_COLUMNS], from `DATAFLOW` to `MEASURE_QUAL_5`.
KEY_COLUMNS <- DSD_COLUMNS[1:18]
