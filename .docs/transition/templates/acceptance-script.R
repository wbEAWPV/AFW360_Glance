#!/usr/bin/env Rscript
# Acceptance-script skeleton for the AFW 360 data-transition project.
#
# Copy this file to pipeline/acceptance/<wp_id_lower>_<slug>.R and replace
# section 4 with the checks from your WP's card (.docs/transition/work-
# packages.qmd, anchor #sec-wpNN), one check() call per "WPNN.A<n>" id.
#
# Self-contained on purpose: it must NOT depend on pipeline/R/io.R or any
# other pipeline module, so it verifies the pipeline instead of trusting it.
# It must write nothing outside a temp directory and must run standalone:
#
#   Rscript pipeline/acceptance/<wp_id_lower>_<slug>.R --root .
#
# Exit status is 0 only if every check passes.

## ---- 1. Parse --root ------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
root <- "."
root_idx <- which(args == "--root")
if (length(root_idx) == 1 && length(args) >= root_idx + 1) {
  root <- args[root_idx + 1]
}
root <- normalizePath(root, mustWork = TRUE)

## ---- 2. check() helper -----------------------------------------------------
# Prints "CHECK <id> PASS|FAIL <evidence>" and records failures for the exit
# code. Call this once per acceptance-check id, never skip an id silently.

.failures <- character(0)

check <- function(id, ok, evidence) {
  status <- if (isTRUE(ok)) "PASS" else "FAIL"
  cat(sprintf("CHECK %s %s %s\n", id, status, evidence))
  if (!isTRUE(ok)) {
    .failures[[length(.failures) + 1]] <<- sprintf("%s: %s", id, evidence)
  }
  invisible(ok)
}

## ---- 3. Self-contained CSV helpers -----------------------------------------
# All columns read as character, BOM stripped, "" stays "" (never becomes NA).
# No dependency on pipeline code -- copy these two functions along with the
# rest of this file rather than sourcing them from elsewhere.

read_csv_char <- function(path) {
  if (!file.exists(path)) {
    stop(sprintf("read_csv_char: file not found: %s", path))
  }
  raw <- readLines(path, encoding = "UTF-8", warn = FALSE)
  if (length(raw) > 0) {
    raw[1] <- sub("^\xEF\xBB\xBF", "", raw[1])  # strip a raw UTF-8 BOM
    raw[1] <- sub("^﻿", "", raw[1])         # strip an already-decoded BOM
  }
  con <- textConnection(raw)
  on.exit(close(con))
  read.csv(
    con,
    colClasses = "character",
    na.strings = NULL,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

# Look up one expected value from contract/expected_counts.csv by check_id.
# expected_counts.csv columns: check_id, scope, quantity, expected, tolerance, source
# ("tolerance" is the allowed deviation from "expected"; a real check should
# compare its computed value against expected_count() using that tolerance).
expected_count <- function(root, check_id) {
  path <- file.path(root, ".docs", "transition", "contract", "expected_counts.csv")
  tab <- read_csv_char(path)
  row <- tab[tab$check_id == check_id, , drop = FALSE]
  if (nrow(row) != 1) {
    stop(sprintf("expected_count: '%s' not found (or not unique) in %s", check_id, path))
  }
  row$expected[[1]]
}

## ---- 4. Checks --------------------------------------------------------------
# DEMO checks below so this skeleton runs standalone before any real WP,
# contract or data_raw exists. Delete them and write your WP's real checks
# here, e.g.:
#
#   sen <- read_csv_char(file.path(root, "data", "AFW360_HH_SEN_2021.csv"))
#   check("WP13.A2", nrow(sen) == as.integer(expected_count(root, "WP13.A2")),
#         sprintf("SEN row count = %d", nrow(sen)))

# Demo A: a row count against expected_counts.csv, with a literal fallback
# for a bare checkout of this skeleton where the contract does not exist yet,
# or where the real contract has no "DEMO.A1" row of its own.
{
  expected_path <- file.path(root, ".docs", "transition", "contract", "expected_counts.csv")
  has_demo_row <- file.exists(expected_path) &&
    "DEMO.A1" %in% read_csv_char(expected_path)$check_id
  if (has_demo_row) {
    exp_val <- expected_count(root, "DEMO.A1")
    check("DEMO.A1", TRUE, sprintf("expected_counts.csv lists '%s' for DEMO.A1", exp_val))
  } else {
    check("DEMO.A1", 1 + 1 == 2, "expected_counts.csv has no 'DEMO.A1' row (or does not exist yet); ran a literal check instead (1 + 1 == 2)")
  }
}

# Demo B: a code regex, e.g. CL_GEO codes for scheme=ADM1 matching the
# P-code pattern SN## / GW##.
{
  demo_codes <- c("SN01", "SN02", "GW08")
  matches <- grepl("^(SN|GW)[0-9]{2}$", demo_codes)
  check("DEMO.A2", all(matches), sprintf("%d/%d demo codes match ^(SN|GW)[0-9]{2}$", sum(matches), length(demo_codes)))
}

# Demo C: a file sha256 against a registry (e.g. GEO_SOURCES.csv), written
# only to a temp file as this script must not write inside the repo.
{
  demo_file <- tempfile(fileext = ".txt")
  writeLines("acceptance-script.R demo", demo_file)
  has_digest <- requireNamespace("digest", quietly = TRUE)
  if (has_digest) {
    sha <- digest::digest(file = demo_file, algo = "sha256")
    check("DEMO.A3", nchar(sha) == 64, sprintf("sha256 of demo temp file is %s (64 hex chars)", sha))
  } else {
    check("DEMO.A3", FALSE, "package 'digest' is not installed -- install it before writing a real acceptance script")
  }
  unlink(demo_file)
}

## ---- 5. Exit -----------------------------------------------------------------

n_fail <- length(.failures)
if (n_fail > 0) {
  cat(sprintf("\n%d check(s) failed:\n", n_fail))
  for (f in .failures) cat(sprintf("  - %s\n", f))
} else {
  cat("\nAll checks passed.\n")
}
quit(status = if (n_fail > 0) 1L else 0L, save = "no")
