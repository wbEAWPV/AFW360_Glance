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
source(file.path(.root, "pipeline", "R", "manifest.R"))
source(file.path(.root, "pipeline", "R", "docs.R"))
source(file.path(.root, "pipeline", "R", "validate_structure.R"))
source(file.path(.root, "pipeline", "R", "validate_codes.R"))
source(file.path(.root, "pipeline", "R", "validate_metadata.R"))
source(file.path(.root, "pipeline", "R", "validate_docs.R"))

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
.small_fixture <- function(include = NULL) {
  tmp <- if (is.null(include)) make_temp_root(.root) else make_temp_root(.root, include = include)
  keep_ids <- c("POV_HC.POVLINE_PL420.PPP_2021", "POP_HH_SH.HE_COUNT_0", "CONS_SH.COICOP_CP01")
  dp <- make_data_fixture(tmp, "GNB", series_ids = keep_ids)
  # A copied data/ folder also holds the real SEN file, which the trimmed
  # SERIES_PLAN no longer describes; keep only the fixture and its manifest.
  others <- setdiff(
    list.files(file.path(tmp, "data"), full.names = TRUE),
    c(dp, sub("\\.csv$", "_manifest.csv", dp))
  )
  unlink(others)
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

test_that("validate.R on the clean fixture gives 0 ERROR from STRUCT, CODES and META (WP11.A1)", {
  # A1 was corrected on 2026-09-23 (dev/eb 00e61fc) to ask for 0 ERROR from
  # WP11's own modules rather than from the whole validator. WP08's fixture is
  # not validator-clean, and WP08's card puts that out of scope: it writes no
  # SURVEYS row (so COVER.SURVEY can never match), keeps the withheld cells
  # (COVER.WITHHELD_PRESENT), and fills OBS_VALUE with one constant, so
  # RULE.SUM_TO_1_* fires on any breakdown without exactly two categories.
  # Those findings are expected and belong to WP12 and WP13, so validate.R
  # exits non-zero here. That the whole validator is clean is proven on the
  # real data by the wave-3 integrator, not on this fixture.
  # --root also has to resolve pipeline/R/*.R (.docs/data-standard.qmd), so
  # the temp copy needs "pipeline" alongside the metadata/content/data it
  # is testing.
  fx <- .small_fixture(include = c("metadata", "content", "data", "pipeline"))

  out_path <- file.path(fx$tmp, "findings.csv")
  # The non-zero exit is expected here, so silence system2()'s warning about it.
  suppressWarnings(system2(
    "Rscript",
    c(shQuote(file.path(fx$tmp, "pipeline", "validate.R")), "--root", shQuote(fx$tmp), "--out", shQuote(out_path)),
    stdout = TRUE, stderr = TRUE
  ))
  expect_true(file.exists(out_path))
  findings <- read_std_csv(out_path)
  own <- findings[grepl("^(STRUCT|CODES|META)\\.", findings$check_id), ]
  expect_equal(nrow(own[own$severity == "ERROR", ]), 0)
})

test_that("a group a module already capped is not capped a second time", {
  # Regression. The modules are sourced into one environment, so a module whose
  # file sorts later can replace a same-named private binder that an earlier
  # module's checks call, and those checks then cap before returning. validate.R
  # used to cap such a group again, which added a second SUMMARY row for the
  # same check_id and file and dropped a real finding: the SUMMARY's empty
  # row_key sorts first, so it survived the re-cap and displaced the twentieth.
  # Leaving LEGACY_LABELS.csv untrimmed orphans 88 series_id references, well
  # over the cap of 20, which is the case that exposed it.
  tmp <- make_temp_root(.root, include = c("metadata", "content", "data", "pipeline"))
  make_data_fixture(tmp, "GNB", series_ids = c("POV_HC.POVLINE_PL420.PPP_2021"))

  out_path <- file.path(tmp, "findings.csv")
  suppressWarnings(system2(
    "Rscript",
    c(shQuote(file.path(tmp, "pipeline", "validate.R")), "--root", shQuote(tmp), "--out", shQuote(out_path)),
    stdout = TRUE, stderr = TRUE
  ))
  expect_true(file.exists(out_path))
  findings <- read_std_csv(out_path)
  grp <- findings[findings$check_id == "META.REFERENCE" &
                    findings$file == "metadata/plans/LEGACY_LABELS.csv", , drop = FALSE]
  summaries <- grp[grepl("^SUMMARY: ", grp$message), , drop = FALSE]
  expect_equal(nrow(summaries), 1L)
  expect_equal(nrow(grp) - nrow(summaries), 20L)
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

test_that("MEASURE_QUAL_2 of a POVLINE_PL420 row set to PPP_2017 gives CODES.QUAL_PAIRS", {
  fx <- .small_fixture()
  # Also set COMP_BREAKDOWN_1 to POOR_Y so the row is granted PPP/POVLINE
  # via CL_BRK_VAR.requires_qual, isolating QUAL_PAIRS from QUAL_DECLARED
  # (INDICATOR_QUALIFIERS.csv declares only PPP_2021 for POV_HC).
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
  # The row no longer matches its SERIES_ID's qualifiers either, which
  # CODES.SERIES_ID reports on its own.
  expect_equal(.error_ids(findings), c("CODES.QUAL_PAIRS", "CODES.SERIES_ID"))
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
  # The row no longer matches its SERIES_ID's qualifiers either, which
  # CODES.SERIES_ID reports on its own.
  expect_equal(.error_ids(findings), c("CODES.QUAL_DECLARED", "CODES.SERIES_ID"))
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
  edit_csv(file.path(tmp, "metadata", "codelists", "CL_UNIT_MEASURE.csv"), function(df) {
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
  # cap (see .docs/data-standard.qmd) can fold those 20+ rows into one
  # extra SUMMARY row for the same check_id/file. Every other ERROR would
  # be unexplained and should fail this test.
  unexplained <- errors[!(errors$check_id == "META.REQUIRED" &
    errors$file == "metadata/plans/LEGACY_LABELS.csv"), ]
  expect_equal(nrow(unexplained), 0)
})

# ---- standard v0.5 (WP-C): structure ---------------------------------------

test_that("the fixture has the 37 SDMX-CSV 2.1 columns and a 19-column key", {
  fx <- .small_fixture()
  df <- read_std_csv(fx$data_path)
  expect_equal(ncol(df), 37L)
  expect_equal(names(df)[1:4], c("STRUCTURE", "STRUCTURE_ID", "ACTION", "FREQ"))
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  expect_equal(length(ctx_key_columns(ctx)), 19L)
  expect_equal(ctx_key_columns(ctx)[c(1, 19)], c("FREQ", "TIME_PERIOD"))
  expect_equal(nrow(vc_struct_header(ctx)), 0L)
  expect_equal(nrow(vc_struct_file_name(ctx)), 0L)
  expect_equal(nrow(vc_struct_structure(ctx)), 0L)
  expect_equal(nrow(vc_struct_action(ctx)), 0L)
  expect_equal(nrow(vc_struct_attr_level(ctx)), 0L)
})

# ---- SDMX-CSV 2.1 (WP4a): fixed columns and attribute level ----------------

.struct_errors <- function(ctx) {
  findings <- .run_all_checks(ctx)
  .error_ids(findings[grepl("^STRUCT[.]", findings$check_id), ])
}

test_that("a data file without the ACTION column gives STRUCT.HEADER only", {
  fx <- .small_fixture()
  edit_csv(fx$data_path, function(df) df[setdiff(names(df), "ACTION")])
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  expect_equal(.struct_errors(ctx), "STRUCT.HEADER")
  expect_true(grepl("expected [STRUCTURE, STRUCTURE_ID, ACTION, FREQ,", vc_struct_header(ctx)$message, fixed = TRUE))
})

test_that("a STRUCTURE other than dataflow gives STRUCT.STRUCTURE", {
  fx <- .small_fixture()
  edit_csv(fx$data_path, function(df) {
    df$STRUCTURE[1] <- "datastructure"
    df
  })
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  expect_equal(.struct_errors(ctx), "STRUCT.STRUCTURE")
  res <- vc_struct_structure(ctx)
  expect_equal(nrow(res), 1L)
  expect_true(grepl("STRUCTURE 'datastructure' is not dataflow", res$message, fixed = TRUE))
})

test_that("a STRUCTURE_ID of another version gives STRUCT.STRUCTURE", {
  fx <- .small_fixture()
  edit_csv(fx$data_path, function(df) {
    df$STRUCTURE_ID[2] <- "WB.AFW360:AFW360_HH(0.2.0)"
    df
  })
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  expect_false(is.na(ctx$version))
  expect_equal(.struct_errors(ctx), "STRUCT.STRUCTURE")
  res <- vc_struct_structure(ctx)
  expect_equal(nrow(res), 1L)
  expect_true(grepl(paste0("is not ", structure_id(ctx$version)), res$message, fixed = TRUE))
})

test_that("an ACTION other than R gives STRUCT.ACTION", {
  fx <- .small_fixture()
  edit_csv(fx$data_path, function(df) {
    df$ACTION[1] <- "I"
    df$ACTION[2] <- "D"
    df
  })
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  expect_equal(.struct_errors(ctx), "STRUCT.ACTION")
  res <- vc_struct_action(ctx)
  expect_equal(nrow(res), 2L)
  expect_true(all(grepl("is not R$", res$message)))
})

test_that("two UNIT_MEASURE values for one REF_AREA and INDICATOR give STRUCT.ATTR_LEVEL", {
  fx <- .small_fixture()
  df0 <- read_std_csv(fx$data_path)
  ind <- df0$INDICATOR[1]
  expect_true(sum(df0$INDICATOR == ind) >= 2)
  edit_csv(fx$data_path, function(df) {
    df$UNIT_MEASURE[1] <- if (df$UNIT_MEASURE[1] == "SHARE") "COUNT" else "SHARE"
    df
  })
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  expect_equal(.struct_errors(ctx), "STRUCT.ATTR_LEVEL")
  res <- vc_struct_attr_level(ctx)
  expect_equal(nrow(res), 1L)
  expect_equal(res$row_key, paste("UNIT_MEASURE GNB", ind))
  expect_equal(res$file, "data/AFW360_HH_GNB_2021_SURVEY.csv")
})

test_that("STRUCT.ATTR_LEVEL groups SERIES_ID across all data files", {
  fx <- .small_fixture()
  # A second file (another year) repeats the fixture with one SERIES_ID changed.
  df <- read_std_csv(fx$data_path)
  df$TIME_PERIOD <- "2022"
  df$SERIES_ID[1] <- paste0(df$SERIES_ID[1], "_X")
  second <- file.path(fx$tmp, "data", "AFW360_HH_GNB_2022_SURVEY.csv")
  write_std_csv(df, second)
  ctx <- build_ctx(fx$tmp, data_files = c(fx$data_path, second))
  res <- vc_struct_attr_level(ctx)
  expect_true(nrow(res) >= 1)
  expect_true(all(res$check_id == "STRUCT.ATTR_LEVEL"))
  expect_true(all(startsWith(res$row_key, "SERIES_ID ")))
  expect_true(any(grepl("AFW360_HH_GNB_2021_SURVEY.csv, data/AFW360_HH_GNB_2022_SURVEY.csv", res$message, fixed = TRUE)))
})

test_that("a row whose ESTIMATION differs from the file name gives STRUCT.FILE_NAME", {
  fx <- .small_fixture()
  edit_csv(fx$data_path, function(df) {
    df$ESTIMATION[1] <- "MODEL" # a valid CL_ESTIMATION code, but not the file's
    df
  })
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  res <- vc_struct_file_name(ctx)
  expect_true(nrow(res) >= 1)
  expect_true(all(res$check_id == "STRUCT.FILE_NAME"))
  expect_true(any(grepl("ESTIMATION 'MODEL' differs from the file name's 'SURVEY'", res$message)))
  expect_true(any(grepl("differs from the manifest's 'SURVEY'", res$message)))
})

test_that("a data file named without its ESTIMATION gives STRUCT.FILE_NAME", {
  fx <- .small_fixture()
  old_stem <- file.path(fx$tmp, "data", "AFW360_HH_GNB_2021_SURVEY")
  new_stem <- file.path(fx$tmp, "data", "AFW360_HH_GNB_2021")
  file.rename(paste0(old_stem, ".csv"), paste0(new_stem, ".csv"))
  file.rename(paste0(old_stem, "_manifest.csv"), paste0(new_stem, "_manifest.csv"))
  ctx <- build_ctx(fx$tmp, data_files = paste0(new_stem, ".csv"))
  res <- vc_struct_file_name(ctx)
  expect_true(any(res$check_id == "STRUCT.FILE_NAME" & res$row_key == ""))
})

test_that("an ESTIMATION that is not in CL_ESTIMATION gives CODES.UNKNOWN", {
  fx <- .small_fixture()
  edit_csv(fx$data_path, function(df) {
    df$ESTIMATION[1] <- "NOWCAST"
    df
  })
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  res <- vc_codes_unknown(ctx)
  expect_equal(nrow(res), 1L)
  expect_match(res$message, "ESTIMATION=NOWCAST", fixed = TRUE)
})

# ---- codes: SERIES_ID, UNIT_MEASURE, SOURCE_ID, pairs ------------------------

test_that("CODES.SERIES_ID passes on the fixture and flags an unknown or mismatched SERIES_ID", {
  fx <- .small_fixture()
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  expect_equal(nrow(vc_codes_series_id(ctx)), 0L)

  edit_csv(fx$data_path, function(df) {
    pov <- which(df$INDICATOR == "POV_HC")
    df$SERIES_ID[pov[1]] <- "NOT_A_SERIES"
    df$SERIES_ID[pov[2]] <- "CONS_SH.COICOP_CP01" # exists, but a different indicator and qualifiers
    df
  })
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  findings <- .run_all_checks(ctx)
  # Both rows share their INDICATOR/breakdown/qualifier group with the
  # unchanged SEN/GNB rows, so SERIES_ID also varies within its attachment
  # group (STRUCT.ATTR_LEVEL, WP4a).
  expect_equal(.error_ids(findings), c("CODES.SERIES_ID", "STRUCT.ATTR_LEVEL"))
  res <- findings[findings$check_id == "CODES.SERIES_ID", ]
  expect_equal(nrow(res), 2L)
  expect_true(any(grepl("NOT_A_SERIES is not in SERIES_PLAN.csv", res$message, fixed = TRUE)))
  expect_true(any(grepl("INDICATOR POV_HC but the plan says CONS_SH", res$message, fixed = TRUE)))
})

test_that("CODES.SERIES_ID flags a share row whose defining category is missing", {
  fx <- .small_fixture()
  edit_csv(fx$data_path, function(df) {
    idx <- which(df$SERIES_ID == "POP_HH_SH.HE_COUNT_0" & df$COMP_BREAKDOWN_1 == "HE_COUNT_0")[1]
    df$COMP_BREAKDOWN_1[idx] <- "HE_COUNT_1" # the row now claims another category
    df
  })
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  res <- vc_codes_series_id(ctx)
  expect_equal(nrow(res), 1L)
  expect_match(res$message, "defining category HE_COUNT_0", fixed = TRUE)
})

test_that("UNIT_MEASURE of an LCU indicator is the country's currency; LCU or another unit gives CODES.UNIT", {
  tmp <- make_temp_root(.root)
  dp <- make_data_fixture(tmp, "GNB", series_ids = c("HE_PROFIT", "POV_HC.POVLINE_PL420.PPP_2021"))
  df <- read_std_csv(dp)
  expect_true(all(df$UNIT_MEASURE[df$INDICATOR == "HE_PROFIT"] == "XOF"))
  expect_true(all(df$UNIT_MEASURE[df$INDICATOR == "POV_HC"] == "SHARE"))
  ctx <- build_ctx(tmp, data_files = dp)
  expect_equal(nrow(vc_codes_unit(ctx)), 0L)

  edit_csv(dp, function(df) {
    hp <- which(df$INDICATOR == "HE_PROFIT")
    df$UNIT_MEASURE[hp[1]] <- "LCU"   # the dictionary's placeholder, not resolved
    df$UNIT_MEASURE[hp[2]] <- "XAF"   # a currency, but not GNB's
    df$UNIT_MEASURE[which(df$INDICATOR == "POV_HC")[1]] <- "PERSON"
    df
  })
  ctx <- build_ctx(tmp, data_files = dp)
  res <- vc_codes_unit(ctx)
  expect_equal(nrow(res), 3L)
  expect_true(all(res$check_id == "CODES.UNIT"))
  expect_true(any(grepl("'LCU' differs from 'XOF'", res$message, fixed = TRUE)))
  expect_true(any(grepl("'PERSON' differs from 'SHARE'", res$message, fixed = TRUE)))
})

test_that("CODES.SOURCE_ID flags an unknown source, a source of another country and one missing from the manifest", {
  fx <- .small_fixture()
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  expect_equal(nrow(vc_codes_source_id(ctx)), 0L)

  # A second GNB source, registered in SOURCES.csv but not in the manifest.
  edit_csv(file.path(fx$tmp, "metadata", "registries", "SOURCES.csv"), function(s) {
    extra <- s[s$source_id == "GNB_EHCVM2021_LEGACY_v1", ]
    extra$source_id <- "GNB_EHCVM2021_LEGACY_v2"
    rbind(s, extra)
  })
  edit_csv(fx$data_path, function(df) {
    df$SOURCE_ID[1] <- "NO_SUCH_SOURCE_v1"
    df$SOURCE_ID[2] <- "SEN_EHCVM2021_LEGACY_v1"
    df$SOURCE_ID[3] <- "GNB_EHCVM2021_LEGACY_v2"
    df
  })
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  res <- vc_codes_source_id(ctx)
  expect_true(all(res$check_id == "CODES.SOURCE_ID"))
  expect_true(any(grepl("NO_SUCH_SOURCE_v1 is not in SOURCES.csv", res$message, fixed = TRUE)))
  expect_true(any(grepl("SEN_EHCVM2021_LEGACY_v1 belongs to ref_area SEN, not GNB", res$message, fixed = TRUE)))
  expect_true(any(res$row_key == "SOURCE_ID=GNB_EHCVM2021_LEGACY_v2"))

  # Listing the new sources in the manifest clears the manifest finding.
  man_path <- sub("\\.csv$", "_manifest.csv", fx$data_path)
  edit_csv(man_path, function(m) {
    m$value[m$key == "sources"] <- paste(
      "GNB_EHCVM2021_LEGACY_v1 GNB_EHCVM2021_LEGACY_v2 NO_SUCH_SOURCE_v1 SEN_EHCVM2021_LEGACY_v1"
    )
    m
  })
  res2 <- vc_codes_source_id(build_ctx(fx$tmp, data_files = fx$data_path))
  expect_false(any(grepl("^SOURCE_ID=", res2$row_key)))
})

test_that("QUALIFIER_PAIRS' _Z overrides CL_QUAL_VAR.requires: POVLINE_NPL passes without PPP and fails with it", {
  fx <- .small_fixture()
  # POOR_Y requires POVLINE and PPP (CL_BRK_VAR.requires_qual), so the row is
  # granted both variables and QUAL_DECLARED stays quiet.
  edit_csv(fx$data_path, function(df) {
    idx <- which(df$INDICATOR == "POV_HC" & df$COMP_BREAKDOWN_1 == "_T")[1:2]
    df$COMP_BREAKDOWN_1[idx] <- "POOR_Y"
    df$MEASURE_QUAL_1[idx] <- "POVLINE_NPL"
    df$MEASURE_QUAL_2[idx[1]] <- "_Z"      # NPL takes no PPP: passes
    df$MEASURE_QUAL_2[idx[2]] <- "PPP_2021" # NPL with a PPP round: fails
    df
  })
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  res <- vc_codes_qual_pairs(ctx)
  expect_equal(nrow(res), 1L)
  expect_match(res$row_key, "POVLINE_NPL PPP_2021", fixed = TRUE)
  expect_match(res$message, "POVLINE_NPL takes no PPP", fixed = TRUE)
})

test_that("a qualifier declared nowhere and dropped from INDICATOR_QUALIFIERS.csv gives CODES.QUAL_DECLARED", {
  fx <- .small_fixture()
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  expect_equal(nrow(vc_codes_qual_declared(ctx)), 0L)
  edit_csv(file.path(fx$tmp, "metadata", "structure", "INDICATOR_QUALIFIERS.csv"), function(df) {
    df[!(df$indicator == "POV_HC" & df$qual_var == "PPP"), ]
  })
  res <- vc_codes_qual_declared(build_ctx(fx$tmp, data_files = fx$data_path))
  expect_true(nrow(res) > 0)
  # The module caps its findings (validate_common.R), so skip a SUMMARY row.
  real <- res[!grepl("^SUMMARY: ", res$message), ]
  expect_true(all(grepl("PPP_2021", real$message)))
})

# ---- metadata: code syntax, RULES, relations, SERIES_PLAN, SOURCES ---------

test_that("a codelist code starting with '_' gives META.CODE_SYNTAX", {
  tmp <- make_temp_root(.root)
  edit_csv(file.path(tmp, "metadata", "codelists", "CL_THEME.csv"), function(df) {
    df$code[df$code == "INEQ"] <- "_X"
    df
  })
  findings <- .run_all_checks(build_ctx(tmp))
  expect_equal(.error_ids(findings), "META.CODE_SYNTAX")
  hit <- findings[findings$check_id == "META.CODE_SYNTAX", ]
  expect_match(hit$message, "starts with '_'", fixed = TRUE)
})

test_that("the real RULES.csv passes META.RULES, and each malformed row fails it", {
  tmp <- make_temp_root(.root)
  expect_equal(nrow(vc_meta_rules(build_ctx(tmp))), 0L)

  path <- file.path(tmp, "metadata", "rules", "RULES.csv")
  edit_csv(path, function(df) {
    df$rule[df$rule_id == "POV_HC.RANGE_0_1"] <- "RANGE_0_2"           # unknown rule
    df$scope_code[df$rule_id == "CONS_SH.RANGE_0_1"] <- "NO_SUCH_IND"  # unresolved scope_code
    df$param[df$rule_id == "POV_HC.MONOTONE_IN.POVLINE"] <- ""         # a missing param
    df$severity[df$rule_id == "POV_NUM.AGG_SUM"] <- "FATAL"            # unknown severity
    df[df$rule != "RELIABILITY_MAX_CV", ]                              # a missing threshold
  })
  res <- vc_meta_rules(build_ctx(tmp))
  expect_true(all(res$check_id == "META.RULES"))
  expect_true(any(res$row_key == "rule_id=POV_HC.RANGE_0_1" & grepl("unknown rule", res$message)))
  expect_true(any(res$row_key == "rule_id=CONS_SH.RANGE_0_1" & grepl("not a CL_INDICATOR code", res$message)))
  expect_true(any(res$row_key == "rule_id=POV_HC.MONOTONE_IN.POVLINE" & grepl("param", res$message)))
  expect_true(any(res$row_key == "rule_id=POV_NUM.AGG_SUM" & grepl("severity", res$message)))
  expect_true(any(grepl("RELIABILITY_MAX_CV must exist exactly once", res$message)))
})

test_that("INDICATOR_QUALIFIERS.csv and QUALIFIER_PAIRS.csv rows with foreign categories fail their META checks", {
  tmp <- make_temp_root(.root)
  ctx <- build_ctx(tmp)
  expect_equal(nrow(vc_meta_indicator_qualifiers(ctx)), 0L)
  expect_equal(nrow(vc_meta_qualifier_pairs(ctx)), 0L)

  edit_csv(file.path(tmp, "metadata", "structure", "INDICATOR_QUALIFIERS.csv"), function(df) {
    df$allowed[df$indicator == "POV_HC" & df$qual_var == "POVLINE"] <- "POVLINE_PL300 PPP_2021"
    df
  })
  edit_csv(file.path(tmp, "metadata", "structure", "QUALIFIER_PAIRS.csv"), function(df) {
    df$allowed[df$qualifier == "POVLINE_PL300"] <- "POVLINE_PL420"
    df
  })
  ctx <- build_ctx(tmp)
  iq <- vc_meta_indicator_qualifiers(ctx)
  expect_equal(nrow(iq), 1L)
  expect_match(iq$message, "PPP_2021", fixed = TRUE)
  qp <- vc_meta_qualifier_pairs(ctx)
  expect_equal(nrow(qp), 1L)
  expect_match(qp$message, "not PPP categories: POVLINE_PL420", fixed = TRUE)
})

test_that("META.SERIES_PLAN accepts a NOT_PRODUCED country row with notes and rejects the malformed ones", {
  tmp <- make_temp_root(.root)
  path <- file.path(tmp, "metadata", "plans", "SERIES_PLAN.csv")
  expect_equal(nrow(vc_meta_series_plan(build_ctx(tmp))), 0L)

  edit_csv(path, function(df) {
    ok <- df[df$series_id == "AGR_TLU", ]
    ok$ref_area <- "GNB"
    ok$status <- "NOT_PRODUCED"
    ok$notes <- "No livestock module."
    rbind(df, ok)
  })
  expect_equal(nrow(vc_meta_series_plan(build_ctx(tmp))), 0L)

  edit_csv(path, function(df) {
    no_notes <- df[df$series_id == "AGR_CULTIVATES" & df$ref_area == "ALL", ]
    no_notes$ref_area <- "SEN"
    no_notes$status <- "DEVIATES"
    orphan <- df[df$series_id == "AGR_CULTIVATES" & df$ref_area == "ALL", ]
    orphan$series_id <- "AGR_CULTIVATES.X"
    orphan$ref_area <- "SEN"
    df$status[df$series_id == "HE_AGE"] <- "DEVIATES"          # on the ALL row
    df$estimation[df$series_id == "HE_ELEC"] <- "NOWCAST"      # unknown estimation
    df$series_id[df$series_id == "HE_RENT"] <- "HE_RENT_X"     # id != composition
    rbind(df, no_notes, orphan)
  })
  res <- vc_meta_series_plan(build_ctx(tmp))
  expect_true(all(res$check_id == "META.SERIES_PLAN"))
  msg <- paste(res$message, collapse = "\n")
  expect_match(msg, "status DEVIATES requires notes", fixed = TRUE)
  expect_match(msg, "country row has no ALL row", fixed = TRUE)
  expect_match(msg, "allowed only on a row for a specific ref_area", fixed = TRUE)
  expect_match(msg, "estimation has unknown code(s): NOWCAST", fixed = TRUE)
  expect_match(msg, "series_id should be 'HE_RENT'", fixed = TRUE)
})

test_that("META.SOURCES checks kind and the checksum of an input file under the root", {
  tmp <- make_temp_root(.root)
  path <- file.path(tmp, "metadata", "registries", "SOURCES.csv")
  version_sha <- sha256_file(file.path(tmp, "metadata", "VERSION"))
  edit_csv(path, function(df) {
    df$inputs[1] <- "metadata/VERSION"
    df$inputs_sha256[1] <- version_sha
    df
  })
  expect_equal(nrow(vc_meta_sources(build_ctx(tmp))), 0L)

  edit_csv(path, function(df) {
    df$inputs_sha256[1] <- paste(rep("0", 64), collapse = "")
    df$kind[2] <- "SCRAPER"
    df
  })
  res <- vc_meta_sources(build_ctx(tmp))
  expect_equal(nrow(res), 2L)
  msg <- paste(res$message, collapse = "\n")
  expect_match(msg, "inputs_sha256 of metadata/VERSION does not match", fixed = TRUE)
  expect_match(msg, "kind 'SCRAPER'", fixed = TRUE)
})

test_that("the real SOURCES.csv inputs_sha256 match data_raw/", {
  ctx <- build_ctx(.root)
  expect_equal(nrow(vc_meta_sources(ctx)), 0L)
})

# ---- documentation module ---------------------------------------------------

test_that("the DOCS module passes on current fragments and reports a stale one", {
  tmp <- make_temp_root(.root, include = c("metadata", "content", ".docs"))
  expect_equal(nrow(vc_docs_fragments(build_ctx(tmp))), 0L)

  edit_csv(file.path(tmp, "metadata", "codelists", "CL_OBS_STATUS.csv"), function(df) {
    df$name_en[df$code == "U"] <- "Unreliable"
    df
  })
  res <- vc_docs_fragments(build_ctx(tmp))
  expect_true(nrow(res) >= 1)
  expect_true(all(res$severity == "ERROR"))
  expect_true(any(res$check_id == "DOCS.FRAGMENT_STALE" & res$file == ".docs/generated/tbl-obs-status.md"))
})

test_that("the DOCS module gives one INFO when the root has no standard", {
  tmp <- make_temp_root(.root, include = "metadata")
  res <- vc_docs_fragments(build_ctx(tmp))
  expect_equal(res$check_id, "DOCS.SKIPPED")
  expect_equal(res$severity, "INFO")
})

# ---- WP4b: SDMX-CSV values, derived codelists, ARTEFACTS, global_urn -----------

#' The VALUE checks, sourced into their own environment so that
#' .run_all_checks() above keeps its module set.
.values_env <- function() {
  ve <- new.env(parent = globalenv())
  sys.source(file.path(.root, "pipeline", "R", "validate_values.R"), envir = ve)
  ve
}

test_that("NaN is the missing OBS_VALUE on O and M rows only (D39)", {
  # Row 3 (M, empty cell) is accepted: an empty cell still counts as missing.
  ve <- .values_env()
  fx <- .small_fixture()
  edit_csv(fx$data_path, function(df) {
    df$OBS_VALUE[1] <- "NaN"
    df$OBS_STATUS[1] <- "O"
    df$OBS_COMMENT[1] <- "LEGACY_EMPTY: test"
    df$OBS_VALUE[2] <- "NaN" # status stays A
    df$OBS_VALUE[3] <- ""
    df$OBS_STATUS[3] <- "M"
    df
  })
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  expect_equal(nrow(ve$vc_value_numeric(ctx)), 0L)
  res <- ve$vc_value_status_empty(ctx)
  expect_equal(nrow(res), 1L)
  expect_equal(res$message, "OBS_STATUS 'A' requires OBS_VALUE, but it is NaN.")
})

test_that("N_OBS_NUM, DEFF and DF are checked, and N_OBS_NUM <= N_OBS", {
  ve <- .values_env()
  fx <- .small_fixture()
  edit_csv(fx$data_path, function(df) {
    df$N_OBS[1] <- "10"
    df$N_POP[1] <- "100"
    df$N_OBS_NUM[1] <- "12"
    df$DEFF[2] <- "-1"
    df$DF[3] <- "2.5"
    df$N_OBS_NUM[4] <- "1e3"
    df
  })
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  num <- ve$vc_value_numeric(ctx)
  expect_equal(num$message, "N_OBS_NUM '1e3' is not a plain decimal number.")
  res <- ve$vc_value_n(ctx)
  res <- res[res$severity == "ERROR", ]
  expect_equal(nrow(res), 3L)
  expect_true(any(grepl("N_OBS_NUM exceeds N_OBS", res$message)))
  expect_true(any(grepl("DEFF is negative", res$message)))
  expect_true(any(grepl("DF is not a non-negative integer", res$message)))
})

test_that("CODES read the SDMX-CSV header and resolve CL_SOURCE from SOURCES.csv", {
  fx <- .small_fixture()
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  expect_equal(length(.codes_files(ctx)), 1L)
  expect_identical(.codes_codelist_codes(ctx, "CL_SOURCE"), ctx$meta$SOURCES$source_id)
  expect_identical(.codes_codelist_codes(ctx, "CL_UNIT_MEASURE"), ctx$meta$CL_UNIT_MEASURE$code)
  expect_null(.codes_codelist_codes(ctx, "CL_SERIES"))
})

test_that("a UNIT_MEASURE outside CL_UNIT_MEASURE gives CODES.UNIT", {
  fx <- .small_fixture()
  edit_csv(fx$data_path, function(df) {
    df$UNIT_MEASURE[1] <- "XXX"
    df
  })
  ctx <- build_ctx(fx$tmp, data_files = fx$data_path)
  res <- vc_codes_unit(ctx)
  expect_equal(nrow(res), 1L)
})

test_that("a CL_AREA currency outside CL_UNIT_MEASURE gives META.REFERENCE", {
  tmp <- make_temp_root(.root)
  edit_csv(file.path(tmp, "metadata", "codelists", "CL_AREA.csv"), function(df) {
    df$currency[df$code == "SEN"] <- "EUR"
    df
  })
  res <- vc_meta_reference(build_ctx(tmp))
  expect_equal(nrow(res), 1L)
  expect_match(res$message, "currency references unknown CL_UNIT_MEASURE[.]code: EUR")
})

test_that("ARTEFACTS.csv passes, and an unlisted codelist or a missing source file gives META.ARTEFACTS", {
  tmp <- make_temp_root(.root)
  expect_equal(nrow(vc_meta_artefacts(build_ctx(tmp))), 0L)
  edit_csv(file.path(tmp, "metadata", "structure", "ARTEFACTS.csv"), function(df) {
    df$source_file[df$artefact_id == "CL_SOURCE"] <- "metadata/registries/NOPE.csv"
    df[df$artefact_id != "CL_THEME", , drop = FALSE]
  })
  res <- vc_meta_artefacts(build_ctx(tmp))
  expect_equal(unique(res$check_id), "META.ARTEFACTS")
  expect_equal(sort(res$row_key), c("", "artefact_id=CL_SOURCE", "artefact_id=CL_THEME"))
  expect_true(any(grepl("has 31 rows; expected 32", res$message)))
})

test_that("a global_urn that is not a full code URN gives META.GLOBAL_URN", {
  tmp <- make_temp_root(.root)
  expect_equal(nrow(vc_meta_global_urn(build_ctx(tmp))), 0L)
  edit_csv(file.path(tmp, "metadata", "codelists", "CL_SEX.csv"), function(df) {
    df$global_urn[df$code == "F"] <- "SDMX:CL_SEX(2.1).F"
    df
  })
  res <- vc_meta_global_urn(build_ctx(tmp))
  expect_equal(nrow(res), 1L)
  expect_equal(res$row_key, "code=F")
  expect_equal(res$file, "metadata/codelists/CL_SEX.csv")
})

# ---- determinism of the findings file ------------------------------------------

test_that("two validator runs on the same fixture give identical findings", {
  fx <- .small_fixture(include = c("metadata", "content", "data", "pipeline"))
  run <- function(out) {
    suppressWarnings(system2(
      "Rscript",
      c(shQuote(file.path(fx$tmp, "pipeline", "validate.R")), "--root", shQuote(fx$tmp), "--out", shQuote(out)),
      stdout = TRUE, stderr = TRUE
    ))
    read_std_csv(out)
  }
  a <- run(file.path(fx$tmp, "findings-a.csv"))
  b <- run(file.path(fx$tmp, "findings-b.csv"))
  expect_true(nrow(a) > 0)
  expect_identical(as.data.frame(a), as.data.frame(b))
  bytes <- function(p) readBin(p, "raw", file.info(p)$size)
  expect_identical(bytes(file.path(fx$tmp, "findings-a.csv")), bytes(file.path(fx$tmp, "findings-b.csv")))
  # The rows are in radix (C-locale) order of check_id, file, row_key.
  ord <- order(a$check_id, a$file, a$row_key, method = "radix")
  expect_equal(ord, seq_len(nrow(a)))
})
