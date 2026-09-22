root <- find_root()
source(file.path(root, "pipeline", "R", "io.R"))
source(file.path(root, "pipeline", "R", "ctx.R"))

test_that("build_ctx returns the six expected components with no data files", {
  tmp <- tempfile()
  on.exit(unlink(tmp, recursive = TRUE))
  dir.create(tmp)

  ctx <- build_ctx(tmp)
  expect_equal(sort(names(ctx)), sort(c("root", "meta", "data", "manifests", "precision", "opts")))
  expect_equal(ctx$root, tmp)
  expect_type(ctx$meta, "list")
  expect_equal(ctx$data, list())
  expect_equal(ctx$manifests, list())
  expect_length(ctx$precision, 0)
  expect_equal(ctx$opts, list())
})

test_that("build_ctx loads metadata under the given root", {
  tmp <- tempfile()
  on.exit(unlink(tmp, recursive = TRUE))
  dir.create(file.path(tmp, "metadata", "structure"), recursive = TRUE)
  write_std_csv(
    data.frame(x = "1", stringsAsFactors = FALSE),
    file.path(tmp, "metadata", "structure", "CL_GEO.csv")
  )

  ctx <- build_ctx(tmp)
  expect_true("CL_GEO" %in% names(ctx$meta))
})

test_that("build_ctx reads a data file and defaults precision to EXACT when no manifest exists", {
  tmp <- tempfile()
  on.exit(unlink(tmp, recursive = TRUE))
  dir.create(file.path(tmp, "data"), recursive = TRUE)
  data_path <- file.path(tmp, "data", "AFW360_HH_SEN_2021.csv")
  write_std_csv(data.frame(DATAFLOW = "AFW360_HH", stringsAsFactors = FALSE), data_path)

  ctx <- build_ctx(tmp, data_files = data_path)
  expect_equal(names(ctx$data), "AFW360_HH_SEN_2021")
  expect_equal(ctx$data[["AFW360_HH_SEN_2021"]]$DATAFLOW, "AFW360_HH")
  expect_length(ctx$manifests[["AFW360_HH_SEN_2021"]], 0)
  expect_equal(unname(ctx$precision["AFW360_HH_SEN_2021"]), "EXACT")
})

test_that("build_ctx reads a manifest's precision and other keys when present", {
  tmp <- tempfile()
  on.exit(unlink(tmp, recursive = TRUE))
  dir.create(file.path(tmp, "data"), recursive = TRUE)
  data_path <- file.path(tmp, "data", "AFW360_HH_SEN_2021.csv")
  write_std_csv(data.frame(DATAFLOW = "AFW360_HH", stringsAsFactors = FALSE), data_path)

  manifest_path <- file.path(tmp, "data", "AFW360_HH_SEN_2021_manifest.csv")
  write_std_csv(
    data.frame(
      key = c("precision", "source"),
      value = c("ROUNDED", "Tables_SEN.xlsx"),
      stringsAsFactors = FALSE
    ),
    manifest_path
  )

  ctx <- build_ctx(tmp, data_files = data_path)
  man <- ctx$manifests[["AFW360_HH_SEN_2021"]]
  expect_equal(unname(man["precision"]), "ROUNDED")
  expect_equal(unname(man["source"]), "Tables_SEN.xlsx")
  expect_equal(unname(ctx$precision["AFW360_HH_SEN_2021"]), "ROUNDED")
})

test_that("build_ctx carries opts through unchanged", {
  tmp <- tempfile()
  on.exit(unlink(tmp, recursive = TRUE))
  dir.create(tmp)
  ctx <- build_ctx(tmp, opts = list(verbose = TRUE))
  expect_equal(ctx$opts, list(verbose = TRUE))
})
