# pipeline/tests/testthat/test-migrate-0.3.0.R
#
# Runs pipeline/migrations/0.3.0/migrate.R on the frozen 0.2.0 fixture
# (fixtures/metadata-0.2.0/, a byte copy of metadata/ at commit e24b664) with
# --out-root, and checks that the result equals the committed metadata/ byte
# for byte. Also checks the version guard.

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

test_that("the migrated fixture equals the committed metadata/ byte for byte", {
  got <- sort(list.files(file.path(out_root, "metadata"), recursive = TRUE), method = "radix")
  want <- sort(list.files(file.path(root, "metadata"), recursive = TRUE), method = "radix")
  expect_equal(got, want)
  for (f in intersect(got, want)) {
    a <- file.path(out_root, "metadata", f)
    b <- file.path(root, "metadata", f)
    expect_identical(readBin(a, "raw", file.info(a)$size), readBin(b, "raw", file.info(b)$size), info = f)
  }
})

test_that("the guard refuses to run on metadata that is not 0.2.0 and writes nothing", {
  refused <- tempfile("afw360_migrate_")
  dir.create(refused)
  on.exit(unlink(refused, recursive = TRUE))
  r <- run_migration(root, refused)
  expect_equal(r$status, 1L)
  expect_true(any(grepl("not 0.2.0", r$output, fixed = TRUE)))
  expect_length(list.files(refused, recursive = TRUE, all.files = TRUE, no.. = TRUE), 0L)
})
