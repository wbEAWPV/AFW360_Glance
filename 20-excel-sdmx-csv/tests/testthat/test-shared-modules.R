# 20-excel-sdmx-csv/tests/testthat/test-shared-modules.R
#
# The modules both stages need are copied, not shared across folders: each
# stage runs on its own. This test keeps the copies from drifting: when the
# SDMX stage is present next to this one, every shared module here must be
# byte-identical to its copy in 30-sdmx/pipeline/R/.

root <- find_root()

# The shared modules (listed in both stages' README.md).
SHARED_MODULES <- c("io.R", "codes.R", "constants.R", "manifest.R", "docs_md.R")

test_that("the shared modules are byte-identical to 30-sdmx/pipeline/R/", {
  other <- file.path(stage_dir(root, "sdmx_stage"), "pipeline", "R")
  skip_if_not(dir.exists(other), "30-sdmx/pipeline/R/ is not present")
  for (m in SHARED_MODULES) {
    a <- stage_path(root, "code", m)
    b <- file.path(other, m)
    expect_true(file.exists(b), info = m)
    expect_identical(
      readBin(a, "raw", file.info(a)$size), readBin(b, "raw", file.info(b)$size),
      info = paste(m, "differs from 30-sdmx/pipeline/R/; change both copies together")
    )
  }
})

test_that("every shared module says it is shared", {
  for (m in SHARED_MODULES) {
    txt <- readLines(stage_path(root, "code", m), n = 6, warn = FALSE)
    expect_true(any(grepl("Shared module", txt, fixed = TRUE)), info = m)
  }
})
