# pipeline/tests/testthat/test-validate-coverage.R
#
# Tests for pipeline/R/validate_coverage.R and pipeline/R/validate_values.R
# (WP12: coverage and value checks).
#
# helper-data-fixture.R's make_data_fixture() writes a data file's manifest
# as a LONG 2-column CSV (`key`, `value`, one row per key), matching
# seeds/csv_headers.csv and ctx.R's build_ctx(). This file's tests use
# that manifest as written; set_manifest() below only edits one key of an
# already long-form manifest.

root <- find_root()
source(file.path(root, "pipeline", "R", "io.R"))
source(file.path(root, "pipeline", "R", "codes.R"))
source(file.path(root, "pipeline", "R", "constants.R"))
source(file.path(root, "pipeline", "R", "plan.R"))
source(file.path(root, "pipeline", "R", "ctx.R"))
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
#'   18 key column names, as they appear on `withheld`/`required_rows()`).
build_clean_gnb_fixture <- function() {
  tmp <- make_temp_root(root)
  data_path <- make_data_fixture(tmp, "GNB", series_ids = c("AGR_CULT_AREA", "CONS_SH.COICOP_CP01"))

  meta <- load_metadata(tmp)
  withheld <- withheld_rows(meta, "GNB", "2021")
  key_cols <- names(withheld)[!(names(withheld) %in% c("series_id", "cut_id"))]

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
  vc_value_status_empty, vc_value_legacy_empty, vc_value_se_ci, vc_value_n
)

#' Bind every vc_* function's findings for one ctx into one data frame.
run_all_checks <- function(ctx) {
  do.call(rbind, lapply(ALL_CHECK_FNS, function(fn) as.data.frame(fn(ctx))))
}

#' Drop non-ERROR findings (vc_value_n's per-file INFO row on a
#' ROUNDED_2DP fixture is expected background noise, not a mutation's
#' effect - see the WP12.A1 test).
only_errors <- function(findings) findings[findings$severity == "ERROR", , drop = FALSE]

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
  # The fixture's default precision is ROUNDED_2DP (helper-data-fixture.R),
  # so VALUE.N still gives its one INFO finding noting the exemption.
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
  withheld_row <- s$withheld[1, s$key_cols, drop = FALSE]
  withheld_row$OBS_VALUE <- "0.5"
  withheld_row$OBS_STATUS <- "A"
  withheld_row$STD_ERR <- ""
  withheld_row$CI_LOWER <- ""
  withheld_row$CI_UPPER <- ""
  withheld_row$N_OBS <- ""
  withheld_row$N_POP <- ""
  withheld_row$OBS_COMMENT <- ""
  withheld_row <- withheld_row[names(df)]
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

# ---- VALUE.N on an EXACT-precision file ------------------------------------

test_that("vc_value_n flags EXACT-file N_OBS/N_POP problems, and gives no INFO row", {
  s <- build_clean_gnb_fixture()
  set_manifest(s$data_path, "precision", "EXACT")

  df <- read_std_csv(s$data_path)
  df$N_OBS <- "10"
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

test_that("vc_value_n gives one INFO finding per ROUNDED_2DP file, and no ERROR", {
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
