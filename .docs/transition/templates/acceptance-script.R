#!/usr/bin/env Rscript
# Acceptance-script skeleton for the AFW 360 data transition.
#
# Copy to pipeline/acceptance/<wp_id_lower>_<slug>.R, keep sections 1-3, and
# write one check() call per acceptance check of the card in section 4, with
# the check ID spelled exactly as on the card ("WP05.A1").
#
#   Rscript pipeline/acceptance/<wp_id_lower>_<slug>.R --root .
#
# Rules: standalone (do not source pipeline/R/ unless the check is about those
# functions); expected numbers come from contract/expected_counts.csv; write
# only to tempdir(); compare against the tag transition-base and against files,
# never against transition/main, so the script keeps passing after the merge.

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
# Raw bytes of a committed file (the working copy may differ in line endings).
blob_bytes <- function(path, rev = "HEAD") {
  tmp <- tempfile(); on.exit(unlink(tmp))
  system2("git", c("-C", shQuote(root), "cat-file", "blob", shQuote(paste0(rev, ":", path))), stdout = tmp)
  readBin(tmp, "raw", file.size(tmp))
}
no_bom_no_cr <- function(bytes) !(length(bytes) >= 3 && identical(bytes[1:3], as.raw(c(0xef, 0xbb, 0xbf)))) && !any(bytes == as.raw(0x0d))
# Run a pipeline script; returns its exit status. Output goes to a temp log.
run_script <- function(script, script_args) {
  log <- tempfile(fileext = ".log")
  system2("Rscript", c(shQuote(file.path(root, script)), script_args), stdout = log, stderr = log)
}
same_file <- function(a, b) file.exists(a) && file.exists(b) && identical(unname(tools::md5sum(a)), unname(tools::md5sum(b)))

## ---- 3. Example (delete) --------------------------------------------------------
# sen <- read_csv_char(file.path(root, "data", "AFW360_HH_SEN_2021.csv"))
# check("WP15.A2", meets(nrow(sen), "DATA.SEN.ROWS") && all(sen$OBS_STATUS == "A"),
#       sprintf("SEN rows = %d, all A = %s", nrow(sen), all(sen$OBS_STATUS == "A")))
# try_check("WP04.A2", check("WP04.A2", identical(names(read_csv_char(f)), header_of("CL_SEX.csv")), "CL_SEX header"))

## ---- 4. Checks ------------------------------------------------------------------


## ---- 5. Exit ----------------------------------------------------------------------
cat(if (length(.failures)) sprintf("\n%d check(s) failed: %s\n", length(.failures), paste(.failures, collapse = ", ")) else "\nAll checks passed.\n")
quit(status = if (length(.failures)) 1L else 0L, save = "no")
