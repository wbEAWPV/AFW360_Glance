#!/usr/bin/env Rscript
# Acceptance script for WP11 - Validator core: structure, codes, metadata.
#
#   Rscript pipeline/acceptance/wp11_validator-core.R --root .
#
# Every check exercises pipeline/validate.R (WP11's deliverable) as a black
# box, over a subprocess Rscript call, and reads its --out findings CSV with
# this script's own reader (read_csv_char() below) - never with WP11's own
# code. WP11.md has no numeric entries in contract/expected_counts.csv (all
# six checks are existence/exit-code checks), so none of the checks below
# look up a number there.
#
# To build valid data fixtures this script sources pipeline/R/io.R,
# constants.R, codes.R and plan.R, plus the two test helpers
# (helper-temp-root.R, helper-data-fixture.R). None of these are WP11's own
# deliverable (WP11 owns only pipeline/validate.R and pipeline/R/validate_*.R;
# see contract/output_ownership.csv) - they are the same pre-existing,
# already-merged fixture-building infrastructure the card's own "Steps"
# section tells the implementer to build its tests on. The functions under
# test (vc_* in validate_structure.R/validate_codes.R/validate_metadata.R,
# and validate.R's CLI) are never sourced; they are only ever invoked via a
# fresh `Rscript pipeline/validate.R ...` subprocess.

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
# All columns as character, BOM stripped, "" stays "" (never NA).
read_csv_char <- function(path) {
  raw <- readLines(path, encoding = "UTF-8", warn = FALSE)
  if (length(raw)) raw[1] <- sub("^﻿", "", raw[1])
  read.csv(text = paste(raw, collapse = "\n"), colClasses = "character", na.strings = NULL,
           check.names = FALSE, encoding = "UTF-8")
}

# --- Fixture-building infrastructure (COMMON.md section 5; not WP11's own
# code - see the header note above). Sourced once, used only to build inputs.
suppressPackageStartupMessages({
  source(file.path(root, "pipeline", "R", "io.R"))
  source(file.path(root, "pipeline", "R", "constants.R"))
  source(file.path(root, "pipeline", "R", "codes.R"))
  source(file.path(root, "pipeline", "R", "plan.R"))
  source(file.path(root, "pipeline", "tests", "testthat", "helper-temp-root.R"))
  source(file.path(root, "pipeline", "tests", "testthat", "helper-data-fixture.R"))
})

# helper-data-fixture.R's make_data_fixture() (owned by WP08, wave 2) writes
# the "<stem>_manifest.csv" beside the data file in WIDE form (one row, 16
# named columns). contract/csv_headers.csv defines that file as exactly two
# columns, "key" and "value" (one row per field), and pipeline/R/ctx.R's
# build_ctx() reads it that way. Left as WIDE, a manifest field such as
# "status" is never found, which silently breaks any check that reads it
# (observed: CODES.DRAFT gives ERROR instead of WARN on a manifest that says
# status = DRAFT). This is a pre-existing mismatch in wave-2 shared test
# infrastructure, not WP11's fault and not this script's to fix (see the
# verifier report's Questions section) - so every fixture built below is
# repaired to the contract's long form before use.
fix_manifest_long <- function(data_path) {
  mp <- file.path(dirname(data_path), paste0(tools::file_path_sans_ext(basename(data_path)), "_manifest.csv"))
  wide <- read_std_csv(mp)
  long <- data.frame(key = names(wide), value = as.character(unlist(wide[1, ])), stringsAsFactors = FALSE)
  write_std_csv(long, mp)
  invisible(mp)
}

# A root with metadata/content/geo/assets copied, plus a copy of pipeline/R
# (validate.R sources shared code as file.path(root,"pipeline","R",...), so
# a temp --root needs its own copy; COMMON.md section 5).
build_root_with_code <- function() {
  tmp <- make_temp_root(root)
  dir.create(file.path(tmp, "pipeline"), recursive = TRUE, showWarnings = FALSE)
  file.copy(file.path(root, "pipeline", "R"), file.path(tmp, "pipeline"), recursive = TRUE)
  tmp
}

# The full clean GNB/2021 fixture (every indicator required_rows() derives),
# used for WP11.A1 so nothing is trimmed out of SERIES_PLAN (trimming it, as
# the card's own series_ids= example does, orphans LEGACY_LABELS.series_id
# references and manufactures unrelated META.REFERENCE noise).
build_full_clean_root <- function() {
  tmp <- build_root_with_code()
  dp <- make_data_fixture(tmp, "GNB", series_ids = NULL)
  fix_manifest_long(dp)
  list(root = tmp, data_path = dp, data_rel = "data/AFW360_HH_GNB_2021.csv")
}

# A small (78-row), fast fixture over three indicators, exactly the set the
# card's Steps section 2 names, used as the base for WP11.A2/A3's mutations
# (which only need presence of one check_id, not an error-free baseline).
build_small_clean_root <- function() {
  tmp <- build_root_with_code()
  dp <- make_data_fixture(tmp, "GNB", series_ids = c(
    "POV_HC.POVLINE_PL420.PPP_2021", "POP_HH_SH.HE_COUNT_0", "CONS_SH.COICOP_CP01"
  ))
  fix_manifest_long(dp)
  list(root = tmp, data_path = dp, data_rel = "data/AFW360_HH_GNB_2021.csv")
}

copy_root <- function(src) {
  dst <- tempfile(pattern = "afw360_mut_")
  dir.create(dst)
  for (nm in list.files(src, all.files = FALSE)) file.copy(file.path(src, nm), dst, recursive = TRUE)
  dst
}

# Runs pipeline/validate.R (WP11's own CLI) as a subprocess. `root` is the
# --root passed to it (never this script's own sourcing); `data_rel` is a
# path *relative to that root* (validate.R joins --data onto --root).
run_validate <- function(vroot, data_rel = NULL, metadata_only = FALSE) {
  out <- tempfile(fileext = ".csv")
  a <- c(shQuote(file.path(root, "pipeline", "validate.R")), "--root", shQuote(vroot))
  if (metadata_only) a <- c(a, "--metadata-only")
  if (!is.null(data_rel)) a <- c(a, "--data", shQuote(data_rel))
  a <- c(a, "--out", shQuote(out))
  res <- system2("Rscript", a, stdout = TRUE, stderr = TRUE)
  status <- attr(res, "status"); if (is.null(status)) status <- 0L
  findings <- if (file.exists(out)) read_csv_char(out) else data.frame(
    check_id = character(0), severity = character(0), file = character(0),
    row_key = character(0), message = character(0)
  )
  list(status = as.integer(status), findings = findings, log = res)
}

err_ids <- function(findings) {
  if (!nrow(findings)) return(character(0))
  unique(findings$check_id[findings$severity == "ERROR"])
}

## ---- 3. Fixtures (built once) --------------------------------------------------
full_fixture <- build_full_clean_root()
small_fixture <- build_small_clean_root()

## ---- 4. Checks ------------------------------------------------------------------

## WP11.A1: on the clean fixture, validate.R exits 0 with 0 ERROR.
try_check("WP11.A1", {
  r1 <- run_validate(full_fixture$root, data_rel = full_fixture$data_rel)
  e1 <- err_ids(r1$findings)
  n_err <- if (nrow(r1$findings)) sum(r1$findings$severity == "ERROR") else 0L
  by_mod <- function(pfx) sum(grepl(paste0("^", pfx, "\\."), r1$findings$check_id[r1$findings$severity == "ERROR"]))
  check("WP11.A1", r1$status == 0L && n_err == 0L,
        sprintf("exit=%d ERROR rows=%d (STRUCT=%d CODES=%d META=%d) ids=%s - see report Questions for pre-existing metadata ERRORs",
                r1$status, n_err, by_mod("STRUCT"), by_mod("CODES"), by_mod("META"), paste(e1, collapse = "|")))
})
a1_findings <- if (exists("r1")) r1$findings else data.frame()

## WP11.A2: each mutation gives an ERROR with exactly its check_id, and exit 1.
mutations <- list(
  list(label = "Two data columns swapped", id = "STRUCT.HEADER", fn = function(df) {
    nm <- names(df); nm[17:18] <- nm[18:17]; names(df) <- nm; df
  }),
  list(label = "One GEO cell emptied", id = "STRUCT.EMPTY_KEY", fn = function(df) {
    df$GEO[1] <- ""; df
  }),
  list(label = "A row duplicated", id = "STRUCT.DUPLICATE_KEY", fn = function(df) {
    rbind(df, df[1, ])
  }),
  list(label = "GEO set to XX99", id = "CODES.UNKNOWN", fn = function(df) {
    df$GEO[1] <- "XX99"; df
  }),
  list(label = "GEO set to the country's ADM0 code", id = "CODES.GEO_ADM0", fn = function(df) {
    df$GEO[1] <- "GW"; df
  }),
  list(label = "A breakdown moved to slot 2 with slot 1 left _T", id = "CODES.BRK_SLOTS", fn = function(df) {
    i <- which(df$INDICATOR == "POP_HH_SH" & df$COMP_BREAKDOWN_1 == "HE_COUNT_0")[1]
    df$COMP_BREAKDOWN_2[i] <- df$COMP_BREAKDOWN_1[i]; df$COMP_BREAKDOWN_1[i] <- "_T"; df
  }),
  list(label = "SEX = _T on a row of an HH indicator", id = "CODES.SEX_AGE_UNIT", fn = function(df) {
    i <- which(df$INDICATOR == "CONS_SH")[1]; df$SEX[i] <- "_T"; df
  }),
  list(label = "MEASURE_QUAL_2 of a POVLINE_PL420 row set to PPP_2017", id = "CODES.VALID_WITH", fn = function(df) {
    i <- which(df$INDICATOR == "POV_HC" & df$MEASURE_QUAL_1 == "POVLINE_PL420")[1]
    df$MEASURE_QUAL_2[i] <- "PPP_2017"; df
  }),
  list(label = "COICOP_CP01 added to a POV_HC row", id = "CODES.QUAL_DECLARED", fn = function(df) {
    i <- which(df$INDICATOR == "POV_HC")[1]; df$MEASURE_QUAL_3[i] <- "COICOP_CP01"; df
  }),
  list(label = "A 33-character code in CL_THEME", id = "META.CODE_SYNTAX", meta = "codelists/CL_THEME.csv", fn = function(df) {
    pad <- paste(rep("Z", 33 - nchar(df$code[1])), collapse = ""); df$code[1] <- paste0(df$code[1], pad); df
  }),
  list(label = "A parent that does not exist, in CL_URBANISATION", id = "META.REFERENCE", meta = "codelists/CL_URBANISATION.csv", fn = function(df) {
    df$parent[1] <- "ZZZZ_NOPE"; df
  }),
  list(label = "A row of CL_THEME set to ACTIVE with definition_en = TBD", id = "META.TBD", meta = "codelists/CL_THEME.csv", fn = function(df) {
    df$status[1] <- "ACTIVE"; df$definition_en[1] <- "TBD"; df
  })
)

try_check("WP11.A2", {
  results <- vapply(mutations, function(m) {
    d <- copy_root(small_fixture$root)
    if (is.null(m$meta)) {
      edit_csv(file.path(d, "data", "AFW360_HH_GNB_2021.csv"), m$fn)
      r <- run_validate(d, data_rel = "data/AFW360_HH_GNB_2021.csv")
    } else {
      edit_csv(file.path(d, "metadata", m$meta), m$fn)
      r <- run_validate(d, data_rel = "data/AFW360_HH_GNB_2021.csv")
    }
    ok <- r$status == 1L && (m$id %in% err_ids(r$findings))
    ok
  }, logical(1))
  names(results) <- vapply(mutations, function(m) m$id, character(1))
  bad <- names(results)[!results]
  check("WP11.A2", all(results),
        sprintf("%d/%d mutations caught with exit=1 and their check_id present; failing: %s",
                sum(results), length(results), if (length(bad)) paste(bad, collapse = ", ") else "none"))
})

## WP11.A3: a check function that calls stop() gives exit 2 and a finding
## <MODULE>.CRASH; the other checks still run (proven by also mutating GEO).
try_check("WP11.A3", {
  d3 <- copy_root(small_fixture$root)
  writeLines(c(
    "vc_zzz_forcedcrash <- function(ctx) {",
    "  stop(\"forced crash for WP11.A3\")",
    "}"
  ), file.path(d3, "pipeline", "R", "validate_zzz_crash.R"))
  edit_csv(file.path(d3, "data", "AFW360_HH_GNB_2021.csv"), function(df) { df$GEO[1] <- "XX99"; df })
  r3 <- run_validate(d3, data_rel = "data/AFW360_HH_GNB_2021.csv")
  crash_rows <- if (nrow(r3$findings)) r3$findings[grepl("\\.CRASH$", r3$findings$check_id), ] else r3$findings[0, ]
  has_crash <- nrow(crash_rows) >= 1 &&
    any(grepl("vc_zzz_forcedcrash", crash_rows$message)) &&
    any(grepl("forced crash for WP11.A3", crash_rows$message))
  others_ran <- "CODES.UNKNOWN" %in% err_ids(r3$findings)
  check("WP11.A3", r3$status == 2L && has_crash && others_ran,
        sprintf("exit=%d crash finding(s)=%d naming function+message=%s CODES.UNKNOWN still ran=%s",
                r3$status, nrow(crash_rows), has_crash, others_ran))
})

## WP11.A4: the findings file has exactly the columns check_id, severity,
## file, row_key, message (checked on WP11.A1's own findings file).
try_check("WP11.A4", {
  want <- c("check_id", "severity", "file", "row_key", "message")
  got <- names(a1_findings)
  check("WP11.A4", identical(got, want), sprintf("columns = %s", paste(got, collapse = ",")))
})

## WP11.A5: validate.R --metadata-only on the real metadata gives 0 ERROR
## from STRUCT, CODES and META, or every such ERROR is listed in the
## implementer's report as a metadata defect (file, row, rule). This check
## only verifies the report *mentions* each affected file (a formal,
## syntactic reading); whether the metadata is really wrong or the check is
## wrong is judged by hand per the card's "Verifier focus" (see the
## verifier's report), not by this script.
try_check("WP11.A5", {
  r5 <- run_validate(root, metadata_only = TRUE)
  core <- if (nrow(r5$findings)) {
    r5$findings[r5$findings$severity == "ERROR" & grepl("^(STRUCT|CODES|META)\\.", r5$findings$check_id), ]
  } else r5$findings[0, ]
  if (nrow(core) == 0) {
    check("WP11.A5", TRUE, sprintf("exit=%d, 0 ERROR from STRUCT/CODES/META on the real metadata", r5$status))
  } else {
    report_path <- file.path(root, ".docs", "transition", "reports", "WP11-implementer.md")
    report_txt <- if (file.exists(report_path)) paste(readLines(report_path, warn = FALSE), collapse = "\n") else ""
    files_affected <- unique(core$file)
    documented <- vapply(files_affected, function(f) grepl(f, report_txt, fixed = TRUE), logical(1))
    check("WP11.A5", file.exists(report_path) && all(documented),
          sprintf("%d ERROR rows from STRUCT/CODES/META; files=%s; documented in WP11-implementer.md=%s",
                  nrow(core), paste(files_affected, collapse = "|"), paste(documented, collapse = ",")))
  }
})

## WP11.A6: the unit tests pass.
try_check("WP11.A6", {
  # A temp runner file (not an -e string) avoids Windows path backslashes
  # being misread as R string escapes; --root is passed as a plain argument.
  runner6 <- tempfile(fileext = ".R")
  writeLines(c(
    "args <- commandArgs(trailingOnly = TRUE)",
    "i <- which(args == '--root')",
    "r <- args[i + 1]",
    "setwd(r)",
    "testthat::test_dir('pipeline/tests/testthat', stop_on_failure = TRUE, reporter = 'summary')"
  ), runner6)
  log6 <- tempfile(fileext = ".log")
  res6 <- system2("Rscript", c(shQuote(runner6), "--root", shQuote(root)), stdout = log6, stderr = log6)
  ok6 <- identical(as.integer(res6), 0L)
  tail6 <- tail(readLines(log6, warn = FALSE), 15)
  check("WP11.A6", ok6, sprintf("testthat::test_dir exit=%s; last lines: %s", res6, paste(tail6, collapse = " / ")))
})

## ---- 5. Exit ----------------------------------------------------------------------
cat(if (length(.failures)) sprintf("\n%d check(s) failed: %s\n", length(.failures), paste(.failures, collapse = ", ")) else "\nAll checks passed.\n")
quit(status = if (length(.failures)) 1L else 0L, save = "no")
