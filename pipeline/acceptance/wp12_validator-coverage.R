#!/usr/bin/env Rscript
# Acceptance script for WP12 (Validator: coverage and values).
# .docs/transition/packages/WP12.md
#
#   Rscript pipeline/acceptance/wp12_validator-coverage.R --root .
#
# Standalone; sources pipeline/R/ only because every WP12 check is about the
# functions those files define (validate_coverage.R, validate_values.R) and
# the ctx/plan machinery the card's Interface section names as their input
# (build_ctx(), required_rows()). Expected numbers come from
# contract/expected_counts.csv, read with this script's own reader, never
# with read_std_csv()/write_std_csv(). All fixtures are written under
# tempdir().

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

## ---- 2. Helpers (this script's own reader; never read_std_csv/write_std_csv) --
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

## ---- 3. Load the modules under test and their declared dependencies -----------
# ctx.R depends on io.R; plan.R depends on codes.R/constants.R and (for
# meta) io.R; validate_coverage.R/validate_values.R are the two modules
# WP12 owns. The two test helpers build fixtures the way the card's Step 2
# specifies.
suppressWarnings(suppressMessages({
  source(file.path(root, "pipeline", "R", "constants.R"))
  source(file.path(root, "pipeline", "R", "io.R"))
  source(file.path(root, "pipeline", "R", "codes.R"))
  source(file.path(root, "pipeline", "R", "ctx.R"))
  source(file.path(root, "pipeline", "R", "plan.R"))
  source(file.path(root, "pipeline", "R", "validate_coverage.R"))
  source(file.path(root, "pipeline", "R", "validate_values.R"))
  source(file.path(root, "pipeline", "tests", "testthat", "helper-temp-root.R"))
  source(file.path(root, "pipeline", "tests", "testthat", "helper-data-fixture.R"))
}))

CHECK_IDS <- c(
  "COVER.MISSING", "COVER.EXTRA", "COVER.WITHHELD_PRESENT", "COVER.MANIFEST",
  "COVER.SURVEY", "VALUE.NUMERIC", "VALUE.RANGE", "VALUE.STATUS_EMPTY",
  "VALUE.LEGACY_EMPTY", "VALUE.SE_CI", "VALUE.N"
)

# check_id -> function name, from the card's Interface section:
# "Your functions are named vc_cover_<check>(ctx) and vc_value_<check>(ctx)"
# and "check_id is COVER.<NAME> or VALUE.<NAME>".
vc_fn_name <- function(check_id) {
  parts <- strsplit(check_id, ".", fixed = TRUE)[[1]]
  prefix <- if (identical(parts[1], "COVER")) "cover" else "value"
  paste0("vc_", prefix, "_", tolower(parts[2]))
}

# Run every vc_cover_*/vc_value_* function named on the card against ctx and
# rbind their findings. A missing function or one that errors becomes a
# synthetic ERROR finding under its own check_id, so a single check() call
# sees a broken interface as a failure instead of crashing the script.
run_all_vc <- function(ctx) {
  parts <- lapply(CHECK_IDS, function(id) {
    nm <- vc_fn_name(id)
    if (!exists(nm, mode = "function")) {
      return(data.frame(check_id = id, severity = "ERROR", file = "", row_key = "",
                         message = paste("function not found:", nm), stringsAsFactors = FALSE))
    }
    fn <- get(nm, mode = "function")
    res <- tryCatch(as.data.frame(fn(ctx), stringsAsFactors = FALSE),
                     error = function(e) data.frame(check_id = id, severity = "ERROR", file = "",
                                                     row_key = "",
                                                     message = paste("error calling", nm, ":", conditionMessage(e)),
                                                     stringsAsFactors = FALSE))
    if (nrow(res) == 0) {
      res <- res[, c("check_id", "severity", "file", "row_key", "message"), drop = FALSE]
    }
    res
  })
  do.call(rbind, parts)
}

# A manifest in the contract's key/value shape (csv_headers.csv: columns
# key, value), not the wide one-row shape
# pipeline/tests/testthat/helper-data-fixture.R writes for
# "<stem>_manifest.csv" -- see this run's report, Questions section.
write_manifest_kv <- function(path, kv) {
  df <- data.frame(key = names(kv), value = unname(unlist(kv)), stringsAsFactors = FALSE)
  write_std_csv(df, path)
}
base_manifest_kv <- function(ref_area, time_period, file_name, n_rows, survey_id) {
  c(dataflow = DATAFLOW_ID, dsd_version = "TBD", metadata_version = "TBD",
    ref_area = ref_area, time_period = time_period, source_type = "SURVEY",
    survey_id = survey_id, precision = "ROUNDED_2DP", file_name = file_name,
    n_rows = as.character(n_rows), producer = "TBD", program = "TBD",
    software = "TBD", run_timestamp = "TBD", status = "DRAFT", notes = "")
}

## ---- 4. The shared GNB fixture -------------------------------------------------
# AGR_CULT_AREA (withheld cells exist for it, card Step 2/3) and
# EN_ELEC_ACCESS (a share, valid_min=0/valid_max=1 in CL_INDICATOR, needed
# to make "a share set to 1.3" an out-of-range value under WP12.A2).
tmp_root <- make_temp_root(root, include = "metadata")
raw_data_path <- make_data_fixture(tmp_root, "GNB", "2021",
                                    series_ids = c("AGR_CULT_AREA", "EN_ELEC_ACCESS"))
meta_fx <- load_metadata(tmp_root)
withheld_fx <- withheld_rows(meta_fx, "GNB", "2021")
stopifnot(nrow(withheld_fx) >= 1)

raw_data <- read_std_csv(raw_data_path)
clean_data <- dplyr::anti_join(raw_data, withheld_fx[KEY_COLUMNS], by = KEY_COLUMNS)

idx_agr <- which(clean_data$INDICATOR == "AGR_CULT_AREA")
idx_en <- which(clean_data$INDICATOR == "EN_ELEC_ACCESS")
stopifnot(length(idx_agr) >= 4, length(idx_en) >= 1)

clean_dir <- tempfile("wp12_clean_")
dir.create(clean_dir, recursive = TRUE)
clean_data_path <- file.path(clean_dir, basename(raw_data_path))
clean_manifest_path <- sub("\\.csv$", "_manifest.csv", clean_data_path)
write_std_csv(clean_data, clean_data_path)
write_manifest_kv(clean_manifest_path,
                   base_manifest_kv("GNB", "2021", basename(clean_data_path),
                                     nrow(clean_data), "GNB_EHCVM_2021"))

# Writes `d` (a mutated copy of clean_data) and a manifest that always
# agrees with `d`'s own row count, into a fresh temp dir, then builds ctx.
ctx_for_data <- function(d, manifest_kv_edit = identity) {
  dir <- tempfile("wp12_fx_")
  dir.create(dir, recursive = TRUE)
  dp <- file.path(dir, basename(raw_data_path))
  mp <- sub("\\.csv$", "_manifest.csv", dp)
  write_std_csv(d, dp)
  kv <- base_manifest_kv("GNB", "2021", basename(dp), nrow(d), "GNB_EHCVM_2021")
  kv <- manifest_kv_edit(kv)
  write_manifest_kv(mp, kv)
  build_ctx(tmp_root, data_files = dp)
}

error_ids <- function(fnd) sort(unique(fnd$check_id[fnd$severity == "ERROR"]))

ctx_clean <- ctx_for_data(clean_data)

## ---- WP12.A1 --------------------------------------------------------------------
try_check("WP12.A1", {
  fnd <- run_all_vc(ctx_clean)
  n_err <- sum(fnd$severity == "ERROR")
  check("WP12.A1", n_err == 0,
        sprintf("clean GNB fixture (%d rows): %d ERROR finding(s)%s", nrow(clean_data), n_err,
                if (n_err > 0) paste0(" [", paste(error_ids(fnd), collapse = ", "), "]") else ""))
})

## ---- WP12.A2 --------------------------------------------------------------------
mutations <- list(
  list(name = "row deleted", expect = "COVER.MISSING",
       fn = function(d) d[-idx_agr[1], ]),
  list(name = "row added, unplanned breakdown", expect = "COVER.EXTRA",
       fn = function(d) { row <- d[idx_agr[1], ]; row$COMP_BREAKDOWN_1 <- "BOGUS_CAT"; rbind(d, row) }),
  list(name = "withheld row added back", expect = "COVER.WITHHELD_PRESENT",
       fn = function(d) {
         wr <- withheld_fx[1, KEY_COLUMNS]
         wr$OBS_VALUE <- "0.5"; wr$OBS_STATUS <- "A"
         wr$STD_ERR <- ""; wr$CI_LOWER <- ""; wr$CI_UPPER <- ""
         wr$N_OBS <- ""; wr$N_POP <- ""; wr$OBS_COMMENT <- ""
         wr <- wr[DSD_COLUMNS]
         rbind(d, wr)
       }),
  list(name = "share set to 1.3", expect = "VALUE.RANGE",
       fn = function(d) { d$OBS_VALUE[idx_en[1]] <- "1.3"; d }),
  list(name = "value 1e-3", expect = "VALUE.NUMERIC",
       fn = function(d) { d$OBS_VALUE[idx_agr[2]] <- "1e-3"; d }),
  list(name = "O row with a value", expect = "VALUE.STATUS_EMPTY",
       fn = function(d) {
         i <- idx_agr[3]
         d$OBS_STATUS[i] <- "O"; d$OBS_VALUE[i] <- "0.5"; d$OBS_COMMENT[i] <- "LEGACY_EMPTY: test"
         d
       }),
  list(name = "A row without a value", expect = "VALUE.STATUS_EMPTY",
       fn = function(d) { i <- idx_agr[4]; d$OBS_STATUS[i] <- "A"; d$OBS_VALUE[i] <- ""; d }),
  list(name = "O row with an empty comment", expect = "VALUE.LEGACY_EMPTY",
       fn = function(d) {
         i <- idx_en[1]
         d$OBS_STATUS[i] <- "O"; d$OBS_VALUE[i] <- ""; d$OBS_COMMENT[i] <- ""
         d
       })
)

manifest_mutations <- list(
  list(name = "manifest n_rows changed", expect = "COVER.MANIFEST",
       fn = function(kv) { kv["n_rows"] <- as.character(as.integer(kv["n_rows"]) + 1); kv }),
  list(name = "manifest survey_id set to XXX", expect = "COVER.SURVEY",
       fn = function(kv) { kv["survey_id"] <- "XXX"; kv })
)

try_check("WP12.A2", {
  lines <- character(0)
  all_ok <- TRUE
  for (m in mutations) {
    d <- m$fn(clean_data)
    ctx <- ctx_for_data(d)
    got <- error_ids(run_all_vc(ctx))
    ok <- identical(got, m$expect)
    all_ok <- all_ok && ok
    lines <- c(lines, sprintf("%s: got {%s} want {%s} %s", m$name,
                               paste(got, collapse = ","), m$expect, if (ok) "OK" else "MISMATCH"))
  }
  for (m in manifest_mutations) {
    ctx <- ctx_for_data(clean_data, manifest_kv_edit = m$fn)
    got <- error_ids(run_all_vc(ctx))
    ok <- identical(got, m$expect)
    all_ok <- all_ok && ok
    lines <- c(lines, sprintf("%s: got {%s} want {%s} %s", m$name,
                               paste(got, collapse = ","), m$expect, if (ok) "OK" else "MISMATCH"))
  }
  check("WP12.A2", all_ok, paste(lines, collapse = " | "))
})

## ---- WP12.A3 --------------------------------------------------------------------
try_check("WP12.A3", {
  meta_real <- load_metadata(root)
  wh_gnb <- withheld_rows(meta_real, "GNB", "2021")
  wh_sen <- withheld_rows(meta_real, "SEN", "2021")
  req_gnb <- required_rows(meta_real, "GNB", "2021")
  n_wh_gnb <- nrow(wh_gnb)
  n_wh_sen <- nrow(wh_sen)
  n_data_gnb <- nrow(req_gnb) - n_wh_gnb
  ok <- meets(n_wh_gnb, "GNB.WITHHELD_CELLS") && n_wh_sen == 0 && meets(n_data_gnb, "GNB.DATA.ROWS")
  check("WP12.A3", ok,
        sprintf("withheld GNB=%d (want %s), withheld SEN=%d (want 0), required-withheld GNB=%d (want %s)",
                n_wh_gnb, expected("GNB.WITHHELD_CELLS")$value, n_wh_sen, n_data_gnb,
                expected("GNB.DATA.ROWS")$value))
})

## ---- WP12.A4 --------------------------------------------------------------------
try_check("WP12.A4", {
  ctx_empty <- build_ctx(root, data_files = character(0))
  fnd <- run_all_vc(ctx_empty)
  ok <- nrow(fnd) == 0
  check("WP12.A4", ok,
        sprintf("empty ctx$data: %d row(s) returned%s", nrow(fnd),
                if (!ok) paste0(" [", paste(unique(fnd$check_id), collapse = ", "), "]") else ""))
})

## ---- WP12.A5 --------------------------------------------------------------------
try_check("WP12.A5", {
  test_dir_path <- file.path(root, "pipeline", "tests", "testthat")
  res <- testthat::test_dir(test_dir_path, filter = "validate-coverage",
                             reporter = "silent", stop_on_failure = FALSE)
  df <- as.data.frame(res)
  ok <- nrow(df) > 0 && sum(df$failed) == 0 && !any(as.logical(df$error))
  check("WP12.A5", ok,
        sprintf("%d test(s) in test-validate-coverage.R: %d failed, %d errored",
                nrow(df), sum(df$failed), sum(as.logical(df$error))))
})

## ---- 5. Exit ----------------------------------------------------------------------
cat(if (length(.failures)) sprintf("\n%d check(s) failed: %s\n", length(.failures), paste(.failures, collapse = ", ")) else "\nAll checks passed.\n")
quit(status = if (length(.failures)) 1L else 0L, save = "no")
