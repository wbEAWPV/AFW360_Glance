#!/usr/bin/env Rscript
# Acceptance script for WP13 -- Validator: verification rules.
#
#   Rscript pipeline/acceptance/wp13_validator-rules.R --root .
#
# Standalone: sources pipeline/R/{constants,codes,io,ctx,plan,validate_rules}.R
# because every check here is about validate_rules.R's vc_rule_*() functions
# and the plumbing (build_ctx(), required_rows()) they need to run. Writes
# only under tempdir(). Never edits real metadata: it copies metadata/content
# into a fresh temp root per scenario and mutates only that copy.

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

## ---- 3. WP13-specific setup ----------------------------------------------------
# validate_rules.R is exactly what these checks are about; io.R/ctx.R/plan.R are
# the plumbing it and required_rows() need (constants.R/codes.R are their
# dependencies, same pattern already used by pipeline/acceptance/wp08_plans.R).
suppressPackageStartupMessages({
  source(file.path(root, "pipeline", "R", "constants.R"))
  source(file.path(root, "pipeline", "R", "codes.R"))
  source(file.path(root, "pipeline", "R", "io.R"))
  source(file.path(root, "pipeline", "R", "ctx.R"))
  source(file.path(root, "pipeline", "R", "plan.R"))
  source(file.path(root, "pipeline", "R", "validate_rules.R"))
  # make_temp_root()/edit_csv() are plain R helpers (not testthat-specific)
  # shared by every WP's tests; they only need io.R, already sourced above.
  source(file.path(root, "pipeline", "tests", "testthat", "helper-temp-root.R"))
})

REF_AREA <- "SEN"
TIME_PERIOD <- "2021"
POV_NUM_PL300 <- "POV_NUM.POVLINE_PL300.PPP_2021"
POV_NUM_PL420 <- "POV_NUM.POVLINE_PL420.PPP_2021"
POV_HC_PL300  <- "POV_HC.POVLINE_PL300.PPP_2021"
POV_HC_PL420  <- "POV_HC.POVLINE_PL420.PPP_2021"
COICOP_IDS <- sprintf("CONS_SH.COICOP_CP%02d", 1:13)
HE_COUNT_IDS <- c("POP_HH_SH.HE_COUNT_0", "POP_HH_SH.HE_COUNT_1", "POP_HH_SH.HE_COUNT_2",
                   "POP_HH_SH.HE_COUNT_3", "POP_HH_SH.HE_COUNT_4P")

# A fresh temp copy of metadata+content only (no real data/ dir: none exists
# yet, WP15 builds the converter separately). Mutating this copy never
# touches the real repo.
new_temp_root <- function() make_temp_root(root, include = c("metadata", "content"))

# required_rows() gives every required (series_id, cut_id) row for the given
# series_ids, on whatever SERIES_PLAN the temp root currently has (so a plan
# restricted by restrict_series_plan() is honoured).
rows_for <- function(tmp_root, series_ids) {
  meta <- load_metadata(tmp_root)
  rows <- required_rows(meta, REF_AREA, TIME_PERIOD)
  rows[rows$series_id %in% series_ids, , drop = FALSE]
}

# Drop SERIES_PLAN rows outside keep_ids on a temp root's own copy, so a
# comp-breakdown/qual-var closure is no longer fully present in the plan.
restrict_series_plan <- function(tmp_root, keep_ids) {
  sp_path <- file.path(tmp_root, "metadata", "plans", "SERIES_PLAN.csv")
  edit_csv(sp_path, function(df) df[df$series_id %in% keep_ids, , drop = FALSE])
}

# Every POV_NUM child in a cut is parent_val / k, split so children sum to
# parent_val exactly (integer persons, last child absorbs the remainder).
# This keeps every one of the 6 non-TOTAL cuts (which have different child
# counts k) simultaneously consistent with the single TOTAL row.
build_povnum_rows <- function(rows_df, parent_pl300 = 3000000, parent_pl420 = 4000000) {
  rows_df$OBS_VALUE <- NA_character_
  for (sid in unique(rows_df$series_id)) {
    parent_val <- if (grepl("PL300", sid, fixed = TRUE)) parent_pl300 else parent_pl420
    idx_total <- rows_df$series_id == sid & rows_df$cut_id == "TOTAL"
    rows_df$OBS_VALUE[idx_total] <- fmt_num(parent_val)
    for (cid in setdiff(unique(rows_df$cut_id[rows_df$series_id == sid]), "TOTAL")) {
      idx <- rows_df$series_id == sid & rows_df$cut_id == cid
      k <- sum(idx)
      base_val <- floor(parent_val / k)
      vals <- rep(base_val, k)
      vals[k] <- vals[k] + (parent_val - base_val * k)
      rows_df$OBS_VALUE[idx] <- fmt_num(vals)
    }
  }
  rows_df
}

# POV_HC is a rate: every row (TOTAL and every child, in every cut) gets the
# same flat value per poverty line, which trivially satisfies AGG_BRACKET
# (min == max == parent) and MONOTONE_IN:POVLINE (PL420 > PL300 everywhere).
build_povhc_rows <- function(rows_df, val_pl300 = 0.2, val_pl420 = 0.4) {
  rows_df$OBS_VALUE <- ifelse(grepl("PL300", rows_df$series_id, fixed = TRUE),
                               fmt_num(val_pl300), fmt_num(val_pl420))
  rows_df
}

# CONS_SH (13 COICOP categories) and POP_HH_SH (5 HE_COUNT categories) are
# shares of a closure: a flat value of 1/n on every row makes every cell
# (every cut x geo combination) sum to 1, independent of cut/k.
build_flat_rows <- function(rows_df, value) {
  rows_df$OBS_VALUE <- fmt_num(value)
  rows_df
}

# Write rows_df (must carry the 18 KEY_COLUMNS + OBS_VALUE) as a standard
# data file plus its manifest (precision = ROUNDED_2DP, as the card's Steps
# section specifies), inside tmp_root/data/.
write_fixture <- function(tmp_root, rows_df) {
  data <- rows_df[KEY_COLUMNS]
  data$OBS_VALUE <- rows_df$OBS_VALUE
  data$OBS_STATUS <- "A"
  data$STD_ERR <- ""
  data$CI_LOWER <- ""
  data$CI_UPPER <- ""
  data$N_OBS <- ""
  data$N_POP <- ""
  data$OBS_COMMENT <- ""
  data <- data[DSD_COLUMNS]

  stem <- paste0(DATAFLOW_ID, "_", REF_AREA, "_", TIME_PERIOD)
  data_dir <- file.path(tmp_root, "data")
  dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
  data_path <- file.path(data_dir, paste0(stem, ".csv"))
  manifest_path <- file.path(data_dir, paste0(stem, "_manifest.csv"))
  write_std_csv(data, data_path)

  # contract/csv_headers.csv fixes AFW360_HH_<ISO3>_<YEAR>_manifest.csv as a
  # long key/value table (columns "key", "value"), which is what build_ctx()
  # (pipeline/R/ctx.R) reads: it takes column 1 as names and column 2 as
  # values. A wide one-row manifest (one column per field) is read back
  # wrong -- "precision" is never among the names, so ctx$precision silently
  # defaults to EXACT instead of ROUNDED_2DP. See the verifier report.
  manifest <- data.frame(
    key = c("dataflow", "dsd_version", "metadata_version", "ref_area", "time_period",
            "source_type", "survey_id", "precision", "file_name", "n_rows",
            "producer", "program", "software", "run_timestamp", "status", "notes"),
    value = c(DATAFLOW_ID, "TBD", "TBD", REF_AREA, TIME_PERIOD, "SURVEY", "TBD",
              "ROUNDED_2DP", basename(data_path), as.character(nrow(data)),
              "TBD", "TBD", "TBD", "TBD", "DRAFT", ""),
    stringsAsFactors = FALSE
  )
  write_std_csv(manifest, manifest_path)
  data_path
}

ctx_for <- function(tmp_root, data_path) build_ctx(tmp_root, data_files = data_path)

# Run every vc_rule_*() function found in this session (the naming
# convention the card fixes) and rbind their findings.
run_all_rules <- function(ctx) {
  fn_names <- sort(ls(envir = .GlobalEnv, pattern = "^vc_rule_"))
  cols <- c("check_id", "severity", "file", "row_key", "message")
  parts <- lapply(fn_names, function(nm) {
    res <- get(nm, envir = .GlobalEnv)(ctx)
    if (is.null(res)) return(NULL)
    res <- as.data.frame(res, stringsAsFactors = FALSE)
    if (nrow(res) == 0) return(NULL)
    res[cols]
  })
  parts <- parts[!vapply(parts, is.null, logical(1))]
  if (!length(parts)) return(as.data.frame(setNames(rep(list(character(0)), 5), cols)))
  do.call(rbind, parts)
}

## ---- 4. Checks ------------------------------------------------------------------

## WP13.A1 -- on a fully self-consistent fixture, 0 ERROR findings.
try_check("WP13.A1", {
  tmp_root <- new_temp_root()
  all_ids <- c(POV_NUM_PL300, POV_NUM_PL420, POV_HC_PL300, POV_HC_PL420, COICOP_IDS, HE_COUNT_IDS)
  rows <- rows_for(tmp_root, all_ids)
  pn <- build_povnum_rows(rows[rows$series_id %in% c(POV_NUM_PL300, POV_NUM_PL420), , drop = FALSE])
  ph <- build_povhc_rows(rows[rows$series_id %in% c(POV_HC_PL300, POV_HC_PL420), , drop = FALSE])
  cs <- build_flat_rows(rows[rows$series_id %in% COICOP_IDS, , drop = FALSE], 1 / 13)
  he <- build_flat_rows(rows[rows$series_id %in% HE_COUNT_IDS, , drop = FALSE], 1 / 5)
  combined <- rbind(pn, ph, cs, he)
  data_path <- write_fixture(tmp_root, combined)
  res <- run_all_rules(ctx_for(tmp_root, data_path))
  n_err <- sum(res$severity == "ERROR")
  check("WP13.A1", n_err == 0, sprintf("errors=%d (total findings=%d, rows=%d)", n_err, nrow(res), nrow(combined)))
})

## WP13.A2 -- each of the six mutations gives exactly its check_id.
try_check("WP13.A2", {
  mutate_agg_sum <- function() {
    tmp_root <- new_temp_root()
    rows <- build_povnum_rows(rows_for(tmp_root, c(POV_NUM_PL300, POV_NUM_PL420)))
    idx <- which(rows$series_id == POV_NUM_PL420 & rows$cut_id == "URB")[1]
    rows$OBS_VALUE[idx] <- fmt_num(as.numeric(rows$OBS_VALUE[idx]) * 2)
    ctx_for(tmp_root, write_fixture(tmp_root, rows))
  }
  mutate_agg_bracket <- function() {
    tmp_root <- new_temp_root()
    rows <- build_povhc_rows(rows_for(tmp_root, c(POV_HC_PL300, POV_HC_PL420)))
    idx <- which(rows$series_id == POV_HC_PL300 & rows$cut_id == "TOTAL")[1]
    rows$OBS_VALUE[idx] <- fmt_num(0.21) # > every child (0.2) + h (0.005)
    ctx_for(tmp_root, write_fixture(tmp_root, rows))
  }
  mutate_sum_to_1_qual <- function() {
    tmp_root <- new_temp_root()
    rows <- build_flat_rows(rows_for(tmp_root, COICOP_IDS), 1 / 13)
    idx <- which(rows$series_id == "CONS_SH.COICOP_CP01" & rows$cut_id == "URB")[1]
    rows$OBS_VALUE[idx] <- fmt_num(as.numeric(rows$OBS_VALUE[idx]) + 0.2) # cell sums to ~1.2
    ctx_for(tmp_root, write_fixture(tmp_root, rows))
  }
  mutate_sum_to_1_brk <- function() {
    tmp_root <- new_temp_root()
    rows <- build_flat_rows(rows_for(tmp_root, HE_COUNT_IDS), 1 / 5)
    idx <- which(rows$series_id == "POP_HH_SH.HE_COUNT_0" & rows$cut_id == "URB")[1]
    rows$OBS_VALUE[idx] <- fmt_num(as.numeric(rows$OBS_VALUE[idx]) + 0.2) # cell sums to ~1.2
    ctx_for(tmp_root, write_fixture(tmp_root, rows))
  }
  mutate_monotone <- function() {
    tmp_root <- new_temp_root()
    rows <- build_povhc_rows(rows_for(tmp_root, c(POV_HC_PL300, POV_HC_PL420)))
    idx <- which(rows$series_id == POV_HC_PL300 & rows$cut_id == "URB")[1]
    rows$OBS_VALUE[idx] <- fmt_num(0.5) # PL300 (0.5) > PL420 (0.4) in that one cell
    ctx_for(tmp_root, write_fixture(tmp_root, rows))
  }
  mutate_range01 <- function() {
    tmp_root <- new_temp_root()
    rows <- build_povhc_rows(rows_for(tmp_root, c(POV_HC_PL300, POV_HC_PL420)))
    idx <- which(rows$series_id == POV_HC_PL420 & rows$cut_id == "URB")[1]
    rows$OBS_VALUE[idx] <- fmt_num(1.3)
    ctx_for(tmp_root, write_fixture(tmp_root, rows))
  }

  cases <- list(
    list(id = "RULE.AGG_SUM", ctx = mutate_agg_sum()),
    list(id = "RULE.AGG_BRACKET", ctx = mutate_agg_bracket()),
    list(id = "RULE.SUM_TO_1_QUAL", ctx = mutate_sum_to_1_qual()),
    list(id = "RULE.SUM_TO_1_BRK", ctx = mutate_sum_to_1_brk()),
    list(id = "RULE.MONOTONE", ctx = mutate_monotone()),
    list(id = "RULE.RANGE_0_1", ctx = mutate_range01())
  )
  all_ok <- TRUE
  details <- character(0)
  for (cs in cases) {
    res <- run_all_rules(cs$ctx)
    errs <- res[res$severity == "ERROR", , drop = FALSE]
    ok <- nrow(errs) > 0 && all(errs$check_id == cs$id)
    all_ok <- all_ok && ok
    details <- c(details, sprintf("%s=%s(n=%d)", cs$id, ok, nrow(errs)))
  }
  check("WP13.A2", all_ok, paste(details, collapse = "; "))
})

## WP13.A3 -- rounding noise does not fail.
try_check("WP13.A3", {
  # A COICOP cell that sums to 0.97 passes (tolerance 13 * 0.005 * 1 = 0.065).
  tmp_root1 <- new_temp_root()
  rows1 <- build_flat_rows(rows_for(tmp_root1, COICOP_IDS), 1 / 13)
  idx1 <- which(rows1$series_id == "CONS_SH.COICOP_CP01" & rows1$cut_id == "URB")[1]
  rows1$OBS_VALUE[idx1] <- fmt_num(as.numeric(rows1$OBS_VALUE[idx1]) + (0.97 - 1))
  res1 <- run_all_rules(ctx_for(tmp_root1, write_fixture(tmp_root1, rows1)))
  ok1 <- !any(res1$check_id == "RULE.SUM_TO_1_QUAL")

  # A POV_NUM parent of 3130000 with 6 (ZONES) children summing to 3120000
  # passes (tolerance (6 + 1) * 0.005 * 1e6 = 35000).
  tmp_root2 <- new_temp_root()
  rows2 <- build_povnum_rows(rows_for(tmp_root2, c(POV_NUM_PL300, POV_NUM_PL420)),
                              parent_pl300 = 3130000, parent_pl420 = 4000000)
  idxZ <- which(rows2$series_id == POV_NUM_PL300 & rows2$cut_id == "ZONES")
  k <- length(idxZ)
  base_val <- floor(3120000 / k)
  vals <- rep(base_val, k)
  vals[k] <- vals[k] + (3120000 - base_val * k)
  rows2$OBS_VALUE[idxZ] <- fmt_num(vals)
  res2 <- run_all_rules(ctx_for(tmp_root2, write_fixture(tmp_root2, rows2)))
  ok2 <- k == 6 && !any(res2$check_id == "RULE.AGG_SUM")

  check("WP13.A3", ok1 && ok2, sprintf("COICOP 0.97 no-finding=%s; POV_NUM k=%d 3130000/3120000 no-finding=%s", ok1, k, ok2))
})

## WP13.A4 -- boundary: deviation exactly the tolerance passes; tolerance +
## 0.001 * scale fails. Uses CONS_SH SUM_TO_1_QUAL (k = 13, h = 0.005 * 1,
## tolerance = 0.065, scale = 1).
try_check("WP13.A4", {
  build_case <- function(target_sum) {
    tmp_root <- new_temp_root()
    rows <- build_flat_rows(rows_for(tmp_root, COICOP_IDS), 1 / 13)
    idx <- which(rows$series_id == "CONS_SH.COICOP_CP01" & rows$cut_id == "URB")[1]
    rows$OBS_VALUE[idx] <- fmt_num(as.numeric(rows$OBS_VALUE[idx]) + (target_sum - 1))
    run_all_rules(ctx_for(tmp_root, write_fixture(tmp_root, rows)))
  }
  res_pass <- build_case(1 + 0.065)
  res_fail <- build_case(1 + 0.065 + 0.001 * 1)
  pass_ok <- !any(res_pass$check_id == "RULE.SUM_TO_1_QUAL")
  fail_ok <- any(res_fail$check_id == "RULE.SUM_TO_1_QUAL" & res_fail$severity == "ERROR")
  check("WP13.A4", pass_ok && fail_ok, sprintf("deviation==tolerance passes=%s; tolerance+0.001*scale fails=%s", pass_ok, fail_ok))
})

## WP13.A5 -- a deleted child gives WARN RULE.AGG_SKIPPED (no ERROR for that
## parent/cut); a plan not covering every category of a comp-breakdown
## variable gives INFO RULE.CLOSURE_PARTIAL (no ERROR). The second case is
## simulated with HE_COUNT (drop 1 of its 5 categories from SERIES_PLAN on a
## temp copy) rather than the real EMP_STATUS data, since CLOSURE_PARTIAL is
## a generic "plan vs CL_COMP_BREAKDOWN" mechanism, not indicator-specific;
## see the verifier report's Deviations.
try_check("WP13.A5", {
  tmp_root1 <- new_temp_root()
  rows1 <- build_povnum_rows(rows_for(tmp_root1, c(POV_NUM_PL300, POV_NUM_PL420)))
  idx_del <- which(rows1$series_id == POV_NUM_PL300 & rows1$cut_id == "URB")[1]
  rows1 <- rows1[-idx_del, , drop = FALSE]
  res1 <- run_all_rules(ctx_for(tmp_root1, write_fixture(tmp_root1, rows1)))
  skip_ok <- any(res1$check_id == "RULE.AGG_SKIPPED" & res1$severity == "WARN")
  no_err1 <- !any(res1$severity == "ERROR")

  tmp_root2 <- new_temp_root()
  partial_ids <- HE_COUNT_IDS[1:4]
  restrict_series_plan(tmp_root2, partial_ids)
  rows2 <- build_flat_rows(rows_for(tmp_root2, partial_ids), 1 / 4)
  res2 <- run_all_rules(ctx_for(tmp_root2, write_fixture(tmp_root2, rows2)))
  partial_ok <- any(res2$check_id == "RULE.CLOSURE_PARTIAL" & res2$severity == "INFO")
  no_err2 <- !any(res2$severity == "ERROR")

  check("WP13.A5", skip_ok && no_err1 && partial_ok && no_err2,
        sprintf("agg_skipped=%s no_error_after_delete=%s closure_partial=%s no_error_partial_plan=%s",
                skip_ok, no_err1, partial_ok, no_err2))
})

## WP13.A6 -- with ctx$data empty, every vc_rule_*() returns zero rows; the
## unit tests pass.
try_check("WP13.A6", {
  fn_names <- sort(ls(envir = .GlobalEnv, pattern = "^vc_rule_"))
  tmp_root <- new_temp_root()
  ctx_empty <- build_ctx(tmp_root, data_files = character(0))
  empty_ok <- length(fn_names) > 0 && all(vapply(fn_names, function(nm) {
    res <- get(nm, envir = .GlobalEnv)(ctx_empty)
    is.null(res) || nrow(res) == 0
  }, logical(1)))

  suppressPackageStartupMessages(library(testthat))
  test_res <- as.data.frame(test_dir(file.path(root, "pipeline", "tests", "testthat"),
                                      filter = "validate-rules", reporter = "silent", stop_on_failure = FALSE))
  tests_ok <- nrow(test_res) > 0 && sum(test_res$failed) == 0 && !any(test_res$error %in% TRUE)

  check("WP13.A6", empty_ok && tests_ok,
        sprintf("vc_rule_* found=%d all-empty-on-empty-ctx=%s; testthat files=%d failed=%d error=%s",
                length(fn_names), empty_ok, nrow(test_res), sum(test_res$failed), any(test_res$error %in% TRUE)))
})

## ---- 5. Exit ----------------------------------------------------------------------
cat(if (length(.failures)) sprintf("\n%d check(s) failed: %s\n", length(.failures), paste(.failures, collapse = ", ")) else "\nAll checks passed.\n")
quit(status = if (length(.failures)) 1L else 0L, save = "no")
