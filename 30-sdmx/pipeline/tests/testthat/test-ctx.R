root <- find_root()
source(file.path(root, "pipeline", "R", "io.R"))
source(file.path(root, "pipeline", "R", "constants.R"))
source(file.path(root, "pipeline", "R", "ctx.R"))

test_that("build_ctx returns the six expected components with no data files", {
  tmp <- tempfile()
  on.exit(unlink(tmp, recursive = TRUE))
  dir.create(tmp)

  ctx <- build_ctx(tmp)
  expect_equal(sort(names(ctx)), sort(c("root", "meta", "data", "manifests", "version", "opts")))
  expect_equal(ctx$root, tmp)
  expect_type(ctx$meta, "list")
  expect_equal(ctx$data, list())
  expect_equal(ctx$manifests, list())
  expect_equal(ctx$opts, list())
  # No metadata/VERSION under the root: the version is NA.
  expect_true(is.na(ctx$version))
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
  write_std_csv(data.frame(STRUCTURE = "dataflow", stringsAsFactors = FALSE), data_path)

  ctx <- build_ctx(tmp, data_files = data_path)
  expect_equal(names(ctx$data), "AFW360_HH_SEN_2021_SURVEY")
  expect_equal(ctx$data[["AFW360_HH_SEN_2021_SURVEY"]]$STRUCTURE, "dataflow")
  expect_length(ctx$manifests[["AFW360_HH_SEN_2021_SURVEY"]], 0)
  # With no manifest, the estimation comes from the file name.
  expect_equal(ctx_file_estimation(ctx, "AFW360_HH_SEN_2021_SURVEY"), "SURVEY")
})

test_that("build_ctx reads a manifest's keys when present", {
  tmp <- tempfile()
  on.exit(unlink(tmp, recursive = TRUE))
  dir.create(file.path(tmp, "data"), recursive = TRUE)
  data_path <- file.path(tmp, "data", "AFW360_HH_SEN_2021_MODEL.csv")
  write_std_csv(data.frame(STRUCTURE = "dataflow", stringsAsFactors = FALSE), data_path)

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

test_that("build_ctx reads the metadata version from metadata/VERSION", {
  tmp <- tempfile()
  on.exit(unlink(tmp, recursive = TRUE))
  dir.create(file.path(tmp, "metadata"), recursive = TRUE)
  writeLines("0.3.0", file.path(tmp, "metadata", "VERSION"))
  ctx <- build_ctx(tmp)
  expect_equal(ctx$version, "0.3.0")
  expect_equal(structure_id(ctx$version), "WB.AFW360:AFW360_HH(0.3.0)")
})

test_that("the column accessors follow the real DSD: 19 key columns, 34 components, 37 data columns", {
  ctx <- build_ctx(root)
  key <- ctx_key_columns(ctx)
  expect_length(key, 19L)
  expect_equal(key[c(1, 2, 18, 19)], c("FREQ", "REF_AREA", "MEASURE_QUAL_5", "TIME_PERIOD"))
  expect_false("DATAFLOW" %in% key)
  expect_length(ctx_dsd_columns(ctx), 34L)
  cols <- ctx_data_columns(ctx)
  expect_length(cols, 37L)
  expect_equal(cols[1:4], c("STRUCTURE", "STRUCTURE_ID", "ACTION", "FREQ"))
  expect_equal(cols[37], "OBS_COMMENT")
  expect_equal(ctx$version, trimws(readLines(file.path(root, "metadata", "VERSION"), n = 1)))
})

test_that("the column accessors stop without DSD_AFW360_HH (no hard-coded fallback)", {
  tmp <- tempfile()
  on.exit(unlink(tmp, recursive = TRUE))
  dir.create(tmp)
  ctx <- build_ctx(tmp)
  expect_error(ctx_key_columns(ctx), "DSD_AFW360_HH")
  expect_error(ctx_dsd_columns(ctx), "DSD_AFW360_HH")
  expect_error(ctx_row_keys(ctx, data.frame(REF_AREA = "SEN")), "DSD_AFW360_HH")
})
