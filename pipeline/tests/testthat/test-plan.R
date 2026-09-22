# pipeline/tests/testthat/test-plan.R
#
# Tests for pipeline/R/plan.R's required_rows(), and for
# make_data_fixture() (helper-data-fixture.R, auto-sourced by testthat).
#
# The other packages' metadata files do not exist on this branch yet, so
# these tests build `meta` from the contract seeds (WP08.md step 3), using
# the two plan files this package owns.

root <- find_root()
source(file.path(root, "pipeline", "R", "io.R"))
source(file.path(root, "pipeline", "R", "codes.R"))
source(file.path(root, "pipeline", "R", "constants.R"))
source(file.path(root, "pipeline", "R", "plan.R"))

contract_path <- function(...) file.path(root, ".docs", "transition", "contract", ...)

#' Build `meta` from the real contract seeds and this package's own plan
#' files (WP08.md step 3).
seed_meta_real <- function() {
  codes <- read_std_csv(contract_path("codes.csv"))
  geo <- read_std_csv(contract_path("geo_codes.csv"))
  triage <- read_std_csv(contract_path("label_triage.csv"))

  series_plan <- read_std_csv(file.path(root, "metadata", "plans", "SERIES_PLAN.csv"))
  tab_plan <- read_std_csv(file.path(root, "metadata", "plans", "TAB_PLAN.csv"))

  map_rows <- triage[triage$action == "MAP", , drop = FALSE]
  indicator_codes <- unique(map_rows$INDICATOR)
  stat_unit_of <- setNames(map_rows$stat_unit, map_rows$INDICATOR)

  cl_indicator <- data.frame(
    code = indicator_codes,
    stat_unit = unname(stat_unit_of[indicator_codes]),
    theme = "ALL_THEME",
    excluded_breakdowns = "",
    stringsAsFactors = FALSE
  )

  list(
    SERIES_PLAN = series_plan,
    TAB_PLAN = tab_plan,
    CL_INDICATOR = cl_indicator,
    CL_BRK_VAR = codes[codes$codelist == "CL_BRK_VAR", , drop = FALSE],
    CL_COMP_BREAKDOWN = codes[codes$codelist == "CL_COMP_BREAKDOWN", , drop = FALSE],
    CL_QUAL_VAR = codes[codes$codelist == "CL_QUAL_VAR", , drop = FALSE],
    CL_QUALIFIER = codes[codes$codelist == "CL_QUALIFIER", , drop = FALSE],
    CL_GEO = geo
  )
}

#' Write the seed metadata tables of [seed_meta_real()] as standard CSVs
#' under `tmp_root/metadata/`, so [load_metadata()] can find them by file
#' stem (used to test `make_data_fixture()`, which reads `meta` from disk).
seed_temp_metadata <- function(tmp_root) {
  meta <- seed_meta_real()
  write_std_csv(meta$SERIES_PLAN, file.path(tmp_root, "metadata", "plans", "SERIES_PLAN.csv"))
  write_std_csv(meta$TAB_PLAN, file.path(tmp_root, "metadata", "plans", "TAB_PLAN.csv"))
  write_std_csv(meta$CL_INDICATOR, file.path(tmp_root, "metadata", "structure", "CL_INDICATOR.csv"))
  write_std_csv(meta$CL_BRK_VAR, file.path(tmp_root, "metadata", "structure", "CL_BRK_VAR.csv"))
  write_std_csv(meta$CL_COMP_BREAKDOWN, file.path(tmp_root, "metadata", "structure", "CL_COMP_BREAKDOWN.csv"))
  write_std_csv(meta$CL_QUAL_VAR, file.path(tmp_root, "metadata", "structure", "CL_QUAL_VAR.csv"))
  write_std_csv(meta$CL_QUALIFIER, file.path(tmp_root, "metadata", "structure", "CL_QUALIFIER.csv"))
  write_std_csv(meta$CL_GEO, file.path(tmp_root, "metadata", "structure", "CL_GEO.csv"))
  invisible(NULL)
}

#' A made-up, minimal two-cut, three-series `meta` for exercising the
#' `excluded_breakdowns` and `SEX`/`AGE` rules by hand.
seed_meta_toy <- function() {
  series_plan <- data.frame(
    series_id = c("IND1", "IND2", "IND3"),
    ref_area = "ALL",
    INDICATOR = c("IND1", "IND2", "IND3"),
    MEASURE_QUALS = "",
    DEFINING_BREAKDOWN = "",
    stringsAsFactors = FALSE
  )

  tab_plan <- data.frame(
    cut_id = c("TOTAL", "CUTV"),
    ref_area = "ALL",
    geo_scheme = "_T",
    urbanisation = "_T",
    sex = "_T",
    age = "_T",
    comp_breakdowns = c("", "VARX"),
    themes = "ALL",
    stringsAsFactors = FALSE
  )

  cl_indicator <- data.frame(
    code = c("IND1", "IND2", "IND3"),
    stat_unit = c("IND", "HH", "IND"),
    theme = "T1",
    excluded_breakdowns = c("", "CAT_B", "VARX"),
    stringsAsFactors = FALSE
  )

  cl_brk_var <- data.frame(
    code = "VARX",
    slot_order = "10",
    applies_to_units = "IND HH",
    stringsAsFactors = FALSE
  )

  cl_comp_breakdown <- data.frame(
    code = c("CAT_A", "CAT_B", "CAT_C"),
    var_code = "VARX",
    stringsAsFactors = FALSE
  )

  cl_qual_var <- data.frame(code = character(0), slot_order = character(0), stringsAsFactors = FALSE)
  cl_qualifier <- data.frame(code = character(0), var_code = character(0), stringsAsFactors = FALSE)
  cl_geo <- data.frame(code = character(0), ref_area = character(0), scheme = character(0), stringsAsFactors = FALSE)

  list(
    SERIES_PLAN = series_plan,
    TAB_PLAN = tab_plan,
    CL_INDICATOR = cl_indicator,
    CL_BRK_VAR = cl_brk_var,
    CL_COMP_BREAKDOWN = cl_comp_breakdown,
    CL_QUAL_VAR = cl_qual_var,
    CL_QUALIFIER = cl_qualifier,
    CL_GEO = cl_geo
  )
}

test_that("required_rows stops when meta is missing a table", {
  meta <- seed_meta_toy()
  meta$CL_GEO <- NULL
  expect_error(required_rows(meta, "ZZ", "2099"), "CL_GEO")
})

test_that("required_rows produces a unique, fully populated key for SEN and GNB", {
  meta <- seed_meta_real()

  sen <- required_rows(meta, "SEN", "2021")
  gnb <- required_rows(meta, "GNB", "2021")

  n_series <- nrow(meta$SERIES_PLAN)
  expect_equal(n_series, 91)

  # Every series applies to every cut in this seed data (WP08.md's
  # acceptance check A6 cell counts): TOTAL 1, URB 3, HHH_SEX 2, HHH_AGE 2,
  # QUINT 5, ADM1 14 (SEN) / 9 (GNB), ZONES 6 (SEN only), AEZ 4 (GNB only).
  expect_equal(nrow(sen), n_series * (1 + 3 + 2 + 2 + 5 + 14 + 6))
  expect_equal(nrow(gnb), n_series * (1 + 3 + 2 + 2 + 5 + 9 + 4))

  for (rows in list(sen, gnb)) {
    key <- do.call(paste, c(as.list(rows[KEY_COLUMNS]), list(sep = "")))
    expect_equal(anyDuplicated(key), 0L)
    expect_false(any(vapply(rows[KEY_COLUMNS], function(col) any(col == ""), logical(1))))
  }

  expect_equal(sum(sen$cut_id == "TOTAL"), n_series)
  expect_equal(sum(sen$cut_id == "QUINT"), n_series * 5)
  expect_equal(sum(sen$cut_id == "ADM1"), n_series * 14)
  expect_equal(sum(sen$cut_id == "ZONES"), n_series * 6)
  expect_equal(sum(gnb$cut_id == "ADM1"), n_series * 9)
  expect_equal(sum(gnb$cut_id == "AEZ"), n_series * 4)
  expect_false("ZONES" %in% gnb$cut_id)
  expect_false("AEZ" %in% sen$cut_id)
})

test_that("SEX/AGE become _Z exactly when stat_unit is not IND, and slot order is correct", {
  meta <- seed_meta_real()
  sen <- required_rows(meta, "SEN", "2021")

  stat_unit_of_ind <- setNames(meta$CL_INDICATOR$stat_unit, meta$CL_INDICATOR$code)
  indicator_of_series <- setNames(meta$SERIES_PLAN$INDICATOR, meta$SERIES_PLAN$series_id)
  sen$stat_unit <- unname(stat_unit_of_ind[unname(indicator_of_series[sen$series_id])])

  is_ind <- sen$stat_unit == "IND"
  expect_true(all(sen$SEX[is_ind] != "_Z"))
  expect_true(all(sen$AGE[is_ind] != "_Z"))
  expect_true(all(sen$SEX[!is_ind] == "_Z"))
  expect_true(all(sen$AGE[!is_ind] == "_Z"))

  he_count_quint <- sen[sen$series_id == "POP_HH_SH.HE_COUNT_0" & sen$cut_id == "QUINT", ]
  expect_true(nrow(he_count_quint) > 0)
  expect_true(all(grepl("^QUINT_", he_count_quint$COMP_BREAKDOWN_1)))
  expect_true(all(he_count_quint$COMP_BREAKDOWN_2 == "HE_COUNT_0"))
  expect_true(all(he_count_quint$COMP_BREAKDOWN_3 == "_T"))

  povline <- sen[sen$series_id == "POV_HC.POVLINE_PL420.PPP_2021" & sen$cut_id == "TOTAL", ]
  expect_equal(nrow(povline), 1)
  expect_equal(povline$MEASURE_QUAL_1, "POVLINE_PL420")
  expect_equal(povline$MEASURE_QUAL_2, "PPP_2021")
  expect_equal(povline$MEASURE_QUAL_3, "_Z")
})

test_that("excluded_breakdowns and the SEX/AGE rule work on a made-up plan", {
  meta <- seed_meta_toy()
  rows <- required_rows(meta, "ZZ", "2099")

  # IND1 (IND, no exclusions): TOTAL (1) + CUTV (3 categories) = 4.
  # IND2 (HH, excludes category CAT_B): TOTAL (1) + CUTV (2 categories) = 3.
  # IND3 (IND, excludes the whole variable VARX): TOTAL (1) + CUTV (0) = 1.
  expect_equal(sum(rows$series_id == "IND1"), 4)
  expect_equal(sum(rows$series_id == "IND2"), 3)
  expect_equal(sum(rows$series_id == "IND3"), 1)
  expect_equal(nrow(rows), 8)

  ind1_total <- rows[rows$series_id == "IND1" & rows$cut_id == "TOTAL", ]
  expect_equal(ind1_total$SEX, "_T")
  expect_equal(ind1_total$AGE, "_T")

  ind2_total <- rows[rows$series_id == "IND2" & rows$cut_id == "TOTAL", ]
  expect_equal(ind2_total$SEX, "_Z")
  expect_equal(ind2_total$AGE, "_Z")

  ind2_cutv <- rows[rows$series_id == "IND2" & rows$cut_id == "CUTV", ]
  expect_equal(sort(ind2_cutv$COMP_BREAKDOWN_1), c("CAT_A", "CAT_C"))
  expect_true(all(ind2_cutv$SEX == "_Z"))

  ind3_cutv <- rows[rows$series_id == "IND3" & rows$cut_id == "CUTV", ]
  expect_equal(nrow(ind3_cutv), 0)

  ind1_cutv <- rows[rows$series_id == "IND1" & rows$cut_id == "CUTV", ]
  expect_equal(sort(ind1_cutv$COMP_BREAKDOWN_1), c("CAT_A", "CAT_B", "CAT_C"))
})

test_that("make_data_fixture writes a data file and manifest for GNB", {
  tmp_root <- make_temp_root(root, include = character(0))
  seed_temp_metadata(tmp_root)

  path <- make_data_fixture(
    tmp_root,
    ref_area = "GNB",
    series_ids = c("POV_HC.POVLINE_PL420.PPP_2021", "POP_HH_SH.HE_COUNT_0")
  )

  expect_true(file.exists(path))
  expect_equal(basename(path), "AFW360_HH_GNB_2021.csv")

  data <- read_std_csv(path)
  expect_equal(names(data), DSD_COLUMNS)
  expect_equal(nrow(data), 52L)
  expect_true(all(data$OBS_VALUE == "0.5"))
  expect_true(all(data$OBS_STATUS == "A"))

  manifest_path <- file.path(dirname(path), "AFW360_HH_GNB_2021_manifest.csv")
  expect_true(file.exists(manifest_path))
  manifest <- read_std_csv(manifest_path)
  # Long `key`, `value` form (contract/csv_headers.csv for
  # AFW360_HH_<ISO3>_<YEAR>_manifest.csv; read that way by build_ctx() in
  # pipeline/R/ctx.R), not one wide row.
  expect_equal(names(manifest), c("key", "value"))
  expect_equal(nrow(manifest), 16L)
  expect_equal(
    sort(manifest$key),
    sort(c(
      "dataflow", "dsd_version", "metadata_version", "ref_area", "time_period",
      "source_type", "survey_id", "precision", "file_name", "n_rows",
      "producer", "program", "software", "run_timestamp", "status", "notes"
    ))
  )
  man_vec <- stats::setNames(manifest$value, manifest$key)
  expect_equal(man_vec[["n_rows"]], "52")
  expect_equal(man_vec[["precision"]], "ROUNDED_2DP")
  expect_equal(man_vec[["status"]], "DRAFT")
  expect_equal(man_vec[["source_type"]], "SURVEY")

  reduced_series_plan <- read_std_csv(file.path(tmp_root, "metadata", "plans", "SERIES_PLAN.csv"))
  expect_equal(sort(reduced_series_plan$series_id), sort(c("POV_HC.POVLINE_PL420.PPP_2021", "POP_HH_SH.HE_COUNT_0")))
})
