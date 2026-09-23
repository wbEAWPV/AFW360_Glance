#!/usr/bin/env Rscript
# Acceptance script for WP07 - Indicator dictionary (CL_INDICATOR.csv).
#
#   Rscript pipeline/acceptance/wp07_dictionary.R --root .
#
# Standalone: does not source pipeline/R/. Expected numbers come from
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
# Run a pipeline script; returns its exit status. Output goes to a temp log.
run_script <- function(script, script_args) {
  log <- tempfile(fileext = ".log")
  system2("Rscript", c(shQuote(file.path(root, script)), script_args), stdout = log, stderr = log)
}
same_file <- function(a, b) file.exists(a) && file.exists(b) && identical(unname(tools::md5sum(a)), unname(tools::md5sum(b)))
# Compare two triage-vs-output values: numeric-tolerant, else trimmed string.
values_equal <- function(a, b) {
  if (is.na(a) || is.na(b)) return(FALSE)
  na <- suppressWarnings(as.numeric(a)); nb <- suppressWarnings(as.numeric(b))
  if (!is.na(na) && !is.na(nb)) return(abs(na - nb) < 1e-9)
  identical(trimws(a), trimws(b))
}

## ---- 3. Shared data --------------------------------------------------------------
cl_path <- file.path(root, "metadata", "codelists", "CL_INDICATOR.csv")
cl <- read_csv_char(cl_path)

triage <- read_csv_char(file.path(contract, "label_triage.csv"))
map_rows <- triage[triage$action == "MAP", ]

codes_all <- read_csv_char(file.path(contract, "codes.csv"))
qual_codes <- codes_all[codes_all$codelist == "CL_QUALIFIER", c("code", "var_code", "order")]
qual_vars  <- codes_all[codes_all$codelist == "CL_QUAL_VAR", c("code", "slot_order")]

# Unique, space-separated MEASURE_QUALS codes used by an indicator's MAP rows.
get_used_quals <- function(indicator_code) {
  rows <- map_rows[map_rows$INDICATOR == indicator_code, ]
  mq <- trimws(rows$MEASURE_QUALS)
  unique(unlist(strsplit(mq[nzchar(mq)], "\\s+")))
}
# A single triage value for a mechanical column, for one indicator; NA if inconsistent/absent.
triage_lookup <- function(col, indicator_code) {
  v <- unique(trimws(map_rows[[col]][map_rows$INDICATOR == indicator_code]))
  if (length(v) != 1) NA_character_ else v
}
rebuild_qualifiers <- function(indicator_code) {
  used <- get_used_quals(indicator_code)
  if (length(used) == 0) return("_Z")
  vc  <- qual_codes$var_code[match(used, qual_codes$code)]
  ord <- suppressWarnings(as.numeric(qual_codes$order[match(used, qual_codes$code)]))
  vars <- unique(vc)
  so <- suppressWarnings(as.numeric(qual_vars$slot_order[match(vars, qual_vars$code)]))
  vars_sorted <- vars[order(so)]
  parts <- vapply(vars_sorted, function(v) {
    idx <- which(vc == v)
    codes_v <- used[idx][order(ord[idx])]
    paste0(v, ":", paste(codes_v, collapse = ","))
  }, character(1))
  paste(parts, collapse = " ")
}
has_povline <- function(indicator_code) {
  used <- get_used_quals(indicator_code)
  if (length(used) == 0) return(FALSE)
  vc <- qual_codes$var_code[match(used, qual_codes$code)]
  any(vc == "POVLINE", na.rm = TRUE)
}
rebuild_checks <- function(indicator_code) {
  um   <- triage_lookup("unit_measure", indicator_code)
  vmin <- triage_lookup("valid_min", indicator_code)
  stat <- triage_lookup("statistic", indicator_code)
  toks <- character(0)
  if (!is.na(um) && identical(um, "SHARE")) {
    toks <- c(toks, "RANGE_0_1")
  } else if (!is.na(vmin) && identical(vmin, "0")) {
    toks <- c(toks, "RANGE_NONNEG")
  }
  if (!identical(indicator_code, "EN_OUTAGE_DUR_CODE")) {
    toks <- c(toks, if (!is.na(stat) && identical(stat, "TOTAL")) "AGG_SUM" else "AGG_BRACKET")
  }
  if (has_povline(indicator_code)) toks <- c(toks, "MONOTONE_IN:POVLINE")
  if (identical(indicator_code, "CONS_SH")) toks <- c(toks, "SUM_TO_1_OVER:COICOP")
  if (indicator_code %in% c("POP_SH", "POP_HH_SH", "POP_HE_SH")) toks <- c(toks, "SUM_TO_1_OVER_BRK")
  if (length(toks) == 0) "NONE" else paste(toks, collapse = " ")
}

## ---- 4. Checks ------------------------------------------------------------------

## WP07.A1 -- code set and row count
try_check("WP07.A1", {
  expected_codes <- sort(unique(map_rows$INDICATOR))
  actual_codes <- sort(unique(cl$code))
  codes_match <- identical(expected_codes, actual_codes)
  no_dup <- length(unique(cl$code)) == nrow(cl)
  count_ok <- meets(nrow(cl), "INDICATOR.CODES")
  check("WP07.A1", codes_match && no_dup && count_ok,
        sprintf("codes_match=%s no_dup=%s n=%d expected=%s",
                codes_match, no_dup, nrow(cl), expected("INDICATOR.CODES")$value))
})

## WP07.A2 -- mechanical columns copied from the triage
try_check("WP07.A2", {
  mech_cols <- c("stat_unit", "statistic", "weight", "ref_period", "unit_measure",
                 "unit_denom", "unit_time", "price_basis", "display_as", "decimals",
                 "valid_min", "valid_max")
  bad <- character(0)
  for (col in mech_cols) {
    exp_vals <- vapply(cl$code, function(cd) triage_lookup(col, cd), character(1))
    act_vals <- trimws(cl[[col]])
    eq <- mapply(values_equal, exp_vals, act_vals)
    if (!all(eq)) bad <- c(bad, col)
  }
  check("WP07.A2", length(bad) == 0,
        if (length(bad) == 0) sprintf("all %d mechanical columns match for %d codes", length(mech_cols), nrow(cl))
        else paste("mismatch in:", paste(bad, collapse = ",")))
})

## WP07.A3 -- qualifiers rebuilt from triage + codes.csv
try_check("WP07.A3", {
  exp_qual <- vapply(cl$code, rebuild_qualifiers, character(1))
  act_qual <- trimws(cl$qualifiers)
  mism <- cl$code[exp_qual != act_qual]
  check("WP07.A3", length(mism) == 0,
        if (length(mism) == 0) sprintf("qualifiers match for all %d codes", nrow(cl))
        else paste("mismatch for:", paste(head(mism, 10), collapse = ",")))
})

## WP07.A4 -- checks rebuilt, and vocabulary
try_check("WP07.A4", {
  exp_checks <- vapply(cl$code, rebuild_checks, character(1))
  act_checks <- trimws(cl$checks)
  mism <- cl$code[exp_checks != act_checks]
  vocab <- c("RANGE_0_1", "RANGE_NONNEG", "AGG_SUM", "AGG_BRACKET", "AGG_NPOP_MEAN",
             "SUM_TO_1_OVER_BRK", "EQUALS_NPOP_RATIO", "MONOTONE_IN:POVLINE", "NONE")
  vocab_ok_one <- function(s) {
    toks <- strsplit(s, "\\s+")[[1]]
    if (length(toks) == 0) return(FALSE)
    all(toks %in% vocab | grepl("^SUM_TO_1_OVER:[A-Z0-9_]+$", toks))
  }
  vocab_bad <- cl$code[!vapply(act_checks, vocab_ok_one, logical(1))]
  check("WP07.A4", length(mism) == 0 && length(vocab_bad) == 0,
        sprintf("rebuild_mismatches=%d (%s) vocab_violations=%d (%s)",
                length(mism), paste(head(mism, 10), collapse = ","),
                length(vocab_bad), paste(head(vocab_bad, 10), collapse = ",")))
})

## WP07.A5 -- codelist membership, and related codes exist in the file
try_check("WP07.A5", {
  codelist_map <- c(theme = "CL_THEME", stat_unit = "CL_STAT_UNIT", statistic = "CL_STATISTIC",
                     weight = "CL_WEIGHT", unit_measure = "CL_UNIT")
  bad_cols <- character(0)
  for (col in names(codelist_map)) {
    valid_codes <- codes_all$code[codes_all$codelist == codelist_map[[col]]]
    bad_rows <- cl$code[!(trimws(cl[[col]]) %in% valid_codes)]
    if (length(bad_rows)) bad_cols <- c(bad_cols, sprintf("%s(%s)", col, paste(head(bad_rows, 5), collapse = ",")))
  }
  related_raw <- trimws(cl$related)
  related_all <- unique(unlist(strsplit(related_raw[nzchar(related_raw)], "\\s+")))
  related_bad <- setdiff(related_all, cl$code)
  check("WP07.A5", length(bad_cols) == 0 && length(related_bad) == 0,
        sprintf("codelist_violations=%s related_missing=%s",
                paste(bad_cols, collapse = ";"), paste(related_bad, collapse = ",")))
})

## WP07.A6 -- short_name_en length, required columns filled, higher_is enum
try_check("WP07.A6", {
  short_bad <- cl$code[nchar(cl$short_name_en) > 40]
  r_cols <- c("code", "name_en", "definition_en", "status", "version_added", "short_name_en",
              "theme", "stat_unit", "universe_unit", "statistic", "weight", "ref_period",
              "qualifiers", "unit_measure", "display_as", "decimals", "checks", "higher_is",
              "source_questionnaire", "source_vars", "program", "owner")
  empty_bad <- character(0)
  for (col in r_cols) {
    n_empty <- sum(!nzchar(trimws(cl[[col]])))
    if (n_empty > 0) empty_bad <- c(empty_bad, sprintf("%s:%d", col, n_empty))
  }
  higher_bad <- cl$code[!(cl$higher_is %in% c("BETTER", "WORSE", "NEUTRAL"))]
  check("WP07.A6", length(short_bad) == 0 && length(empty_bad) == 0 && length(higher_bad) == 0,
        sprintf("short_name_over40=%d empty_R_cols=%s higher_is_bad=%d",
                length(short_bad), paste(empty_bad, collapse = ";"), length(higher_bad)))
})

## WP07.A7 -- header equals csv_headers.csv, status is DRAFT
try_check("WP07.A7", {
  expected_header <- header_of("CL_INDICATOR.csv")
  header_ok <- identical(names(cl), expected_header)
  status_ok <- all(cl$status == "DRAFT")
  check("WP07.A7", header_ok && status_ok,
        sprintf("header_ok=%s status_DRAFT_all=%s (n_cols=%d expected=%d)",
                header_ok, status_ok, length(names(cl)), length(expected_header)))
})

## WP07.A8 -- rebuild into a temp dir reproduces the file byte for byte
try_check("WP07.A8", {
  tmp_out <- file.path(tempdir(), paste0("wp07_outroot_", as.integer(Sys.time())))
  dir.create(tmp_out, recursive = TRUE, showWarnings = FALSE)
  rc <- run_script(file.path("pipeline", "bootstrap", "build_indicators.R"),
                    c("--root", root, "--out-root", tmp_out))
  out_file <- file.path(tmp_out, "metadata", "codelists", "CL_INDICATOR.csv")
  repro_ok <- identical(rc, 0L) && same_file(out_file, cl_path)
  check("WP07.A8", repro_ok,
        sprintf("exit=%s out_exists=%s same_bytes=%s", rc, file.exists(out_file),
                if (file.exists(out_file)) same_file(out_file, cl_path) else NA))
})

## ---- 5. Exit ----------------------------------------------------------------------
cat(if (length(.failures)) sprintf("\n%d check(s) failed: %s\n", length(.failures), paste(.failures, collapse = ", ")) else "\nAll checks passed.\n")
quit(status = if (length(.failures)) 1L else 0L, save = "no")
