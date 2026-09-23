#!/usr/bin/env Rscript
# Acceptance script for WP12 -- Validator: coverage and values.
#
#   Rscript pipeline/acceptance/wp12_validator-coverage.R --root .
#
# Rules: standalone; expected numbers come from contract/expected_counts.csv;
# writes only to tempdir(); compares against the tag transition-base and
# against files, never against transition/main or the branch diff.

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

## ---- 3. Module setup -----------------------------------------------------------
# These checks are about the functions in plan.R, validate_coverage.R and
# validate_values.R, so sourcing pipeline/R/ is in scope for this card.
pr <- function(...) file.path(root, "pipeline", "R", ...)
source(pr("constants.R"))
source(pr("io.R"))
source(pr("codes.R"))     # plan.R depends on slot_sort()/fill_slots() from codes.R
source(pr("ctx.R"))
source(pr("plan.R"))
source(file.path(root, "pipeline", "tests", "testthat", "helper-temp-root.R"))
source(file.path(root, "pipeline", "tests", "testthat", "helper-data-fixture.R"))

vc_env <- new.env()
sys.source(pr("validate_coverage.R"), envir = vc_env)
sys.source(pr("validate_values.R"), envir = vc_env)
vc_fun_names <- sort(ls(vc_env, pattern = "^vc_(cover|value)_"))

# Run every vc_cover_*/vc_value_* function on ctx and row-bind the findings.
run_all_checks <- function(ctx) {
  out <- lapply(vc_fun_names, function(fn) {
    res <- get(fn, envir = vc_env)(ctx)
    if (is.null(res) || nrow(res) == 0) return(NULL)
    as.data.frame(res, stringsAsFactors = FALSE)
  })
  out <- out[!vapply(out, is.null, logical(1))]
  if (!length(out)) {
    return(data.frame(check_id = character(0), severity = character(0), file = character(0),
                       row_key = character(0), message = character(0)))
  }
  do.call(rbind, out)
}

KEY_COLS <- c("DATAFLOW", "REF_AREA", "GEO", "TIME_PERIOD", "INDICATOR", "SEX", "AGE",
              "URBANISATION", paste0("COMP_BREAKDOWN_", 1:5), paste0("MEASURE_QUAL_", 1:5))

# Build a clean GNB fixture (temp dir): every required row for two series
# (AGR_CULT_AREA, which has withheld cells, and a share series), minus the
# withheld rows -- so it should validate with zero ERROR findings. Returns a
# list with tmp root, data-file path, manifest path and the withheld-row table.
build_clean_fixture <- function() {
  tmp <- make_temp_root(root)
  fx <- make_data_fixture(tmp, "GNB", series_ids = c("AGR_CULT_AREA", "POP_HH_SH.HE_COUNT_0"))
  mf <- sub("[.]csv$", "_manifest.csv", fx)
  meta <- load_metadata(tmp)
  wh <- vc_env$withheld_rows(meta, "GNB", "2021")
  d <- read.csv(fx, colClasses = "character", na.strings = NULL)
  d_clean <- dplyr::anti_join(d, wh[KEY_COLS], by = KEY_COLS)
  write_std_csv(d_clean, fx)
  m <- read.csv(mf, colClasses = "character", na.strings = NULL)
  m$value[m$key == "n_rows"] <- as.character(nrow(d_clean))
  # SURVEYS.csv carries GNB_EHCVM_2021 for GNB/2021 (see metadata/surveys/SURVEYS.csv);
  # give the fixture a real survey_id so the clean baseline has no COVER.SURVEY finding.
  m$value[m$key == "survey_id"] <- "GNB_EHCVM_2021"
  write_std_csv(m, mf)
  list(tmp = tmp, fx = fx, mf = mf, wh = wh)
}

# Apply one mutation to a fresh clean fixture and return the ERROR check_ids found.
mutation_error_ids <- function(mutate_fn) {
  cl <- build_clean_fixture()
  mutate_fn(cl)
  ctx <- build_ctx(cl$tmp, data_files = cl$fx)
  res <- run_all_checks(ctx)
  unique(res$check_id[res$severity == "ERROR"])
}

## ---- 4. Checks ------------------------------------------------------------------

## WP12.A1: on the clean fixture, the functions return 0 ERROR.
try_check("WP12.A1", {
  cl <- build_clean_fixture()
  ctx <- build_ctx(cl$tmp, data_files = cl$fx)
  res <- run_all_checks(ctx)
  n_error <- sum(res$severity == "ERROR")
  check("WP12.A1", n_error == 0,
        sprintf("clean GNB fixture (%d rows): %d ERROR findings", nrow(read.csv(cl$fx, colClasses = "character", na.strings = NULL)), n_error))
})

## WP12.A2: each mutation gives exactly its check_id.
try_check("WP12.A2", {
  mutations <- list(
    "COVER.MISSING" = function(cl) {
      d <- read.csv(cl$fx, colClasses = "character", na.strings = NULL)
      d2 <- d[-1, ]
      write_std_csv(d2, cl$fx)
      m <- read.csv(cl$mf, colClasses = "character", na.strings = NULL)
      m$value[m$key == "n_rows"] <- as.character(nrow(d2))
      write_std_csv(m, cl$mf)
    },
    "COVER.EXTRA" = function(cl) {
      d <- read.csv(cl$fx, colClasses = "character", na.strings = NULL)
      newrow <- d[1, ]
      newrow$GEO <- "ZZZ"  # not a code any required row of this cut uses
      d2 <- rbind(d, newrow)
      write_std_csv(d2, cl$fx)
      m <- read.csv(cl$mf, colClasses = "character", na.strings = NULL)
      m$value[m$key == "n_rows"] <- as.character(nrow(d2))
      write_std_csv(m, cl$mf)
    },
    "COVER.WITHHELD_PRESENT" = function(cl) {
      d <- read.csv(cl$fx, colClasses = "character", na.strings = NULL)
      wrow <- cl$wh[1, intersect(names(d), names(cl$wh))]
      full <- d[1, ]
      for (nm in names(wrow)) full[[nm]] <- wrow[[nm]]
      full$OBS_VALUE <- "0.5"; full$OBS_STATUS <- "A"; full$OBS_COMMENT <- ""
      full$STD_ERR <- ""; full$CI_LOWER <- ""; full$CI_UPPER <- ""
      full$N_OBS <- ""; full$N_POP <- ""
      d2 <- rbind(d, full)
      write_std_csv(d2, cl$fx)
      m <- read.csv(cl$mf, colClasses = "character", na.strings = NULL)
      m$value[m$key == "n_rows"] <- as.character(nrow(d2))
      write_std_csv(m, cl$mf)
    },
    "COVER.MANIFEST" = function(cl) {
      m <- read.csv(cl$mf, colClasses = "character", na.strings = NULL)
      m$value[m$key == "n_rows"] <- as.character(as.integer(m$value[m$key == "n_rows"]) + 5L)
      write_std_csv(m, cl$mf)
    },
    "COVER.SURVEY" = function(cl) {
      m <- read.csv(cl$mf, colClasses = "character", na.strings = NULL)
      m$value[m$key == "survey_id"] <- "XXX"
      write_std_csv(m, cl$mf)
    },
    "VALUE.RANGE" = function(cl) {
      d <- read.csv(cl$fx, colClasses = "character", na.strings = NULL)
      idx <- which(d$INDICATOR == "POP_HH_SH")[1]
      d$OBS_VALUE[idx] <- "1.3"
      write_std_csv(d, cl$fx)
    },
    "VALUE.NUMERIC" = function(cl) {
      d <- read.csv(cl$fx, colClasses = "character", na.strings = NULL)
      idx <- which(d$INDICATOR == "AGR_CULT_AREA")[1]
      d$OBS_VALUE[idx] <- "1e-3"
      write_std_csv(d, cl$fx)
    },
    "VALUE.STATUS_EMPTY (O with value)" = function(cl) {
      d <- read.csv(cl$fx, colClasses = "character", na.strings = NULL)
      d$OBS_STATUS[1] <- "O"
      d$OBS_COMMENT[1] <- "LEGACY_EMPTY: dummy"  # keep LEGACY_EMPTY silent for this case
      write_std_csv(d, cl$fx)
    },
    "VALUE.STATUS_EMPTY (A without value)" = function(cl) {
      d <- read.csv(cl$fx, colClasses = "character", na.strings = NULL)
      d$OBS_VALUE[1] <- ""
      write_std_csv(d, cl$fx)
    },
    "VALUE.LEGACY_EMPTY" = function(cl) {
      d <- read.csv(cl$fx, colClasses = "character", na.strings = NULL)
      d$OBS_STATUS[1] <- "O"
      d$OBS_VALUE[1] <- ""
      d$OBS_COMMENT[1] <- ""
      write_std_csv(d, cl$fx)
    }
  )
  expected_ids <- sub(" \\(.*\\)$", "", names(mutations))
  actual <- Map(function(label, fn) mutation_error_ids(fn), names(mutations), mutations)
  ok_each <- mapply(function(exp_id, act_ids) identical(act_ids, exp_id), expected_ids, actual)
  bad <- names(mutations)[!ok_each]
  evidence <- paste(sprintf("%s -> {%s}", names(mutations), vapply(actual, paste, character(1), collapse = ",")), collapse = "; ")
  check("WP12.A2", all(ok_each), if (length(bad)) sprintf("mismatches: %s | %s", paste(bad, collapse = ", "), evidence) else evidence)
})

## WP12.A3: withheld_rows() on the real metadata, and required - withheld == GNB.DATA.ROWS.
try_check("WP12.A3", {
  meta_real <- load_metadata(root)
  wh_gnb <- vc_env$withheld_rows(meta_real, "GNB", "2021")
  wh_sen <- vc_env$withheld_rows(meta_real, "SEN", "2021")
  rr_gnb <- required_rows(meta_real, "GNB", "2021")
  net <- nrow(rr_gnb) - nrow(wh_gnb)
  ok <- meets(nrow(wh_gnb), "GNB.WITHHELD_CELLS") && nrow(wh_sen) == 0 && meets(net, "GNB.DATA.ROWS")
  check("WP12.A3", ok,
        sprintf("GNB withheld=%d (expect %s), SEN withheld=%d (expect 0), required-withheld=%d (expect %s)",
                nrow(wh_gnb), expected("GNB.WITHHELD_CELLS")$value, nrow(wh_sen), net, expected("GNB.DATA.ROWS")$value))
})

## WP12.A4: with ctx$data empty, every function returns zero rows and does not fail.
try_check("WP12.A4", {
  tmp <- make_temp_root(root)
  ctx <- build_ctx(tmp, data_files = character(0))
  ok <- length(ctx$data) == 0
  errs <- character(0)
  for (fn in vc_fun_names) {
    res <- tryCatch(get(fn, envir = vc_env)(ctx), error = function(e) { errs[[length(errs) + 1]] <<- fn; NULL })
    if (!is.null(res) && nrow(res) != 0) { ok <- FALSE }
  }
  check("WP12.A4", ok && length(errs) == 0,
        sprintf("ctx$data empty=%s, functions erroring=%s, all zero rows=%s", length(ctx$data) == 0, paste(errs, collapse = ","), ok))
})

## WP12.A5: the unit tests pass.
try_check("WP12.A5", {
  suppressPackageStartupMessages(library(testthat))
  res <- test_dir(file.path(root, "pipeline", "tests", "testthat"),
                   filter = "validate-coverage", reporter = "silent", stop_on_failure = FALSE)
  df <- as.data.frame(res)
  n_fail <- sum(df$failed) + sum(df$error)
  check("WP12.A5", nrow(df) > 0 && n_fail == 0,
        sprintf("test-validate-coverage.R: %d test blocks, %d failed/errored", nrow(df), n_fail))
})

## ---- 5. Exit ----------------------------------------------------------------------
cat(if (length(.failures)) sprintf("\n%d check(s) failed: %s\n", length(.failures), paste(.failures, collapse = ", ")) else "\nAll checks passed.\n")
quit(status = if (length(.failures)) 1L else 0L, save = "no")
