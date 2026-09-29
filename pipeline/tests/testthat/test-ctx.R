root <- find_root()
source(file.path(root, "pipeline", "R", "io.R"))
source(file.path(root, "pipeline", "R", "constants.R"))
source(file.path(root, "pipeline", "R", "ctx.R"))

test_that("build_ctx returns the five expected components with no data files", {
  tmp <- tempfile()
  on.exit(unlink(tmp, recursive = TRUE))
  dir.create(tmp)

  ctx <- build_ctx(tmp)
  expect_equal(sort(names(ctx)), sort(c("root", "meta", "data", "manifests", "opts")))
  expect_equal(ctx$root, tmp)
  expect_type(ctx$meta, "list")
  expect_equal(ctx$data, list())
  expect_equal(ctx$manifests, list())
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

test_that("build_ctx reads a data file and gives an empty manifest when none exists", {
  tmp <- tempfile()
  on.exit(unlink(tmp, recursive = TRUE))
  dir.create(file.path(tmp, "data"), recursive = TRUE)
  data_path <- file.path(tmp, "data", "AFW360_HH_SEN_2021_SURVEY.csv")
  write_std_csv(data.frame(DATAFLOW = "AFW360_HH", stringsAsFactors = FALSE), data_path)

  ctx <- build_ctx(tmp, data_files = data_path)
  expect_equal(names(ctx$data), "AFW360_HH_SEN_2021_SURVEY")
  expect_equal(ctx$data[["AFW360_HH_SEN_2021_SURVEY"]]$DATAFLOW, "AFW360_HH")
  expect_length(ctx$manifests[["AFW360_HH_SEN_2021_SURVEY"]], 0)
  # With no manifest, the estimation comes from the file name.
  expect_equal(ctx_file_estimation(ctx, "AFW360_HH_SEN_2021_SURVEY"), "SURVEY")
})

test_that("build_ctx reads a manifest's keys when present", {
  tmp <- tempfile()
  on.exit(unlink(tmp, recursive = TRUE))
  dir.create(file.path(tmp, "data"), recursive = TRUE)
  data_path <- file.path(tmp, "data", "AFW360_HH_SEN_2021_MODEL.csv")
  write_std_csv(data.frame(DATAFLOW = "AFW360_HH", stringsAsFactors = FALSE), data_path)

  manifest_path <- file.path(tmp, "data", "AFW360_HH_SEN_2021_MODEL_manifest.csv")
  write_std_csv(
    data.frame(
      key = c("estimation", "sources"),
      value = c("SURVEY", "SEN_EHCVM2021_LEGACY_v1"),
      stringsAsFactors = FALSE
    ),
    manifest_path
  )

  ctx <- build_ctx(tmp, data_files = data_path)
  man <- ctx$manifests[["AFW360_HH_SEN_2021_MODEL"]]
  expect_equal(unname(man["estimation"]), "SURVEY")
  expect_equal(unname(man["sources"]), "SEN_EHCVM2021_LEGACY_v1")
  # The manifest's estimation wins over the file name's.
  expect_equal(ctx_file_estimation(ctx, "AFW360_HH_SEN_2021_MODEL"), "SURVEY")
})

test_that("ctx_parse_file_name reads the three parts of a data file stem", {
  expect_equal(
    ctx_parse_file_name("AFW360_HH_GNB_2021_SURVEY"),
    c(ref_area = "GNB", time_period = "2021", estimation = "SURVEY")
  )
  expect_null(ctx_parse_file_name("AFW360_HH_GNB_2021"))
})

test_that("build_ctx carries opts through unchanged", {
  tmp <- tempfile()
  on.exit(unlink(tmp, recursive = TRUE))
  dir.create(tmp)
  ctx <- build_ctx(tmp, opts = list(verbose = TRUE))
  expect_equal(ctx$opts, list(verbose = TRUE))
})
