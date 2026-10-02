# 20-excel-sdmx-csv/tests/testthat/test-plans.R
#
# Tests for R/plans_check.R: the committed plans are clean against
# plans/PLAN_COLUMNS.csv and the standard, and each kind of defect is found.

root <- find_root()
source(stage_path(root, "code", "constants.R"))
source(stage_path(root, "code", "plans_check.R"))

test_that("the committed plans have no ERROR", {
  f <- plans_check(root)
  expect_named(f, c("check_id", "severity", "file", "row_key", "message"))
  expect_equal(nrow(f[f$severity == "ERROR", ]), 0, info = paste(f$message, collapse = "\n"))
})

test_that("PLAN_COLUMNS.csv lists exactly the CSV files under plans/", {
  reg <- read_std_csv(stage_path(root, "plans", "PLAN_COLUMNS.csv"))
  expect_setequal(unique(reg$file), list.files(stage_dir(root, "plans"), pattern = "[.]csv$"))
})

test_that("a swapped header, an empty required cell and a broken reference are found", {
  tmp <- make_temp_root(root, include = "metadata")
  on.exit(unlink(dirname(tmp), recursive = TRUE), add = TRUE)
  edit_csv(stage_path(tmp, "plans", "TAB_PLAN.csv"), function(df) df[c(2, 1, 3:ncol(df))])
  edit_csv(stage_path(tmp, "plans", "LEGACY_COLUMNS.csv"), function(df) {
    df$cut_id[1] <- "NO_SUCH_CUT"
    df$sheet[2] <- ""
    df
  })
  f <- plans_check(tmp)
  expect_true(any(f$check_id == "PLANS.HEADER" & f$file == "plans/TAB_PLAN.csv"))
  expect_true(any(f$check_id == "PLANS.REQUIRED" & f$file == "plans/LEGACY_COLUMNS.csv"))
  expect_true(any(f$check_id == "PLANS.REFERENCE" & grepl("NO_SUCH_CUT", f$message)))
})

test_that("a series_id unknown to the standard's SERIES_PLAN is found", {
  tmp <- make_temp_root(root, include = "metadata")
  on.exit(unlink(dirname(tmp), recursive = TRUE), add = TRUE)
  edit_csv(stage_path(tmp, "plans", "LEGACY_LABELS.csv"), function(df) {
    i <- which(df$series_id != "")[1]
    df$series_id[i] <- "NOT_A_SERIES"
    df
  })
  f <- plans_check(tmp)
  hit <- f[f$check_id == "PLANS.REFERENCE" & f$file == "plans/LEGACY_LABELS.csv", ]
  expect_equal(nrow(hit), 1)
  expect_match(hit$message, "SERIES_PLAN.series_id: NOT_A_SERIES", fixed = TRUE)
})

test_that("a plan CSV without register rows is found", {
  tmp <- make_temp_root(root, include = "metadata")
  on.exit(unlink(dirname(tmp), recursive = TRUE), add = TRUE)
  writeLines("a,b", stage_path(tmp, "plans", "EXTRA.csv"))
  f <- plans_check(tmp)
  expect_true(any(f$check_id == "PLANS.MISSING" & f$file == "plans/EXTRA.csv"))
})
