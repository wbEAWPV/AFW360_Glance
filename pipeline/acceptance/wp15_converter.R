#!/usr/bin/env Rscript
# Acceptance script for WP15 (Legacy converter).
#
#   Rscript pipeline/acceptance/wp15_converter.R --root .
#
# Standalone: does not source pipeline/R/. Rebuilds the expected output
# independently from the card's rules, the metadata plans and the legacy
# workbooks, and compares it to the committed data files.

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

suppressPackageStartupMessages({
  library(readxl)
})

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
blob_bytes <- function(path, rev = "HEAD") {
  tmp <- tempfile(); on.exit(unlink(tmp))
  system2("git", c("-C", shQuote(root), "cat-file", "blob", shQuote(paste0(rev, ":", path))), stdout = tmp)
  readBin(tmp, "raw", file.size(tmp))
}
file_bytes <- function(path) readBin(path, "raw", file.size(path))
no_bom_no_cr <- function(bytes) !(length(bytes) >= 3 && identical(bytes[1:3], as.raw(c(0xef, 0xbb, 0xbf)))) && !any(bytes == as.raw(0x0d))
run_cmd <- function(cmd, cmd_args) {
  out <- suppressWarnings(system2(cmd, cmd_args, stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status"); if (is.null(status)) status <- 0L
  list(status = status, output = paste(out, collapse = "\n"))
}

## ---- 3. Load metadata (own reader; not pipeline/R/) --------------------------
m <- function(...) read_csv_char(file.path(root, "metadata", ...))
LEGACY_LABELS    <- m("plans", "LEGACY_LABELS.csv")
LEGACY_COLUMNS   <- m("plans", "LEGACY_COLUMNS.csv")
LEGACY_OVERRIDES <- m("plans", "LEGACY_OVERRIDES.csv")
SERIES_PLAN      <- m("plans", "SERIES_PLAN.csv")
SURVEYS          <- m("surveys", "SURVEYS.csv")
CL_INDICATOR       <- m("codelists", "CL_INDICATOR.csv")
CL_BRK_VAR          <- m("codelists", "CL_BRK_VAR.csv")
CL_QUAL_VAR         <- m("codelists", "CL_QUAL_VAR.csv")
CL_COMP_BREAKDOWN   <- m("codelists", "CL_COMP_BREAKDOWN.csv")
CL_QUALIFIER        <- m("codelists", "CL_QUALIFIER.csv")
DSD <- read_csv_char(file.path(root, "metadata", "structure", "DSD_AFW360_HH.csv"))
DSD <- DSD[order(as.integer(DSD$position)), ]
DSD_ID <- DSD$id
KEY_COLS <- DSD_ID[1:18]
META_VERSION <- trimws(readLines(file.path(root, "metadata", "VERSION"), warn = FALSE)[1])

stat_unit_of <- setNames(CL_INDICATOR$stat_unit, CL_INDICATOR$code)
comp_var_of  <- setNames(CL_COMP_BREAKDOWN$var_code, CL_COMP_BREAKDOWN$code)
brk_slot_of  <- setNames(suppressWarnings(as.numeric(CL_BRK_VAR$slot_order)), CL_BRK_VAR$code)
qual_var_of  <- setNames(CL_QUALIFIER$var_code, CL_QUALIFIER$code)
qslot_of     <- setNames(suppressWarnings(as.numeric(CL_QUAL_VAR$slot_order)), CL_QUAL_VAR$code)

sort_by_slot <- function(codes, var_of, slot_of) {
  codes <- codes[trimws(codes) != ""]
  if (length(codes) <= 1) return(codes)
  key <- slot_of[var_of[codes]]
  codes[order(key)]
}
pad5 <- function(codes, pad) c(codes, rep(pad, 5 - length(codes)))
split_ws <- function(x) { x <- trimws(x); if (identical(x, "")) character(0) else strsplit(x, "\\s+")[[1]] }

## ---- 4. Independently rebuild expected rows from the metadata + workbooks ----
# Returns list(rows = data.frame of expected key/value/status/comment for kept
# cells, withheld_keys = character vector of "|"-joined 18-col keys).
build_expected <- function(country) {
  wb_path <- file.path(root, "data_raw", "tables", paste0("Tables_", country, ".xlsx"))
  sheets <- c("National", "ADM 1", "ZAE")
  surv <- SURVEYS[SURVEYS$ref_area == country, ]
  if (nrow(surv) != 1) stop("SURVEYS.csv does not have exactly one row for ", country)
  time_period <- surv$time_period
  survey_id <- surv$survey_id

  cols_all <- LEGACY_COLUMNS[LEGACY_COLUMNS$ref_area == country & LEGACY_COLUMNS$action == "MAP", ]
  labels_all <- LEGACY_LABELS[LEGACY_LABELS$action == "MAP", ]
  ov <- LEGACY_OVERRIDES[LEGACY_OVERRIDES$ref_area == country, ]

  rows <- vector("list", 0)
  withheld <- character(0)
  unmapped <- character(0)

  for (sh in sheets) {
    cols_sh <- cols_all[cols_all$sheet == sh, ]
    if (nrow(cols_sh) == 0) next
    labs_sh <- labels_all[labels_all$sheet == sh | labels_all$sheet == "*", ]
    df <- as.data.frame(read_excel(wb_path, sheet = sh, col_types = "text"))
    ind_col <- df[[1]]
    for (ci in seq_len(nrow(cols_sh))) {
      crow <- cols_sh[ci, ]
      colname <- crow$column
      if (!(colname %in% names(df))) { unmapped <- c(unmapped, paste0(sh, "/", colname, ": column not in workbook")); next }
      for (li in seq_len(nrow(labs_sh))) {
        lrow <- labs_sh[li, ]
        lbl <- lrow$legacy_label
        idx <- match(lbl, ind_col)
        if (is.na(idx)) { unmapped <- c(unmapped, paste0(sh, "/", colname, "/", lbl, ": label not in workbook")); next }
        raw_chr <- df[[colname]][idx]
        raw_empty <- is.na(raw_chr) || trimws(raw_chr) == ""

        srow <- SERIES_PLAN[SERIES_PLAN$series_id == lrow$series_id, ]
        if (nrow(srow) != 1) stop("SERIES_PLAN.csv does not have exactly one row for series_id ", lrow$series_id)
        indicator <- srow$INDICATOR
        su <- stat_unit_of[[indicator]]
        sex_age <- if (identical(su, "IND")) "_T" else "_Z"

        geo <- if (trimws(crow$GEO) == "") "_T" else crow$GEO
        urb <- if (trimws(crow$URBANISATION) == "") "_T" else crow$URBANISATION

        brk <- c(crow$COMP_BREAKDOWN, srow$DEFINING_BREAKDOWN)
        brk <- sort_by_slot(brk, comp_var_of, brk_slot_of)
        brk <- pad5(brk, "_T")

        qual <- sort_by_slot(split_ws(srow$MEASURE_QUALS), qual_var_of, qslot_of)
        qual <- pad5(qual, "_Z")

        key <- c("AFW360_HH", country, geo, time_period, indicator, sex_age, sex_age, urb, brk, qual)
        key_str <- paste(key, collapse = "|")

        ov_match <- ov[(ov$sheet == sh | ov$sheet == "*") &
                       (ov$column == colname | ov$column == "*") &
                       (ov$legacy_label == lbl | ov$legacy_label == "*"), ]
        ov_withhold <- any(ov_match$action == "WITHHOLD")
        ov_comments <- ov_match$obs_comment[ov_match$action == "COMMENT"]

        if (ov_withhold) {
          withheld <- c(withheld, key_str)
          next
        }
        scale <- as.numeric(lrow$scale)
        if (raw_empty) {
          obs_value <- NA_real_
          obs_status <- "O"
          base_comment <- sprintf("LEGACY_EMPTY: empty cell in sheet '%s', column '%s'", sh, colname)
          full_comment <- if (length(ov_comments)) paste(c(base_comment, ov_comments), collapse = " | ") else base_comment
        } else {
          obs_value <- round(as.numeric(raw_chr) * scale, 10)
          obs_status <- "A"
          full_comment <- if (length(ov_comments)) paste(ov_comments, collapse = " | ") else ""
        }
        rows[[length(rows) + 1]] <- data.frame(
          key = key_str, obs_status = obs_status, obs_value = obs_value,
          raw = if (raw_empty) NA_character_ else raw_chr, scale = scale,
          obs_comment = full_comment, has_comment_override = length(ov_comments) > 0,
          sheet = sh, column = colname, legacy_label = lbl,
          stringsAsFactors = FALSE
        )
      }
    }
  }
  list(
    rows = if (length(rows)) do.call(rbind, rows) else data.frame(),
    withheld_keys = withheld,
    unmapped = unmapped
  )
}

exp_build <- tryCatch(list(SEN = build_expected("SEN"), GNB = build_expected("GNB")),
                       error = function(e) e)
build_ok <- !inherits(exp_build, "error")
if (!build_ok) cat("build_expected() failed:", conditionMessage(exp_build), "\n")

## ---- 5. Read the actual outputs ----------------------------------------------
data_path <- function(cc) file.path(root, "data", sprintf("AFW360_HH_%s_2021.csv", cc))
manifest_path <- function(cc) file.path(root, "data", sprintf("AFW360_HH_%s_2021_manifest.csv", cc))

sen <- tryCatch(read_csv_char(data_path("SEN")), error = function(e) NULL)
gnb <- tryCatch(read_csv_char(data_path("GNB")), error = function(e) NULL)
sen_man <- tryCatch(read_csv_char(manifest_path("SEN")), error = function(e) NULL)
gnb_man <- tryCatch(read_csv_char(manifest_path("GNB")), error = function(e) NULL)

key_string <- function(df) apply(as.matrix(df[, KEY_COLS, drop = FALSE]), 1, paste, collapse = "|")

## ---- 6. Checks ------------------------------------------------------------------

## WP15.A1 -- header of both data files matches DSD_AFW360_HH.csv id order.
try_check("WP15.A1", {
  ok <- !is.null(sen) && !is.null(gnb) && identical(names(sen), DSD_ID) && identical(names(gnb), DSD_ID)
  check("WP15.A1", ok, sprintf("SEN header match=%s, GNB header match=%s",
        !is.null(sen) && identical(names(sen), DSD_ID), !is.null(gnb) && identical(names(gnb), DSD_ID)))
})

## WP15.A2 -- SEN row count and all A.
try_check("WP15.A2", {
  ok <- !is.null(sen) && meets(nrow(sen), "DATA.SEN.ROWS") && all(sen$OBS_STATUS == "A")
  check("WP15.A2", ok, sprintf("SEN rows=%s, all A=%s", if (!is.null(sen)) nrow(sen) else NA,
        if (!is.null(sen)) all(sen$OBS_STATUS == "A") else NA))
})

## WP15.A3 -- GNB row count, A count, O count.
try_check("WP15.A3", {
  n <- if (!is.null(gnb)) nrow(gnb) else NA
  na <- if (!is.null(gnb)) sum(gnb$OBS_STATUS == "A") else NA
  no <- if (!is.null(gnb)) sum(gnb$OBS_STATUS == "O") else NA
  ok <- !is.null(gnb) && meets(n, "GNB.DATA.ROWS") && meets(na, "GNB.DATA.ROWS.A") && meets(no, "GNB.DATA.ROWS.O")
  check("WP15.A3", ok, sprintf("GNB rows=%s, A=%s, O=%s", n, na, no))
})

## WP15.A4 -- 18-col key unique and non-empty in both files.
try_check("WP15.A4", {
  chk_one <- function(df) {
    if (is.null(df)) return(list(unique = FALSE, nonempty = FALSE))
    ks <- key_string(df)
    list(unique = !any(duplicated(ks)), nonempty = !any(df[, KEY_COLS] == ""))
  }
  rs <- chk_one(sen); rg <- chk_one(gnb)
  ok <- rs$unique && rs$nonempty && rg$unique && rg$nonempty
  check("WP15.A4", ok, sprintf("SEN unique=%s nonempty=%s; GNB unique=%s nonempty=%s",
        rs$unique, rs$nonempty, rg$unique, rg$nonempty))
})

## WP15.A5 -- for every A row, value/scale equals source cell within 1e-9;
## traced through the whole rebuilt expected table (both countries).
try_check("WP15.A5", {
  if (!build_ok) {
    check("WP15.A5", FALSE, paste("expected-build error:", conditionMessage(exp_build)))
  } else {
    bad <- character(0)
    n_checked <- 0
    for (cc in c("SEN", "GNB")) {
      actual <- if (cc == "SEN") sen else gnb
      exp <- exp_build[[cc]]$rows
      if (is.null(actual) || nrow(exp) == 0) next
      a_rows <- actual[actual$OBS_STATUS == "A", ]
      a_keys <- key_string(a_rows)
      exp_a <- exp[exp$obs_status == "A", ]
      # every actual A row must correspond to exactly one expected A cell, and vice versa
      missing_in_exp <- setdiff(a_keys, exp_a$key)
      missing_in_actual <- setdiff(exp_a$key, a_keys)
      if (length(missing_in_exp)) bad <- c(bad, paste0(cc, ": actual A row with no expected match: ", head(missing_in_exp, 3)))
      if (length(missing_in_actual)) bad <- c(bad, paste0(cc, ": expected A cell missing from actual: ", head(missing_in_actual, 3)))
      m <- match(a_keys, exp_a$key)
      ok_m <- !is.na(m)
      av <- suppressWarnings(as.numeric(a_rows$OBS_VALUE[ok_m]))
      ev <- exp_a[m[ok_m], ]
      dev <- abs(av / ev$scale - as.numeric(ev$raw))
      n_checked <- n_checked + length(dev)
      bad_idx <- which(dev > 1e-9 | is.na(dev))
      if (length(bad_idx)) bad <- c(bad, paste0(cc, ": value mismatch at key ", head(ev$key[bad_idx], 3)))
    }
    ok <- length(bad) == 0 && n_checked > 0
    check("WP15.A5", ok, sprintf("checked %d A rows across both countries; issues=%s", n_checked,
          if (length(bad)) paste(head(bad, 5), collapse = " ; ") else "none"))
  }
})

## WP15.A6 -- every O row's comment starts with LEGACY_EMPTY:; no withheld
## cell has a row; every COMMENT-override cell carries its obs_comment.
try_check("WP15.A6", {
  if (!build_ok) {
    check("WP15.A6", FALSE, paste("expected-build error:", conditionMessage(exp_build)))
  } else {
    bad <- character(0)
    for (cc in c("SEN", "GNB")) {
      actual <- if (cc == "SEN") sen else gnb
      exp <- exp_build[[cc]]$rows
      wk <- exp_build[[cc]]$withheld_keys
      if (is.null(actual)) next
      a_keys <- key_string(actual)
      # O rows carry LEGACY_EMPTY: prefix
      o_rows <- actual[actual$OBS_STATUS == "O", ]
      bad_o <- !startsWith(o_rows$OBS_COMMENT, "LEGACY_EMPTY:")
      if (any(bad_o)) bad <- c(bad, paste0(cc, ": O row without LEGACY_EMPTY: prefix, n=", sum(bad_o)))
      # withheld cells absent from output
      present <- intersect(wk, a_keys)
      if (length(present)) bad <- c(bad, paste0(cc, ": withheld key present in output: ", head(present, 3)))
      # COMMENT-override cells carry the exact expected comment
      com <- exp[exp$has_comment_override, ]
      if (nrow(com)) {
        m <- match(com$key, a_keys)
        miss <- is.na(m)
        if (any(miss)) bad <- c(bad, paste0(cc, ": comment-override cell missing from output: ", head(com$key[miss], 3)))
        got <- actual$OBS_COMMENT[m[!miss]]
        want <- com$obs_comment[!miss]
        mism <- which(got != want)
        if (length(mism)) bad <- c(bad, paste0(cc, ": comment mismatch at key ", head(com$key[!miss][mism], 3)))
      }
    }
    ok <- length(bad) == 0
    check("WP15.A6", ok, if (ok) "O comments, withheld keys and override comments all match" else paste(head(bad, 6), collapse = " ; "))
  }
})

## WP15.A7 -- SEX/AGE = _Z iff stat_unit != IND, else _T.
try_check("WP15.A7", {
  chk <- function(df) {
    if (is.null(df)) return(FALSE)
    su <- stat_unit_of[df$INDICATOR]
    want <- ifelse(is.na(su), NA, ifelse(su == "IND", "_T", "_Z"))
    all(!is.na(want)) && all(df$SEX == want) && all(df$AGE == want)
  }
  ok <- chk(sen) && chk(gnb)
  check("WP15.A7", ok, sprintf("SEN ok=%s, GNB ok=%s", chk(sen), chk(gnb)))
})

## WP15.A8 -- manifest structure, keys, values.
try_check("WP15.A8", {
  want_keys <- c("dataflow","dsd_version","metadata_version","ref_area","time_period",
                 "source_type","survey_id","precision","file_name","n_rows","producer",
                 "program","software","run_timestamp","status","notes")
  chk_manifest <- function(man, cc, dat) {
    if (is.null(man)) return("manifest missing")
    issues <- character(0)
    if (!identical(names(man), c("key","value"))) issues <- c(issues, "bad columns")
    if (!identical(man$key, want_keys)) issues <- c(issues, "bad key order/set")
    v <- setNames(man$value, man$key)
    surv <- SURVEYS[SURVEYS$ref_area == cc, ]
    if (!identical(v[["dataflow"]], "AFW360_HH")) issues <- c(issues, "dataflow")
    if (!identical(v[["dsd_version"]], META_VERSION)) issues <- c(issues, "dsd_version")
    if (!identical(v[["metadata_version"]], META_VERSION)) issues <- c(issues, "metadata_version")
    if (!identical(v[["ref_area"]], cc)) issues <- c(issues, "ref_area")
    if (nrow(surv) == 1 && !identical(v[["time_period"]], surv$time_period)) issues <- c(issues, "time_period")
    if (!identical(v[["source_type"]], "SURVEY")) issues <- c(issues, "source_type")
    if (nrow(surv) == 1 && !identical(v[["survey_id"]], surv$survey_id)) issues <- c(issues, "survey_id")
    if (!identical(v[["precision"]], "ROUNDED_2DP")) issues <- c(issues, "precision")
    if (!is.null(dat) && !identical(v[["n_rows"]], as.character(nrow(dat)))) issues <- c(issues, "n_rows")
    if (!identical(v[["status"]], "DRAFT")) issues <- c(issues, "status")
    issues
  }
  iss_sen <- chk_manifest(sen_man, "SEN", sen)
  iss_gnb <- chk_manifest(gnb_man, "GNB", gnb)
  ok <- length(iss_sen) == 0 && length(iss_gnb) == 0
  check("WP15.A8", ok, sprintf("SEN issues=%s; GNB issues=%s",
        if (length(iss_sen)) paste(iss_sen, collapse=",") else "none",
        if (length(iss_gnb)) paste(iss_gnb, collapse=",") else "none"))
})

## WP15.A9 -- two fresh runs are byte-identical to each other and to committed files.
try_check("WP15.A9", {
  out1 <- tempfile("wp15a9_1"); out2 <- tempfile("wp15a9_2")
  dir.create(out1); dir.create(out2)
  r1 <- run_cmd("Rscript", c(shQuote(file.path(root, "pipeline", "convert_legacy.R")),
                              "--root", shQuote(root), "--country", "ALL",
                              "--timestamp", "2026-01-01T00:00:00Z", "--out-root", shQuote(out1)))
  r2 <- run_cmd("Rscript", c(shQuote(file.path(root, "pipeline", "convert_legacy.R")),
                              "--root", shQuote(root), "--country", "ALL",
                              "--timestamp", "2026-01-01T00:00:00Z", "--out-root", shQuote(out2)))
  files <- c("data/AFW360_HH_SEN_2021.csv", "data/AFW360_HH_SEN_2021_manifest.csv",
             "data/AFW360_HH_GNB_2021.csv", "data/AFW360_HH_GNB_2021_manifest.csv")
  bad <- character(0)
  if (r1$status != 0) bad <- c(bad, paste("run1 exit", r1$status, r1$output))
  if (r2$status != 0) bad <- c(bad, paste("run2 exit", r2$status, r2$output))
  if (length(bad) == 0) {
    for (f in files) {
      p1 <- file.path(out1, f); p2 <- file.path(out2, f)
      if (!file.exists(p1) || !file.exists(p2)) { bad <- c(bad, paste(f, "missing from a run")); next }
      b1 <- file_bytes(p1); b2 <- file_bytes(p2); bh <- blob_bytes(f, "HEAD")
      if (!identical(b1, b2)) bad <- c(bad, paste(f, "run1 != run2"))
      if (!identical(b1, bh)) bad <- c(bad, paste(f, "run1 != committed HEAD"))
    }
  }
  unlink(out1, recursive = TRUE); unlink(out2, recursive = TRUE)
  ok <- length(bad) == 0
  check("WP15.A9", ok, if (ok) "two fresh runs match each other and HEAD" else paste(head(bad, 6), collapse = " ; "))
})

## WP15.A10 -- no scientific notation, no NA cells, no BOM, no CR (on the blobs).
try_check("WP15.A10", {
  files <- c("data/AFW360_HH_SEN_2021.csv", "data/AFW360_HH_SEN_2021_manifest.csv",
             "data/AFW360_HH_GNB_2021.csv", "data/AFW360_HH_GNB_2021_manifest.csv")
  bad <- character(0)
  for (f in files) {
    b <- blob_bytes(f, "HEAD")
    if (!no_bom_no_cr(b)) bad <- c(bad, paste(f, "BOM or CR"))
    txt <- rawToChar(b)
    if (grepl("[0-9][eE][+-][0-9]", txt)) bad <- c(bad, paste(f, "scientific notation"))
    lines <- strsplit(txt, "\n", fixed = TRUE)[[1]]
    if (length(lines) > 1) {
      cells <- unlist(strsplit(lines[-1], ",", fixed = TRUE))
      if (any(cells == "NA")) bad <- c(bad, paste(f, "literal NA cell"))
    }
  }
  ok <- length(bad) == 0
  check("WP15.A10", ok, if (ok) "no e+/e-, no NA, no BOM, no CR" else paste(bad, collapse = " ; "))
})

## WP15.A11 -- convert_legacy.R and convert_tables.R hold no legacy label,
## column or sheet name, or country code outside the usage message.
## (Targets exactly these two implementer files -- never this script itself.)
try_check("WP15.A11", {
  files <- c("pipeline/convert_legacy.R", "pipeline/R/convert_tables.R")
  bad <- character(0)
  map_sheets <- sort(unique(LEGACY_COLUMNS$sheet[LEGACY_COLUMNS$action == "MAP"]))  # "ADM 1" "National" "ZAE"
  all_labels <- unique(LEGACY_LABELS$legacy_label)
  for (f in files) {
    p <- file.path(root, f)
    if (!file.exists(p)) { bad <- c(bad, paste(f, "missing")); next }
    lines <- readLines(p, warn = FALSE)
    code_lines <- lines[!grepl("^\\s*#", lines)]
    corpus <- paste(code_lines, collapse = "\n")

    if (grepl("estimate", corpus, fixed = TRUE)) bad <- c(bad, paste(f, "contains 'estimate'"))

    hit_lbl <- all_labels[vapply(all_labels, function(l) grepl(l, corpus, fixed = TRUE), logical(1))]
    if (length(hit_lbl)) bad <- c(bad, paste0(f, ": legacy label text: ", head(hit_lbl, 2)))

    # documented constant exception: a single line holding exactly the MAP
    # sheet names together (and not "Departement") is allowed.
    is_wildcard_const <- grepl("National", code_lines, fixed = TRUE) &
                          grepl("ADM 1", code_lines, fixed = TRUE) &
                          grepl("ZAE", code_lines, fixed = TRUE) &
                          !grepl("Departement", code_lines, fixed = TRUE)
    sheet_corpus <- paste(code_lines[!is_wildcard_const], collapse = "\n")
    for (sh in c("National", "ADM 1", "ZAE", "Departement")) {
      if (grepl(sh, sheet_corpus, fixed = TRUE)) bad <- c(bad, paste(f, "contains sheet name", sh))
    }

    # country codes outside the usage message ("--country SEN|GNB|ALL").
    is_usage_line <- grepl("SEN|GNB", code_lines, fixed = TRUE)
    cc_corpus <- paste(code_lines[!is_usage_line], collapse = "\n")
    if (grepl("\\bSEN\\b", cc_corpus) || grepl("\\bGNB\\b", cc_corpus)) bad <- c(bad, paste(f, "contains a country code outside usage"))
  }
  ok <- length(bad) == 0
  check("WP15.A11", ok, if (ok) "no leaked labels/columns/sheets/country codes" else paste(bad, collapse = " ; "))
})

## WP15.A12 -- altering one LEGACY_LABELS.legacy_label makes the converter
## exit non-zero and name the unmapped label.
try_check("WP15.A12", {
  tmp_root <- tempfile("wp15a12_root"); dir.create(tmp_root)
  for (d in c("pipeline", "metadata", "content")) {
    src <- file.path(root, d)
    if (dir.exists(src)) file.copy(src, tmp_root, recursive = TRUE)
  }
  dir.create(file.path(tmp_root, "data_raw", "tables"), recursive = TRUE)
  file.copy(file.path(root, "data_raw", "tables", "Tables_SEN.xlsx"),
            file.path(tmp_root, "data_raw", "tables", "Tables_SEN.xlsx"))

  ll_path <- file.path(tmp_root, "metadata", "plans", "LEGACY_LABELS.csv")
  ll <- read_csv_char(ll_path)
  map_idx <- which(ll$action == "MAP")[1]
  original_label <- ll$legacy_label[map_idx]
  ll$legacy_label[map_idx] <- paste0(original_label, "_ALTERED_BY_A12")
  write.csv(ll, ll_path, row.names = FALSE, na = "")

  out_dir <- tempfile("wp15a12_out"); dir.create(out_dir)
  r <- run_cmd("Rscript", c(shQuote(file.path(tmp_root, "pipeline", "convert_legacy.R")),
                             "--root", shQuote(tmp_root), "--country", "SEN",
                             "--out-root", shQuote(out_dir)))
  names_it <- grepl(original_label, r$output, fixed = TRUE)
  ok <- r$status != 0 && names_it
  check("WP15.A12", ok, sprintf("exit=%s, names unmapped label=%s", r$status, names_it))
  unlink(tmp_root, recursive = TRUE); unlink(out_dir, recursive = TRUE)
})

## ---- 7. Exit ----------------------------------------------------------------------
cat(if (length(.failures)) sprintf("\n%d check(s) failed: %s\n", length(.failures), paste(.failures, collapse = ", ")) else "\nAll checks passed.\n")
quit(status = if (length(.failures)) 1L else 0L, save = "no")
