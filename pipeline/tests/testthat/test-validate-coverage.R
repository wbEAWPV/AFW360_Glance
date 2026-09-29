# pipeline/tests/testthat/test-validate-coverage.R
#
# Tests for pipeline/R/validate_coverage.R and pipeline/R/validate_values.R
# (coverage and value checks, standard v0.5).
#
# helper-data-fixture.R's make_data_fixture() writes a data file's manifest
# as a LONG 2-column CSV (`key`, `value`, one row per key), as ctx.R's
# build_ctx() reads it. This file's tests use
# that manifest as written; set_manifest() below only edits one key of an
# already long-form manifest.

root <- find_root()
source(file.path(root, "pipeline", "R", "io.R"))
source(file.path(root, "pipeline", "R", "codes.R"))
source(file.path(root, "pipeline", "R", "constants.R"))
source(file.path(root, "pipeline", "R", "plan.R"))
source(file.path(root, "pipeline", "R", "ctx.R"))
source(file.path(root, "pipeline", "R", "manifest.R"))
source(file.path(root, "pipeline", "R", "validate_coverage.R"))
source(file.path(root, "pipeline", "R", "validate_values.R"))

#' Targets fixed when the transition was accepted (metadata 0.1.0): GNB has
#' 98 withheld cells (the whole `estimateCapital` column on `National`, plus
#' 7 cultivated-area outliers) and 2,268 data rows.
EXPECTED_COUNTS <- c(GNB.WITHHELD_CELLS = 98L, GNB.DATA.ROWS = 2268L)
expected_count <- function(check_id) EXPECTED_COUNTS[[check_id]]

#' The manifest path next to a standard data file.
manifest_path_for <- function(data_path) {
  file.path(dirname(data_path), paste0(tools::file_path_sans_ext(basename(data_path)), "_manifest.csv"))
}

#' Set one key of a (already long-form) manifest.
set_manifest <- function(data_path, key, value) {
  manifest_path <- manifest_path_for(data_path)
  man <- read_std_csv(manifest_path)
  man$value[man$key == key] <- value
  write_std_csv(man, manifest_path)
  invisible(man)
}

#' Build a clean GNB fixture that includes AGR_CULT_AREA (withheld by a
#' specific LEGACY_OVERRIDES row) and a CONS_SH share (withheld by the
#' estimateCapital "every MAP label" row), with the withheld rows removed
#' so the fixture starts from a genuinely clean, fully-covered state
#' (WP12.md steps 2-3).
#'
#' @return A list with `tmp` (the temp root), `data_path`, `withheld`
#'   (the withheld_rows() result for this fixture) and `key_cols` (the
#'   19 key column names, as they appear on `withheld`/`required_rows()`).
build_clean_gnb_fixture <- function() {
  tmp <- make_temp_root(root)
  data_path <- make_data_fixture(tmp, "GNB", series_ids = c("AGR_CULT_AREA", "CONS_SH.COICOP_CP01"))

  meta <- load_metadata(tmp)
  withheld <- withheld_rows(meta, "GNB", "2021")
  key_cols <- names(withheld)[!(names(withheld) %in% c("series_id", "cut_id", "defining_breakdown"))]

  df <- read_std_csv(data_path)
  withheld_key <- do.call(paste, c(withheld[key_cols], sep = " "))
  df_key <- do.call(paste, c(df[key_cols], sep = " "))
  df_clean <- df[!(df_key %in% withheld_key), , drop = FALSE]
  write_std_csv(df_clean, data_path)

  set_manifest(data_path, "n_rows", as.character(nrow(df_clean)))
  set_manifest(data_path, "survey_id", "GNB_EHCVM_2021")

  list(tmp = tmp, data_path = data_path, withheld = withheld, key_cols = key_cols)
}

ALL_CHECK_FNS <- list(
  vc_cover_missing, vc_cover_extra, vc_cover_withheld_present,
  vc_cover_manifest, vc_cover_survey, vc_value_numeric, vc_value_range,
  vc_value_status_empty, vc_value_legacy_empty, vc_value_se_ci, vc_value_n,
  vc_value_se_required, vc_value_precision, vc_value_status_model,
  vc_value_status_deviates, vc_value_status_reliability, vc_value_status_q
)

#' Bind every vc_* function's findings for one ctx into one data frame.
run_all_checks <- function(ctx) {
  do.call(rbind, lapply(ALL_CHECK_FNS, function(fn) as.data.frame(fn(ctx))))
}

#' Drop non-ERROR findings (vc_value_n's per-file INFO row on a legacy
#' (LEGACY_CONVERSION-source) fixture is expected background noise, not a mutation's
#' effect - see the WP12.A1 test).
only_errors <- function(findings) findings[findings$severity == "ERROR", , drop = FALSE]

#' Register a PRODUCER source for `ref_area` in the temp root's SOURCES.csv
#' and make every row of the data file (and its manifest) use it, with
#' PRECISION emptied (a producer writes unrounded values).
#'
#' @return The new source id, invisibly.
use_producer_source <- function(tmp, data_path, ref_area, source_id = paste0(ref_area, "_EHCVM2021_PROD_v1")) {
  edit_csv(file.path(tmp, "metadata", "registries", "SOURCES.csv"), function(s) {
    extra <- s[s$ref_area == ref_area, , drop = FALSE][1, ]
    extra$source_id <- source_id
    extra$kind <- "PRODUCER"
    extra$program <- "producer/estimate.do"
    extra$inputs <- "EHCVM 2021 microdata"
    extra$inputs_sha256 <- ""
    rbind(s, extra)
  })
  edit_csv(data_path, function(df) {
    df$SOURCE_ID <- source_id
    df$PRECISION <- ""
    df
  })
  set_manifest(data_path, "sources", source_id)
  invisible(source_id)
}

#' Fill the reliability attributes of every row with values that pass: 100
#' records, a population of 1000, and for a statistic that admits a
#' standard error, STD_ERR 0.01 with a 95% interval around the value.
fill_reliability <- function(df, meta) {
  ind <- meta$CL_INDICATOR
  st <- meta$CL_STATISTIC
  admits <- st$admits_se[match(ind$statistic[match(df$INDICATOR, ind$code)], st$code)] %in% "Y"
  filled <- df$OBS_VALUE != ""
  df$N_OBS <- "100"
  df$N_POP <- "1000"
  val <- suppressWarnings(as.numeric(df$OBS_VALUE))
  df$STD_ERR <- ifelse(admits & filled, "0.01", "")
  df$CI_LOWER <- ifelse(admits & filled, fmt_num(val - 0.0196), "")
  df$CI_UPPER <- ifelse(admits & filled, fmt_num(val + 0.0196), "")
  df
}

#' A clean SEN fixture (SEN has no withheld cells) for the given series,
#' estimation and, optionally, a PRODUCER source with reliability filled.
build_sen_fixture <- function(series_ids, estimation = "SURVEY", producer = FALSE, plan_edit = NULL) {
  tmp <- make_temp_root(root)
  if (!is.null(plan_edit)) edit_csv(file.path(tmp, "metadata", "plans", "SERIES_PLAN.csv"), plan_edit)
  data_path <- make_data_fixture(tmp, "SEN", series_ids = series_ids, estimation = estimation)
  if (producer) {
    use_producer_source(tmp, data_path, "SEN")
    meta <- load_metadata(tmp)
    edit_csv(data_path, function(df) fill_reliability(df, meta))
  }
  list(tmp = tmp, data_path = data_path)
}

# ---- withheld_rows() (WP12.A3, and the "Withheld cells" rule) -------------

test_that("withheld_rows on the real metadata matches the accepted counts", {
  meta <- load_metadata(root)

  withheld_gnb <- withheld_rows(meta, "GNB", "2021")
  withheld_sen <- withheld_rows(meta, "SEN", "2021")
  required_gnb <- required_rows(meta, "GNB", "2021")

  expect_equal(nrow(withheld_gnb), expected_count("GNB.WITHHELD_CELLS"))
  expect_equal(nrow(withheld_sen), 0L)
  expect_equal(nrow(required_gnb) - nrow(withheld_gnb), expected_count("GNB.DATA.ROWS"))
})

test_that("withheld_rows returns the same columns as required_rows, zero rows with no overrides", {
  meta <- load_metadata(root)
  required_sen <- required_rows(meta, "SEN", "2021")
  withheld_sen <- withheld_rows(meta, "SEN", "2021")
  expect_equal(names(withheld_sen), names(required_sen))
  expect_equal(nrow(withheld_sen), 0L)
})

# ---- WP12.A1: clean fixture, zero ERROR findings ---------------------------

test_that("clean GNB fixture: every check returns zero ERROR findings (WP12.A1)", {
  s <- build_clean_gnb_fixture()
  ctx <- build_ctx(s$tmp, data_files = s$data_path)
  findings <- run_all_checks(ctx)

  expect_equal(sum(findings$severity == "ERROR"), 0L)
  # The fixture's rows come from a LEGACY_CONVERSION source
  # (helper-data-fixture.R), so VALUE.N gives its one INFO finding noting
  # the exemption.
  expect_equal(findings$check_id[findings$severity == "INFO"], "VALUE.N")
})

# ---- WP12.A2: each mutation gives exactly its own check_id -----------------

test_that("a row deleted gives COVER.MISSING and nothing else (WP12.A2)", {
  s <- build_clean_gnb_fixture()
  df <- read_std_csv(s$data_path)
  df2 <- df[-1, , drop = FALSE]
  write_std_csv(df2, s$data_path)
  set_manifest(s$data_path, "n_rows", as.character(nrow(df2)))

  ctx <- build_ctx(s$tmp, data_files = s$data_path)
  findings <- only_errors(run_all_checks(ctx))

  expect_equal(unique(findings$check_id), "COVER.MISSING")
  expect_true(all(findings$severity == "ERROR"))
  expect_true(nrow(findings) >= 1)
})

test_that("a row added with an unplanned breakdown gives COVER.EXTRA and nothing else (WP12.A2)", {
  s <- build_clean_gnb_fixture()
  df <- read_std_csv(s$data_path)
  extra <- df[1, , drop = FALSE]
  extra$MEASURE_QUAL_1 <- "ZZZ_NOT_A_REAL_QUALIFIER"
  df2 <- rbind(df, extra)
  write_std_csv(df2, s$data_path)
  set_manifest(s$data_path, "n_rows", as.character(nrow(df2)))

  ctx <- build_ctx(s$tmp, data_files = s$data_path)
  findings <- only_errors(run_all_checks(ctx))

  expect_equal(unique(findings$check_id), "COVER.EXTRA")
  expect_equal(nrow(findings), 1L)
})

test_that("a withheld row added back gives COVER.WITHHELD_PRESENT and nothing else (WP12.A2)", {
  s <- build_clean_gnb_fixture()
  expect_true(nrow(s$withheld) > 0)

  df <- read_std_csv(s$data_path)
  # The attributes come from a row of the same series already in the file.
  template <- df[df$SERIES_ID == s$withheld$series_id[1], , drop = FALSE][1, ]
  withheld_row <- template
  withheld_row[s$key_cols] <- s$withheld[1, s$key_cols, drop = FALSE]
  withheld_row$OBS_VALUE <- "0.5"
  withheld_row$OBS_STATUS <- "A"
  df2 <- rbind(df, withheld_row)
  write_std_csv(df2, s$data_path)
  set_manifest(s$data_path, "n_rows", as.character(nrow(df2)))

  ctx <- build_ctx(s$tmp, data_files = s$data_path)
  findings <- only_errors(run_all_checks(ctx))

  expect_equal(unique(findings$check_id), "COVER.WITHHELD_PRESENT")
  expect_equal(nrow(findings), 1L)
})

test_that("the manifest's n_rows changed gives COVER.MANIFEST and nothing else (WP12.A2)", {
  s <- build_clean_gnb_fixture()
  set_manifest(s$data_path, "n_rows", "999")

  ctx <- build_ctx(s$tmp, data_files = s$data_path)
  findings <- only_errors(run_all_checks(ctx))

  expect_equal(unique(findings$check_id), "COVER.MANIFEST")
  expect_equal(nrow(findings), 1L)
  expect_equal(findings$row_key, "key=n_rows")
})

test_that("vc_cover_manifest flags a manifest file that does not exist", {
  s <- build_clean_gnb_fixture()
  file.remove(manifest_path_for(s$data_path))

  ctx <- build_ctx(s$tmp, data_files = s$data_path)
  res <- vc_cover_manifest(ctx)

  expect_equal(nrow(res), 1L)
  expect_equal(res$check_id, "COVER.MANIFEST")
  expect_equal(res$row_key, "")
})

test_that("the manifest's survey_id set to XXX gives COVER.SURVEY and nothing else (WP12.A2)", {
  s <- build_clean_gnb_fixture()
  set_manifest(s$data_path, "survey_id", "XXX")

  ctx <- build_ctx(s$tmp, data_files = s$data_path)
  findings <- only_errors(run_all_checks(ctx))

  expect_equal(unique(findings$check_id), "COVER.SURVEY")
  expect_equal(nrow(findings), 1L)
  expect_equal(findings$row_key, "survey_id=XXX")
})

test_that("a share set to 1.3 gives VALUE.RANGE and nothing else (WP12.A2)", {
  s <- build_clean_gnb_fixture()
  df <- read_std_csv(s$data_path)
  idx <- which(df$INDICATOR == "CONS_SH")[1]
  expect_false(is.na(idx))
  df$OBS_VALUE[idx] <- "1.3"
  write_std_csv(df, s$data_path)

  ctx <- build_ctx(s$tmp, data_files = s$data_path)
  findings <- only_errors(run_all_checks(ctx))

  expect_equal(unique(findings$check_id), "VALUE.RANGE")
  expect_equal(nrow(findings), 1L)
})

test_that("a value 1e-3 gives VALUE.NUMERIC and nothing else (WP12.A2)", {
  s <- build_clean_gnb_fixture()
  df <- read_std_csv(s$data_path)
  idx <- which(df$INDICATOR == "AGR_CULT_AREA")[1]
  expect_false(is.na(idx))
  df$OBS_VALUE[idx] <- "1e-3"
  write_std_csv(df, s$data_path)

  ctx <- build_ctx(s$tmp, data_files = s$data_path)
  findings <- only_errors(run_all_checks(ctx))

  expect_equal(unique(findings$check_id), "VALUE.NUMERIC")
  expect_equal(nrow(findings), 1L)
})

test_that("an O row with a value gives VALUE.STATUS_EMPTY and nothing else (WP12.A2)", {
  s <- build_clean_gnb_fixture()
  df <- read_std_csv(s$data_path)
  df$OBS_STATUS[1] <- "O"
  # Give a valid LEGACY_EMPTY: comment so this mutation only exercises
  # VALUE.STATUS_EMPTY, not VALUE.LEGACY_EMPTY as well.
  df$OBS_COMMENT[1] <- "LEGACY_EMPTY: test fixture, value kept on purpose"
  write_std_csv(df, s$data_path)

  ctx <- build_ctx(s$tmp, data_files = s$data_path)
  findings <- only_errors(run_all_checks(ctx))

  expect_equal(unique(findings$check_id), "VALUE.STATUS_EMPTY")
  expect_equal(nrow(findings), 1L)
})

test_that("an A row without a value gives VALUE.STATUS_EMPTY and nothing else (WP12.A2)", {
  s <- build_clean_gnb_fixture()
  df <- read_std_csv(s$data_path)
  df$OBS_VALUE[1] <- ""
  write_std_csv(df, s$data_path)

  ctx <- build_ctx(s$tmp, data_files = s$data_path)
  findings <- only_errors(run_all_checks(ctx))

  expect_equal(unique(findings$check_id), "VALUE.STATUS_EMPTY")
  expect_equal(nrow(findings), 1L)
})

test_that("an O row with an empty comment gives VALUE.LEGACY_EMPTY and nothing else (WP12.A2)", {
  s <- build_clean_gnb_fixture()
  df <- read_std_csv(s$data_path)
  df$OBS_STATUS[1] <- "O"
  df$OBS_VALUE[1] <- ""
  write_std_csv(df, s$data_path)

  ctx <- build_ctx(s$tmp, data_files = s$data_path)
  findings <- only_errors(run_all_checks(ctx))

  expect_equal(unique(findings$check_id), "VALUE.LEGACY_EMPTY")
  expect_equal(nrow(findings), 1L)
  expect_match(findings$message, "LEGACY_EMPTY:", fixed = TRUE)
})

# ---- VALUE.N on the rows of a PRODUCER source --------------------------------

test_that("vc_value_n flags PRODUCER-source N_OBS/N_POP problems, and gives no INFO row", {
  s <- build_clean_gnb_fixture()
  use_producer_source(s$tmp, s$data_path, "GNB")

  df <- read_std_csv(s$data_path)
  df$N_OBS <- "100"
  df$N_POP <- "1000"
  df$N_OBS[1] <- ""    # missing
  df$N_POP[2] <- "-5"  # negative
  df$N_OBS[3] <- "0"   # zero without OBS_STATUS = O (status stays "A")
  write_std_csv(df, s$data_path)

  ctx <- build_ctx(s$tmp, data_files = s$data_path)
  res <- vc_value_n(ctx)

  expect_true(all(res$check_id == "VALUE.N"))
  expect_true(all(res$severity == "ERROR"))
  expect_equal(nrow(res), 3L)
})

test_that("vc_value_n gives one INFO finding per legacy-source file, and no ERROR", {
  s <- build_clean_gnb_fixture()
  ctx <- build_ctx(s$tmp, data_files = s$data_path)
  res <- vc_value_n(ctx)

  expect_equal(nrow(res), 1L)
  expect_equal(res$check_id, "VALUE.N")
  expect_equal(res$severity, "INFO")
  expect_equal(res$row_key, "")
})

# ---- WP12.A4: no data in ctx -----------------------------------------------

test_that("with no data in ctx, every function returns zero rows and does not fail (WP12.A4)", {
  tmp <- make_temp_root(root)
  ctx <- build_ctx(tmp, data_files = character(0))
  for (fn in ALL_CHECK_FNS) {
    res <- fn(ctx)
    expect_equal(nrow(res), 0L)
    expect_equal(names(res), c("check_id", "severity", "file", "row_key", "message"))
  }
})

# ---- Findings format: the 20-finding cap -----------------------------------

test_that("more than 20 findings for one check/file are capped, with one SUMMARY row", {
  s <- build_clean_gnb_fixture()
  df <- read_std_csv(s$data_path)
  extra <- df[rep(1, 25), , drop = FALSE]
  extra$MEASURE_QUAL_1 <- paste0("ZZZ_FAKE_", sprintf("%02d", seq_len(25)))
  df2 <- rbind(df, extra)
  write_std_csv(df2, s$data_path)
  set_manifest(s$data_path, "n_rows", as.character(nrow(df2)))

  ctx <- build_ctx(s$tmp, data_files = s$data_path)
  res <- vc_cover_extra(ctx)

  expect_equal(nrow(res), 21L)
  expect_true(all(res$check_id == "COVER.EXTRA"))
  expect_true(all(res$severity == "ERROR"))
  expect_true(all(nchar(res$row_key[1:20]) > 0))
  expect_equal(res$row_key[1:20], sort(res$row_key[1:20]))
  expect_equal(res$row_key[21], "")
  expect_equal(res$message[21], "SUMMARY: 25 findings in total, 20 shown")
})

# ---- standard v0.5 (WP-C): coverage ----------------------------------------

SEN_SERIES <- c("POV_HC.POVLINE_PL420.PPP_2021", "POV_NUM.POVLINE_PL420.PPP_2021", "HE_PROFIT")

test_that("a NOT_PRODUCED country row removes the series from the required rows", {
  add_not_produced <- function(df) {
    extra <- df[df$series_id == "HE_PROFIT", ]
    extra$ref_area <- "SEN"
    extra$status <- "NOT_PRODUCED"
    extra$notes <- "Test: the survey cannot support the series."
    rbind(df, extra)
  }
  # The fixture is built before the country row exists, so it holds the
  # HE_PROFIT rows; once the series is NOT_PRODUCED they are extra.
  s <- build_sen_fixture(SEN_SERIES)
  edit_csv(file.path(s$tmp, "metadata", "plans", "SERIES_PLAN.csv"), add_not_produced)
  ctx <- build_ctx(s$tmp, data_files = s$data_path)
  extra <- vc_cover_extra(ctx)
  expect_true(nrow(extra) > 0)
  expect_true(all(grepl(" HE_PROFIT ", extra$row_key[extra$row_key != ""])))
  expect_equal(nrow(vc_cover_missing(ctx)), 0L)

  # Built with the country row in place, the fixture has no HE_PROFIT rows
  # and is clean.
  s2 <- build_sen_fixture(SEN_SERIES, plan_edit = add_not_produced)
  df <- read_std_csv(s2$data_path)
  expect_false(any(df$INDICATOR == "HE_PROFIT"))
  findings <- run_all_checks(build_ctx(s2$tmp, data_files = s2$data_path))
  expect_equal(nrow(only_errors(findings)), 0L)
})

test_that("a MODEL file requires only the series whose estimation includes MODEL", {
  both <- function(df) {
    df$estimation[df$series_id == "POV_HC.POVLINE_PL420.PPP_2021"] <- "SURVEY MODEL"
    df
  }
  s <- build_sen_fixture(SEN_SERIES, estimation = "MODEL", plan_edit = both)
  df <- read_std_csv(s$data_path)
  expect_equal(unique(df$SERIES_ID), "POV_HC.POVLINE_PL420.PPP_2021")
  expect_true(all(df$ESTIMATION == "MODEL"))
  expect_true(all(df$OBS_STATUS == "E"))
  findings <- run_all_checks(build_ctx(s$tmp, data_files = s$data_path))
  expect_equal(nrow(only_errors(findings)), 0L)
})

test_that("the manifest's estimation and sources are checked against the file", {
  s <- build_clean_gnb_fixture()
  set_manifest(s$data_path, "estimation", "MODEL")
  set_manifest(s$data_path, "sources", "GNB_EHCVM2021_LEGACY_v1 SEN_EHCVM2021_LEGACY_v1")
  res <- vc_cover_manifest(build_ctx(s$tmp, data_files = s$data_path))
  expect_setequal(res$row_key, c("key=estimation", "key=sources"))
  expect_match(res$message[res$row_key == "key=estimation"], "disagrees with the file name's SURVEY", fixed = TRUE)
  expect_match(res$message[res$row_key == "key=sources"], "SEN_EHCVM2021_LEGACY_v1", fixed = TRUE)
})

test_that("a manifest missing a 0.2.0 key gives COVER.MANIFEST key=<name>", {
  s <- build_clean_gnb_fixture()
  man_path <- manifest_path_for(s$data_path)
  edit_csv(man_path, function(m) m[m$key != "sources", ])
  res <- vc_cover_manifest(build_ctx(s$tmp, data_files = s$data_path))
  expect_equal(res$row_key, "key=sources")
})

# ---- standard v0.5 (WP-C): values -------------------------------------------

test_that("VALUE.PRECISION: legacy rows need PRECISION, and it must be positive", {
  s <- build_clean_gnb_fixture()
  ctx <- build_ctx(s$tmp, data_files = s$data_path)
  expect_equal(nrow(vc_value_precision(ctx)), 0L)

  df <- read_std_csv(s$data_path)
  df$PRECISION[1] <- ""
  df$PRECISION[2] <- "0"
  write_std_csv(df, s$data_path)
  findings <- only_errors(run_all_checks(build_ctx(s$tmp, data_files = s$data_path)))
  expect_equal(unique(findings$check_id), "VALUE.PRECISION")
  expect_equal(nrow(findings), 2L)

  # An empty PRECISION is fine on a PRODUCER row (an exact value).
  s2 <- build_sen_fixture(SEN_SERIES, producer = TRUE)
  expect_equal(nrow(vc_value_precision(build_ctx(s2$tmp, data_files = s2$data_path))), 0L)
})

test_that("PRODUCER rows need their reliability attributes; legacy rows do not", {
  s <- build_sen_fixture(SEN_SERIES, producer = TRUE)
  findings <- run_all_checks(build_ctx(s$tmp, data_files = s$data_path))
  expect_equal(nrow(only_errors(findings)), 0L)
  expect_false("VALUE.N" %in% findings$check_id) # no legacy exemption INFO either

  df <- read_std_csv(s$data_path)
  pov <- which(df$INDICATOR == "POV_HC")
  df$STD_ERR[pov[1]] <- ""  # POV_HC's statistic admits a standard error
  df$CI_UPPER[pov[2]] <- ""
  df$N_POP[pov[3]] <- ""
  write_std_csv(df, s$data_path)
  findings <- only_errors(run_all_checks(build_ctx(s$tmp, data_files = s$data_path)))
  expect_setequal(unique(findings$check_id), c("VALUE.SE_REQUIRED", "VALUE.N"))
  expect_equal(sum(findings$check_id == "VALUE.SE_REQUIRED"), 2L)
})

test_that("VALUE.LEGACY_EMPTY applies to O rows of a LEGACY_CONVERSION source only", {
  s <- build_sen_fixture(SEN_SERIES, producer = TRUE)
  df <- read_std_csv(s$data_path)
  df$OBS_STATUS[1] <- "O"
  df$OBS_VALUE[1] <- ""
  df$STD_ERR[1] <- ""
  df$CI_LOWER[1] <- ""
  df$CI_UPPER[1] <- ""
  df$N_OBS[1] <- "0"
  write_std_csv(df, s$data_path)
  findings <- only_errors(run_all_checks(build_ctx(s$tmp, data_files = s$data_path)))
  expect_equal(nrow(findings), 0L)
})

test_that("VALUE.STATUS_MODEL: a MODEL file's filled rows are E, and a SURVEY file has no E", {
  both <- function(df) {
    df$estimation[df$series_id == "POV_HC.POVLINE_PL420.PPP_2021"] <- "SURVEY MODEL"
    df
  }
  s <- build_sen_fixture(SEN_SERIES, estimation = "MODEL", plan_edit = both)
  edit_csv(s$data_path, function(df) {
    df$OBS_STATUS[1] <- "A"
    df
  })
  findings <- only_errors(run_all_checks(build_ctx(s$tmp, data_files = s$data_path)))
  expect_equal(unique(findings$check_id), "VALUE.STATUS_MODEL")
  expect_equal(nrow(findings), 1L)
  expect_match(findings$message, "MODEL file", fixed = TRUE)

  s2 <- build_clean_gnb_fixture()
  edit_csv(s2$data_path, function(df) {
    df$OBS_STATUS[1] <- "E"
    df
  })
  findings2 <- only_errors(run_all_checks(build_ctx(s2$tmp, data_files = s2$data_path)))
  expect_equal(unique(findings2$check_id), "VALUE.STATUS_MODEL")
  expect_match(findings2$message, "SURVEY file", fixed = TRUE)
})

test_that("VALUE.STATUS_DEVIATES: D on every row of a DEVIATES series and on no other", {
  deviates <- function(df) {
    extra <- df[df$series_id == "HE_PROFIT", ]
    extra$ref_area <- "SEN"
    extra$status <- "DEVIATES"
    extra$notes <- "Test: profit measured before depreciation."
    rbind(df, extra)
  }
  s <- build_sen_fixture(SEN_SERIES, plan_edit = deviates)
  edit_csv(s$data_path, function(df) {
    df$OBS_STATUS[df$INDICATOR == "HE_PROFIT"] <- "D"
    df
  })
  ctx <- build_ctx(s$tmp, data_files = s$data_path)
  expect_equal(nrow(only_errors(run_all_checks(ctx))), 0L)

  edit_csv(s$data_path, function(df) {
    df$OBS_STATUS[which(df$INDICATOR == "HE_PROFIT")[1]] <- "A" # D missing
    df$OBS_STATUS[which(df$INDICATOR == "POV_HC")[1]] <- "D"    # D without DEVIATES
    df
  })
  findings <- only_errors(run_all_checks(build_ctx(s$tmp, data_files = s$data_path)))
  expect_equal(unique(findings$check_id), "VALUE.STATUS_DEVIATES")
  expect_equal(nrow(findings), 2L)
  msg <- paste(findings$message, collapse = "\n")
  expect_match(msg, "expected D", fixed = TRUE)
  expect_match(msg, "not DEVIATES", fixed = TRUE)
})

test_that("VALUE.STATUS_RELIABILITY: U is required below 30 records or above CV 0.3, and forbidden otherwise", {
  s <- build_sen_fixture(SEN_SERIES, producer = TRUE)
  edit_csv(s$data_path, function(df) {
    pov <- which(df$INDICATOR == "POV_HC")
    df$N_OBS[pov[1]] <- "29"; df$OBS_STATUS[pov[1]] <- "U"   # correct U (few records)
    df$STD_ERR[pov[2]] <- "0.2"                              # CV 0.4 > 0.3
    df$CI_LOWER[pov[2]] <- "0.1"; df$CI_UPPER[pov[2]] <- "0.9"
    df$OBS_STATUS[pov[2]] <- "U"                             # correct U (high CV)
    df
  })
  findings <- run_all_checks(build_ctx(s$tmp, data_files = s$data_path))
  expect_equal(nrow(only_errors(findings)), 0L)

  edit_csv(s$data_path, function(df) {
    pov <- which(df$INDICATOR == "POV_HC")
    df$OBS_STATUS[pov[1]] <- "A" # U required, missing
    df$OBS_STATUS[pov[3]] <- "U" # 100 records, CV 0.02: U forbidden
    df
  })
  findings <- only_errors(run_all_checks(build_ctx(s$tmp, data_files = s$data_path)))
  expect_equal(unique(findings$check_id), "VALUE.STATUS_RELIABILITY")
  expect_equal(nrow(findings), 2L)
  msg <- paste(findings$message, collapse = "\n")
  expect_match(msg, "N_OBS below 30", fixed = TRUE)
  expect_match(msg, "breaches neither", fixed = TRUE)
})

test_that("VALUE.STATUS_RELIABILITY: a row with neither N_OBS nor STD_ERR is never U", {
  s <- build_clean_gnb_fixture()
  edit_csv(s$data_path, function(df) {
    df$OBS_STATUS[1] <- "U"
    df
  })
  findings <- only_errors(run_all_checks(build_ctx(s$tmp, data_files = s$data_path)))
  expect_equal(unique(findings$check_id), "VALUE.STATUS_RELIABILITY")
  expect_equal(nrow(findings), 1L)
})

test_that("a model-based row that would be U is E (precedence M O E D U A)", {
  both <- function(df) {
    df$estimation[df$series_id == "POV_HC.POVLINE_PL420.PPP_2021"] <- "SURVEY MODEL"
    df
  }
  s <- build_sen_fixture(SEN_SERIES, estimation = "MODEL", producer = TRUE, plan_edit = both)
  edit_csv(s$data_path, function(df) {
    df$N_OBS[1] <- "5" # breaches RELIABILITY_MIN_NOBS, but E takes precedence
    df
  })
  findings <- only_errors(run_all_checks(build_ctx(s$tmp, data_files = s$data_path)))
  expect_equal(nrow(findings), 0L)
})

test_that("VALUE.STATUS_Q: Q is used nowhere", {
  s <- build_clean_gnb_fixture()
  edit_csv(s$data_path, function(df) {
    df$OBS_STATUS[1] <- "Q"
    df
  })
  findings <- only_errors(run_all_checks(build_ctx(s$tmp, data_files = s$data_path)))
  expect_equal(unique(findings$check_id), "VALUE.STATUS_Q")
  expect_equal(nrow(findings), 1L)
})
