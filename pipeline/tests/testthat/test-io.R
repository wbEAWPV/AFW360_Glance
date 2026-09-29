root <- find_root()
source(file.path(root, "pipeline", "R", "io.R"))
source(file.path(root, "pipeline", "R", "constants.R"))

test_that("fmt_num formats fixed notation, never scientific, no trailing zeros", {
  x <- c(0.37, 6520000, -3460.12, 1e-7, 100, NA)
  expect_equal(
    fmt_num(x),
    c("0.37", "6520000", "-3460.12", "0.0000001", "100", "")
  )
})

test_that("fmt_num trims trailing zeros and a trailing decimal point", {
  expect_equal(fmt_num(c(2, 2.5, 0)), c("2", "2.5", "0"))
})

test_that("write_std_csv writes no BOM, no CR byte, and NA as empty", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  df <- data.frame(
    id = c("a", "b"),
    val = c(1, NA_real_),
    txt = c(NA_character_, "y"),
    stringsAsFactors = FALSE
  )
  write_std_csv(df, tmp)

  raw <- readBin(tmp, "raw", n = file.size(tmp))
  expect_false(length(raw) >= 3 && identical(raw[1:3], as.raw(c(0xEF, 0xBB, 0xBF))))
  expect_false(any(raw == as.raw(0x0D)))

  back <- read_std_csv(tmp)
  expect_true(all(vapply(back, is.character, logical(1))))
  expect_equal(back$val, c("1", ""))
  expect_equal(back$txt, c("", "y"))
})

test_that("read_std_csv strips a BOM, accepts CRLF, and keeps empty cells as \"\"", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  bom <- as.raw(c(0xEF, 0xBB, 0xBF))
  content <- "a,b,c\r\n1,,3\r\n"
  con <- file(tmp, open = "wb")
  writeBin(bom, con)
  writeBin(charToRaw(content), con)
  close(con)

  df <- read_std_csv(tmp)
  expect_equal(names(df), c("a", "b", "c"))
  expect_true(all(vapply(df, is.character, logical(1))))
  expect_equal(df$b[1], "")
  expect_equal(df$a[1], "1")
})

test_that("sha256_file returns a lower-case hex digest", {
  tmp <- tempfile()
  on.exit(unlink(tmp))
  writeLines("hello", tmp, useBytes = TRUE)
  h <- sha256_file(tmp)
  expect_match(h, "^[0-9a-f]{64}$")
})

test_that("load_metadata reads csvs under metadata/ and content/, keyed by stem", {
  tmp <- tempfile()
  on.exit(unlink(tmp, recursive = TRUE))
  dir.create(file.path(tmp, "metadata", "structure"), recursive = TRUE)
  write_std_csv(
    data.frame(x = "1", stringsAsFactors = FALSE),
    file.path(tmp, "metadata", "structure", "CL_GEO.csv")
  )

  meta <- load_metadata(tmp)
  expect_true("CL_GEO" %in% names(meta))
  expect_true(is.data.frame(meta$CL_GEO))
  expect_equal(meta$CL_GEO$x, "1")
})

test_that("load_metadata skips a missing metadata/content folder silently", {
  tmp <- tempfile()
  on.exit(unlink(tmp, recursive = TRUE))
  dir.create(tmp)
  meta <- load_metadata(tmp)
  expect_equal(meta, list())
})

test_that("repo_path joins segments under root", {
  expect_equal(repo_path("root", "a", "b.csv"), file.path("root", "a", "b.csv"))
})

test_that("cli_arg, cli_args and cli_flag parse a commandArgs-style vector", {
  args <- c("--root", "somewhere", "--data", "a.csv", "--data", "b.csv", "--verbose")
  expect_equal(cli_arg(args, "--root"), "somewhere")
  expect_equal(cli_arg(args, "--missing", "default"), "default")
  expect_null(cli_arg(args, "--missing"))
  expect_equal(cli_args(args, "--data"), c("a.csv", "b.csv"))
  expect_equal(cli_args(args, "--missing"), character(0))
  expect_true(cli_flag(args, "--verbose"))
  expect_false(cli_flag(args, "--quiet"))
})

test_that("structure_id and data_columns follow SDMX-CSV 2.1 and the DSD", {
  expect_equal(structure_id("0.3.0"), "WB.AFW360:AFW360_HH(0.3.0)")
  meta <- load_metadata(root)
  comps <- dsd_components(meta)
  expect_length(comps, 34)
  expect_equal(comps[c(1, 19, 20, 34)], c("FREQ", "TIME_PERIOD", "OBS_VALUE", "OBS_COMMENT"))
  cols <- data_columns(meta)
  expect_length(cols, 37)
  expect_equal(cols[1:3], c("STRUCTURE", "STRUCTURE_ID", "ACTION"))
  expect_equal(cols[-(1:3)], comps)
  expect_equal(dsd_key_columns(meta), comps[1:19])
})

test_that("write_sdmx_csv adds the fixed columns, writes NaN literally and round-trips", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  df <- data.frame(
    FREQ = c("A", "A"),
    OBS_VALUE = c("0.5", "NaN"),
    STD_ERR = c(NA_character_, ""),
    N_POP = c(NaN, 2),
    stringsAsFactors = FALSE
  )
  write_sdmx_csv(df, tmp, "0.3.0")

  lines <- readLines(tmp)
  expect_equal(lines[1], "STRUCTURE,STRUCTURE_ID,ACTION,FREQ,OBS_VALUE,STD_ERR,N_POP")
  expect_equal(lines[2], "dataflow,WB.AFW360:AFW360_HH(0.3.0),R,A,0.5,,NaN")
  expect_equal(lines[3], "dataflow,WB.AFW360:AFW360_HH(0.3.0),R,A,NaN,,2")
  raw <- readBin(tmp, "raw", n = file.size(tmp))
  expect_false(any(raw == as.raw(0x0D)))
  expect_false(identical(raw[1:3], as.raw(c(0xEF, 0xBB, 0xBF))))

  back <- read_sdmx_csv(tmp, "0.3.0")
  expect_equal(names(back), names(df))
  expect_equal(back$OBS_VALUE, c("0.5", "NaN"))
  expect_equal(back$STD_ERR, c("", ""))
})

test_that("read_sdmx_csv stops on a STRUCTURE_ID of another version or missing fixed columns", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  write_sdmx_csv(data.frame(FREQ = "A", stringsAsFactors = FALSE), tmp, "0.2.0")
  expect_error(read_sdmx_csv(tmp, "0.3.0"), "expected 'WB.AFW360:AFW360_HH(0.3.0)'", fixed = TRUE)

  write_std_csv(data.frame(FREQ = "A", stringsAsFactors = FALSE), tmp)
  expect_error(read_sdmx_csv(tmp, "0.3.0"), "does not start with")
})
