# pipeline/tests/testthat/test-reconcile.R
#
# WP16 - Independent reconciliation tool. Builds data files straight from
# expected_rows() (never from the converter), checks the tool reports
# PASS, then mutates one thing at a time to check the comparison logic.
# The verifier checks expected_rows() itself against the raw workbook by
# hand.

root <- find_root()
source(file.path(root, "pipeline", "R", "io.R"))
source(file.path(root, "pipeline", "R", "codes.R"))
source(file.path(root, "pipeline", "R", "reconcile.R"))

.key_cols <- c(
  "DATAFLOW", "REF_AREA", "GEO", "TIME_PERIOD", "INDICATOR", "SEX", "AGE",
  "URBANISATION", paste0("COMP_BREAKDOWN_", 1:5), paste0("MEASURE_QUAL_", 1:5)
)
.dsd_cols <- c(
  .key_cols, "OBS_VALUE", "OBS_STATUS", "STD_ERR", "CI_LOWER", "CI_UPPER",
  "N_OBS", "N_POP", "OBS_COMMENT"
)

#' Write data/AFW360_HH_<ref_area>_<time_period>.csv under `tmp`, straight
#' from `erows` (the output of expected_rows()), one file per country,
#' one row per *converted* cell (withheld cells are correctly absent).
#'
#' @return A named character vector of the data file paths, by ref_area.
.write_fixture_data <- function(tmp, erows) {
  meta <- load_metadata(tmp)
  surveys <- meta$SURVEYS
  paths <- character(0)
  for (ra in sort(unique(erows$ref_area))) {
    sub <- erows[erows$ref_area == ra & erows$class == "converted", ]
    data <- sub[.key_cols]
    data$OBS_VALUE <- sub$OBS_VALUE
    data$OBS_STATUS <- sub$OBS_STATUS
    data$STD_ERR <- ""
    data$CI_LOWER <- ""
    data$CI_UPPER <- ""
    data$N_OBS <- ""
    data$N_POP <- ""
    data$OBS_COMMENT <- sub$OBS_COMMENT_EXPECTED
    data <- data[.dsd_cols]
    tp <- surveys$time_period[surveys$ref_area == ra]
    path <- file.path(tmp, "data", paste0("AFW360_HH_", ra, "_", tp, ".csv"))
    write_std_csv(data, path)
    paths[[ra]] <- path
  }
  paths
}

#' A fresh temp root (metadata + data_raw copied) with matching fixture
#' data already written, plus the expected_rows() it was built from.
.new_fixture <- function() {
  tmp <- make_temp_root(root, include = c("metadata", "data_raw"))
  erows <- expected_rows(tmp)
  paths <- .write_fixture_data(tmp, erows)
  list(tmp = tmp, erows = erows, paths = paths)
}

test_that("source_cells() classifies every real source cell as accepted", {
  cells <- source_cells(root)

  expect_equal(sum(cells$ref_area == "SEN" & cells$sheet != "Departement"), 3201)
  expect_equal(sum(cells$ref_area == "SEN" & cells$sheet == "Departement"), 1148)
  expect_equal(sum(cells$ref_area == "GNB"), 2522)

  expect_equal(sum(cells$ref_area == "SEN" & cells$class == "converted"), 3003)
  expect_equal(sum(cells$ref_area == "SEN" & cells$class == "withheld"), 0)
  expect_equal(sum(cells$ref_area == "GNB" & cells$class == "converted"), 2268)
  expect_equal(sum(cells$ref_area == "GNB" & cells$class == "withheld"), 98)

  expect_equal(
    sum(cells$ref_area == "SEN" & cells$sheet != "Departement" &
          cells$class %in% c("duplicate", "derived", "skipped")),
    198
  )
  expect_equal(
    sum(cells$ref_area == "GNB" & cells$class %in% c("duplicate", "derived", "skipped")),
    156
  )

  # Every class assigned; class counts add up to the source cells (WP16.A1).
  expect_false(anyNA(cells$class))
  expect_true(all(cells$class %in% c("skipped", "duplicate", "derived", "withheld", "converted")))
})

test_that("reconcile() passes on data generated straight from expected_rows()", {
  fx <- .new_fixture()
  on.exit(unlink(fx$tmp, recursive = TRUE), add = TRUE)

  res <- reconcile(fx$tmp)

  expect_length(res$missing_files, 0)
  expect_true(all(res$report_rows$result == "OK"))
  expect_equal(nrow(res$orphans), 0)

  # WP16.A4: 9 columns, one row per source cell.
  expect_equal(
    names(res$report_rows),
    c("ref_area", "sheet", "legacy_label", "column", "class", "result",
      "source_value", "data_value", "row_key")
  )
  expect_equal(nrow(res$report_rows), nrow(source_cells(fx$tmp)))
})

test_that("a changed value gives MISMATCH", {
  fx <- .new_fixture()
  on.exit(unlink(fx$tmp, recursive = TRUE), add = TRUE)

  edit_csv(fx$paths[["SEN"]], function(df) {
    i <- which(df$OBS_VALUE != "")[1]
    df$OBS_VALUE[i] <- fmt_num(as.numeric(df$OBS_VALUE[i]) + 1)
    df
  })

  res <- reconcile(fx$tmp)
  expect_true(any(res$report_rows$result == "MISMATCH"))
  expect_false(all(res$report_rows$result == "OK"))
})

test_that("a deleted row gives MISSING_ROW", {
  fx <- .new_fixture()
  on.exit(unlink(fx$tmp, recursive = TRUE), add = TRUE)

  edit_csv(fx$paths[["SEN"]], function(df) df[-1, , drop = FALSE])

  res <- reconcile(fx$tmp)
  expect_true(any(res$report_rows$result == "MISSING_ROW"))
})

test_that("a duplicated row gives DUPLICATE_ROW", {
  fx <- .new_fixture()
  on.exit(unlink(fx$tmp, recursive = TRUE), add = TRUE)

  edit_csv(fx$paths[["SEN"]], function(df) rbind(df, df[1, , drop = FALSE]))

  res <- reconcile(fx$tmp)
  expect_true(any(res$report_rows$result == "DUPLICATE_ROW"))
})

test_that("a row added for a withheld cell gives WITHHELD_PRESENT", {
  fx <- .new_fixture()
  on.exit(unlink(fx$tmp, recursive = TRUE), add = TRUE)

  withheld <- fx$erows[fx$erows$class == "withheld", ][1, ]
  expect_equal(nrow(withheld), 1)

  new_row <- data.frame(as.list(stats::setNames(
    strsplit(withheld$row_key, "|", fixed = TRUE)[[1]], .key_cols
  )), stringsAsFactors = FALSE)
  new_row$OBS_VALUE <- "0.5"
  new_row$OBS_STATUS <- "A"
  new_row$STD_ERR <- ""
  new_row$CI_LOWER <- ""
  new_row$CI_UPPER <- ""
  new_row$N_OBS <- ""
  new_row$N_POP <- ""
  new_row$OBS_COMMENT <- ""
  new_row <- new_row[.dsd_cols]

  edit_csv(fx$paths[["GNB"]], function(df) rbind(df, new_row))

  res <- reconcile(fx$tmp)
  expect_true(any(res$report_rows$result == "WITHHELD_PRESENT"))
})

test_that("a row with an unplanned key gives ORPHAN", {
  fx <- .new_fixture()
  on.exit(unlink(fx$tmp, recursive = TRUE), add = TRUE)

  edit_csv(fx$paths[["SEN"]], function(df) {
    bogus <- df[1, , drop = FALSE]
    bogus$INDICATOR <- "NOT_A_REAL_INDICATOR"
    rbind(df, bogus)
  })

  res <- reconcile(fx$tmp)
  expect_gt(nrow(res$orphans), 0)
})

test_that("an O row given a value gives MISMATCH", {
  fx <- .new_fixture()
  on.exit(unlink(fx$tmp, recursive = TRUE), add = TRUE)

  o_rows <- fx$erows[fx$erows$class == "converted" & fx$erows$OBS_STATUS == "O", ]
  expect_gt(nrow(o_rows), 0)
  target_ra <- o_rows$ref_area[1]

  edit_csv(fx$paths[[target_ra]], function(df) {
    i <- which(df$OBS_STATUS == "O")[1]
    df$OBS_VALUE[i] <- "0.5"
    df
  })

  res <- reconcile(fx$tmp)
  expect_true(any(res$report_rows$result == "MISMATCH"))
})

test_that("neither pipeline/reconcile.R nor pipeline/R/reconcile.R refers to the converter", {
  # Built from parts, not spelled out whole, so this check's own text does
  # not itself trip a plain-text search for the names it looks for
  # (WP16.A5: the code must not refer to them at all).
  code <- c(
    readLines(file.path(root, "pipeline", "reconcile.R"), warn = FALSE),
    readLines(file.path(root, "pipeline", "R", "reconcile.R"), warn = FALSE)
  )
  forbidden <- c(
    paste0("convert", "_", "tables"),
    paste0("convert", "_", "legacy"),
    paste0("required", "_", "rows")
  )
  for (pattern in forbidden) {
    expect_false(any(grepl(pattern, code, fixed = TRUE)), info = pattern)
  }
})

test_that("the CLI exits 0 and writes a PASS report on matching fixture data", {
  fx <- .new_fixture()
  on.exit(unlink(fx$tmp, recursive = TRUE), add = TRUE)
  file.copy(file.path(root, "pipeline"), fx$tmp, recursive = TRUE)

  out_md <- file.path(fx$tmp, "report.md")
  out_csv <- file.path(fx$tmp, "cells.csv")
  cli <- file.path(fx$tmp, "pipeline", "reconcile.R")
  res <- system2(
    "Rscript",
    args = shQuote(c(cli, "--root", fx$tmp, "--out", out_md, "--csv", out_csv)),
    stdout = TRUE, stderr = TRUE
  )
  status <- attr(res, "status")
  status <- if (is.null(status)) 0L else status

  expect_equal(status, 0L)
  expect_true(file.exists(out_md))
  expect_true(file.exists(out_csv))
  md <- readLines(out_md, warn = FALSE)
  expect_equal(tail(md, 1), "RECONCILIATION: PASS")
})

test_that("the CLI exits 1 on a MISMATCH and exits 2 on a missing data file", {
  fx <- .new_fixture()
  on.exit(unlink(fx$tmp, recursive = TRUE), add = TRUE)
  file.copy(file.path(root, "pipeline"), fx$tmp, recursive = TRUE)
  cli <- file.path(fx$tmp, "pipeline", "reconcile.R")

  edit_csv(fx$paths[["SEN"]], function(df) {
    i <- which(df$OBS_VALUE != "")[1]
    df$OBS_VALUE[i] <- fmt_num(as.numeric(df$OBS_VALUE[i]) + 1)
    df
  })
  out_md <- file.path(fx$tmp, "report_fail.md")
  res <- suppressWarnings(system2(
    "Rscript",
    args = shQuote(c(cli, "--root", fx$tmp, "--out", out_md)),
    stdout = TRUE, stderr = TRUE
  ))
  expect_equal(attr(res, "status"), 1L)
  md <- readLines(out_md, warn = FALSE)
  expect_equal(tail(md, 1), "RECONCILIATION: FAIL")

  unlink(file.path(fx$tmp, "data"), recursive = TRUE)
  out_md2 <- file.path(fx$tmp, "report_missing.md")
  res2 <- suppressWarnings(system2(
    "Rscript",
    args = shQuote(c(cli, "--root", fx$tmp, "--out", out_md2)),
    stdout = TRUE, stderr = TRUE
  ))
  expect_equal(attr(res2, "status"), 2L)
})
