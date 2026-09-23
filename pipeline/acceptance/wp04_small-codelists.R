#!/usr/bin/env Rscript
# Acceptance script for WP04 -- Small codelists and CL_AREA.
#
#   Rscript pipeline/acceptance/wp04_small-codelists.R --root .
#
# Standalone: does not source pipeline/R/. Compares against the committed
# blobs at HEAD and against files generated into a temporary directory,
# never against transition/main.

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
  status <- system2("Rscript", c(shQuote(file.path(root, script)), script_args), stdout = log, stderr = log)
  list(status = status, log = log)
}

## ---- 3. WP04 fixtures -----------------------------------------------------------
# The ten small codelists and their relative paths under metadata/codelists/.
codelist_files <- c(
  CL_SEX          = "CL_SEX.csv",
  CL_AGE          = "CL_AGE.csv",
  CL_URBANISATION = "CL_URBANISATION.csv",
  CL_OBS_STATUS   = "CL_OBS_STATUS.csv",
  CL_THEME        = "CL_THEME.csv",
  CL_UNIT         = "CL_UNIT.csv",
  CL_STAT_UNIT    = "CL_STAT_UNIT.csv",
  CL_STATISTIC    = "CL_STATISTIC.csv",
  CL_WEIGHT       = "CL_WEIGHT.csv",
  CL_AREA         = "CL_AREA.csv"
)
metadata_rel <- file.path("metadata", "codelists", codelist_files)
names(metadata_rel) <- names(codelist_files)
metadata_abs <- file.path(root, metadata_rel)
names(metadata_abs) <- names(codelist_files)

codes_all <- read_csv_char(file.path(contract, "codes.csv"))

## ---- 4. Checks ------------------------------------------------------------------

## WP04.A1: for each of the ten codelists, the set of code values equals the
## set in contract/codes.csv.
try_check("WP04.A1", {
  bad <- character(0)
  for (cl in names(codelist_files)) {
    expected_codes <- codes_all$code[codes_all$codelist == cl]
    out <- read_csv_char(metadata_abs[[cl]])
    actual_codes <- out$code
    if (!setequal(actual_codes, expected_codes) ||
        length(actual_codes) != length(unique(actual_codes)) ||
        length(actual_codes) != length(expected_codes)) {
      bad <- c(bad, cl)
    }
  }
  check("WP04.A1", length(bad) == 0,
        if (length(bad) == 0) "all ten codelists match contract/codes.csv code sets"
        else paste("mismatched:", paste(bad, collapse = ", ")))
})

## WP04.A2: each file's header equals its rows in csv_headers.csv, in order.
try_check("WP04.A2", {
  bad <- character(0)
  for (cl in names(codelist_files)) {
    out <- read_csv_char(metadata_abs[[cl]])
    exp_h <- header_of(codelist_files[[cl]])
    if (!identical(names(out), exp_h)) bad <- c(bad, cl)
  }
  check("WP04.A2", length(bad) == 0,
        if (length(bad) == 0) "all ten headers match contract/csv_headers.csv"
        else paste("mismatched headers:", paste(bad, collapse = ", ")))
})

## WP04.A3: every code passes ^[A-Z][A-Z0-9_]{0,31}$ and does not start with _T or _Z.
try_check("WP04.A3", {
  bad <- character(0)
  code_re <- "^[A-Z][A-Z0-9_]{0,31}$"
  for (cl in names(codelist_files)) {
    out <- read_csv_char(metadata_abs[[cl]])
    codes <- out$code
    invalid <- !grepl(code_re, codes) | grepl("^_T", codes) | grepl("^_Z", codes)
    if (any(invalid)) bad <- c(bad, paste0(cl, ":", paste(codes[invalid], collapse = "|")))
  }
  check("WP04.A3", length(bad) == 0,
        if (length(bad) == 0) "all codes match ^[A-Z][A-Z0-9_]{0,31}$ and avoid _T/_Z"
        else paste("invalid codes:", paste(bad, collapse = "; ")))
})

## WP04.A4: name_en, definition_en, status and version_added filled on every
## row; status is DRAFT and version_added is 0.1.0 everywhere; no
## definition_en is TBD.
try_check("WP04.A4", {
  bad <- character(0)
  for (cl in names(codelist_files)) {
    out <- read_csv_char(metadata_abs[[cl]])
    filled_ok <- trimws(out$name_en) != "" & trimws(out$definition_en) != "" &
      trimws(out$status) != "" & trimws(out$version_added) != ""
    status_ok <- out$status == "DRAFT"
    version_ok <- out$version_added == "0.1.0"
    no_tbd <- out$definition_en != "TBD"
    if (!all(filled_ok) || !all(status_ok) || !all(version_ok) || !all(no_tbd)) bad <- c(bad, cl)
  }
  check("WP04.A4", length(bad) == 0,
        if (length(bad) == 0) "name_en/definition_en/status/version_added filled, status=DRAFT, version_added=0.1.0, no TBD definitions"
        else paste("problems in:", paste(bad, collapse = ", ")))
})

## WP04.A5: every parent in CL_URBANISATION is a code of that file. CAP and
## OU have parent U.
try_check("WP04.A5", {
  out <- read_csv_char(metadata_abs[["CL_URBANISATION"]])
  codes <- out$code
  parent <- out$parent
  nonblank <- trimws(parent) != ""
  parent_valid <- !nonblank | parent %in% codes
  cap_row <- out[out$code == "CAP", ]
  ou_row <- out[out$code == "OU", ]
  cap_ok <- nrow(cap_row) == 1 && cap_row$parent[1] == "U"
  ou_ok <- nrow(ou_row) == 1 && ou_row$parent[1] == "U"
  check("WP04.A5", all(parent_valid) && cap_ok && ou_ok,
        sprintf("parents valid=%s, CAP parent=%s, OU parent=%s",
                all(parent_valid),
                if (nrow(cap_row) == 1) cap_row$parent[1] else "<missing>",
                if (nrow(ou_row) == 1) ou_row$parent[1] else "<missing>"))
})

## WP04.A6: CL_AREA has the iso2, currency and wb_region values given above.
## CL_STATISTIC.admits_se is Y or N on every row.
try_check("WP04.A6", {
  area <- read_csv_char(metadata_abs[["CL_AREA"]])
  sen <- area[area$code == "SEN", ]
  gnb <- area[area$code == "GNB", ]
  area_ok <- nrow(sen) == 1 && nrow(gnb) == 1 &&
    sen$iso2[1] == "SN" && sen$currency[1] == "XOF" && sen$wb_region[1] == "AFW" &&
    gnb$iso2[1] == "GW" && gnb$currency[1] == "XOF" && gnb$wb_region[1] == "AFW"

  statistic <- read_csv_char(metadata_abs[["CL_STATISTIC"]])
  admits_ok <- all(statistic$admits_se %in% c("Y", "N")) && all(trimws(statistic$admits_se) != "")

  check("WP04.A6", area_ok && admits_ok,
        sprintf("CL_AREA SEN/GNB fields ok=%s, CL_STATISTIC.admits_se all Y/N=%s", area_ok, admits_ok))
})

## WP04.A7: the committed blobs have no BOM and no CR byte. Applies to the
## ten codelist files and the seed text file (this acceptance script's own
## source is never part of WP04's owned outputs, so it is not in scope here).
try_check("WP04.A7", {
  paths <- c(unname(metadata_rel), file.path("pipeline", "bootstrap", "text", "small_codelists_text.csv"))
  bad <- character(0)
  for (p in paths) {
    bytes <- tryCatch(blob_bytes(p), error = function(e) raw(0))
    if (length(bytes) == 0 || !no_bom_no_cr(bytes)) bad <- c(bad, p)
  }
  check("WP04.A7", length(bad) == 0,
        if (length(bad) == 0) "no BOM/CR in the 10 codelists + seed text file"
        else paste("BOM/CR or unreadable:", paste(bad, collapse = ", ")))
})

## WP04.A8: running the script with --out-root <tempdir> writes ten files
## that are byte-identical to the committed ones.
try_check("WP04.A8", {
  build_script <- file.path("pipeline", "bootstrap", "build_small_codelists.R")
  out_root <- file.path(tempdir(), paste0("wp04_a8_", as.integer(Sys.time())))
  dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
  res <- run_script(build_script, c("--root", shQuote(root), "--out-root", shQuote(out_root)))
  if (!identical(res$status, 0L) && !identical(res$status, 0)) {
    log_txt <- tryCatch(paste(readLines(res$log, warn = FALSE), collapse = " | "), error = function(e) "<no log>")
    check("WP04.A8", FALSE, sprintf("build script exit status %s: %s", res$status, log_txt))
  } else {
    bad <- character(0)
    for (cl in names(codelist_files)) {
      committed <- tryCatch(blob_bytes(metadata_rel[[cl]]), error = function(e) raw(0))
      generated_path <- file.path(out_root, metadata_rel[[cl]])
      generated <- if (file.exists(generated_path)) readBin(generated_path, "raw", file.size(generated_path)) else raw(0)
      if (!identical(committed, generated)) bad <- c(bad, cl)
    }
    check("WP04.A8", length(bad) == 0,
          if (length(bad) == 0) "rebuilt files byte-identical to committed ones"
          else paste("differs:", paste(bad, collapse = ", ")))
  }
})

## ---- 5. Exit ----------------------------------------------------------------------
cat(if (length(.failures)) sprintf("\n%d check(s) failed: %s\n", length(.failures), paste(.failures, collapse = ", ")) else "\nAll checks passed.\n")
quit(status = if (length(.failures)) 1L else 0L, save = "no")
