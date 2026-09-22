#!/usr/bin/env Rscript
# Acceptance script for WP09 (Legacy maps).
#
#   Rscript pipeline/acceptance/wp09_legacy-maps.R --root .
#
# Standalone: does not source pipeline/R/. Expected numbers come from
# contract/expected_counts.csv, looked up by check_id. Writes only to
# tempdir().

suppressPackageStartupMessages({
  library(readxl)
})

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
header_of <- function(file) {
  h <- read_csv_char(file.path(contract, "csv_headers.csv")); h <- h[h$file == file, ]
  h$column[order(as.integer(h$position))]
}
run_script <- function(script, script_args) {
  log <- tempfile(fileext = ".log")
  status <- system2("Rscript", c(shQuote(file.path(root, script)), script_args), stdout = log, stderr = log)
  list(status = status, log = log)
}
same_file <- function(a, b) file.exists(a) && file.exists(b) && identical(unname(tools::md5sum(a)), unname(tools::md5sum(b)))

## ---- 3. Domain helpers ---------------------------------------------------------

# Contract seeds (whole, per the card's Read section).
triage      <- read_csv_char(file.path(contract, "label_triage.csv"))
nat_cols    <- read_csv_char(file.path(contract, "legacy_national_columns.csv"))
geo_codes   <- read_csv_char(file.path(contract, "geo_codes.csv"))
overrides_s <- read_csv_char(file.path(contract, "legacy_overrides.csv"))

# Implementer's outputs.
plans_dir <- file.path(root, "metadata", "plans")
ll_path <- file.path(plans_dir, "LEGACY_LABELS.csv")
lc_path <- file.path(plans_dir, "LEGACY_COLUMNS.csv")
lo_path <- file.path(plans_dir, "LEGACY_OVERRIDES.csv")
ll <- read_csv_char(ll_path)
lc <- read_csv_char(lc_path)
lo <- read_csv_char(lo_path)

# Raw workbooks, read once.
wb_path <- function(iso3) file.path(root, "data_raw", "tables", paste0("Tables_", iso3, ".xlsx"))
sheets_for <- list(SEN = c("National", "ADM 1", "ZAE", "Departement"),
                    GNB = c("National", "ADM 1", "ZAE"))
read_sheet <- function(iso3, sheet) {
  df <- as.data.frame(readxl::read_excel(wb_path(iso3), sheet = sheet, col_types = "text"),
                       stringsAsFactors = FALSE)
  names(df)[1] <- "indicator"
  df
}
wb <- list()
for (iso3 in names(sheets_for)) {
  wb[[iso3]] <- list()
  for (sh in sheets_for[[iso3]]) wb[[iso3]][[sh]] <- read_sheet(iso3, sh)
}

canon_sheet <- function(s) ifelse(s %in% c("National", "ADM 1", "ZAE"), "*", s)
is_blank <- function(v) is.na(v) | trimws(v) == ""

# All (ref_area, sheet, label) triples present in the raw workbooks.
wb_label_rows <- do.call(rbind, lapply(names(wb), function(iso3) {
  do.call(rbind, lapply(names(wb[[iso3]]), function(sh) {
    labs <- wb[[iso3]][[sh]]$indicator
    labs <- labs[!is_blank(labs)]
    if (!length(labs)) return(NULL)
    data.frame(ref_area = iso3, sheet = sh, label = labs, stringsAsFactors = FALSE)
  }))
}))

# All (ref_area, sheet, column) triples present in the raw workbooks.
wb_col_rows <- do.call(rbind, lapply(names(wb), function(iso3) {
  do.call(rbind, lapply(names(wb[[iso3]]), function(sh) {
    cols <- setdiff(names(wb[[iso3]][[sh]]), "indicator")
    if (!length(cols)) return(NULL)
    data.frame(ref_area = iso3, sheet = sh, column = cols, stringsAsFactors = FALSE)
  }))
}))

# Lookup: (canon_sheet, label) -> triage row index (single row expected).
triage_key <- paste(triage$sheet, triage$legacy_label, sep = "")
triage_idx_of <- function(canon_sh, label) {
  key <- paste(canon_sh, label, sep = "")
  m <- match(key, triage_key)
  m
}

get_label_row <- function(iso3, sheet, label) {
  df <- wb[[iso3]][[sheet]]
  idx <- which(df$indicator == label)
  if (length(idx) != 1) return(NULL)
  df[idx, setdiff(names(df), "indicator"), drop = FALSE]
}

# Expand a LEGACY_OVERRIDES / seed row (with possible '*' wildcards) into the
# concrete (ref_area, sheet, column, label) cells it targets, restricted to
# cells that actually exist in the raw workbooks. `map_labels_only` restricts
# a wildcard legacy_label to labels whose triage action is MAP.
expand_override_row <- function(ref_area, sheet, column, legacy_label, map_labels_only) {
  sheets <- if (sheet == "*") c("National", "ADM 1", "ZAE") else sheet
  out <- list()
  for (sh in sheets) {
    df <- wb[[ref_area]][[sh]]
    if (is.null(df)) next
    cols <- if (column == "*") setdiff(names(df), "indicator") else intersect(column, names(df))
    if (!length(cols)) next
    if (legacy_label == "*") {
      labs <- df$indicator[!is_blank(df$indicator)]
      if (map_labels_only) {
        keep <- vapply(labs, function(l) {
          ti <- triage_idx_of(canon_sheet(sh), l)
          !is.na(ti) && triage$action[ti] == "MAP"
        }, logical(1))
        labs <- labs[keep]
      }
    } else {
      labs <- legacy_label
      if (map_labels_only) {
        ti <- triage_idx_of(canon_sheet(sh), legacy_label)
        if (is.na(ti) || triage$action[ti] != "MAP") labs <- character(0)
      }
      labs <- intersect(labs, df$indicator[!is_blank(df$indicator)])
    }
    if (!length(labs)) next
    for (col in cols) {
      for (l in labs) out[[length(out) + 1]] <- data.frame(ref_area = ref_area, sheet = sh, column = col, label = l, stringsAsFactors = FALSE)
    }
  }
  if (!length(out)) return(data.frame(ref_area = character(0), sheet = character(0), column = character(0), label = character(0)))
  do.call(rbind, out)
}

## ---- 4. Checks ------------------------------------------------------------------

## WP09.A1: every (sheet, label) pair of both workbooks matches exactly one
## LEGACY_LABELS row, byte for byte. A '*' row stands for the three sheets.
## The file has META.LEGACY_LABELS rows.
try_check("WP09.A1", {
  ll_expanded <- do.call(rbind, lapply(seq_len(nrow(ll)), function(r) {
    sh <- ll$sheet[r]; lab <- ll$legacy_label[r]
    sheets <- if (sh == "*") c("National", "ADM 1", "ZAE") else sh
    data.frame(sheet = sheets, label = lab, stringsAsFactors = FALSE)
  }))
  key_wb <- paste(wb_label_rows$sheet, wb_label_rows$label, sep = "")
  key_ll <- paste(ll_expanded$sheet, ll_expanded$label, sep = "")
  tab_ll <- table(key_ll)
  match_counts <- tab_ll[key_wb]
  match_counts[is.na(match_counts)] <- 0L
  all_one <- all(match_counts == 1)
  bad <- unique(key_wb[match_counts != 1])
  row_count_ok <- nrow(ll) == expected("META.LEGACY_LABELS")$value
  check("WP09.A1", all_one && row_count_ok,
        sprintf("LEGACY_LABELS rows=%d (expected %d); wb (sheet,label) pairs=%d, all matched exactly once=%s%s",
                nrow(ll), expected("META.LEGACY_LABELS")$value, nrow(unique(wb_label_rows[, c("sheet", "label")])),
                all_one, if (!all_one) paste0("; first bad: ", paste(head(bad, 3), collapse = " | ")) else ""))
})

## WP09.A2: every (ref_area, sheet, column) of both workbooks matches exactly
## one LEGACY_COLUMNS row. Every GEO equals geo_codes.csv, and estimateSAB
## maps to GW08. Every URBANISATION and COMP_BREAKDOWN equals
## legacy_national_columns.csv.
try_check("WP09.A2", {
  key_wb <- paste(wb_col_rows$ref_area, wb_col_rows$sheet, wb_col_rows$column, sep = "")
  key_lc <- paste(lc$ref_area, lc$sheet, lc$column, sep = "")
  tab_lc <- table(key_lc)
  match_counts <- tab_lc[key_wb]
  match_counts[is.na(match_counts)] <- 0L
  all_one <- all(match_counts == 1)
  row_count_ok <- nrow(lc) == expected("META.LEGACY_COLUMNS")$value

  adm_zae <- lc[lc$sheet %in% c("ADM 1", "ZAE"), ]
  geo_lookup <- setNames(geo_codes$code, paste(geo_codes$ref_area, geo_codes$legacy_sheet, geo_codes$legacy_column, sep = ""))
  adm_zae_expected_geo <- geo_lookup[paste(adm_zae$ref_area, adm_zae$sheet, adm_zae$column, sep = "")]
  geo_ok <- all(!is.na(adm_zae_expected_geo)) && all(adm_zae$GEO == unname(adm_zae_expected_geo))

  sab_row <- lc[lc$ref_area == "GNB" & lc$sheet == "ADM 1" & lc$column == "estimateSAB", ]
  sab_ok <- nrow(sab_row) == 1 && sab_row$GEO[1] == "GW08"

  nat <- lc[lc$sheet == "National", ]
  nat_lookup_urb <- setNames(nat_cols$URBANISATION, nat_cols$column)
  nat_lookup_comp <- setNames(nat_cols$COMP_BREAKDOWN, nat_cols$column)
  urb_ok <- all(nat$URBANISATION == unname(nat_lookup_urb[nat$column]))
  comp_ok <- all(nat$COMP_BREAKDOWN == unname(nat_lookup_comp[nat$column]))

  check("WP09.A2", all_one && row_count_ok && geo_ok && sab_ok && urb_ok && comp_ok,
        sprintf("rows=%d (expected %d); all matched once=%s; GEO ok=%s; estimateSAB->GW08=%s; URBANISATION ok=%s; COMP_BREAKDOWN ok=%s",
                nrow(lc), expected("META.LEGACY_COLUMNS")$value, all_one, geo_ok, sab_ok, urb_ok, comp_ok))
})

## WP09.A3: the MAP rows' series_id set equals the triage's, and scale equals
## the triage's as a number. No cell of the file contains 'e+'.
try_check("WP09.A3", {
  ll_map <- ll[ll$action == "MAP", ]
  tri_map <- triage[triage$action == "MAP", ]
  series_set_ok <- setequal(ll_map$series_id, tri_map$series_id)
  scale_match <- vapply(seq_len(nrow(ll_map)), function(r) {
    tri_row <- tri_map[tri_map$series_id == ll_map$series_id[r], ]
    if (nrow(tri_row) != 1) return(FALSE)
    isTRUE(all.equal(as.numeric(ll_map$scale[r]), as.numeric(tri_row$scale[1])))
  }, logical(1))
  scale_ok <- all(scale_match)
  # Scientific notation looks like "1e+06": a digit, then e/E, then +/-, then
  # a digit. A literal "e+" inside prose (e.g. "trade+transport") does not
  # match because it requires a digit immediately before the 'e'.
  raw_lines <- readLines(ll_path, encoding = "UTF-8", warn = FALSE)
  no_e_plus <- !any(grepl("[0-9][eE][+-][0-9]", raw_lines))
  check("WP09.A3", series_set_ok && scale_ok && no_e_plus,
        sprintf("series_id set equal=%s (ll MAP=%d, triage MAP=%d); scale matches=%d/%d; no 'e+' in file=%s",
                series_set_ok, nrow(ll_map), nrow(tri_map), sum(scale_match), length(scale_match), no_e_plus))
})

## WP09.A4: every duplicate_of and every assert_rule target is the series_id
## of a MAP row. Every rule holds on the raw data of both countries within
## its tolerance.
try_check("WP09.A4", {
  ll_map <- ll[ll$action == "MAP", ]
  map_series <- ll_map$series_id
  series_to_label <- setNames(ll_map$legacy_label, ll_map$series_id)

  dup_targets <- ll$duplicate_of[ll$duplicate_of != ""]
  dup_ok <- all(dup_targets %in% map_series)

  parse_rule <- function(rule) {
    m <- regmatches(rule, regexec("^(EQUALS|ONE_MINUS):([^ ]+)(?: tol=([0-9.]+))?$", rule, perl = TRUE))[[1]]
    if (length(m) == 0) return(NULL)
    list(op = m[2], target = m[3], tol = if (nchar(m[4]) > 0) as.numeric(m[4]) else 0)
  }

  rule_rows <- which(ll$assert_rule != "")
  target_ok <- logical(length(rule_rows))
  rule_holds <- logical(length(rule_rows))
  evid <- character(length(rule_rows))
  for (k in seq_along(rule_rows)) {
    r <- rule_rows[k]
    pr <- parse_rule(ll$assert_rule[r])
    if (is.null(pr) || !(pr$target %in% map_series)) {
      target_ok[k] <- FALSE; rule_holds[k] <- FALSE
      evid[k] <- sprintf("row %d: unparsable or unknown target in '%s'", r, ll$assert_rule[r])
      next
    }
    target_ok[k] <- TRUE
    label <- ll$legacy_label[r]
    target_label <- series_to_label[[pr$target]]
    max_dev <- 0; n_checked <- 0; ok <- TRUE
    for (iso3 in c("SEN", "GNB")) {
      for (sh in c("National", "ADM 1", "ZAE")) {
        src <- get_label_row(iso3, sh, label)
        tgt <- get_label_row(iso3, sh, target_label)
        if (is.null(src) || is.null(tgt)) next
        common_cols <- intersect(names(src), names(tgt))
        for (col in common_cols) {
          sv <- suppressWarnings(as.numeric(src[[col]][1]))
          tv <- suppressWarnings(as.numeric(tgt[[col]][1]))
          if (is.na(sv) || is.na(tv)) next
          n_checked <- n_checked + 1
          exp_v <- if (pr$op == "EQUALS") tv else (1 - tv)
          dev <- abs(sv - exp_v)
          if (dev > max_dev) max_dev <- dev
          if (dev > pr$tol + 1e-9) ok <- FALSE
        }
      }
    }
    rule_holds[k] <- ok && n_checked > 0
    evid[k] <- sprintf("row %d (%s %s): n=%d max_dev=%.6f tol=%.4f ok=%s", r, ll$assert_rule[r], label, n_checked, max_dev, pr$tol, rule_holds[k])
  }
  all_ok <- dup_ok && all(target_ok) && all(rule_holds)
  check("WP09.A4", all_ok,
        sprintf("duplicate_of targets ok=%s (%d checked); assert_rule targets ok=%s; rules hold=%s; details: %s",
                dup_ok, length(dup_targets), all(target_ok), all(rule_holds), paste(evid, collapse = " || ")))
})

## WP09.A5: LEGACY_OVERRIDES has META.LEGACY_OVERRIDES rows that equal the
## seed. Its WITHHOLD rows cover exactly GNB.WITHHELD_CELLS cells of MAP
## labels, and every row targets a cell that exists.
try_check("WP09.A5", {
  shared_cols <- c("ref_area", "sheet", "column", "legacy_label", "action", "reason")
  row_count_ok <- nrow(lo) == expected("META.LEGACY_OVERRIDES")$value && nrow(lo) == nrow(overrides_s)
  seed_match <- row_count_ok && isTRUE(all.equal(
    as.data.frame(lo[, shared_cols], stringsAsFactors = FALSE),
    as.data.frame(overrides_s[, shared_cols], stringsAsFactors = FALSE)
  ))

  cell_sets <- lapply(seq_len(nrow(overrides_s)), function(r) {
    expand_override_row(overrides_s$ref_area[r], overrides_s$sheet[r], overrides_s$column[r],
                         overrides_s$legacy_label[r], map_labels_only = TRUE)
  })
  exists_ok <- vapply(cell_sets, nrow, integer(1)) > 0

  withhold_idx <- which(overrides_s$action == "WITHHOLD")
  withhold_cells <- do.call(rbind, cell_sets[withhold_idx])
  withhold_key <- unique(paste(withhold_cells$ref_area, withhold_cells$sheet, withhold_cells$column, withhold_cells$label, sep = ""))
  count_ok <- meets(length(withhold_key), "GNB.WITHHELD_CELLS")

  check("WP09.A5", seed_match && all(exists_ok) && count_ok,
        sprintf("rows=%d (expected %d); seed match=%s; every row targets existing cell=%s (%d/%d); withheld distinct cells=%d (expected %s)",
                nrow(lo), expected("META.LEGACY_OVERRIDES")$value, seed_match, all(exists_ok), sum(exists_ok), length(exists_ok),
                length(withhold_key), expected("GNB.WITHHELD_CELLS")$value))
})

## WP09.A6: applying the three files to the raw workbooks gives these counts:
## SEN rows, all non-empty; GNB rows, of which A non-empty and O empty.
try_check("WP09.A6", {
  match_override <- function(ref_area, sheet, column, label) {
    rows <- overrides_s[overrides_s$ref_area == ref_area &
                           (overrides_s$sheet == "*" | overrides_s$sheet == sheet) &
                           (overrides_s$column == "*" | overrides_s$column == column) &
                           (overrides_s$legacy_label == "*" | overrides_s$legacy_label == label), ]
    if (nrow(rows) == 0) return(NA_character_)
    if (any(rows$action == "WITHHOLD")) "WITHHOLD" else "COMMENT"
  }

  counts <- list(SEN = list(total = 0L, empty = 0L), GNB = list(total = 0L, empty = 0L, nonempty = 0L))
  for (iso3 in names(sheets_for)) {
    for (sh in sheets_for[[iso3]]) {
      df <- wb[[iso3]][[sh]]
      cs <- canon_sheet(sh)
      cols <- setdiff(names(df), "indicator")
      for (ridx in seq_len(nrow(df))) {
        label <- df$indicator[ridx]
        if (is_blank(label)) next
        ti <- triage_idx_of(cs, label)
        if (is.na(ti) || triage$action[ti] != "MAP") next
        for (col in cols) {
          ov <- match_override(iso3, sh, col, label)
          if (!is.na(ov) && ov == "WITHHOLD") next
          val <- df[[col]][ridx]
          empty <- is_blank(val)
          counts[[iso3]]$total <- counts[[iso3]]$total + 1L
          if (empty) counts[[iso3]]$empty <- counts[[iso3]]$empty + 1L
        }
      }
    }
  }
  sen_ok <- meets(counts$SEN$total, "DATA.SEN.ROWS") && counts$SEN$empty == 0
  gnb_total_ok <- meets(counts$GNB$total, "GNB.DATA.ROWS")
  gnb_nonempty <- counts$GNB$total - counts$GNB$empty
  gnb_a_ok <- meets(gnb_nonempty, "GNB.DATA.ROWS.A")
  gnb_o_ok <- meets(counts$GNB$empty, "GNB.DATA.ROWS.O")

  check("WP09.A6", sen_ok && gnb_total_ok && gnb_a_ok && gnb_o_ok,
        sprintf("SEN rows=%d (expected %d, empty=%d); GNB rows=%d (expected %d), A=%d (expected %d), O=%d (expected %d)",
                counts$SEN$total, expected("DATA.SEN.ROWS")$value, counts$SEN$empty,
                counts$GNB$total, expected("GNB.DATA.ROWS")$value,
                gnb_nonempty, expected("GNB.DATA.ROWS.A")$value,
                counts$GNB$empty, expected("GNB.DATA.ROWS.O")$value))
})

## WP09.A7: the headers equal csv_headers.csv, and --out-root <tempdir>
## reproduces the three files byte for byte.
try_check("WP09.A7", {
  header_ok <- identical(names(ll), header_of("LEGACY_LABELS.csv")) &&
    identical(names(lc), header_of("LEGACY_COLUMNS.csv")) &&
    identical(names(lo), header_of("LEGACY_OVERRIDES.csv"))

  out_root <- file.path(tempdir(), paste0("wp09_out_", as.integer(Sys.time())))
  dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
  res <- run_script(file.path("pipeline", "bootstrap", "build_legacy_maps.R"),
                     c("--root", shQuote(root), "--out-root", shQuote(out_root)))
  ran_ok <- res$status == 0

  repro_ok <- ran_ok &&
    same_file(file.path(out_root, "metadata", "plans", "LEGACY_LABELS.csv"), ll_path) &&
    same_file(file.path(out_root, "metadata", "plans", "LEGACY_COLUMNS.csv"), lc_path) &&
    same_file(file.path(out_root, "metadata", "plans", "LEGACY_OVERRIDES.csv"), lo_path)

  log_tail <- if (!ran_ok || !repro_ok) paste(tail(readLines(res$log, warn = FALSE), 10), collapse = " / ") else ""
  check("WP09.A7", header_ok && repro_ok,
        sprintf("headers ok=%s; script exit=%s; out-root reproduces byte for byte=%s%s",
                header_ok, res$status, repro_ok, if (nchar(log_tail)) paste0("; log tail: ", log_tail) else ""))
})

## ---- 5. Exit ----------------------------------------------------------------------
cat(if (length(.failures)) sprintf("\n%d check(s) failed: %s\n", length(.failures), paste(.failures, collapse = ", ")) else "\nAll checks passed.\n")
quit(status = if (length(.failures)) 1L else 0L, save = "no")
