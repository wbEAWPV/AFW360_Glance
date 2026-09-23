#!/usr/bin/env Rscript
# Acceptance script for WP03 (Pipeline scaffold).
#
#   Rscript pipeline/acceptance/wp03_scaffold.R --root .
#
# Rules: standalone (does not source pipeline/R/ except where a check is about
# those functions); numbers are derived from the contract at run time rather
# than hard-coded; writes only to tempdir(); compares against files, never
# against transition/main or the branch diff.

## ---- 1. Root and check() -----------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
i <- which(args == "--root")
root <- normalizePath(if (length(i) == 1) args[i + 1] else ".", mustWork = TRUE)
contract <- file.path(root, ".docs", "transition", "contract")

.failures <- character(0)
check <- function(id, ok, evidence) {
  cat(sprintf("CHECK %s %s %s\n", id, if (isTRUE(ok)) "PASS" else "FAIL", evidence))
  if (!isTRUE(ok)) .failures[[length(.failures) + 1]] <<- id
  invisible(isTRUE(ok))
}
# Wrap a check that may stop(), so one error does not end the script.
try_check <- function(id, expr) {
  r <- tryCatch(expr, error = function(e) check(id, FALSE, paste("error:", conditionMessage(e))))
  invisible(r)
}

## ---- 2. Helpers ---------------------------------------------------------------
# All columns as character, BOM stripped, "" stays "" (never NA).
read_csv_char <- function(path) {
  raw <- readLines(path, encoding = "UTF-8", warn = FALSE)
  if (length(raw)) raw[1] <- sub("^﻿", "", raw[1])
  read.csv(text = paste(raw, collapse = "\n"), colClasses = "character", na.strings = NULL,
           check.names = FALSE, encoding = "UTF-8")
}
# The contract's header for one file, in order.
header_of <- function(file) {
  h <- read_csv_char(file.path(contract, "csv_headers.csv")); h <- h[h$file == file, ]
  h$column[order(as.integer(h$position))]
}
# Run a command with the working directory temporarily set to `dir`.
run_in_dir <- function(dir, cmd, cmd_args) {
  old <- setwd(dir); on.exit(setwd(old))
  log <- tempfile(fileext = ".log")
  status <- system2(cmd, cmd_args, stdout = log, stderr = log)
  list(status = status, log = paste(readLines(log, warn = FALSE), collapse = "\n"))
}
# Source one or more pipeline/R modules into a fresh, isolated environment.
# Used only for checks that are explicitly about the functions in those modules.
source_modules <- function(root, files) {
  e <- new.env()
  for (f in files) sys.source(file.path(root, "pipeline", "R", f), envir = e)
  e
}

## ---- 3. (example removed) ------------------------------------------------------

## ---- 4. Checks ------------------------------------------------------------------

# WP03.A1: the unit test suite passes, run from the repo root exactly as the
# card specifies. Runs the tests as a subprocess; this script does not itself
# source pipeline/R/.
try_check("WP03.A1", {
  # Passing the expression via -e hits a Windows system2 quoting bug (an
  # embedded-quotes argument gets mis-split, "Error: unexpected end of
  # input"), reproducible even with a trivial system2() call outside this
  # script. Writing the identical expression to a temp .R file and running
  # it with Rscript avoids that, with no change in what is executed.
  tmp_r <- tempfile(fileext = ".R")
  writeLines("testthat::test_dir('pipeline/tests/testthat', stop_on_failure = TRUE)", tmp_r)
  r <- run_in_dir(root, "Rscript", c(shQuote(tmp_r)))
  unlink(tmp_r)
  check("WP03.A1", r$status == 0, sprintf("exit=%s log_tail=%s", r$status,
        substr(r$log, max(1, nchar(r$log) - 400), nchar(r$log))))
})

# WP03.A2: DSD_AFW360_HH.csv has one row per data-file column, in the data-file
# column order, and constants.R's DSD_COLUMNS / KEY_COLUMNS agree with it.
try_check("WP03.A2", {
  dsd <- read_csv_char(file.path(root, "metadata", "structure", "DSD_AFW360_HH.csv"))
  expected_cols <- header_of("AFW360_HH_<ISO3>_<YEAR>.csv")
  ok_id <- identical(dsd$id, expected_cols)

  e <- source_modules(root, "constants.R")
  ok_dsd_const <- identical(e$DSD_COLUMNS, expected_cols)
  ok_key_const <- identical(e$KEY_COLUMNS, expected_cols[seq_len(18)])

  check("WP03.A2",
        nrow(dsd) == length(expected_cols) && ok_id && ok_dsd_const && ok_key_const,
        sprintf("dsd_rows=%d expected=%d id_match=%s DSD_COLUMNS_match=%s KEY_COLUMNS_match=%s",
                nrow(dsd), length(expected_cols), ok_id, ok_dsd_const, ok_key_const))
})

# WP03.A3: fmt_num from io.R.
try_check("WP03.A3", {
  e <- source_modules(root, "io.R")
  actual <- e$fmt_num(c(0.37, 6520000, -3460.12, 1e-7, 100, NA))
  expected_v <- c("0.37", "6520000", "-3460.12", "0.0000001", "100", "")
  check("WP03.A3", identical(actual, expected_v),
        sprintf("actual=[%s] expected=[%s]", paste(actual, collapse = "|"), paste(expected_v, collapse = "|")))
})

# WP03.A4: write_std_csv output has no BOM, no CR byte, and NA becomes "".
try_check("WP03.A4", {
  e <- source_modules(root, "io.R")
  out <- file.path(tempdir(), paste0("wp03a4_", as.integer(Sys.time()), "_", sample(1e5, 1), ".csv"))
  df <- data.frame(id = c("a", "b"), val = c(1.5, NA_real_), stringsAsFactors = FALSE)
  e$write_std_csv(df, out)
  bytes <- readBin(out, "raw", file.size(out))
  no_bom <- !(length(bytes) >= 3 && identical(bytes[1:3], as.raw(c(0xef, 0xbb, 0xbf))))
  no_cr <- !any(bytes == as.raw(0x0d))
  parsed <- read_csv_char(out)
  na_empty <- identical(parsed$val[2], "")
  check("WP03.A4", no_bom && no_cr && na_empty,
        sprintf("no_bom=%s no_cr=%s na_written_as=[%s]", no_bom, no_cr, parsed$val[2]))
  unlink(out)
})

# WP03.A5: read_std_csv on a file with a BOM, CRLF and an empty cell.
try_check("WP03.A5", {
  e <- source_modules(root, "io.R")
  path <- file.path(tempdir(), paste0("wp03a5_", as.integer(Sys.time()), "_", sample(1e5, 1), ".csv"))
  con <- file(path, "wb")
  writeBin(c(as.raw(c(0xEF, 0xBB, 0xBF)), charToRaw("a,b\r\nx,\r\n")), con)
  close(con)
  res <- e$read_std_csv(path)
  all_char <- all(vapply(res, is.character, logical(1)))
  clean_header <- identical(names(res), c("a", "b"))
  empty_cell <- identical(res$b[1], "")
  check("WP03.A5", all_char && clean_header && empty_cell,
        sprintf("names=[%s] all_char=%s b1=[%s]", paste(names(res), collapse = ","), all_char, res$b[1]))
  unlink(path)
})

# WP03.A6: is_valid_code from codes.R.
try_check("WP03.A6", {
  e <- source_modules(root, "codes.R")
  accept <- e$is_valid_code(c("SN01", "POV_HC"))
  reject <- e$is_valid_code(c("_T", "_ZX", "pov_hc", "1A", strrep("A", 33)))
  check("WP03.A6", all(accept) && !any(reject),
        sprintf("accept=[%s] reject=[%s]", paste(accept, collapse = ","), paste(reject, collapse = ",")))
})

# WP03.A7: slot_sort and fill_slots from codes.R.
try_check("WP03.A7", {
  e <- source_modules(root, "codes.R")
  ss <- e$slot_sort(c("HE_COUNT_0", "QUINT_Q1"),
                     c(HE_COUNT_0 = "HE_COUNT", QUINT_Q1 = "QUINT"),
                     c(HE_COUNT = "50", QUINT = "10"))
  fs <- e$fill_slots("A", 3, "_T")
  ok_ss <- length(ss) >= 1 && identical(ss[1], "QUINT_Q1")
  ok_fs <- identical(fs, c("A", "_T", "_T"))
  check("WP03.A7", ok_ss && ok_fs,
        sprintf("slot_sort=[%s] fill_slots=[%s]", paste(ss, collapse = ","), paste(fs, collapse = ",")))
})

# WP03.A8: run_all.R exits 0 with no wp*.R scripts, and non-zero when a dummy
# failing script is present. Both roots are synthetic, temporary, and contain
# nothing but an empty (or one-file) pipeline/acceptance/ directory, so this
# runs the real run_all.R against minimal, disposable inputs.
try_check("WP03.A8", {
  stamp <- paste0(as.integer(Sys.time()), "_", sample(1e5, 1))
  base_no <- file.path(tempdir(), paste0("wp03a8_no_", stamp))
  dir.create(file.path(base_no, "pipeline", "acceptance"), recursive = TRUE)
  r_no <- system2("Rscript",
                   c(shQuote(file.path(root, "pipeline", "acceptance", "run_all.R")), "--root", shQuote(base_no)),
                   stdout = tempfile(), stderr = tempfile())

  base_fail <- file.path(tempdir(), paste0("wp03a8_fail_", stamp))
  dir.create(file.path(base_fail, "pipeline", "acceptance"), recursive = TRUE)
  writeLines("quit(status = 1L, save = 'no')",
             file.path(base_fail, "pipeline", "acceptance", "wp99_dummy.R"))
  r_fail <- system2("Rscript",
                     c(shQuote(file.path(root, "pipeline", "acceptance", "run_all.R")), "--root", shQuote(base_fail)),
                     stdout = tempfile(), stderr = tempfile())

  check("WP03.A8", r_no == 0 && r_fail != 0,
        sprintf("no_scripts_exit=%s dummy_failing_exit=%s", r_no, r_fail))
  unlink(base_no, recursive = TRUE)
  unlink(base_fail, recursive = TRUE)
})

# WP03.A9: metadata/VERSION is exactly "0.1.0"; build_ctx(root) returns the six
# named elements even when called with no data files.
try_check("WP03.A9", {
  version_lines <- readLines(file.path(root, "metadata", "VERSION"), warn = FALSE)
  version_ok <- length(version_lines) == 1 && identical(version_lines[1], "0.1.0")

  e <- source_modules(root, c("io.R", "constants.R", "codes.R", "ctx.R"))
  ctx <- e$build_ctx(root)
  names_ok <- setequal(names(ctx), c("root", "meta", "data", "manifests", "precision", "opts"))

  check("WP03.A9", version_ok && names_ok,
        sprintf("VERSION=[%s] ctx_names=[%s]", paste(version_lines, collapse = "|"),
                paste(names(ctx), collapse = ",")))
})

# WP03.A10: COLUMNS.csv equals csv_headers.csv restricted to file, position,
# column, status, description, minus the rows of the data file, the manifest
# and the validator findings, in the same row order.
try_check("WP03.A10", {
  cols5 <- c("file", "position", "column", "status", "description")
  headers_all <- read_csv_char(file.path(contract, "csv_headers.csv"))
  columns_csv <- read_csv_char(file.path(root, "metadata", "structure", "COLUMNS.csv"))

  has_cols <- all(cols5 %in% names(columns_csv)) && all(cols5 %in% names(headers_all))

  data_file <- "AFW360_HH_<ISO3>_<YEAR>.csv"
  files_headers <- unique(headers_all$file)
  files_columns <- if (has_cols) unique(columns_csv$file) else character(0)
  excluded <- setdiff(files_headers, files_columns)

  self_included <- "COLUMNS.csv" %in% files_columns
  n_excluded_ok <- length(excluded) == 3
  data_excluded <- data_file %in% excluded
  other_excluded <- setdiff(excluded, data_file)
  manifest_like <- length(other_excluded) == 2 && any(grepl("manifest", other_excluded, ignore.case = TRUE))
  findings_like <- length(other_excluded) == 2 && any(grepl("valid", other_excluded, ignore.case = TRUE))
  n_files_ok <- has_cols && length(files_columns) == (length(files_headers) - length(excluded))

  content_match <- FALSE
  if (has_cols) {
    expected_rows <- headers_all[headers_all$file %in% files_columns, cols5]
    rownames(expected_rows) <- NULL
    actual_rows <- columns_csv[, cols5]
    rownames(actual_rows) <- NULL
    content_match <- isTRUE(all.equal(expected_rows, actual_rows, check.attributes = FALSE))
  }

  ok <- has_cols && n_files_ok && self_included && n_excluded_ok && data_excluded &&
    manifest_like && findings_like && content_match
  check("WP03.A10", ok,
        sprintf("files_in_COLUMNS=%d files_in_headers=%d self_included=%s excluded=[%s] content_match=%s",
                length(files_columns), length(files_headers), self_included,
                paste(excluded, collapse = "|"), content_match))
})

## ---- 5. Exit ----------------------------------------------------------------------
cat(if (length(.failures)) sprintf("\n%d check(s) failed: %s\n", length(.failures), paste(.failures, collapse = ", ")) else "\nAll checks passed.\n")
quit(status = if (length(.failures)) 1L else 0L, save = "no")
