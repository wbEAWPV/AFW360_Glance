# 30-sdmx/pipeline/tests/testthat/test-migrate-0.3.0.R
#
# Runs pipeline/migrations/0.3.0/migrate.R on the frozen 0.2.0 fixture
# (fixtures/metadata-0.2.0/, a byte copy of metadata/ at commit e24b664) with
# --out-root, and checks that the result equals the committed metadata byte
# for byte. Also checks the version guard. Since the pipeline split, the
# legacy plans (TAB_PLAN.csv, LEGACY_*.csv) and their rows of COLUMNS.csv
# live in 20-excel-sdmx-csv/plans/ (PLAN_COLUMNS.csv): the standard's part
# is compared with data/metadata/, the plans' part with 20-excel-sdmx-csv/plans/
# when that folder is present.

root <- find_root()
fixture <- file.path(root, "pipeline", "tests", "testthat", "fixtures", "metadata-0.2.0")
script <- file.path(root, "pipeline", "migrations", "0.3.0", "migrate.R")
rscript <- file.path(R.home("bin"), "Rscript")

run_migration <- function(in_root, out_root) {
  out <- suppressWarnings(system2(
    rscript,
    c(shQuote(script), "--root", shQuote(in_root), "--out-root", shQuote(out_root)),
    stdout = TRUE, stderr = TRUE
  ))
  status <- attr(out, "status")
  list(status = if (is.null(status)) 0L else status, output = out)
}

out_root <- tempfile("afw360_migrate_")
dir.create(out_root)
res <- run_migration(fixture, out_root)

test_that("the migration runs cleanly on the 0.2.0 fixture", {
  expect_equal(res$status, 0L, info = paste(res$output, collapse = "\n"))
})

.legacy_plans <- c("LEGACY_COLUMNS.csv", "LEGACY_LABELS.csv", "LEGACY_OVERRIDES.csv", "TAB_PLAN.csv")
.raw <- function(p) readBin(p, "raw", file.info(p)$size)
.lines <- function(p) strsplit(rawToChar(.raw(p)), "\n", fixed = TRUE)[[1]]
.is_plan_row <- function(lines) {
  grepl("^(LEGACY_COLUMNS|LEGACY_LABELS|LEGACY_OVERRIDES|TAB_PLAN)[.]csv,", lines)
}

test_that("the migrated fixture equals the committed metadata byte for byte", {
  got <- sort(list.files(file.path(out_root, "metadata"), recursive = TRUE), method = "radix")
  want <- sort(list.files(stage_dir(root, "metadata"), recursive = TRUE), method = "radix")
  expect_equal(setdiff(got, paste0("plans/", .legacy_plans)), want)
  for (f in intersect(got, want)) {
    a <- file.path(out_root, "metadata", f)
    b <- stage_path(root, "metadata", f)
    if (identical(f, "structure/COLUMNS.csv")) {
      la <- .lines(a)
      expect_identical(la[!.is_plan_row(la)], .lines(b), info = f)
    } else {
      expect_identical(.raw(a), .raw(b), info = f)
    }
  }
})

test_that("the migrated legacy plans equal 20-excel-sdmx-csv/plans/ byte for byte", {
  plans <- stage_dir(root, "plans")
  skip_if_not(dir.exists(plans), "20-excel-sdmx-csv/plans/ is not present")
  for (f in .legacy_plans) {
    expect_identical(.raw(file.path(out_root, "metadata", "plans", f)), .raw(file.path(plans, f)), info = f)
  }
  la <- .lines(file.path(out_root, "metadata", "structure", "COLUMNS.csv"))
  lp <- .lines(file.path(plans, "PLAN_COLUMNS.csv"))
  expect_identical(lp[1], la[1])
  expect_identical(lp[-1][.is_plan_row(lp[-1])], la[.is_plan_row(la)])
})

test_that("the guard refuses to run on metadata that is not 0.2.0 and writes nothing", {
  refused <- tempfile("afw360_migrate_")
  dir.create(refused)
  on.exit(unlink(refused, recursive = TRUE))
  r <- run_migration(stage_dir(root, "data"), refused) # the folder holding metadata/
  expect_equal(r$status, 1L)
  expect_true(any(grepl("not 0.2.0", r$output, fixed = TRUE)))
  expect_length(list.files(refused, recursive = TRUE, all.files = TRUE, no.. = TRUE), 0L)
})
