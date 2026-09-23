#!/usr/bin/env Rscript
# Acceptance script for WP16 -- Independent reconciliation tool.
#
#   Rscript pipeline/acceptance/wp16_reconcile.R --root .
#
# Design: WP16's whole deliverable is the pair of functions source_cells()/
# expected_rows() (pipeline/R/reconcile.R) plus the CLI that wraps them
# (pipeline/reconcile.R). Every check below therefore treats pipeline/R/
# reconcile.R as fair game to source (COMMON.md's "unless the check is about
# those functions" exception) but ONLY to build a self-consistent fixture:
# expected_rows() supplies the converted- and withheld-cell keys/values that
# a correct converter output would contain, and every PASS/FAIL verdict is
# then read back off the *actual compiled CLI's* files (report.md, cells.csv)
# against contract/expected_counts.csv, never off expected_rows() itself.
# Independent, by-hand verification of expected_rows() against the raw
# workbook is the verifier's separate, non-scripted "Verifier focus" pass.

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
try_check <- function(id, expr) {
  r <- tryCatch(expr, error = function(e) check(id, FALSE, paste("error:", conditionMessage(e))))
  invisible(r)
}

## ---- 2. Helpers ---------------------------------------------------------------
read_csv_char <- function(path) {
  raw <- readLines(path, encoding = "UTF-8", warn = FALSE)
  if (length(raw)) raw[1] <- sub("^﻿", "", raw[1])
  read.csv(text = paste(raw, collapse = "\n"), colClasses = "character", na.strings = NULL,
           check.names = FALSE, encoding = "UTF-8")
}
expected <- function(check_id) {
  tab <- read_csv_char(file.path(contract, "expected_counts.csv"))
  row <- tab[tab$check_id == check_id, ]
  if (nrow(row) != 1) stop("no unique row in expected_counts.csv for ", check_id)
  list(value = as.numeric(row$expected), tol = as.numeric(row$tolerance))
}
meets <- function(actual, check_id) { e <- expected(check_id); abs(actual - e$value) <= e$tol + 1e-9 }
sum_expected <- function(check_ids) sum(vapply(check_ids, function(id) expected(id)$value, numeric(1)))

## ---- 3. Source WP16's own library (fixture generation only) -------------------
# Allowed: this whole package IS source_cells()/expected_rows()/reconcile().
suppressPackageStartupMessages({
  source(file.path(root, "pipeline", "R", "io.R"))
  source(file.path(root, "pipeline", "R", "codes.R"))
  source(file.path(root, "pipeline", "R", "constants.R"))
  source(file.path(root, "pipeline", "R", "reconcile.R"))
})

fmt_value <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(is.na(x), "", format(round(x, 6), scientific = FALSE, trim = TRUE))
}

# Build a 26-column DSD data frame from a set of expected_rows()-shaped rows
# (must carry KEY_COLUMNS, OBS_VALUE, OBS_STATUS, OBS_COMMENT_EXPECTED).
rows_to_dsd <- function(rows) {
  df <- rows[, KEY_COLUMNS]
  df$OBS_VALUE <- fmt_value(rows$OBS_VALUE)
  df$OBS_STATUS <- rows$OBS_STATUS
  df$STD_ERR <- ""; df$CI_LOWER <- ""; df$CI_UPPER <- ""; df$N_OBS <- ""; df$N_POP <- ""
  df$OBS_COMMENT <- ifelse(is.na(rows$OBS_COMMENT_EXPECTED), "", rows$OBS_COMMENT_EXPECTED)
  df[, DSD_COLUMNS]
}

# (Re)write tmp/data/AFW360_HH_<REF_AREA>_<TIME_PERIOD>.csv from a row set.
write_data_files <- function(base_tmp, rows) {
  data_dir <- file.path(base_tmp, "data")
  old <- list.files(data_dir, full.names = TRUE)
  if (length(old)) file.remove(old)
  grp <- unique(rows[, c("REF_AREA", "TIME_PERIOD")])
  for (k in seq_len(nrow(grp))) {
    sub <- rows[rows$REF_AREA == grp$REF_AREA[k] & rows$TIME_PERIOD == grp$TIME_PERIOD[k], ]
    df <- rows_to_dsd(sub)
    path <- file.path(data_dir, sprintf("AFW360_HH_%s_%s.csv", grp$REF_AREA[k], grp$TIME_PERIOD[k]))
    write.csv(df, path, row.names = FALSE, na = "", fileEncoding = "UTF-8")
  }
}

run_reconcile <- function(base_tmp) {
  out_md <- tempfile(fileext = ".md")
  out_csv <- tempfile(fileext = ".csv")
  log <- tempfile(fileext = ".log")
  script <- file.path(base_tmp, "pipeline", "reconcile.R")
  status <- system2("Rscript", c(shQuote(script), "--root", shQuote(base_tmp),
                                  "--out", shQuote(out_md), "--csv", shQuote(out_csv)),
                     stdout = log, stderr = log)
  list(status = status, report = out_md, csv = out_csv, log = log)
}

report_text <- function(res) if (file.exists(res$report)) paste(readLines(res$report, warn = FALSE), collapse = "\n") else ""
cells_of <- function(res) if (file.exists(res$csv) && file.info(res$csv)$size > 0) read_csv_char(res$csv) else data.frame()

## ---- 4. Build the base temp root (real code + real inputs) --------------------
base_tmp <- file.path(tempdir(), paste0("wp16_root_", as.integer(Sys.time()), "_", sample(1e5, 1)))
dir.create(base_tmp, recursive = TRUE)
invisible(file.copy(file.path(root, "pipeline"), base_tmp, recursive = TRUE))
invisible(file.copy(file.path(root, "metadata"), base_tmp, recursive = TRUE))
dir.create(file.path(base_tmp, "data_raw"), recursive = TRUE)
invisible(file.copy(file.path(root, "data_raw", "tables"), file.path(base_tmp, "data_raw"), recursive = TRUE))
dir.create(file.path(base_tmp, "data"), recursive = TRUE)

er <- expected_rows(root)
stopifnot(all(KEY_COLUMNS %in% names(er)),
          all(c("OBS_VALUE", "OBS_STATUS", "OBS_COMMENT_EXPECTED", "class", "row_key") %in% names(er)))
conv <- er[er$class == "converted", ]
withheld <- er[er$class == "withheld", ]
conv <- conv[order(conv$row_key), ]

## ---- 5. Clean run: WP16.A1, WP16.A2, WP16.A4 -----------------------------------
write_data_files(base_tmp, conv)
clean <- run_reconcile(base_tmp)
clean_csv <- cells_of(clean)

sen_total_expected <- sum_expected(c("CELLS.SEN_National", "CELLS.SEN_ADM1", "CELLS.SEN_ZAE", "CELLS.SEN_Departement"))
gnb_total_expected <- sum_expected(c("CELLS.GNB_National", "CELLS.GNB_ADM1", "CELLS.GNB_ZAE"))
sen_rows <- if (nrow(clean_csv)) sum(clean_csv$ref_area == "SEN") else NA
gnb_rows <- if (nrow(clean_csv)) sum(clean_csv$ref_area == "GNB") else NA

try_check("WP16.A1", check(
  "WP16.A1",
  identical(clean$status, 0L) &&
    isTRUE(sen_rows == sen_total_expected) && isTRUE(gnb_rows == gnb_total_expected) &&
    nrow(clean_csv) > 0 && all(clean_csv$result == "OK") && !any(clean_csv$result == "ORPHAN"),
  sprintf("exit=%s SEN cells=%s (expect %s) GNB cells=%s (expect %s) all-OK=%s",
          clean$status, sen_rows, sen_total_expected, gnb_rows, gnb_total_expected,
          if (nrow(clean_csv)) all(clean_csv$result == "OK") else NA)
))

conv_sen_n <- sum(clean_csv$ref_area == "SEN" & clean_csv$class == "converted")
conv_gnb_n <- sum(clean_csv$ref_area == "GNB" & clean_csv$class == "converted")
withheld_gnb_n <- sum(clean_csv$ref_area == "GNB" & clean_csv$class == "withheld")
three_sheets <- !(clean_csv$sheet %in% "Departement")
nonconv_sen_3sheet <- sum(clean_csv$ref_area == "SEN" & three_sheets &
                             clean_csv$class %in% c("duplicate", "derived", "skipped"))
nonconv_gnb_3sheet <- sum(clean_csv$ref_area == "GNB" & three_sheets &
                             clean_csv$class %in% c("duplicate", "derived", "skipped"))
sen_3sheet_total <- sum_expected(c("CELLS.SEN_National", "CELLS.SEN_ADM1", "CELLS.SEN_ZAE"))
gnb_3sheet_total <- sum_expected(c("CELLS.GNB_National", "CELLS.GNB_ADM1", "CELLS.GNB_ZAE"))
exp_nonconv_sen <- sen_3sheet_total - expected("DATA.SEN.ROWS")$value
exp_nonconv_gnb <- gnb_3sheet_total - expected("GNB.DATA.ROWS")$value - expected("GNB.WITHHELD_CELLS")$value

try_check("WP16.A2", check(
  "WP16.A2",
  meets(conv_sen_n, "DATA.SEN.ROWS") && meets(conv_gnb_n, "GNB.DATA.ROWS") &&
    meets(withheld_gnb_n, "GNB.WITHHELD_CELLS") &&
    isTRUE(nonconv_sen_3sheet == exp_nonconv_sen) && isTRUE(nonconv_gnb_3sheet == exp_nonconv_gnb),
  sprintf("converted SEN=%d GNB=%d withheld GNB=%d; dup+derived+skipped(3 sheets) SEN=%d (expect %d) GNB=%d (expect %d)",
          conv_sen_n, conv_gnb_n, withheld_gnb_n, nonconv_sen_3sheet, exp_nonconv_sen, nonconv_gnb_3sheet, exp_nonconv_gnb)
))

card_csv_cols <- c("ref_area", "sheet", "legacy_label", "column", "class", "result",
                    "source_value", "data_value", "row_key")
total_cells_both <- sen_total_expected + gnb_total_expected
try_check("WP16.A4", check(
  "WP16.A4",
  identical(names(clean_csv), card_csv_cols) && nrow(clean_csv) == total_cells_both,
  sprintf("columns=%s nrow=%d (expect %d)", paste(names(clean_csv), collapse = "|"), nrow(clean_csv), total_cells_both)
))

## ---- 6. Mutations: WP16.A3 ------------------------------------------------------
a3_ok <- TRUE
a3_ev <- character(0)
run_mutation <- function(label, want_result, rows, target_pred) {
  write_data_files(base_tmp, rows)
  res <- run_reconcile(base_tmp)
  csv <- cells_of(res)
  hit <- if (nrow(csv)) csv[target_pred(csv), ] else csv[0, ]
  exit_ok <- identical(res$status, 1L)
  result_ok <- nrow(hit) >= 1 && all(hit$result == want_result)
  ok <- exit_ok && result_ok
  a3_ok <<- a3_ok && ok
  a3_ev <<- c(a3_ev, sprintf("%s: exit=%s result=%s(want %s)=%s", label, res$status,
                              if (nrow(hit)) paste(unique(hit$result), collapse = ",") else "<none>",
                              want_result, ok))
  invisible(ok)
}

target_row <- conv[conv$OBS_STATUS == "A", ][1, ]
row2 <- conv[conv$OBS_STATUS == "A", ][2, ]
row3 <- conv[conv$OBS_STATUS == "A", ][3, ]
o_row <- conv[conv$OBS_STATUS == "O", ][1, ]
w_row <- withheld[1, ]

# a. changed value -> MISMATCH
mut <- conv
mut$OBS_VALUE[mut$row_key == target_row$row_key] <- as.numeric(target_row$OBS_VALUE) + 999
run_mutation("value_changed", "MISMATCH", mut,
             function(csv) csv$ref_area == target_row$ref_area & csv$sheet == target_row$sheet &
               csv$legacy_label == target_row$legacy_label & csv$column == target_row$column)

# b. deleted row -> MISSING_ROW
mut <- conv[conv$row_key != row2$row_key, ]
run_mutation("deleted_row", "MISSING_ROW", mut,
             function(csv) csv$ref_area == row2$ref_area & csv$sheet == row2$sheet &
               csv$legacy_label == row2$legacy_label & csv$column == row2$column)

# c. duplicated row -> DUPLICATE_ROW
mut <- rbind(conv, conv[conv$row_key == row3$row_key, ])
run_mutation("duplicated_row", "DUPLICATE_ROW", mut,
             function(csv) csv$ref_area == row3$ref_area & csv$sheet == row3$sheet &
               csv$legacy_label == row3$legacy_label & csv$column == row3$column)

# d. row added for a withheld cell -> WITHHELD_PRESENT
mut <- rbind(conv, w_row[, names(conv)])
run_mutation("withheld_present", "WITHHELD_PRESENT", mut,
             function(csv) csv$ref_area == w_row$ref_area & csv$sheet == w_row$sheet &
               csv$legacy_label == w_row$legacy_label & csv$column == w_row$column)

# e. row with an unplanned key -> ORPHAN (checked via the report text: an orphan
#    row has no source cell, so it cannot appear as a cells.csv row -- A4 says
#    the CSV holds one row per SOURCE cell).
orphan_row <- target_row
orphan_row$INDICATOR <- paste0(orphan_row$INDICATOR, "_WP16_ORPHAN_TEST")
mut <- rbind(conv, orphan_row)
write_data_files(base_tmp, mut)
res_orphan <- run_reconcile(base_tmp)
orphan_ok <- identical(res_orphan$status, 1L) && grepl("ORPHAN", report_text(res_orphan), fixed = TRUE)
a3_ok <- a3_ok && orphan_ok
a3_ev <- c(a3_ev, sprintf("orphan_key: exit=%s report-has-ORPHAN=%s", res_orphan$status,
                           grepl("ORPHAN", report_text(res_orphan), fixed = TRUE)))

# f. an O row given a value -> MISMATCH
mut <- conv
mut$OBS_VALUE[mut$row_key == o_row$row_key] <- 5
run_mutation("o_row_given_value", "MISMATCH", mut,
             function(csv) csv$ref_area == o_row$ref_area & csv$sheet == o_row$sheet &
               csv$legacy_label == o_row$legacy_label & csv$column == o_row$column)

try_check("WP16.A3", check("WP16.A3", a3_ok, paste(a3_ev, collapse = " | ")))

# restore the clean fixture so any check after this point sees a consistent root
write_data_files(base_tmp, conv)

## ---- 7. WP16.A5: independence from the converter, and the unit tests ----------
owned_files <- c("pipeline/reconcile.R", "pipeline/R/reconcile.R", "pipeline/tests/testthat/test-reconcile.R")
forbidden <- c("convert_tables", "convert_legacy", "required_rows")
# Immune to matching the acceptance script's own source: owned_files never
# includes this script's own path (pipeline/acceptance/wp16_reconcile.R).
code_hits <- character(0)
for (f in owned_files) {
  full <- file.path(root, f)
  if (file.exists(full)) {
    txt <- readLines(full, warn = FALSE)
    for (pat in forbidden) if (any(grepl(pat, txt, fixed = TRUE))) code_hits <- c(code_hits, paste0(f, ":", pat))
  }
}
log_txt <- tryCatch(system2("git", c("-C", shQuote(root), "log", "-p", "--", owned_files), stdout = TRUE, stderr = TRUE),
                     error = function(e) character(0))
log_hits <- forbidden[vapply(forbidden, function(p) any(grepl(p, log_txt, fixed = TRUE)), logical(1))]

ut_script <- tempfile(fileext = ".R")
writeLines(c(
  sprintf("setwd(%s)", deparse(root)),
  "suppressPackageStartupMessages(library(testthat))",
  sprintf('res <- test_dir(file.path(%s, "pipeline", "tests", "testthat"), filter = "reconcile", reporter = "silent", stop_on_failure = FALSE)', deparse(root)),
  "df <- as.data.frame(res)",
  'cat(sprintf("NFAIL=%d NWARN=%d NTEST=%d\\n", sum(df$failed), sum(df$warning), nrow(df)))'
), ut_script)
ut_log <- tempfile(fileext = ".log")
ut_status <- system2("Rscript", c("--vanilla", shQuote(ut_script)), stdout = ut_log, stderr = ut_log)
ut_out <- readLines(ut_log, warn = FALSE)
ut_line <- grep("^NFAIL=", ut_out, value = TRUE)
n_fail <- if (length(ut_line)) as.integer(sub("NFAIL=([0-9]+).*", "\\1", ut_line[1])) else NA_integer_

try_check("WP16.A5", check(
  "WP16.A5",
  length(code_hits) == 0 && length(log_hits) == 0 && identical(ut_status, 0L) && isTRUE(n_fail == 0),
  sprintf("code_hits=%s log_hits=%s unit_tests exit=%s %s",
          if (length(code_hits)) paste(code_hits, collapse = ",") else "none",
          if (length(log_hits)) paste(log_hits, collapse = ",") else "none",
          ut_status, if (length(ut_line)) ut_line[1] else paste(tail(ut_out, 5), collapse = " / "))
))

## ---- 8. Exit ----------------------------------------------------------------------
unlink(base_tmp, recursive = TRUE, force = TRUE)
cat(if (length(.failures)) sprintf("\n%d check(s) failed: %s\n", length(.failures), paste(.failures, collapse = ", ")) else "\nAll checks passed.\n")
quit(status = if (length(.failures)) 1L else 0L, save = "no")
