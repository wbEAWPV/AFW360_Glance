# pipeline/tests/testthat/helper-data-fixture.R
#
# testthat auto-sources every helper-*.R file before running any test file
# (see helper-temp-root.R). make_data_fixture() builds a synthetic data file
# and manifest for a country from required_rows() (pipeline/R/plan.R), so
# every validator test can run against realistic data without re-deriving
# the required rows themselves. Needs read_std_csv()/write_std_csv()/
# write_sdmx_csv()/load_metadata()/dsd_components() (pipeline/R/io.R),
# edit_csv() (helper-temp-root.R), required_rows() (pipeline/R/plan.R) and
# DATAFLOW_ID/SDMX_CSV_FIXED/structure_id() (pipeline/R/constants.R) to
# already be sourced by the time it is called.
#
# The fixture follows DSD 0.3.0 as SDMX-CSV 2.1: 37 columns (STRUCTURE,
# STRUCTURE_ID, ACTION = R, then the 34 components, FREQ = A), a file named
# AFW360_HH_<REF_AREA>_<TIME_PERIOD>_<ESTIMATION>.csv, and by default it
# looks like a legacy conversion - every row's SOURCE_ID is the country's
# LEGACY_CONVERSION source in SOURCES.csv and its PRECISION is 0.01 x the
# series' LEGACY_LABELS scale, with no reliability attributes.

# The manifest keys (pipeline/R/manifest.R's MANIFEST_KEYS, repeated here
# for a test that has not sourced manifest.R).
.FIXTURE_MANIFEST_KEYS <- c(
  "structure_id", "sdmx_csv_version", "dsd_version", "metadata_version", "ref_area", "time_period",
  "estimation", "survey_id", "sources", "file_name", "n_rows",
  "producer", "program", "software", "run_timestamp", "status", "notes"
)

#' Build a synthetic data file and manifest for a country.
#'
#' @param tmp_root A temporary root that already holds `metadata/` (for
#'   example from [make_temp_root()]).
#' @param ref_area A country code, e.g. `"SEN"`.
#' @param time_period A time period string. Default `"2021"`.
#' @param series_ids If given, `metadata/plans/SERIES_PLAN.csv` under
#'   `tmp_root` is first reduced to these `series_id` values.
#' @param value The `OBS_VALUE` written on every row. Default `"0.5"`.
#' @param estimation The file's `ESTIMATION`. Default `"SURVEY"`; a
#'   `"MODEL"` file gets `OBS_STATUS = E` on every row.
#' @param source_id The `SOURCE_ID` of every row. Default: the country's
#'   LEGACY_CONVERSION source in SOURCES.csv (`""` when there is none).
#' @param precision The `PRECISION` of every row. Default: `0.01 x scale`
#'   (LEGACY_LABELS) when the source is a LEGACY_CONVERSION, else empty.
#' @return The path of the data file written under `tmp_root/data/`.
make_data_fixture <- function(tmp_root, ref_area, time_period = "2021",
                               series_ids = NULL, value = "0.5",
                               estimation = "SURVEY", source_id = NULL,
                               precision = NULL) {
  series_plan_path <- file.path(tmp_root, "metadata", "plans", "SERIES_PLAN.csv")

  if (!is.null(series_ids)) {
    edit_csv(series_plan_path, function(df) {
      df[df$series_id %in% series_ids, , drop = FALSE]
    })
  }

  meta <- load_metadata(tmp_root)
  rows <- required_rows(meta, ref_area, time_period, estimation)

  sources <- meta$SOURCES
  if (is.null(source_id)) {
    hit <- if (is.null(sources)) integer(0) else
      which(sources$kind == "LEGACY_CONVERSION" & sources$ref_area == ref_area)
    source_id <- if (length(hit) > 0) sources$source_id[hit[1]] else ""
  }
  kind <- if (is.null(sources)) NA_character_ else sources$kind[match(source_id, sources$source_id)]

  if (is.null(precision)) {
    if (identical(kind, "LEGACY_CONVERSION")) {
      ll <- meta$LEGACY_LABELS
      scale <- rep(1, nrow(rows))
      if (!is.null(ll)) {
        ll <- ll[!is.na(ll$series_id) & ll$series_id != "" & !is.na(suppressWarnings(as.numeric(ll$scale))), ]
        s <- suppressWarnings(as.numeric(ll$scale[match(rows$series_id, ll$series_id)]))
        scale[!is.na(s)] <- s[!is.na(s)]
      }
      precision <- fmt_num(0.01 * scale)
    } else {
      precision <- ""
    }
  }

  unit <- rep("", nrow(rows))
  ind <- meta$CL_INDICATOR
  if (!is.null(ind) && "unit_measure" %in% names(ind)) {
    unit <- ind$unit_measure[match(rows$INDICATOR, ind$code)]
    area <- meta$CL_AREA
    lcu <- !is.na(unit) & unit == "LCU"
    if (!is.null(area)) unit[lcu] <- area$currency[match(ref_area, area$code)]
    unit[is.na(unit)] <- ""
  }

  if (is.null(meta$DSD_AFW360_HH)) {
    stop("make_data_fixture: metadata/structure/DSD_AFW360_HH.csv is missing", call. = FALSE)
  }
  columns <- dsd_components(meta)
  key_cols <- setdiff(names(rows), c("series_id", "cut_id", "defining_breakdown", "DATAFLOW"))
  data <- rows[key_cols]
  data$FREQ <- "A"
  data$SERIES_ID <- rows$series_id
  data$OBS_VALUE <- value
  data$UNIT_MEASURE <- unit
  data$PRECISION <- precision
  data$OBS_STATUS <- if (identical(estimation, "MODEL")) "E" else "A"
  data$STD_ERR <- ""
  data$CI_LOWER <- ""
  data$CI_UPPER <- ""
  data$N_OBS <- ""
  data$N_POP <- ""
  data$N_OBS_NUM <- ""
  data$DEFF <- ""
  data$DF <- ""
  data$SOURCE_ID <- source_id
  data$OBS_COMMENT <- ""
  data <- data[columns]

  stem <- paste0(DATAFLOW_ID, "_", ref_area, "_", time_period, "_", estimation)
  data_path <- file.path(tmp_root, "data", paste0(stem, ".csv"))
  manifest_path <- file.path(tmp_root, "data", paste0(stem, "_manifest.csv"))

  # The manifest in its long form (one `key`, `value` row per key), as
  # build_ctx() (pipeline/R/ctx.R) reads it. Descriptive fields the helper
  # cannot know are TBD.
  surveys <- meta$SURVEYS
  survey_id <- "TBD"
  if (!is.null(surveys)) {
    hit <- which(surveys$ref_area == ref_area)
    if (length(hit) > 0) survey_id <- surveys$survey_id[hit[1]]
  }
  version <- "TBD"
  vf <- file.path(tmp_root, "metadata", "VERSION")
  if (file.exists(vf)) version <- trimws(readLines(vf, warn = FALSE)[1])
  write_sdmx_csv(data, data_path, version)

  values <- c(
    structure_id = structure_id(version), sdmx_csv_version = "2.1.0",
    dsd_version = version, metadata_version = version,
    ref_area = ref_area, time_period = time_period, estimation = estimation,
    survey_id = survey_id, sources = source_id, file_name = basename(data_path),
    n_rows = as.character(nrow(data)), producer = "TBD", program = "TBD",
    software = "TBD", run_timestamp = "TBD", status = "DRAFT", notes = ""
  )
  manifest <- data.frame(
    key = .FIXTURE_MANIFEST_KEYS,
    value = unname(values[.FIXTURE_MANIFEST_KEYS]),
    stringsAsFactors = FALSE
  )
  write_std_csv(manifest, manifest_path)

  data_path
}
