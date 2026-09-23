# pipeline/tests/testthat/test-validate-core.R
#
# WP11: tests for the validator's entry point and the STRUCT/CODES/META
# modules. Sources the shared pipeline code and the three modules directly
# (helper-temp-root.R and helper-data-fixture.R are auto-sourced by
# testthat). Most tests build a temporary root with make_temp_root(), add a
# small data fixture with make_data_fixture() (real, merged wave-2
# metadata; see WP11.md step 2), apply one mutation with edit_csv(), and
# call the relevant vc_*() function(s) directly against a ctx built with
# build_ctx() -- this is faster and more precise than shelling out to
# validate.R for every case. The CLI contract itself (exit codes, the
# --metadata-only/--data flags, the crash path, the findings file shape)
# is exercised by running pipeline/validate.R as a real Rscript subprocess.

.root <- find_root()
source(file.path(.root, "pipeline", "R", "io.R"))
source(file.path(.root, "pipeline", "R", "constants.R"))
source(file.path(.root, "pipeline", "R", "codes.R"))
source(file.path(.root, "pipeline", "R", "ctx.R"))
source(file.path(.root, "pipeline", "R", "plan.R"))
source(file.path(.root, "pipeline", "R", "validate_structure.R"))
source(file.path(.root, "pipeline", "R", "validate_codes.R"))
source(file.path(.root, "pipeline", "R", "validate_metadata.R"))

# ---- local test helpers -----------------------------------------------

#' Run every discovered vc_*() check against ctx and return one combined
#' findings tibble (mirrors validate.R's discovery, without the CLI/cap
#' machinery).
.run_all_checks <- function(ctx) {
  check_names <- sort(ls(pattern = "^vc_", envir = .GlobalEnv))
  out <- lapply(check_names, function(nm) get(nm, envir = .GlobalEnv)(ctx))
  dplyr::bind_rows(out)
}

#' Build a small clean data fixture (the three series named on the card)
#' under a fresh temp root, with a correct manifest, and return list(tmp=,
#' data_path=). SERIES_PLAN is trimmed to those three series (via
#' make_data_fixture()'s own series_ids filtering); LEGACY_LABELS is
#' trimmed to match so META.REFERENCE does not flag the series_ids that
#' filtering removed. (`metadata/structure/COLUMNS.csv` now marks
#' LEGACY_LABELS.csv's `scale` column `status=C`, not `R` -- WP03 patch
#' p1 -- so its 88 blank `scale` cells no longer trip META.REQUIRED and
#' need no fixture patch.) make_data_fixture() writes the manifest in the
#' contract's long key/value form (WP08's fix to helper-data-fixture.R),
#' matching what build_ctx() reads, so no repair is needed here.
.small_fixture <- function() {
  tmp <- make_temp_root(.root)
  keep_ids <- c("POV_HC.POVLINE_PL420.PPP_2021", "POP_HH_SH.HE_COUNT_0", "CONS_SH.COICOP_CP01")
  dp <- make_data_fixture(tmp, "GNB", series_ids = keep_ids)
  edit_csv(file.path(tmp, "metadata", "plans", "LEGACY_LABELS.csv"), function(df) {
    df[trimws(df$series_id) == "" | df$series_id %in% keep_ids, , drop = FALSE]
  })
  list(tmp = tmp, data_path = dp)
}

#' The check_ids of every ERROR-severity finding, unique and sorted.
.error_ids <- function(findings) {
  sort(unique(findings$check_id[findings$severity == "ERROR"]))
}

# ---- clean fixture: WP11.A1 (spirit, for STRUCT/CODES) -----------------

test_that("the small clean fixture gives 0 ERROR from STRUCT and CODES", {
  fx <- .small_fixture()
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  findings <- .run_all_checks(ctx)
  struct_codes <- findings[grepl("^(STRUCT|CODES)\\.", findings$check_id), ]
  expect_equal(nrow(struct_codes[struct_codes$severity == "ERROR", ]), 0)
})

test_that("validate.R on the clean full fixture exits 0 with 0 ERROR (WP11.A1)", {
  # --root also has to resolve pipeline/R/*.R (COMMON.md section 5), so
  # the temp copy needs "pipeline" alongside the metadata/content/data it
  # is testing.
  tmp <- make_temp_root(.root, include = c("metadata", "content", "data", "pipeline"))
  dp <- make_data_fixture(tmp, "GNB")

  out_path <- file.path(tmp, "findings.csv")
  res <- system2(
    "Rscript",
    c(shQuote(file.path(tmp, "pipeline", "validate.R")), "--root", shQuote(tmp), "--out", shQuote(out_path)),
    stdout = TRUE, stderr = TRUE
  )
  status <- attr(res, "status")
  status <- if (is.null(status)) 0L else status
  expect_equal(status, 0L)
  expect_true(file.exists(out_path))
  findings <- read_std_csv(out_path)
  expect_equal(nrow(findings[findings$severity == "ERROR", ]), 0)
})

# ---- WP11.A2: one mutation per test, assert exactly its check_id -------

test_that("two data columns swapped gives STRUCT.HEADER", {
  fx <- .small_fixture()
  edit_csv(fx$data_path, function(df) {
    nm <- names(df)
    i <- match("REF_AREA", nm)
    j <- match("GEO", nm)
    nm[c(i, j)] <- nm[c(j, i)]
    names(df) <- nm
    df
  })
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  findings <- .run_all_checks(ctx)
  expect_equal(.error_ids(findings), "STRUCT.HEADER")
})

test_that("one GEO cell emptied gives STRUCT.EMPTY_KEY", {
  fx <- .small_fixture()
  edit_csv(fx$data_path, function(df) {
    df$GEO[1] <- ""
    df
  })
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  findings <- .run_all_checks(ctx)
  expect_equal(.error_ids(findings), "STRUCT.EMPTY_KEY")
})

test_that("a duplicated row gives STRUCT.DUPLICATE_KEY", {
  fx <- .small_fixture()
  edit_csv(fx$data_path, function(df) rbind(df, df[1, ]))
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  findings <- .run_all_checks(ctx)
  expect_equal(.error_ids(findings), "STRUCT.DUPLICATE_KEY")
})

test_that("GEO set to XX99 gives CODES.UNKNOWN", {
  fx <- .small_fixture()
  edit_csv(fx$data_path, function(df) {
    df$GEO[1] <- "XX99"
    df
  })
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  findings <- .run_all_checks(ctx)
  expect_equal(.error_ids(findings), "CODES.UNKNOWN")
})

test_that("GEO set to the country's ADM0 code gives CODES.GEO_ADM0", {
  fx <- .small_fixture()
  edit_csv(fx$data_path, function(df) {
    idx <- which(df$REF_AREA == "GNB")[1]
    df$GEO[idx] <- "GW" # GNB's ADM0 (geometry-only) code, from CL_GEO
    df
  })
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  findings <- .run_all_checks(ctx)
  expect_equal(.error_ids(findings), "CODES.GEO_ADM0")
})

test_that("a breakdown moved to slot 2 with slot 1 left _T gives CODES.BRK_SLOTS", {
  fx <- .small_fixture()
  edit_csv(fx$data_path, function(df) {
    idx <- which(df$COMP_BREAKDOWN_1 != "_T")[1]
    df$COMP_BREAKDOWN_2[idx] <- df$COMP_BREAKDOWN_1[idx]
    df$COMP_BREAKDOWN_1[idx] <- "_T"
    df
  })
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  findings <- .run_all_checks(ctx)
  expect_equal(.error_ids(findings), "CODES.BRK_SLOTS")
})

test_that("SEX = _T on a row of an HH indicator gives CODES.SEX_AGE_UNIT", {
  fx <- .small_fixture()
  edit_csv(fx$data_path, function(df) {
    idx <- which(df$INDICATOR == "CONS_SH")[1] # CONS_SH has stat_unit HH
    df$SEX[idx] <- "_T"
    df
  })
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  findings <- .run_all_checks(ctx)
  expect_equal(.error_ids(findings), "CODES.SEX_AGE_UNIT")
})

test_that("MEASURE_QUAL_2 of a POVLINE_PL420 row set to PPP_2017 gives CODES.VALID_WITH", {
  fx <- .small_fixture()
  # Also set COMP_BREAKDOWN_1 to POOR_Y so the row is granted PPP/POVLINE
  # via CL_BRK_VAR.requires_qual, isolating VALID_WITH from QUAL_DECLARED
  # (POV_HC's own `qualifiers` field declares only PPP_2021).
  edit_csv(fx$data_path, function(df) {
    idx <- which(
      df$INDICATOR == "POV_HC" & df$MEASURE_QUAL_1 == "POVLINE_PL420" &
        df$MEASURE_QUAL_2 == "PPP_2021" & df$COMP_BREAKDOWN_1 == "_T"
    )[1]
    df$COMP_BREAKDOWN_1[idx] <- "POOR_Y"
    df$MEASURE_QUAL_2[idx] <- "PPP_2017"
    df
  })
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  findings <- .run_all_checks(ctx)
  expect_equal(.error_ids(findings), "CODES.VALID_WITH")
})

test_that("COICOP_CP01 added to a POV_HC row gives CODES.QUAL_DECLARED", {
  fx <- .small_fixture()
  edit_csv(fx$data_path, function(df) {
    idx <- which(
      df$INDICATOR == "POV_HC" & df$MEASURE_QUAL_1 == "POVLINE_PL420" &
        df$MEASURE_QUAL_2 == "PPP_2021" & df$COMP_BREAKDOWN_1 == "_T"
    )[1]
    df$MEASURE_QUAL_3[idx] <- "COICOP_CP01" # slot_order(COICOP)=40 > PPP's 30: still left-packed
    df
  })
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  findings <- .run_all_checks(ctx)
  expect_equal(.error_ids(findings), "CODES.QUAL_DECLARED")
})

# ---- extra coverage for the checks not in the WP11.A2 table ------------

test_that("a valid CL_GEO code of the wrong REF_AREA gives CODES.GEO_AREA", {
  fx <- .small_fixture()
  edit_csv(fx$data_path, function(df) {
    idx <- which(df$REF_AREA == "GNB")[1]
    df$GEO[idx] <- "SN01" # a real CL_GEO code, but of SEN, not GNB
    df
  })
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  findings <- .run_all_checks(ctx)
  expect_equal(.error_ids(findings), "CODES.GEO_AREA")
})

test_that("a qualifier used out of slot_order gives CODES.QUAL_SLOTS", {
  fx <- .small_fixture()
  edit_csv(fx$data_path, function(df) {
    idx <- which(
      df$INDICATOR == "POV_HC" & df$MEASURE_QUAL_1 == "POVLINE_PL420" &
        df$MEASURE_QUAL_2 == "PPP_2021"
    )[1]
    df$MEASURE_QUAL_1[idx] <- "PPP_2021" # slot_order(PPP)=30 ahead of POVLINE's 20
    df$MEASURE_QUAL_2[idx] <- "POVLINE_PL420"
    df
  })
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  findings <- .run_all_checks(ctx)
  expect_equal(.error_ids(findings), "CODES.QUAL_SLOTS")
})

test_that("a breakdown code that does not apply to the indicator's stat_unit gives CODES.BRK_UNIT", {
  fx <- .small_fixture()
  edit_csv(fx$data_path, function(df) {
    # CONS_SH has stat_unit HH; EMP_STATUS_* breakdowns apply only to IND.
    idx <- which(df$INDICATOR == "CONS_SH" & df$COMP_BREAKDOWN_1 == "_T")[1]
    df$COMP_BREAKDOWN_1[idx] <- "EMP_STATUS_EMPLOYED"
    df
  })
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  findings <- .run_all_checks(ctx)
  expect_equal(.error_ids(findings), "CODES.BRK_UNIT")
})

test_that("a 33-character code in CL_THEME gives META.CODE_SYNTAX", {
  tmp <- make_temp_root(.root)
  # INEQ is not referenced by CL_INDICATOR.theme or anywhere else, so
  # renaming it cannot also break META.REFERENCE.
  edit_csv(file.path(tmp, "metadata", "codelists", "CL_THEME.csv"), function(df) {
    df$code[df$code == "INEQ"] <- paste(rep("A", 33), collapse = "")
    df
  })
  ctx <- build_ctx(tmp)
  findings <- .run_all_checks(ctx)
  expect_equal(.error_ids(findings), "META.CODE_SYNTAX")
})

test_that("a duplicated code within a file gives META.CODE_UNIQUE", {
  tmp <- make_temp_root(.root)
  # JOB and INEQ are both unused themes (not referenced by CL_INDICATOR.theme
  # or anywhere else), so colliding them cannot also break META.REFERENCE.
  edit_csv(file.path(tmp, "metadata", "codelists", "CL_THEME.csv"), function(df) {
    df$code[df$code == "JOB"] <- "INEQ"
    df
  })
  ctx <- build_ctx(tmp)
  findings <- .run_all_checks(ctx)
  expect_equal(.error_ids(findings), "META.CODE_UNIQUE")
})

test_that("a renamed column header gives META.HEADER", {
  tmp <- make_temp_root(.root)
  edit_csv(file.path(tmp, "metadata", "codelists", "CL_UNIT.csv"), function(df) {
    names(df)[names(df) == "notes"] <- "note"
    df
  })
  ctx <- build_ctx(tmp)
  findings <- .run_all_checks(ctx)
  expect_equal(.error_ids(findings), "META.HEADER")
})

test_that("a parent that does not exist in CL_URBANISATION gives META.REFERENCE", {
  tmp <- make_temp_root(.root)
  edit_csv(file.path(tmp, "metadata", "codelists", "CL_URBANISATION.csv"), function(df) {
    df$parent[df$code == "CAP"] <- "ZZZ_NOPE"
    df
  })
  ctx <- build_ctx(tmp)
  findings <- .run_all_checks(ctx)
  expect_equal(.error_ids(findings), "META.REFERENCE")
})

test_that("a CL_THEME row set to ACTIVE with definition_en = TBD gives META.TBD (ERROR)", {
  tmp <- make_temp_root(.root)
  edit_csv(file.path(tmp, "metadata", "codelists", "CL_THEME.csv"), function(df) {
    df$status[1] <- "ACTIVE"
    df$definition_en[1] <- "TBD"
    df
  })
  ctx <- build_ctx(tmp)
  findings <- .run_all_checks(ctx)
  expect_equal(.error_ids(findings), "META.TBD")
  hit <- findings[findings$check_id == "META.TBD" & findings$severity == "ERROR", ]
  expect_true(nrow(hit) >= 1)
})

# ---- WP11.A3: a crashing check gives exit 2 and <MODULE>.CRASH ---------

test_that("a check that calls stop() gives exit 2, <MODULE>.CRASH, and other checks still run", {
  tmp <- make_temp_root(.root, include = c("metadata", "content", "pipeline"))
  crash_file <- file.path(tmp, "pipeline", "R", "validate_zzzcrash.R")
  writeLines('vc_zzz_boom <- function(ctx) stop("boom from a test check")', crash_file)

  out_path <- file.path(tmp, "findings.csv")
  res <- suppressWarnings(system2(
    "Rscript",
    c(
      shQuote(file.path(tmp, "pipeline", "validate.R")), "--root", shQuote(tmp),
      "--metadata-only", "--out", shQuote(out_path)
    ),
    stdout = TRUE, stderr = TRUE
  ))
  status <- attr(res, "status")
  status <- if (is.null(status)) 0L else status
  expect_equal(status, 2L)
  expect_true(file.exists(out_path))
  findings <- read_std_csv(out_path)
  expect_true("ZZZ.CRASH" %in% findings$check_id)
  # the other modules' checks still ran (META.TBD/META.REQUIRED fire on
  # the real, unpatched metadata copy -- see the LEGACY_LABELS gap above).
  expect_true(any(findings$check_id == "META.TBD" | findings$check_id == "META.REQUIRED"))
})

# ---- WP11.A4: the findings file has exactly the 5 columns --------------

test_that("the findings file has exactly check_id, severity, file, row_key, message", {
  tmp <- make_temp_root(.root)
  out_path <- file.path(tmp, "findings.csv")
  suppressWarnings(system2(
    "Rscript",
    c(
      shQuote(file.path(.root, "pipeline", "validate.R")), "--root", shQuote(.root),
      "--metadata-only", "--out", shQuote(out_path)
    ),
    stdout = TRUE, stderr = TRUE
  ))
  header <- readLines(out_path, n = 1)
  expect_equal(header, "check_id,severity,file,row_key,message")
})

# ---- WP11.A5: real metadata, --metadata-only, 0 unexplained ERROR ------

test_that("validate.R --metadata-only on the real metadata has no unexplained ERROR", {
  out_path <- file.path(tempdir(), "wp11_real_metadata_findings.csv")
  res <- suppressWarnings(system2(
    "Rscript",
    c(
      shQuote(file.path(.root, "pipeline", "validate.R")), "--root", shQuote(.root),
      "--metadata-only", "--out", shQuote(out_path)
    ),
    stdout = TRUE, stderr = TRUE
  ))
  findings <- read_std_csv(out_path)
  errors <- findings[findings$severity == "ERROR", ]
  # The one known, reported metadata defect (WP11-implementer.md,
  # Questions): metadata/plans/LEGACY_LABELS.csv leaves `scale` empty on
  # rows this transition did not touch (mostly action != MAP); a findings
  # cap (COMMON.md "Findings format") can fold those 20+ rows into one
  # extra SUMMARY row for the same check_id/file. Every other ERROR would
  # be unexplained and should fail this test.
  unexplained <- errors[!(errors$check_id == "META.REQUIRED" &
    errors$file == "metadata/plans/LEGACY_LABELS.csv"), ]
  expect_equal(nrow(unexplained), 0)
})
