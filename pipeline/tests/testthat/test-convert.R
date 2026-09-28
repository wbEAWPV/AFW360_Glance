# pipeline/tests/testthat/test-convert.R
#
# Tests for pipeline/R/convert_tables.R (card WP15) and pipeline/R/manifest.R.
# Covers the slot order, the SEX/AGE sentinel rule, an empty cell, WITHHOLD,
# COMMENT, a failing assertion and an unknown label, the DSD 0.2.0 columns
# (ESTIMATION, SERIES_ID, UNIT_MEASURE, PRECISION, SOURCE_ID), the file names
# and the manifest keys, plus the small pure helpers.

root <- find_root()
source(file.path(root, "pipeline", "R", "codes.R"))
source(file.path(root, "pipeline", "R", "constants.R"))
source(file.path(root, "pipeline", "R", "convert_tables.R"))
source(file.path(root, "pipeline", "R", "manifest.R"))

# ---- a tiny, fully synthetic fixture (not the real metadata) --------------
#
# One sheet ("National"), two columns:
#   ColA: no column-level breakdown (GEO/URBANISATION/COMP_BREAKDOWN all "")
#   ColB: COMP_BREAKDOWN = "BRKX_HI" (var BRKVARX, slot_order 10)
#
# Four labels:
#   "Indicator One"       MAP,  series S1 (HH,  no quals, no defining brk)
#   "Indicator Two"       MAP,  series S2 (IND, qual QUALX_A, no defining brk,
#                                           scale 1000000, unit PERSON)
#   "Indicator Three"     MAP,  series S3 (HH,  no quals, defining brk BRKY_LO,
#                                           var BRKVARY, slot_order 20,
#                                           unit LCU, scale empty)
#   "Indicator Duplicate" DUPLICATE_OF, assert_rule "EQUALS:S1"

make_fixture <- function() {
  wb <- list(
    National = data.frame(
      indicator = c("Indicator One", "Indicator Two", "Indicator Three", "Indicator Duplicate"),
      ColA = c("0.5", "10", "0.25", "0.5"),
      ColB = c(NA_character_, "5", "0.75", "0.5"),
      stringsAsFactors = FALSE
    )
  )

  legacy_labels <- data.frame(
    legacy_label = c("Indicator One", "Indicator Two", "Indicator Three", "Indicator Duplicate"),
    sheet = c("*", "*", "*", "*"),
    action = c("MAP", "MAP", "MAP", "DUPLICATE_OF"),
    series_id = c("S1", "S2", "S3", ""),
    duplicate_of = c("", "", "", ""),
    scale = c("1", "1000000", "", ""),
    assert_rule = c("", "", "", "EQUALS:S1"),
    notes = c("", "", "", ""),
    stringsAsFactors = FALSE
  )

  legacy_columns <- data.frame(
    ref_area = c("ZZ", "ZZ"),
    sheet = c("National", "National"),
    column = c("ColA", "ColB"),
    cut_id = c("", ""),
    GEO = c("", ""),
    URBANISATION = c("", ""),
    COMP_BREAKDOWN = c("", "BRKX_HI"),
    action = c("MAP", "MAP"),
    notes = c("", ""),
    stringsAsFactors = FALSE
  )

  legacy_overrides <- data.frame(
    ref_area = c("ZZ", "ZZ"),
    sheet = c("National", "National"),
    column = c("ColB", "ColA"),
    legacy_label = c("Indicator Two", "Indicator Three"),
    action = c("WITHHOLD", "COMMENT"),
    obs_comment = c("", "test comment"),
    reason = c("", ""),
    evidence = c("", ""),
    stringsAsFactors = FALSE
  )

  series_plan <- data.frame(
    series_id = c("S1", "S2", "S3"),
    ref_area = c("ALL", "ALL", "ALL"),
    INDICATOR = c("IND_ONE", "IND_TWO", "IND_THREE"),
    MEASURE_QUALS = c("", "QUALX_A", ""),
    DEFINING_BREAKDOWN = c("", "", "BRKY_LO"),
    status = c("DRAFT", "DRAFT", "DRAFT"),
    notes = c("", "", ""),
    stringsAsFactors = FALSE
  )

  surveys <- data.frame(
    ref_area = "ZZ",
    time_period = "2099",
    survey_id = "ZZ_TEST_2099",
    stringsAsFactors = FALSE
  )

  cl_indicator <- data.frame(
    code = c("IND_ONE", "IND_TWO", "IND_THREE"),
    stat_unit = c("HH", "IND", "HH"),
    unit_measure = c("SHARE", "PERSON", "LCU"),
    stringsAsFactors = FALSE
  )

  cl_area <- data.frame(
    code = c("ZZ", "YY"),
    currency = c("XOF", "EUR"),
    stringsAsFactors = FALSE
  )

  # Two LEGACY_CONVERSION runs for ZZ (v2 is the one to use), a PRODUCER run
  # with a higher version and another country's legacy run, both ignored.
  sources <- data.frame(
    source_id = c("ZZ_TEST_LEGACY_v1", "ZZ_TEST_LEGACY_v2", "ZZ_TEST_PROD_v3", "YY_TEST_LEGACY_v9"),
    kind = c("LEGACY_CONVERSION", "LEGACY_CONVERSION", "PRODUCER", "LEGACY_CONVERSION"),
    ref_area = c("ZZ", "ZZ", "ZZ", "YY"),
    stringsAsFactors = FALSE
  )

  cl_brk_var <- data.frame(
    code = c("BRKVARX", "BRKVARY"),
    slot_order = c("10", "20"),
    stringsAsFactors = FALSE
  )

  cl_comp_breakdown <- data.frame(
    code = c("BRKX_HI", "BRKY_LO"),
    var_code = c("BRKVARX", "BRKVARY"),
    stringsAsFactors = FALSE
  )

  cl_qual_var <- data.frame(
    code = "QUALVARX",
    slot_order = "10",
    stringsAsFactors = FALSE
  )

  cl_qualifier <- data.frame(
    code = "QUALX_A",
    var_code = "QUALVARX",
    stringsAsFactors = FALSE
  )

  meta <- list(
    DSD_AFW360_HH = read_std_csv(file.path(root, "metadata", "structure", "DSD_AFW360_HH.csv")),
    SOURCES = sources,
    CL_AREA = cl_area,
    LEGACY_LABELS = legacy_labels,
    LEGACY_COLUMNS = legacy_columns,
    LEGACY_OVERRIDES = legacy_overrides,
    SERIES_PLAN = series_plan,
    SURVEYS = surveys,
    CL_INDICATOR = cl_indicator,
    CL_BRK_VAR = cl_brk_var,
    CL_QUAL_VAR = cl_qual_var,
    CL_COMP_BREAKDOWN = cl_comp_breakdown,
    CL_QUALIFIER = cl_qualifier
  )

  list(wb = wb, meta = meta)
}

# ---- small pure helpers -----------------------------------------------

test_that("is_blank treats NA and whitespace-only strings as blank", {
  expect_equal(is_blank(c("x", "", "  ", NA_character_, "0")), c(FALSE, TRUE, TRUE, TRUE, FALSE))
})

test_that("wildcard_sheets is computed from LEGACY_COLUMNS MAP rows, not hardcoded", {
  legacy_columns <- data.frame(
    sheet = c("National", "ADM 1", "ZAE", "Departement"),
    action = c("MAP", "MAP", "MAP", "SKIP"),
    stringsAsFactors = FALSE
  )
  expect_equal(wildcard_sheets(legacy_columns), sort(c("National", "ADM 1", "ZAE")))
})

test_that("parse_assert_rule parses EQUALS, ONE_MINUS and an explicit tolerance", {
  r1 <- parse_assert_rule("EQUALS:CONS_SH.COICOP_CP01")
  expect_equal(r1, list(op = "EQUALS", series_id = "CONS_SH.COICOP_CP01", tol = 0))

  r2 <- parse_assert_rule("ONE_MINUS:CONS_SH.COICOP_CP01 tol=0.02")
  expect_equal(r2$op, "ONE_MINUS")
  expect_equal(r2$series_id, "CONS_SH.COICOP_CP01")
  expect_equal(r2$tol, 0.02)
})

test_that("order_and_pad orders by slot_order and pads with the sentinel", {
  cl_table <- data.frame(code = c("A_HI", "B_LO"), var_code = c("VARA", "VARB"), stringsAsFactors = FALSE)
  var_table <- data.frame(code = c("VARB", "VARA"), slot_order = c("20", "10"), stringsAsFactors = FALSE)

  out <- order_and_pad(c("B_LO", "A_HI"), cl_table, var_table, "_T")
  expect_equal(out, c("A_HI", "B_LO", "_T", "_T", "_T"))

  out_empty <- order_and_pad(character(0), cl_table, var_table, "_T")
  expect_equal(out_empty, rep("_T", 5))
})

test_that("match_overrides applies wildcards in ref_area, column and legacy_label, and sheet '*' means the wildcard sheets", {
  overrides <- data.frame(
    ref_area = c("ZZ", "ZZ"),
    sheet = c("*", "National"),
    column = c("*", "ColX"),
    legacy_label = c("Label A", "*"),
    action = c("COMMENT", "WITHHOLD"),
    obs_comment = c("c1", ""),
    stringsAsFactors = FALSE
  )
  wc <- c("National")

  hit1 <- match_overrides(overrides, "ZZ", "National", "AnyCol", "Label A", wc)
  expect_equal(nrow(hit1), 1)
  expect_equal(hit1$action, "COMMENT")

  hit2 <- match_overrides(overrides, "ZZ", "National", "ColX", "Anything", wc)
  expect_equal(nrow(hit2), 1)
  expect_equal(hit2$action, "WITHHOLD")

  hit3 <- match_overrides(overrides, "ZZ", "National", "ColY", "Label B", wc)
  expect_equal(nrow(hit3), 0)
})

# ---- build_country_rows: end-to-end on the tiny fixture ----------------

test_that("build_country_rows applies the slot order, the SEX/AGE sentinel rule, empty cells, WITHHOLD and COMMENT", {
  fx <- make_fixture()
  rows <- build_country_rows("ZZ", fx$wb, fx$meta)

  expect_equal(nrow(rows), 5)

  one_a <- rows[rows$INDICATOR == "IND_ONE" & rows$OBS_STATUS == "A", ]
  expect_equal(nrow(one_a), 1)
  expect_equal(one_a$OBS_VALUE, "0.5")
  expect_equal(one_a$SEX, "_Z")
  expect_equal(one_a$AGE, "_Z")
  expect_equal(one_a$GEO, "_T")
  expect_equal(one_a$URBANISATION, "_T")
  expect_equal(as.character(one_a[, c("COMP_BREAKDOWN_1", "COMP_BREAKDOWN_2", "COMP_BREAKDOWN_3", "COMP_BREAKDOWN_4", "COMP_BREAKDOWN_5")]), rep("_T", 5))
  expect_equal(as.character(one_a[, c("MEASURE_QUAL_1", "MEASURE_QUAL_2", "MEASURE_QUAL_3", "MEASURE_QUAL_4", "MEASURE_QUAL_5")]), rep("_Z", 5))
  expect_equal(one_a$OBS_COMMENT, "")

  # Indicator One / ColB: empty cell -> O status and LEGACY_EMPTY comment
  one_o <- rows[rows$INDICATOR == "IND_ONE" & rows$OBS_STATUS == "O", ]
  expect_equal(nrow(one_o), 1)
  expect_equal(one_o$OBS_VALUE, "")
  expect_equal(one_o$OBS_COMMENT, "LEGACY_EMPTY: empty cell in sheet 'National', column 'ColB'")
  expect_equal(one_o$COMP_BREAKDOWN_1, "BRKX_HI")
  expect_equal(as.character(one_o[, c("COMP_BREAKDOWN_2", "COMP_BREAKDOWN_3", "COMP_BREAKDOWN_4", "COMP_BREAKDOWN_5")]), rep("_T", 4))

  # Indicator Two: IND stat_unit -> SEX/AGE "_T"; scale 1e6; ColB withheld
  two <- rows[rows$INDICATOR == "IND_TWO", ]
  expect_equal(nrow(two), 1)
  expect_equal(two$SEX, "_T")
  expect_equal(two$AGE, "_T")
  expect_equal(two$OBS_VALUE, "10000000")
  expect_equal(two$MEASURE_QUAL_1, "QUALX_A")
  expect_equal(as.character(two[, c("MEASURE_QUAL_2", "MEASURE_QUAL_3", "MEASURE_QUAL_4", "MEASURE_QUAL_5")]), rep("_Z", 4))

  # Indicator Three / ColA: COMMENT override on a non-empty cell
  three_a <- rows[rows$INDICATOR == "IND_THREE" & rows$COMP_BREAKDOWN_1 == "BRKY_LO" & rows$COMP_BREAKDOWN_2 == "_T", ]
  expect_equal(nrow(three_a), 1)
  expect_equal(three_a$OBS_COMMENT, "test comment")
  expect_equal(three_a$OBS_VALUE, "0.25")

  # Indicator Three / ColB: column breakdown (BRKX_HI, slot 10) + defining
  # breakdown (BRKY_LO, slot 20), ordered and padded -- the slot-order case.
  three_b <- rows[rows$INDICATOR == "IND_THREE" & rows$COMP_BREAKDOWN_1 == "BRKX_HI", ]
  expect_equal(nrow(three_b), 1)
  expect_equal(three_b$COMP_BREAKDOWN_2, "BRKY_LO")
  expect_equal(as.character(three_b[, c("COMP_BREAKDOWN_3", "COMP_BREAKDOWN_4", "COMP_BREAKDOWN_5")]), rep("_T", 3))
  expect_equal(three_b$OBS_VALUE, "0.75")

  # Indicator Duplicate produces no row at all.
  expect_equal(nrow(rows[rows$INDICATOR == "IND_ONE" | rows$INDICATOR == "IND_TWO" | rows$INDICATOR == "IND_THREE", ]), 5)
})

test_that("finalize_rows sorts by the 19-column key and stays byte-identical on re-sort", {
  fx <- make_fixture()
  key_cols <- dsd_key_columns(fx$meta)
  expect_length(key_cols, 19)
  expect_equal(key_cols[c(1, 5, 19)], c("DATAFLOW", "ESTIMATION", "MEASURE_QUAL_5"))

  rows <- build_country_rows("ZZ", fx$wb, fx$meta)
  sorted1 <- finalize_rows(rows[rev(seq_len(nrow(rows))), ], key_cols)
  sorted2 <- finalize_rows(sorted1, key_cols)
  expect_equal(sorted1, sorted2)
  ord <- do.call(order, c(unname(as.list(sorted1[, key_cols])), list(method = "radix")))
  expect_equal(ord, seq_len(nrow(sorted1)))
})

test_that("finalize_rows stops on a duplicate key", {
  fx <- make_fixture()
  rows <- build_country_rows("ZZ", fx$wb, fx$meta)
  expect_error(
    finalize_rows(rbind(rows, rows[1, ]), dsd_key_columns(fx$meta)),
    "duplicate key"
  )
})

# ---- DSD 0.2.0 columns ------------------------------------------------

test_that("build_country_rows writes the 31 DSD columns in DSD order", {
  fx <- make_fixture()
  rows <- build_country_rows("ZZ", fx$wb, fx$meta)
  dsd <- fx$meta$DSD_AFW360_HH
  expected <- dsd$id[order(as.integer(dsd$position))]
  expect_length(expected, 31)
  expect_equal(names(rows), expected)
  expect_equal(dsd_columns(fx$meta), expected)
  expect_equal(
    names(rows)[c(1, 5, 20, 21, 22, 23, 24, 30, 31)],
    c("DATAFLOW", "ESTIMATION", "SERIES_ID", "OBS_VALUE", "UNIT_MEASURE", "PRECISION",
      "OBS_STATUS", "SOURCE_ID", "OBS_COMMENT")
  )
})

test_that("build_country_rows fills ESTIMATION, SERIES_ID, UNIT_MEASURE, PRECISION and SOURCE_ID", {
  fx <- make_fixture()
  rows <- build_country_rows("ZZ", fx$wb, fx$meta)

  expect_true(all(rows$ESTIMATION == "SURVEY"))
  expect_true(all(rows$SOURCE_ID == "ZZ_TEST_LEGACY_v2"))
  expect_true(all(rows$SERIES_ID != ""))

  series_of <- c(IND_ONE = "S1", IND_TWO = "S2", IND_THREE = "S3")
  expect_equal(rows$SERIES_ID, unname(series_of[rows$INDICATOR]))

  one <- rows[rows$INDICATOR == "IND_ONE", ]
  expect_true(all(one$UNIT_MEASURE == "SHARE"))
  # An unscaled share: 0.01, on the A row and on the O (empty cell) row alike.
  expect_equal(sort(one$OBS_STATUS), c("A", "O"))
  expect_true(all(one$PRECISION == "0.01"))

  two <- rows[rows$INDICATOR == "IND_TWO", ]
  expect_equal(two$UNIT_MEASURE, "PERSON")
  expect_equal(two$PRECISION, "10000")

  # An LCU indicator resolves to the country currency; an empty scale is 1.
  three <- rows[rows$INDICATOR == "IND_THREE", ]
  expect_true(all(three$UNIT_MEASURE == "XOF"))
  expect_true(all(three$PRECISION == "0.01"))

  # Reliability attributes stay empty on legacy rows.
  for (col in c("STD_ERR", "CI_LOWER", "CI_UPPER", "N_OBS", "N_POP")) {
    expect_true(all(rows[[col]] == ""), info = col)
  }
})

test_that("legacy_precision is 0.01 x scale in fixed notation", {
  expect_equal(legacy_precision("1"), "0.01")
  expect_equal(legacy_precision(""), "0.01")
  expect_equal(legacy_precision(NA_character_), "0.01")
  expect_equal(legacy_precision("1000000"), "10000")
  expect_error(legacy_precision("abc"), "invalid LEGACY_LABELS scale")
})

test_that("legacy_source_id picks the highest _v<N> LEGACY_CONVERSION row of the country", {
  fx <- make_fixture()
  expect_equal(legacy_source_id(fx$meta$SOURCES, "ZZ"), "ZZ_TEST_LEGACY_v2")
  expect_equal(legacy_source_id(fx$meta$SOURCES, "YY"), "YY_TEST_LEGACY_v9")
  expect_error(legacy_source_id(fx$meta$SOURCES, "XX"), "no LEGACY_CONVERSION row")
})

test_that("resolve_unit_measure resolves LCU per country and stops without a currency", {
  fx <- make_fixture()
  expect_equal(resolve_unit_measure(fx$meta$CL_INDICATOR, fx$meta$CL_AREA, "IND_THREE", "YY"), "EUR")
  expect_equal(resolve_unit_measure(fx$meta$CL_INDICATOR, fx$meta$CL_AREA, "IND_ONE", "YY"), "SHARE")
  expect_error(
    resolve_unit_measure(fx$meta$CL_INDICATOR, fx$meta$CL_AREA, "IND_THREE", "XX"),
    "no currency"
  )
})

# ---- file names and manifest -----------------------------------------------

test_that("data and manifest file names follow AFW360_HH_<ISO3>_<YEAR>_<ESTIMATION>", {
  fn <- data_file_name("SEN", "2021", "SURVEY")
  expect_equal(fn, "AFW360_HH_SEN_2021_SURVEY.csv")
  expect_match(fn, "^AFW360_HH_[A-Z]{3}_[0-9]{4}_(SURVEY|MODEL)[.]csv$")
  expect_equal(manifest_file_name(fn), "AFW360_HH_SEN_2021_SURVEY_manifest.csv")
})

test_that("build_manifest writes the 16 keys in order, with sorted distinct sources", {
  man <- build_manifest(
    country = "ZZ", time_period = "2099", estimation = "SURVEY",
    survey_id = "ZZ_TEST_2099",
    source_ids = c("ZZ_B_v1", "ZZ_A_v1", "ZZ_B_v1", ""),
    file_name = "AFW360_HH_ZZ_2099_SURVEY.csv", n_rows = 5,
    metadata_version = "0.2.0", run_timestamp = "2026-01-01T00:00:00Z"
  )
  expect_equal(names(man), c("key", "value"))
  expect_equal(
    man$key,
    c("dataflow", "dsd_version", "metadata_version", "ref_area", "time_period",
      "estimation", "survey_id", "sources", "file_name", "n_rows", "producer",
      "program", "software", "run_timestamp", "status", "notes")
  )
  v <- stats::setNames(man$value, man$key)
  expect_equal(v[["estimation"]], "SURVEY")
  expect_equal(v[["sources"]], "ZZ_A_v1 ZZ_B_v1")
  expect_equal(v[["file_name"]], "AFW360_HH_ZZ_2099_SURVEY.csv")
  expect_equal(v[["n_rows"]], "5")
  expect_equal(v[["dsd_version"]], "0.2.0")
  expect_false(any(c("source_type", "precision") %in% man$key))
})

test_that("the committed data files match the 0.2.0 contract", {
  meta <- load_metadata(root)
  cols <- dsd_columns(meta)
  files <- list.files(file.path(root, "data"), pattern = "^AFW360_HH_.*[.]csv$")
  data_files <- files[!grepl("_manifest[.]csv$", files)]
  expect_setequal(data_files, c("AFW360_HH_GNB_2021_SURVEY.csv", "AFW360_HH_SEN_2021_SURVEY.csv"))
  for (f in data_files) {
    d <- read_std_csv(file.path(root, "data", f))
    expect_equal(names(d), cols, info = f)
    for (col in c("SERIES_ID", "UNIT_MEASURE", "PRECISION", "SOURCE_ID")) {
      expect_true(all(d[[col]] != ""), info = paste(f, col))
    }
    man <- read_std_csv(file.path(root, "data", manifest_file_name(f)))
    v <- stats::setNames(man$value, man$key)
    expect_equal(man$key, MANIFEST_KEYS, info = f)
    expect_equal(v[["file_name"]], f)
    expect_equal(v[["n_rows"]], as.character(nrow(d)))
    expect_equal(v[["sources"]], paste(sort(unique(d$SOURCE_ID)), collapse = " "))
  }
})

test_that("a failing DUPLICATE_OF assertion stops with a clear message", {
  fx <- make_fixture()
  fx$wb$National$ColA[fx$wb$National$indicator == "Indicator Duplicate"] <- "0.9"
  expect_error(build_country_rows("ZZ", fx$wb, fx$meta), "assert_rule violated")
})

test_that("a workbook label with no LEGACY_LABELS row stops, naming the label", {
  fx <- make_fixture()
  fx$wb$National$indicator[fx$wb$National$indicator == "Indicator One"] <- "Mystery Indicator"
  expect_error(build_country_rows("ZZ", fx$wb, fx$meta), "Mystery Indicator")
})

test_that("a LEGACY_COLUMNS row with no matching workbook column stops", {
  fx <- make_fixture()
  fx$meta$LEGACY_COLUMNS <- rbind(
    fx$meta$LEGACY_COLUMNS,
    data.frame(
      ref_area = "ZZ", sheet = "National", column = "ColZ", cut_id = "",
      GEO = "", URBANISATION = "", COMP_BREAKDOWN = "", action = "MAP", notes = "",
      stringsAsFactors = FALSE
    )
  )
  expect_error(build_country_rows("ZZ", fx$wb, fx$meta), "matches nothing")
})
