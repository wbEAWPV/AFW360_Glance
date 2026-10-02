# 20-excel-sdmx-csv/tests/testthat/test-docs.R
#
# Tests for R/docs.R: the five tables of the legacy plans are built from
# plans/, equal the committed .docs/generated/ fragments, and are included.

root <- find_root()
source(stage_path(root, "code", "docs_md.R"))
source(stage_path(root, "code", "docs.R"))

test_that("the generator builds exactly the five tables of the legacy plans", {
  expect_setequal(
    names(docs_fragments(root)),
    c("tbl-initial-plan", "tbl-tab-plan", "tbl-legacy-labels", "tbl-legacy-columns-csv", "tbl-legacy-overrides")
  )
})

test_that("the committed fragments are current and included", {
  skip_if_not(dir.exists(stage_path(root, "docs", "generated")), ".docs/generated/ is not present")
  f <- docs_check(root)
  expect_equal(nrow(f), 0, info = paste(f$check_id, f$file, f$message, collapse = "\n"))
})

test_that("a stale fragment is reported", {
  out <- tempfile("afw360_docs20_")
  on.exit(unlink(out, recursive = TRUE), add = TRUE)
  docs_build(root, out)
  cat("extra\n", file = file.path(out, "tbl-tab-plan.md"), append = TRUE)
  f <- docs_check(root, gen_dir = out)
  expect_true(any(f$check_id == "DOCS.FRAGMENT_STALE" & f$row_key == "tbl-tab-plan"))
})
