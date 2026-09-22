#!/usr/bin/env Rscript
# Acceptance script for WP03 - Pipeline scaffold.
#
#   Rscript pipeline/acceptance/wp03_scaffold.R --root .
#
# Standalone: does not source pipeline/R/ except where a check is directly
# about a function defined there. Expected numbers come from
# contract/expected_counts.csv by check_id. Writes only to tempdir().

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
# Expected value and tolerance from the contract, by check_id.
expected <- function(check_id) {
  tab <- read_csv_char(file.path(contract, "expected_counts.csv"))
  row <- tab[tab$check_id == check_id, ]
  if (nrow(row) != 1) stop("no unique row in expected_counts.csv for ", check_id)
  list(value = as.numeric(row$expected), tol = as.numeric(row$tolerance))
}
meets <- function(actual, check_id) { e <- expected(check_id); abs(actual - e$value) <= e$tol + 1e-9 }
# The contract's header for one file, in order.
header_of <- function(file) {
  h <- read_csv_char(file.path(contract, "csv_headers.csv")); h <- h[h$file == file, ]
  h$column[order(as.integer(h$position))]
}
# Run an Rscript file with --root <root_path>; returns the exit status.
run_rscript <- function(script_path, root_path) {
  log <- tempfile(fileext = ".log")
  system2("Rscript", c(shQuote(script_path), "--root", shQuote(root_path)), stdout = log, stderr = log)
}

DATA_FILE <- "AFW360_HH_<ISO3>_<YEAR>.csv"

## ---- 3. (skeleton example removed) --------------------------------------------

## ---- 4. Checks ------------------------------------------------------------------

## WP03.A1 -- unit tests pass
try_check("WP03.A1", {
  log <- tempfile(fileext = ".log")
  test_dir_expr <- sprintf("testthat::test_dir(%s, stop_on_failure = TRUE)",
                            deparse(file.path(root, "pipeline", "tests", "testthat")))
  status <- system2("Rscript", c("-e", shQuote(test_dir_expr)), stdout = log, stderr = log)
  tail_lines <- tryCatch(tail(readLines(log, warn = FALSE), 10), error = function(e) character(0))
  check("WP03.A1", status == 0L,
        sprintf("exit=%s; tail: %s", status, paste(tail_lines, collapse = " | ")))
})

## WP03.A2 -- DSD has 26 rows; id column matches csv_headers order; DSD_COLUMNS/KEY_COLUMNS match
try_check("WP03.A2", {
  dsd <- read_csv_char(file.path(root, "metadata", "structure", "DSD_AFW360_HH.csv"))
  expected_cols <- header_of(DATA_FILE)
  rows_ok <- meets(nrow(dsd), "META.DSD")
  id_ok <- identical(dsd$id, expected_cols)

  env <- new.env()
  sys.source(file.path(root, "pipeline", "R", "constants.R"), envir = env)
  dsd_columns_ok <- identical(env$DSD_COLUMNS, expected_cols)
  key_columns_ok <- identical(env$KEY_COLUMNS, expected_cols[1:18])

  check("WP03.A2", rows_ok && id_ok && dsd_columns_ok && key_columns_ok,
        sprintf("nrow=%d (expect 26), id order match=%s, DSD_COLUMNS match=%s, KEY_COLUMNS match=%s",
                nrow(dsd), id_ok, dsd_columns_ok, key_columns_ok))
})

## WP03.A3 -- fmt_num
try_check("WP03.A3", {
  env <- new.env()
  sys.source(file.path(root, "pipeline", "R", "io.R"), envir = env)
  got <- env$fmt_num(c(0.37, 6520000, -3460.12, 1e-7, 100, NA))
  want <- c("0.37", "6520000", "-3460.12", "0.0000001", "100", "")
  check("WP03.A3", identical(got, want),
        sprintf("got: %s", paste(sprintf('"%s"', got), collapse = " ")))
})

## WP03.A4 -- write_std_csv: no BOM, no CR, NA -> ""
try_check("WP03.A4", {
  env <- new.env()
  sys.source(file.path(root, "pipeline", "R", "io.R"), envir = env)
  tmp <- tempfile(fileext = ".csv")
  df <- data.frame(id = c("a", "b"), val = c(1.5, NA_real_), stringsAsFactors = FALSE)
  env$write_std_csv(df, tmp)
  bytes <- readBin(tmp, "raw", file.info(tmp)$size)
  no_bom <- !(length(bytes) >= 3 && identical(bytes[1:3], as.raw(c(0xef, 0xbb, 0xbf))))
  no_cr <- !any(bytes == as.raw(0x0d))
  parsed <- read_csv_char(tmp)
  na_empty <- identical(parsed$val[parsed$id == "b"], "")
  check("WP03.A4", no_bom && no_cr && na_empty,
        sprintf("no_bom=%s, no_cr=%s, na_as_empty=%s", no_bom, no_cr, na_empty))
})

## WP03.A5 -- read_std_csv: BOM, CRLF, empty cell
try_check("WP03.A5", {
  env <- new.env()
  sys.source(file.path(root, "pipeline", "R", "io.R"), envir = env)
  tmp <- tempfile(fileext = ".csv")
  con <- file(tmp, open = "wb")
  writeBin(as.raw(c(0xef, 0xbb, 0xbf)), con)
  writeBin(charToRaw("a,b\r\n1,\r\n"), con)
  close(con)
  df <- env$read_std_csv(tmp)
  all_char <- all(vapply(df, is.character, logical(1)))
  header_clean <- identical(names(df), c("a", "b"))
  empty_cell <- identical(df$b[1], "")
  check("WP03.A5", all_char && header_clean && empty_cell,
        sprintf("all_char=%s, header=%s, b[1]=\"%s\"", all_char, paste(names(df), collapse = ","), df$b[1]))
})

## WP03.A6 -- is_valid_code
try_check("WP03.A6", {
  env <- new.env()
  sys.source(file.path(root, "pipeline", "R", "codes.R"), envir = env)
  code33 <- paste0("A", strrep("B", 32))
  accept <- env$is_valid_code(c("SN01", "POV_HC"))
  reject <- env$is_valid_code(c("_T", "_ZX", "pov_hc", "1A", code33))
  check("WP03.A6", all(accept) && !any(reject),
        sprintf("accept=%s, reject=%s", paste(accept, collapse = ","), paste(reject, collapse = ",")))
})

## WP03.A7 -- slot_sort, fill_slots
try_check("WP03.A7", {
  env <- new.env()
  sys.source(file.path(root, "pipeline", "R", "codes.R"), envir = env)
  sorted <- env$slot_sort(
    c("HE_COUNT_0", "QUINT_Q1"),
    c(HE_COUNT_0 = "HE_COUNT", QUINT_Q1 = "QUINT"),
    c(HE_COUNT = "50", QUINT = "10")
  )
  sort_ok <- identical(sorted[1], "QUINT_Q1")
  filled <- env$fill_slots("A", 3, "_T")
  fill_ok <- identical(filled, c("A", "_T", "_T"))
  check("WP03.A7", sort_ok && fill_ok,
        sprintf("slot_sort=%s, fill_slots=%s", paste(sorted, collapse = ","), paste(filled, collapse = ",")))
})

## WP03.A8 -- run_all.R: exits 0 with no scripts, non-zero with a dummy failing script
try_check("WP03.A8", {
  tmp_root <- file.path(tempdir(), paste0("wp03a8_", as.integer(Sys.time()), "_", sample(1e5, 1)))
  dir.create(file.path(tmp_root, "pipeline", "acceptance"), recursive = TRUE)
  file.copy(file.path(root, "pipeline", "acceptance", "run_all.R"),
            file.path(tmp_root, "pipeline", "acceptance", "run_all.R"))

  status_empty <- run_rscript(file.path(tmp_root, "pipeline", "acceptance", "run_all.R"), tmp_root)

  writeLines(c("#!/usr/bin/env Rscript", "quit(status = 1, save = 'no')"),
             file.path(tmp_root, "pipeline", "acceptance", "wp99_dummy_fail.R"))
  status_fail <- run_rscript(file.path(tmp_root, "pipeline", "acceptance", "run_all.R"), tmp_root)

  check("WP03.A8", identical(status_empty, 0L) && status_fail != 0L,
        sprintf("no-scripts exit=%s, dummy-fail exit=%s", status_empty, status_fail))
})

## WP03.A9 -- VERSION == 0.1.0; build_ctx returns the six names
try_check("WP03.A9", {
  version_lines <- readLines(file.path(root, "metadata", "VERSION"), warn = FALSE)
  nonempty <- version_lines[nzchar(trimws(version_lines))]
  version_ok <- length(nonempty) == 1 && identical(trimws(nonempty[1]), "0.1.0")

  env <- new.env()
  sys.source(file.path(root, "pipeline", "R", "io.R"), envir = env)
  sys.source(file.path(root, "pipeline", "R", "ctx.R"), envir = env)
  ctx <- env$build_ctx(root)
  names_ok <- setequal(names(ctx), c("root", "meta", "data", "manifests", "precision", "opts"))

  check("WP03.A9", version_ok && names_ok,
        sprintf("VERSION=\"%s\", ctx names=%s", paste(nonempty, collapse = "|"), paste(names(ctx), collapse = ",")))
})

## WP03.A10 -- COLUMNS.csv == csv_headers.csv minus (data file, manifest, validator findings), same order
try_check("WP03.A10", {
  headers <- read_csv_char(file.path(contract, "csv_headers.csv"))
  cols <- read_csv_char(file.path(root, "metadata", "structure", "COLUMNS.csv"))

  wanted_cols <- c("file", "position", "column", "status", "description")
  cols_shape_ok <- identical(names(cols), wanted_cols)

  files_in_headers <- unique(headers$file)
  files_in_cols <- unique(cols$file)

  # every row of COLUMNS.csv must correspond exactly to a row of csv_headers.csv
  h_key <- if (cols_shape_ok) paste(headers$file, headers$position, headers$column, headers$status, headers$description, sep = "") else character(0)
  c_key <- if (cols_shape_ok) paste(cols$file, cols$position, cols$column, cols$status, cols$description, sep = "") else character(0)
  rows_subset_ok <- cols_shape_ok && all(c_key %in% h_key)

  # for each file kept, all of its rows are kept, and the order (by position) is preserved
  order_ok <- cols_shape_ok
  if (cols_shape_ok) {
    for (f in files_in_cols) {
      h_f <- headers[headers$file == f, ]
      h_f <- h_f[order(as.integer(h_f$position)), ]
      c_f <- cols[cols$file == f, ]
      c_f <- c_f[order(as.integer(c_f$position)), ]
      same_count <- nrow(h_f) == nrow(c_f)
      same_rows <- same_count && all(
        c_f$position == h_f$position & c_f$column == h_f$column &
        c_f$status == h_f$status & c_f$description == h_f$description
      )
      if (!isTRUE(same_rows)) order_ok <- FALSE
    }
  }

  data_file_excluded <- !(DATA_FILE %in% files_in_cols)
  self_included <- "COLUMNS.csv" %in% files_in_cols
  excluded_count <- length(setdiff(files_in_headers, files_in_cols))
  file_count_ok <- length(files_in_cols) == 28 && excluded_count == 3

  check("WP03.A10", cols_shape_ok && rows_subset_ok && order_ok && data_file_excluded && self_included && file_count_ok,
        sprintf("shape=%s, rows_subset=%s, order=%s, data_file_excluded=%s, self_included=%s, files_kept=%d (want 28), files_excluded=%d (want 3)",
                cols_shape_ok, rows_subset_ok, order_ok, data_file_excluded, self_included, length(files_in_cols), excluded_count))
})

## ---- 5. Exit ----------------------------------------------------------------------
cat(if (length(.failures)) sprintf("\n%d check(s) failed: %s\n", length(.failures), paste(.failures, collapse = ", ")) else "\nAll checks passed.\n")
quit(status = if (length(.failures)) 1L else 0L, save = "no")
