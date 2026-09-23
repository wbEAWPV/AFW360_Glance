#!/usr/bin/env Rscript
# WP17 - Final audit acceptance script.
#
#   Rscript pipeline/acceptance/wp17_final-audit.R --root .
#
# Standalone: does not source pipeline/R/ (it runs the top-level pipeline/*.R
# scripts as subprocesses). Expected numbers come from
# contract/expected_counts.csv, looked up by check_id. Writes only to
# tempdir(). Compares generated output against the current committed files
# (git HEAD blobs) and against a fresh reconciliation run, never against the
# branch name "transition/main" or a git diff.

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
# Raw (unparsed) expected text, for the two accounting rows whose "expected"
# column is an equation ("3201 = 3003 + 198"), not a bare number.
expected_raw <- function(check_id) {
  tab <- read_csv_char(file.path(contract, "expected_counts.csv"))
  row <- tab[tab$check_id == check_id, ]
  if (nrow(row) != 1) stop("no unique row in expected_counts.csv for ", check_id)
  row$expected
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

# --- WP17-specific helpers ---

# Cell counts for one workbook sheet: total data cells (all columns but the
# first, "indicator"), and how many are non-empty / empty (NA or blank after
# trimws(), per COMMON.md section 5).
cells_count <- function(path, sheet) {
  d <- readxl::read_excel(path, sheet = sheet, col_types = "text")
  m <- as.matrix(d[, -1, drop = FALSE])
  total <- length(m)
  empty <- sum(is.na(m) | trimws(m) == "")
  list(total = total, nonempty = total - empty, empty = empty)
}
# OBS_VALUE / 1e6 of the POV_NUM row at the national total (GEO, URBANISATION
# and every COMP_BREAKDOWN slot "_T"), for one poverty line ("300" / "420").
povnum <- function(d, line) {
  sub <- d[d$INDICATOR == "POV_NUM" & d$GEO == "_T" & d$URBANISATION == "_T" &
             d$COMP_BREAKDOWN_1 == "_T" & d$COMP_BREAKDOWN_2 == "_T" &
             d$COMP_BREAKDOWN_3 == "_T" & d$COMP_BREAKDOWN_4 == "_T" &
             d$COMP_BREAKDOWN_5 == "_T" & d$MEASURE_QUAL_1 == paste0("POVLINE_PL", line), ]
  if (nrow(sub) != 1) return(NA_real_)
  as.numeric(sub$OBS_VALUE) / 1e6
}
# Tracked (git) file list under a path, relative to root.
tracked_files <- function(relpath) {
  tmp <- tempfile()
  system2("git", c("-C", shQuote(root), "ls-tree", "-r", "--name-only", "HEAD", "--", shQuote(relpath)), stdout = tmp)
  out <- readLines(tmp, warn = FALSE)
  out[nzchar(out)]
}
# Named vector of feature counts per layer for one ref_area's GeoPackage, per
# metadata/registries/GEO_SOURCES.csv (source_id, ref_area, file, layers).
geo_layer_counts <- function(geo_sources, ref_area) {
  row <- geo_sources[geo_sources$ref_area == ref_area, ]
  path <- file.path(root, "geo", "boundaries", row$file[1])
  ly <- sf::st_layers(path)
  stats::setNames(as.integer(ly$features), ly$name)
}

# check_id -> actual value (and a couple of shared data frames), for the
# plain count/rate checks. An *environment* (not a list), because it must be
# mutated from inside tryCatch({...}) blocks below and R's complex-assignment
# superassignment (`A[[id]] <<- value`) does not reliably reach back into the
# script's top level from there, while environments mutate in place under a
# plain `<-`.
A <- new.env()

## ---- 3. (no example) -----------------------------------------------------------

## ---- 4. Checks ------------------------------------------------------------------

# --- CELLS.*: data_raw/tables/*.xlsx, data columns x rows, non-empty/empty ---
tryCatch({
  sen_xlsx <- file.path(root, "data_raw", "tables", "Tables_SEN.xlsx")
  gnb_xlsx <- file.path(root, "data_raw", "tables", "Tables_GNB.xlsx")
  add_cells <- function(prefix, path, sheet) {
    r <- cells_count(path, sheet)
    A[[prefix]] <- r$total
    A[[paste0(prefix, ".NONEMPTY")]] <- r$nonempty
    A[[paste0(prefix, ".EMPTY")]] <- r$empty
  }
  add_cells("CELLS.SEN_National", sen_xlsx, "National")
  add_cells("CELLS.SEN_ADM1", sen_xlsx, "ADM 1")
  add_cells("CELLS.SEN_ZAE", sen_xlsx, "ZAE")
  add_cells("CELLS.SEN_Departement", sen_xlsx, "Departement")
  add_cells("CELLS.GNB_National", gnb_xlsx, "National")
  add_cells("CELLS.GNB_ADM1", gnb_xlsx, "ADM 1")
  add_cells("CELLS.GNB_ZAE", gnb_xlsx, "ZAE")
}, error = function(e) cat(sprintf("ERROR in CELLS.*: %s\n", conditionMessage(e))))

# --- LABELS.*, SERIES.COUNT, INDICATOR.CODES ---
tryCatch({
  legacy_labels <- read_csv_char(file.path(root, "metadata", "plans", "LEGACY_LABELS.csv"))
  A[["LABELS.SHARED"]] <- sum(legacy_labels$sheet == "*")
  A[["LABELS.DEPARTEMENT"]] <- sum(legacy_labels$sheet == "Departement")
  A[["LABELS.TOTAL"]] <- nrow(legacy_labels)

  series_plan <- read_csv_char(file.path(root, "metadata", "plans", "SERIES_PLAN.csv"))
  A[["SERIES.COUNT"]] <- nrow(series_plan)

  cl_indicator <- read_csv_char(file.path(root, "metadata", "codelists", "CL_INDICATOR.csv"))
  A[["INDICATOR.CODES"]] <- nrow(cl_indicator)
}, error = function(e) cat(sprintf("ERROR in LABELS/SERIES/INDICATOR: %s\n", conditionMessage(e))))

# --- DATA.SEN.*, GNB.DATA.*, POVNUM.* : data/AFW360_HH_<ISO3>_2021.csv ---
tryCatch({
  sen_data <- read_csv_char(file.path(root, "data", "AFW360_HH_SEN_2021.csv"))
  gnb_data <- read_csv_char(file.path(root, "data", "AFW360_HH_GNB_2021.csv"))
  A[["_sen_data"]] <- sen_data
  A[["_gnb_data"]] <- gnb_data
  A[["DATA.SEN.ROWS"]] <- nrow(sen_data)
  A[["DATA.SEN.ROWS.A"]] <- sum(sen_data$OBS_STATUS == "A")
  A[["GNB.DATA.ROWS"]] <- nrow(gnb_data)
  A[["GNB.DATA.ROWS.A"]] <- sum(gnb_data$OBS_STATUS == "A")
  A[["GNB.DATA.ROWS.O"]] <- sum(gnb_data$OBS_STATUS == "O")

  A[["POVNUM.SEN.PL300"]] <- povnum(sen_data, "300")
  A[["POVNUM.SEN.PL420"]] <- povnum(sen_data, "420")
  A[["POVNUM.GNB.PL300"]] <- povnum(gnb_data, "300")
  A[["POVNUM.GNB.PL420"]] <- povnum(gnb_data, "420")
}, error = function(e) cat(sprintf("ERROR in DATA/POVNUM: %s\n", conditionMessage(e))))

# --- META.* : row counts of the named registry/plan/codelist/structure files ---
tryCatch({
  meta_files <- list(
    META.CL_INDICATOR      = "metadata/codelists/CL_INDICATOR.csv",
    META.SERIES_PLAN       = "metadata/plans/SERIES_PLAN.csv",
    META.TAB_PLAN           = "metadata/plans/TAB_PLAN.csv",
    META.CL_BRK_VAR         = "metadata/codelists/CL_BRK_VAR.csv",
    META.CL_COMP_BREAKDOWN  = "metadata/codelists/CL_COMP_BREAKDOWN.csv",
    META.CL_QUAL_VAR        = "metadata/codelists/CL_QUAL_VAR.csv",
    META.CL_QUALIFIER       = "metadata/codelists/CL_QUALIFIER.csv",
    META.CL_GEO             = "metadata/codelists/CL_GEO.csv",
    META.CL_GEO_SCHEME      = "metadata/codelists/CL_GEO_SCHEME.csv",
    META.CL_AREA            = "metadata/codelists/CL_AREA.csv",
    META.GEO_SOURCES        = "metadata/registries/GEO_SOURCES.csv",
    META.SURVEYS            = "metadata/surveys/SURVEYS.csv",
    META.LEGACY_LABELS      = "metadata/plans/LEGACY_LABELS.csv",
    META.LEGACY_COLUMNS     = "metadata/plans/LEGACY_COLUMNS.csv",
    META.LEGACY_OVERRIDES   = "metadata/plans/LEGACY_OVERRIDES.csv",
    META.TEXT                = "content/TEXT.csv",
    META.FIGURES             = "metadata/registries/FIGURES.csv",
    META.DSD                 = "metadata/structure/DSD_AFW360_HH.csv"
  )
  for (id in names(meta_files)) {
    A[[id]] <- nrow(read_csv_char(file.path(root, meta_files[[id]])))
  }
  small_names <- c("CL_SEX", "CL_AGE", "CL_URBANISATION", "CL_OBS_STATUS", "CL_THEME",
                    "CL_STAT_UNIT", "CL_STATISTIC", "CL_WEIGHT", "CL_UNIT")
  A[["META.SMALL_CODELISTS"]] <- sum(file.exists(file.path(root, "metadata", "codelists", paste0(small_names, ".csv"))))
}, error = function(e) cat(sprintf("ERROR in META.*: %s\n", conditionMessage(e))))

# --- GEOM.* : GeoPackage feature counts, per metadata/registries/GEO_SOURCES.csv ---
tryCatch({
  geo_sources <- read_csv_char(file.path(root, "metadata", "registries", "GEO_SOURCES.csv"))
  sen_geom <- geo_layer_counts(geo_sources, "SEN")
  gnb_geom <- geo_layer_counts(geo_sources, "GNB")
  A[["GEOM.SEN.ADM0"]] <- unname(sen_geom[["adm0"]])
  A[["GEOM.SEN.ADM1"]] <- unname(sen_geom[["adm1"]])
  A[["GEOM.GNB.ADM0"]] <- unname(gnb_geom[["adm0"]])
  A[["GEOM.GNB.ADM1"]] <- unname(gnb_geom[["adm1"]])
}, error = function(e) cat(sprintf("ERROR in GEOM.*: %s\n", conditionMessage(e))))

# --- LEGACY.FILES : tracked files under data_raw/, minus README.md/CHECKSUMS.sha256 ---
tryCatch({
  dr_files <- tracked_files("data_raw/")
  dr_files <- dr_files[!grepl("(^|/)(README\\.md|CHECKSUMS\\.sha256)$", dr_files)]
  A[["LEGACY.FILES"]] <- length(dr_files)
}, error = function(e) cat(sprintf("ERROR in LEGACY.FILES: %s\n", conditionMessage(e))))

# --- WP17.V3, GNB.MAPPED_CELLS, GNB.WITHHELD_CELLS, SOURCE.*.ACCOUNTING,
#     DEPARTEMENT.SKIPPED : a fresh reconciliation cells CSV ---
tryCatch({
  rc_csv <- tempfile(fileext = ".csv")
  rc_md <- tempfile(fileext = ".md")
  v3_status <- run_script("pipeline/reconcile.R",
    c("--root", shQuote(root), "--out", shQuote(rc_md), "--csv", shQuote(rc_csv)))
  check("WP17.V3", identical(v3_status, 0L), sprintf("reconcile.R --root . --out <tmp> --csv <tmp> exit status = %s", v3_status))

  if (file.exists(rc_csv)) {
    cells <- read_csv_char(rc_csv)
    core <- cells[cells$sheet %in% c("National", "ADM 1", "ZAE"), ]

    sen_core <- core[core$ref_area == "SEN", ]
    sen_converted <- sum(sen_core$class == "converted")
    sen_nonseries <- sum(sen_core$class %in% c("derived", "duplicate", "skipped", "withheld"))
    sen_total <- nrow(sen_core)
    sen_source_total <- A[["CELLS.SEN_National"]] + A[["CELLS.SEN_ADM1"]] + A[["CELLS.SEN_ZAE"]]
    sen_raw <- expected_raw("SOURCE.SEN.ACCOUNTING")
    sen_ok <- isTRUE(sen_total == sen_source_total) && isTRUE(sen_total == (sen_converted + sen_nonseries))
    check("SOURCE.SEN.ACCOUNTING", sen_ok,
          sprintf("expected=%s actual=%d = %d + %d (source cells from xlsx=%d)",
                  sen_raw, sen_total, sen_converted, sen_nonseries, sen_source_total))

    gnb_core <- core[core$ref_area == "GNB", ]
    gnb_converted <- sum(gnb_core$class == "converted")
    gnb_withheld <- sum(gnb_core$class == "withheld")
    gnb_mapped <- gnb_converted + gnb_withheld
    gnb_nonseries <- sum(gnb_core$class %in% c("derived", "duplicate", "skipped"))
    gnb_total <- nrow(gnb_core)
    gnb_source_total <- A[["CELLS.GNB_National"]] + A[["CELLS.GNB_ADM1"]] + A[["CELLS.GNB_ZAE"]]
    gnb_raw <- expected_raw("SOURCE.GNB.ACCOUNTING")
    gnb_ok <- isTRUE(gnb_total == gnb_source_total) && isTRUE(gnb_total == (gnb_mapped + gnb_nonseries))
    check("SOURCE.GNB.ACCOUNTING", gnb_ok,
          sprintf("expected=%s actual=%d = %d + %d (source cells from xlsx=%d)",
                  gnb_raw, gnb_total, gnb_mapped, gnb_nonseries, gnb_source_total))

    A[["GNB.MAPPED_CELLS"]] <- gnb_mapped
    A[["GNB.WITHHELD_CELLS"]] <- gnb_withheld
    A[["DEPARTEMENT.SKIPPED"]] <- sum(cells$ref_area == "SEN" & cells$sheet == "Departement" & cells$class == "skipped")
  } else {
    check("SOURCE.SEN.ACCOUNTING", FALSE, "reconciliation cells CSV was not produced")
    check("SOURCE.GNB.ACCOUNTING", FALSE, "reconciliation cells CSV was not produced")
  }
}, error = function(e) {
  cat(sprintf("ERROR in reconciliation block: %s\n", conditionMessage(e)))
  check("WP17.V3", FALSE, paste("error:", conditionMessage(e)))
})

# --- Generic pass: every row of expected_counts.csv except the two
#     SOURCE.*.ACCOUNTING rows (already checked above, non-numeric "expected"). ---
tryCatch({
  ec <- read_csv_char(file.path(contract, "expected_counts.csv"))
  special_ids <- c("SOURCE.SEN.ACCOUNTING", "SOURCE.GNB.ACCOUNTING")
  for (id in ec$check_id) {
    if (id %in% special_ids) next
    e <- expected(id)
    if (!exists(id, envir = A, inherits = FALSE)) {
      check(id, FALSE, sprintf("expected=%s actual=<not computed - see ERROR above>", format(e$value)))
      next
    }
    av <- A[[id]]
    ok <- !is.na(av) && abs(av - e$value) <= e$tol + 1e-9
    check(id, ok, sprintf("expected=%s actual=%s", format(e$value, trim = TRUE), format(round(av, 6), trim = TRUE)))
  }
}, error = function(e) cat(sprintf("ERROR in generic expected_counts.csv pass: %s\n", conditionMessage(e))))

# --- WP17.V1, WP17.V2 : pipeline/validate.R on the real data ---
tryCatch({
  v1_out <- tempfile(fileext = ".csv")
  v1_status <- run_script("pipeline/validate.R", c("--root", shQuote(root), "--out", shQuote(v1_out)))
  findings <- if (file.exists(v1_out)) read_csv_char(v1_out) else data.frame(check_id = character(0), severity = character(0))
  n_error <- sum(findings$severity == "ERROR")
  n_warn <- sum(findings$severity == "WARN")
  n_info <- sum(findings$severity == "INFO")
  check("WP17.V1", identical(v1_status, 0L) && n_error == 0,
        sprintf("validate.R --root . --out <tmp> exit=%s, ERROR=%d, WARN=%d, INFO=%d", v1_status, n_error, n_warn, n_info))

  allowed_warn <- c("CODES.DRAFT", "META.TBD", "META.SLOT_ORDER_TIE", "RULE.AGG_SKIPPED",
                     "TEXT.TBD", "TEXT.REFERENCE", "ASSET.NAME_MISMATCH")
  warns <- findings[findings$severity == "WARN", ]
  warn_tab <- table(warns$check_id)
  bad_ids <- setdiff(names(warn_tab), allowed_warn)
  cat("WARN_TABLE:\n")
  if (length(warn_tab)) {
    for (nm in names(warn_tab)) cat(sprintf("  WARN %s = %d\n", nm, as.integer(warn_tab[nm])))
  } else {
    cat("  (no WARN findings)\n")
  }
  check("WP17.V2", length(bad_ids) == 0,
        sprintf("WARN check_ids present: %s%s",
                if (length(warn_tab)) paste(sprintf("%s=%d", names(warn_tab), as.integer(warn_tab)), collapse = ", ") else "(none)",
                if (length(bad_ids)) sprintf("; UNEXPECTED (not in allowed list): %s", paste(bad_ids, collapse = ",")) else ""))
}, error = function(e) {
  cat(sprintf("ERROR in validate.R block: %s\n", conditionMessage(e)))
  check("WP17.V1", FALSE, paste("error:", conditionMessage(e)))
  check("WP17.V2", FALSE, paste("error:", conditionMessage(e)))
})

# --- WP17.V4 : pipeline/convert_legacy.R reproduces data/ byte for byte ---
tryCatch({
  out_root <- tempfile()
  dir.create(out_root, recursive = TRUE)
  v4_status <- run_script("pipeline/convert_legacy.R",
    c("--root", shQuote(root), "--country", "ALL", "--timestamp", "2026-01-01T00:00:00Z",
      "--out-root", shQuote(out_root)))
  v4_files <- c("AFW360_HH_GNB_2021.csv", "AFW360_HH_GNB_2021_manifest.csv",
                "AFW360_HH_SEN_2021.csv", "AFW360_HH_SEN_2021_manifest.csv")
  v4_bad <- character(0)
  for (f in v4_files) {
    gen <- file.path(out_root, "data", f)
    want <- blob_bytes(file.path("data", f))
    got <- if (file.exists(gen)) readBin(gen, "raw", file.size(gen)) else raw(0)
    if (!identical(got, want)) v4_bad <- c(v4_bad, f)
  }
  check("WP17.V4", identical(v4_status, 0L) && length(v4_bad) == 0,
        sprintf("convert_legacy.R --country ALL --timestamp 2026-01-01T00:00:00Z exit=%s; byte-identical to HEAD:data/: %d/%d%s",
                v4_status, length(v4_files) - length(v4_bad), length(v4_files),
                if (length(v4_bad)) sprintf(" (mismatched: %s)", paste(v4_bad, collapse = ",")) else ""))
}, error = function(e) {
  cat(sprintf("ERROR in convert_legacy.R block: %s\n", conditionMessage(e)))
  check("WP17.V4", FALSE, paste("error:", conditionMessage(e)))
})

# --- WP17.V5 : every codelist row and every data-file manifest is DRAFT ---
tryCatch({
  codelist_dir <- file.path(root, "metadata", "codelists")
  codelist_files <- list.files(codelist_dir, pattern = "\\.csv$", full.names = TRUE)
  v5_bad <- character(0)
  for (f in codelist_files) {
    d <- read_csv_char(f)
    if (!("status" %in% names(d)) || !all(d$status == "DRAFT")) v5_bad <- c(v5_bad, basename(f))
  }
  manifests <- c(file.path(root, "data", "AFW360_HH_SEN_2021_manifest.csv"),
                 file.path(root, "data", "AFW360_HH_GNB_2021_manifest.csv"))
  for (mf in manifests) {
    m <- read_csv_char(mf)
    st <- m$value[m$key == "status"]
    if (!identical(st, "DRAFT")) v5_bad <- c(v5_bad, basename(mf))
  }
  check("WP17.V5", length(v5_bad) == 0,
        sprintf("%d codelists + %d manifests checked for status DRAFT; not DRAFT: %s",
                length(codelist_files), length(manifests),
                if (length(v5_bad)) paste(v5_bad, collapse = ",") else "none"))
}, error = function(e) {
  cat(sprintf("ERROR in WP17.V5 block: %s\n", conditionMessage(e)))
  check("WP17.V5", FALSE, paste("error:", conditionMessage(e)))
})

# --- WP17.V6 : data_raw/CHECKSUMS.sha256 verifies for all 122 files ---
tryCatch({
  chk_path <- file.path(root, "data_raw", "CHECKSUMS.sha256")
  chk_lines <- readLines(chk_path, encoding = "UTF-8", warn = FALSE)
  chk_lines <- chk_lines[nzchar(chk_lines)]
  v6_bad <- character(0)
  for (ln in chk_lines) {
    m <- regmatches(ln, regexec("^([0-9a-fA-F]{64})\\s+\\*?(.+)$", ln))[[1]]
    if (length(m) != 3) { v6_bad <- c(v6_bad, paste("unparsed:", ln)); next }
    want_hash <- tolower(m[2]); rel <- m[3]
    fp <- file.path(root, rel)
    if (!file.exists(fp)) { v6_bad <- c(v6_bad, paste0(rel, ":MISSING")); next }
    got_hash <- tolower(digest::digest(fp, algo = "sha256", file = TRUE))
    if (!identical(got_hash, want_hash)) v6_bad <- c(v6_bad, paste0(rel, ":MISMATCH"))
  }
  check("WP17.V6", length(chk_lines) == 122 && length(v6_bad) == 0,
        sprintf("data_raw/CHECKSUMS.sha256 lists %d files, %d verified OK%s",
                length(chk_lines), length(chk_lines) - length(v6_bad),
                if (length(v6_bad)) sprintf("; problems: %s", paste(utils::head(v6_bad, 10), collapse = "; ")) else ""))
}, error = function(e) {
  cat(sprintf("ERROR in WP17.V6 block: %s\n", conditionMessage(e)))
  check("WP17.V6", FALSE, paste("error:", conditionMessage(e)))
})

## ---- 5. Exit ----------------------------------------------------------------------
cat(if (length(.failures)) sprintf("\n%d check(s) failed: %s\n", length(.failures), paste(.failures, collapse = ", ")) else "\nAll checks passed.\n")
quit(status = if (length(.failures)) 1L else 0L, save = "no")
