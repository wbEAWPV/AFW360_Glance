#!/usr/bin/env Rscript
# Acceptance script for WP08 -- Plans and the required-row generator.
#
#   Rscript pipeline/acceptance/wp08_plans.R --root .
#
# Standalone: builds its own "meta" from the contract seeds (per WP08.md
# step 3), because the other packages' metadata files do not exist on this
# branch. Sources pipeline/R/{constants,codes,io,plan}.R only because the
# checks are about the functions those files define (required_rows(),
# make_data_fixture()), per COMMON.md section 1 / the card's exception.

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
# Run a pipeline script; returns its exit status. Output goes to a temp log.
run_script <- function(script, script_args) {
  log <- tempfile(fileext = ".log")
  system2("Rscript", c(shQuote(file.path(root, script)), script_args), stdout = log, stderr = log)
}

## ---- 3. Build "meta" from the contract seeds (WP08.md step 3) -----------------
# Same recipe the card gives the implementer for the unit tests: the four
# breakdown/qualifier codelists from codes.csv, CL_GEO from geo_codes.csv,
# CL_INDICATOR from the triage's MAP rows, and the branch's own two plan
# files (metadata/plans/{SERIES_PLAN,TAB_PLAN}.csv).
codes_csv <- read_csv_char(file.path(contract, "codes.csv"))
geo_codes_csv <- read_csv_char(file.path(contract, "geo_codes.csv"))
triage_csv <- read_csv_char(file.path(contract, "label_triage.csv"))
map_rows <- triage_csv[triage_csv$action == "MAP", ]

cl_of <- function(cl) { d <- codes_csv[codes_csv$codelist == cl, ]; d$codelist <- NULL; d }
cl_brk_var <- cl_of("CL_BRK_VAR")
cl_comp_breakdown <- cl_of("CL_COMP_BREAKDOWN")
cl_qual_var <- cl_of("CL_QUAL_VAR")
cl_qualifier <- cl_of("CL_QUALIFIER")
cl_geo <- geo_codes_csv

cl_indicator <- unique(map_rows[, c("INDICATOR", "stat_unit")])
cl_indicator <- cl_indicator[!duplicated(cl_indicator$INDICATOR), ]
cl_indicator$code <- cl_indicator$INDICATOR
cl_indicator$theme <- "T1"
cl_indicator$excluded_breakdowns <- ""
cl_indicator <- cl_indicator[, c("code", "stat_unit", "theme", "excluded_breakdowns")]

series_plan_path <- file.path(root, "metadata", "plans", "SERIES_PLAN.csv")
tab_plan_path <- file.path(root, "metadata", "plans", "TAB_PLAN.csv")
series_plan <- if (file.exists(series_plan_path)) read_csv_char(series_plan_path) else NULL
tab_plan <- if (file.exists(tab_plan_path)) read_csv_char(tab_plan_path) else NULL

build_meta <- function() {
  list(SERIES_PLAN = series_plan, TAB_PLAN = tab_plan, CL_INDICATOR = cl_indicator,
       CL_BRK_VAR = cl_brk_var, CL_COMP_BREAKDOWN = cl_comp_breakdown,
       CL_QUAL_VAR = cl_qual_var, CL_QUALIFIER = cl_qualifier, CL_GEO = cl_geo)
}

## ---- 4. Checks ------------------------------------------------------------------

## WP08.A1 -- SERIES_PLAN has one row per MAP row of the triage, with
## series_id, INDICATOR, MEASURE_QUALS, DEFINING_BREAKDOWN equal to the
## triage's; series_id is unique and code-shaped.
try_check("WP08.A1", {
  sp <- read_csv_char(series_plan_path)
  map_key <- map_rows[, c("series_id", "INDICATOR", "MEASURE_QUALS", "DEFINING_BREAKDOWN")]
  joined <- merge(sp[, c("series_id", "INDICATOR", "MEASURE_QUALS", "DEFINING_BREAKDOWN")],
                   map_key, by = "series_id", suffixes = c(".sp", ".triage"))
  rows_equal <- nrow(joined) == nrow(sp) &&
    all(joined$INDICATOR.sp == joined$INDICATOR.triage) &&
    all(joined$MEASURE_QUALS.sp == joined$MEASURE_QUALS.triage) &&
    all(joined$DEFINING_BREAKDOWN.sp == joined$DEFINING_BREAKDOWN.triage)
  id_unique <- length(unique(sp$series_id)) == nrow(sp)
  id_shaped <- all(grepl("^[A-Z0-9_.]+$", sp$series_id))
  count_ok <- meets(nrow(sp), "SERIES.COUNT") && nrow(sp) == nrow(map_rows)
  check("WP08.A1", count_ok && rows_equal && id_unique && id_shaped,
        sprintf("SERIES_PLAN rows=%d, triage MAP rows=%d, fields match=%s, ids unique=%s, id-shaped=%s",
                nrow(sp), nrow(map_rows), rows_equal, id_unique, id_shaped))
})

## WP08.A2 -- TAB_PLAN equals contract/tab_plan.csv plus status = DRAFT.
try_check("WP08.A2", {
  tp <- read_csv_char(tab_plan_path)
  ct <- read_csv_char(file.path(contract, "tab_plan.csv"))
  expect_cols <- c(names(ct), "status")
  cols_ok <- identical(names(tp), expect_cols)
  rows_ok <- cols_ok && nrow(tp) == nrow(ct) &&
    all(sapply(names(ct), function(cn) identical(tp[[cn]], ct[[cn]]))) &&
    all(tp$status == "DRAFT")
  count_ok <- meets(nrow(tp), "META.TAB_PLAN")
  check("WP08.A2", cols_ok && rows_ok && count_ok,
        sprintf("TAB_PLAN rows=%d, cols_ok=%s, rows_ok=%s", nrow(tp), cols_ok, rows_ok))
})

## WP08.A3 -- headers equal csv_headers.csv.
try_check("WP08.A3", {
  sp_hdr_ok <- identical(names(read_csv_char(series_plan_path)), header_of("SERIES_PLAN.csv"))
  tp_hdr_ok <- identical(names(read_csv_char(tab_plan_path)), header_of("TAB_PLAN.csv"))
  check("WP08.A3", sp_hdr_ok && tp_hdr_ok,
        sprintf("SERIES_PLAN header ok=%s, TAB_PLAN header ok=%s", sp_hdr_ok, tp_hdr_ok))
})

## Source the functions under test only for the checks that need them.
source(file.path(root, "pipeline", "R", "constants.R"))
source(file.path(root, "pipeline", "R", "codes.R"))
source(file.path(root, "pipeline", "R", "io.R"))
source(file.path(root, "pipeline", "R", "plan.R"))

sen_rows <- NULL
gnb_rows <- NULL
try_check("WP08.A4", {
  meta <- build_meta()
  sen_rows <<- required_rows(meta, "SEN", "2021")
  gnb_rows <<- required_rows(meta, "GNB", "2021")
  key_cols <- KEY_COLUMNS
  sen_key <- do.call(paste, c(sen_rows[key_cols], sep = ""))
  gnb_key <- do.call(paste, c(gnb_rows[key_cols], sep = ""))
  sen_unique <- length(unique(sen_key)) == nrow(sen_rows)
  gnb_unique <- length(unique(gnb_key)) == nrow(gnb_rows)
  sen_no_empty <- !any(sen_rows[key_cols] == "")
  gnb_no_empty <- !any(gnb_rows[key_cols] == "")
  sen_count_ok <- meets(nrow(sen_rows), "DATA.SEN.ROWS")
  gnb_count_ok <- meets(nrow(gnb_rows), "GNB.MAPPED_CELLS")
  check("WP08.A4",
        sen_count_ok && gnb_count_ok && sen_unique && gnb_unique && sen_no_empty && gnb_no_empty,
        sprintf("SEN rows=%d (unique=%s, no_empty=%s), GNB rows=%d (unique=%s, no_empty=%s)",
                nrow(sen_rows), sen_unique, sen_no_empty, nrow(gnb_rows), gnb_unique, gnb_no_empty))
})

try_check("WP08.A5", {
  stopifnot(!is.null(sen_rows), !is.null(gnb_rows))
  ind_unit <- setNames(cl_indicator$stat_unit, cl_indicator$code)
  all_rows <- rbind(sen_rows, gnb_rows)
  not_ind <- ind_unit[all_rows$INDICATOR] != "IND"
  sex_z_ok <- all((all_rows$SEX == "_Z") == not_ind)
  age_z_ok <- all((all_rows$AGE == "_Z") == not_ind)

  he0 <- sen_rows[sen_rows$series_id == "POP_HH_SH.HE_COUNT_0" & sen_rows$cut_id == "QUINT", ]
  he0_ok <- nrow(he0) > 0 && all(grepl("^QUINT_", he0$COMP_BREAKDOWN_1)) &&
    all(he0$COMP_BREAKDOWN_2 == "HE_COUNT_0")

  pov <- sen_rows[sen_rows$series_id == "POV_HC.POVLINE_PL420.PPP_2021" & sen_rows$cut_id == "TOTAL", ]
  pov_ok <- nrow(pov) == 1 && pov$MEASURE_QUAL_1 == "POVLINE_PL420" && pov$MEASURE_QUAL_2 == "PPP_2021"

  check("WP08.A5", sex_z_ok && age_z_ok && he0_ok && pov_ok,
        sprintf("sex_z_ok=%s, age_z_ok=%s, HE_COUNT_0/QUINT rows=%d ok=%s, POV/PPP row ok=%s",
                sex_z_ok, age_z_ok, nrow(he0), he0_ok, pov_ok))
})

## WP08.A6 -- per country, rows per cut_id = series count x cut cell count.
## The cell counts are our own small expansion of TAB_PLAN, computed
## independently from the contract, not by calling required_rows() again.
try_check("WP08.A6", {
  stopifnot(!is.null(sen_rows), !is.null(gnb_rows))
  n_series <- nrow(series_plan)
  urb_codes <- strsplit(trimws(tab_plan$urbanisation[tab_plan$cut_id == "URB"]), "\\s+")[[1]]
  cat_count <- function(v) sum(cl_comp_breakdown$var_code == v)
  geo_count <- function(scheme, area) sum(cl_geo$scheme == scheme & cl_geo$ref_area == area)

  cells <- c(TOTAL = 1, URB = length(urb_codes),
             HHH_SEX = cat_count("HHH_SEX"), HHH_AGE = cat_count("HHH_AGE"),
             QUINT = cat_count("QUINT"))
  card_cells <- c(TOTAL = 1, URB = 3, HHH_SEX = 2, HHH_AGE = 2, QUINT = 5)
  cells_match_card <- identical(unname(cells), unname(card_cells))

  sen_adm1 <- geo_count("ADM1", "SEN"); gnb_adm1 <- geo_count("ADM1", "GNB")
  sen_zones <- geo_count("ZONES", "SEN"); gnb_aez <- geo_count("AEZ", "GNB")
  geo_match_card <- sen_adm1 == 14 && gnb_adm1 == 9 && sen_zones == 6 && gnb_aez == 4

  sen_t <- table(sen_rows$cut_id); gnb_t <- table(gnb_rows$cut_id)
  sen_ok <- sen_t[["TOTAL"]] == n_series * cells[["TOTAL"]] &&
    sen_t[["URB"]] == n_series * cells[["URB"]] &&
    sen_t[["HHH_SEX"]] == n_series * cells[["HHH_SEX"]] &&
    sen_t[["HHH_AGE"]] == n_series * cells[["HHH_AGE"]] &&
    sen_t[["QUINT"]] == n_series * cells[["QUINT"]] &&
    sen_t[["ADM1"]] == n_series * sen_adm1 &&
    sen_t[["ZONES"]] == n_series * sen_zones &&
    !("AEZ" %in% names(sen_t))
  gnb_ok <- gnb_t[["TOTAL"]] == n_series * cells[["TOTAL"]] &&
    gnb_t[["URB"]] == n_series * cells[["URB"]] &&
    gnb_t[["HHH_SEX"]] == n_series * cells[["HHH_SEX"]] &&
    gnb_t[["HHH_AGE"]] == n_series * cells[["HHH_AGE"]] &&
    gnb_t[["QUINT"]] == n_series * cells[["QUINT"]] &&
    gnb_t[["ADM1"]] == n_series * gnb_adm1 &&
    gnb_t[["AEZ"]] == n_series * gnb_aez &&
    !("ZONES" %in% names(gnb_t))

  check("WP08.A6", cells_match_card && geo_match_card && sen_ok && gnb_ok,
        sprintf("n_series=%d, cells=%s, sen_adm1=%d, gnb_adm1=%d, sen_zones=%d, gnb_aez=%d, sen_ok=%s, gnb_ok=%s",
                n_series, paste(cells, collapse = ","), sen_adm1, gnb_adm1, sen_zones, gnb_aez, sen_ok, gnb_ok))
})

## WP08.A7 -- unit tests pass, and build_plans.R --out-root reproduces both
## files byte for byte.
try_check("WP08.A7", {
  suppressPackageStartupMessages(library(testthat))
  test_res <- as.data.frame(test_dir(file.path(root, "pipeline", "tests", "testthat"),
                                      filter = "plan", reporter = "silent", stop_on_failure = FALSE))
  tests_ok <- nrow(test_res) > 0 && sum(test_res$failed) == 0 && !any(test_res$error %in% TRUE)

  tmp_out <- file.path(tempdir(), paste0("wp08_out_", as.integer(Sys.time())))
  dir.create(tmp_out, recursive = TRUE, showWarnings = FALSE)
  status <- run_script("pipeline/bootstrap/build_plans.R", c("--root", shQuote(root), "--out-root", shQuote(tmp_out)))
  rebuilt_sp <- file.path(tmp_out, "metadata", "plans", "SERIES_PLAN.csv")
  rebuilt_tp <- file.path(tmp_out, "metadata", "plans", "TAB_PLAN.csv")
  files_exist <- file.exists(rebuilt_sp) && file.exists(rebuilt_tp)
  bytes_ok <- files_exist &&
    identical(blob_bytes("metadata/plans/SERIES_PLAN.csv"), readBin(rebuilt_sp, "raw", file.size(rebuilt_sp))) &&
    identical(blob_bytes("metadata/plans/TAB_PLAN.csv"), readBin(rebuilt_tp, "raw", file.size(rebuilt_tp)))

  check("WP08.A7", tests_ok && status == 0 && files_exist && bytes_ok,
        sprintf("testthat: %d test(s), failed=%d, error=%s; build_plans.R status=%d, byte-identical=%s",
                nrow(test_res), sum(test_res$failed), any(test_res$error %in% TRUE), status, bytes_ok))
})

## WP08.A8 -- make_data_fixture() on a seed-built temporary root.
try_check("WP08.A8", {
  tmp_root <- file.path(tempdir(), paste0("wp08_fixture_", as.integer(Sys.time())))
  meta_dir <- file.path(tmp_root, "metadata")
  dir.create(file.path(meta_dir, "plans"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(meta_dir, "codelists"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(tmp_root, "data"), recursive = TRUE, showWarnings = FALSE)

  file.copy(series_plan_path, file.path(meta_dir, "plans", "SERIES_PLAN.csv"), overwrite = TRUE)
  file.copy(tab_plan_path, file.path(meta_dir, "plans", "TAB_PLAN.csv"), overwrite = TRUE)
  write.csv(cl_indicator, file.path(meta_dir, "codelists", "CL_INDICATOR.csv"), row.names = FALSE, na = "")
  write.csv(cl_brk_var, file.path(meta_dir, "codelists", "CL_BRK_VAR.csv"), row.names = FALSE, na = "")
  write.csv(cl_comp_breakdown, file.path(meta_dir, "codelists", "CL_COMP_BREAKDOWN.csv"), row.names = FALSE, na = "")
  write.csv(cl_qual_var, file.path(meta_dir, "codelists", "CL_QUAL_VAR.csv"), row.names = FALSE, na = "")
  write.csv(cl_qualifier, file.path(meta_dir, "codelists", "CL_QUALIFIER.csv"), row.names = FALSE, na = "")
  write.csv(cl_geo, file.path(meta_dir, "codelists", "CL_GEO.csv"), row.names = FALSE, na = "")

  # helper-data-fixture.R uses edit_csv(), a shared test helper defined in
  # helper-temp-root.R (not owned by WP08); testthat normally sources every
  # helper-*.R in the directory together, so we do the same here.
  source(file.path(root, "pipeline", "tests", "testthat", "helper-temp-root.R"))
  source(file.path(root, "pipeline", "tests", "testthat", "helper-data-fixture.R"))
  data_path <- make_data_fixture(tmp_root, ref_area = "GNB",
                                  series_ids = c("POV_HC.POVLINE_PL420.PPP_2021", "POP_HH_SH.HE_COUNT_0"))
  data_exists <- is.character(data_path) && length(data_path) == 1 && file.exists(data_path)

  data_df <- if (data_exists) read_csv_char(data_path) else NULL
  rows_ok <- data_exists && nrow(data_df) == 52
  cols_ok <- data_exists && identical(names(data_df), DSD_COLUMNS)

  manifest_candidates <- if (data_exists) setdiff(list.files(dirname(data_path), full.names = TRUE), data_path) else character(0)
  manifest_path <- manifest_candidates[grepl("manifest", basename(manifest_candidates), ignore.case = TRUE)]
  if (length(manifest_path) == 0) manifest_path <- manifest_candidates
  manifest_ok <- FALSE
  n_rows_ok <- FALSE
  if (length(manifest_path) >= 1) {
    manifest_path <- manifest_path[1]
    mf <- read_csv_char(manifest_path)
    keys16 <- c("dataflow", "dsd_version", "metadata_version", "ref_area", "time_period", "source_type",
                "survey_id", "precision", "file_name", "n_rows", "producer", "program", "software",
                "run_timestamp", "status", "notes")
    manifest_ok <- setequal(names(mf), keys16)
    n_rows_ok <- manifest_ok && nrow(mf) == 1 && as.character(mf$n_rows) == "52"
  }

  check("WP08.A8", rows_ok && cols_ok && manifest_ok && n_rows_ok,
        sprintf("data rows=%s, 26 DSD cols=%s, manifest found=%s (16 keys=%s), manifest n_rows=52: %s",
                if (data_exists) nrow(data_df) else NA, cols_ok, length(manifest_path) == 1, manifest_ok, n_rows_ok))
})

## ---- 5. Exit ----------------------------------------------------------------------
cat(if (length(.failures)) sprintf("\n%d check(s) failed: %s\n", length(.failures), paste(.failures, collapse = ", ")) else "\nAll checks passed.\n")
quit(status = if (length(.failures)) 1L else 0L, save = "no")
