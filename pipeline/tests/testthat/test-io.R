root <- find_root()
source(file.path(root, "pipeline", "R", "io.R"))

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
