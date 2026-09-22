# pipeline/tests/testthat/helper-data-fixture.R
#
# testthat auto-sources every helper-*.R file before running any test file
# (see helper-temp-root.R). make_data_fixture() builds a synthetic data file
# and manifest for a country from required_rows() (pipeline/R/plan.R), so
# every wave-3 package can test against realistic data without re-deriving
# the required rows themselves. Needs read_std_csv()/write_std_csv()/
# load_metadata()/repo_path() (pipeline/R/io.R), edit_csv()
# (helper-temp-root.R), required_rows() (pipeline/R/plan.R) and
# KEY_COLUMNS/DSD_COLUMNS/DATAFLOW_ID (pipeline/R/constants.R) to already be
# sourced by the time it is called.

#' Build a synthetic data file and manifest for a country.
#'
#' @param tmp_root A temporary root that already holds `metadata/` (for
#'   example from [make_temp_root()]).
#' @param ref_area A country code, e.g. `"SEN"`.
#' @param time_period A time period string. Default `"2021"`.
#' @param series_ids If given, `metadata/plans/SERIES_PLAN.csv` under
#'   `tmp_root` is first reduced to these `series_id` values.
#' @param value The `OBS_VALUE` written on every row. Default `"0.5"`.
#' @return The path of the data file written under `tmp_root/data/`.
make_data_fixture <- function(tmp_root, ref_area, time_period = "2021",
                               series_ids = NULL, value = "0.5") {
  series_plan_path <- file.path(tmp_root, "metadata", "plans", "SERIES_PLAN.csv")

  if (!is.null(series_ids)) {
    edit_csv(series_plan_path, function(df) {
      df[df$series_id %in% series_ids, , drop = FALSE]
    })
  }

  meta <- load_metadata(tmp_root)
  rows <- required_rows(meta, ref_area, time_period)

  data <- rows[KEY_COLUMNS]
  data$OBS_VALUE <- value
  data$OBS_STATUS <- "A"
  data$STD_ERR <- ""
  data$CI_LOWER <- ""
  data$CI_UPPER <- ""
  data$N_OBS <- ""
  data$N_POP <- ""
  data$OBS_COMMENT <- ""
  data <- data[DSD_COLUMNS]

  stem <- paste0(DATAFLOW_ID, "_", ref_area, "_", time_period)
  data_path <- file.path(tmp_root, "data", paste0(stem, ".csv"))
  manifest_path <- file.path(tmp_root, "data", paste0(stem, "_manifest.csv"))

  write_std_csv(data, data_path)

  # The 16 manifest keys (WP08.md step 4). Descriptive fields this helper
  # cannot know from its inputs are TBD (COMMON.md section 4); the three
  # fields the card fixes are set as specified.
  manifest <- data.frame(
    dataflow = DATAFLOW_ID,
    dsd_version = "TBD",
    metadata_version = "TBD",
    ref_area = ref_area,
    time_period = time_period,
    source_type = "SURVEY",
    survey_id = "TBD",
    precision = "ROUNDED_2DP",
    file_name = basename(data_path),
    n_rows = as.character(nrow(data)),
    producer = "TBD",
    program = "TBD",
    software = "TBD",
    run_timestamp = "TBD",
    status = "DRAFT",
    notes = "",
    stringsAsFactors = FALSE
  )
  write_std_csv(manifest, manifest_path)

  data_path
}
