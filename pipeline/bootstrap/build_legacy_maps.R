#!/usr/bin/env Rscript
# pipeline/bootstrap/build_legacy_maps.R
#
# WP09 - Legacy maps. One-time generator (frozen after metadata 0.1.0,
# decision D11): builds the three files that tell the converter how every
# legacy label, column and defective cell maps to the standard.
#
#   Rscript pipeline/bootstrap/build_legacy_maps.R --root . --out-root .
#
# Reads:
#   pipeline/bootstrap/seeds/label_triage.csv
#   pipeline/bootstrap/seeds/legacy_national_columns.csv
#   pipeline/bootstrap/seeds/legacy_overrides.csv
#   pipeline/bootstrap/seeds/geo_codes.csv
#   data_raw/tables/Tables_SEN.xlsx, data_raw/tables/Tables_GNB.xlsx
#
# Writes:
#   metadata/plans/LEGACY_LABELS.csv
#   metadata/plans/LEGACY_COLUMNS.csv
#   metadata/plans/LEGACY_OVERRIDES.csv

suppressPackageStartupMessages({
  library(readxl)
})

## ---- 0. Args and shared code --------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
.get_flag <- function(flag, default) {
  i <- which(args == flag)
  if (length(i) == 1 && i < length(args)) args[i + 1] else default
}
root <- .get_flag("--root", ".")
source(file.path(root, "pipeline", "R", "io.R"))
out_root <- cli_arg(args, "--out-root", root)

seeds_dir <- file.path(root, "pipeline", "bootstrap", "seeds")
tables_dir <- file.path(root, "data_raw", "tables")

## ---- 1. Load seeds --------------------------------------------------------

triage <- read_std_csv(file.path(seeds_dir, "label_triage.csv"))
nat_cols_seed <- read_std_csv(file.path(seeds_dir, "legacy_national_columns.csv"))
overrides_seed <- read_std_csv(file.path(seeds_dir, "legacy_overrides.csv"))
geo_codes <- read_std_csv(file.path(seeds_dir, "geo_codes.csv"))

## ---- 2. Load workbooks -----------------------------------------------------

# Fixed sheet order: National, ADM 1, ZAE, Departement. Do not rely on
# readxl::excel_sheets() order (GNB's is National, ZAE, ADM 1) - each sheet
# is read by name, so this list is only the order we iterate/emit in.
SHEET_ORDER <- c("National", "ADM 1", "ZAE", "Departement")
COUNTRIES <- c("SEN", "GNB")
WORKBOOK <- c(SEN = file.path(tables_dir, "Tables_SEN.xlsx"),
              GNB = file.path(tables_dir, "Tables_GNB.xlsx"))

read_sheet <- function(country, sheet) {
  path <- WORKBOOK[[country]]
  avail <- readxl::excel_sheets(path)
  if (!(sheet %in% avail)) return(NULL)
  d <- as.data.frame(readxl::read_excel(path, sheet = sheet, col_types = "text"),
                      stringsAsFactors = FALSE)
  d
}

wb <- list()
for (cn in COUNTRIES) {
  wb[[cn]] <- list()
  for (sh in SHEET_ORDER) {
    wb[[cn]][[sh]] <- read_sheet(cn, sh)
  }
}

get_row_vals <- function(df, label) {
  r <- df[df$indicator == label, -1, drop = FALSE]
  if (nrow(r) != 1) {
    stop("expected exactly one row for label '", label, "', found ", nrow(r))
  }
  trimws(as.character(unlist(r, use.names = FALSE)))
}

get_cell <- function(df, label, column) {
  r <- df[df$indicator == label, column, drop = TRUE]
  if (length(r) != 1) {
    stop("expected exactly one row for label '", label, "' / column '", column, "'")
  }
  trimws(as.character(r))
}

is_blank <- function(x) is.na(x) | trimws(x) == ""

## ---- 3. LEGACY_LABELS.csv --------------------------------------------------

series_by_row_id <- setNames(triage$series_id, triage$row_id)
label_by_row_id <- setNames(triage$legacy_label, triage$row_id)

resolve_target_series <- function(row_id) {
  if (is_blank(row_id)) return("")
  s <- series_by_row_id[[row_id]]
  if (is.null(s) || is_blank(s)) {
    stop("duplicate_of/assert_rule target row_id '", row_id, "' has no MAP series_id")
  }
  s
}

resolve_assert_rule <- function(rule) {
  if (is_blank(rule)) return("")
  m <- regmatches(rule, regexec("^(EQUALS|ONE_MINUS):([A-Za-z0-9_]+)(.*)$", rule))[[1]]
  if (length(m) == 0) stop("cannot parse assert_rule: '", rule, "'")
  op <- m[2]; target_row_id <- m[3]; rest <- m[4]
  target_series <- resolve_target_series(target_row_id)
  paste0(op, ":", target_series, rest)
}

join_notes <- function(hard_case, notes) {
  hc <- if (is_blank(hard_case)) "" else trimws(hard_case)
  nt <- if (is_blank(notes)) "" else trimws(notes)
  if (hc != "" && nt != "") return(paste0(hc, ": ", nt))
  if (hc != "") return(hc)
  nt
}

parse_tol <- function(rest) {
  m <- regmatches(rest, regexec("tol=([0-9.]+)", rest))[[1]]
  if (length(m) == 0) return(0)
  as.numeric(m[2])
}

n <- nrow(triage)
ll_legacy_label <- triage$legacy_label
ll_sheet <- triage$sheet
ll_action <- triage$action
ll_series_id <- triage$series_id
ll_duplicate_of <- character(n)
ll_scale <- triage$scale
ll_assert_rule <- character(n)
ll_notes <- character(n)

for (i in seq_len(n)) {
  ll_duplicate_of[i] <- if (triage$action[i] %in% c("DUPLICATE_OF", "DERIVED") && !is_blank(triage$duplicate_of[i])) {
    resolve_target_series(triage$duplicate_of[i])
  } else {
    ""
  }
  ll_assert_rule[i] <- resolve_assert_rule(triage$assert_rule[i])
  ll_notes[i] <- join_notes(triage$hard_case[i], triage$notes[i])
}

# Check every assert_rule against the raw cells of both countries, the
# three sheets (National, ADM 1, ZAE), every column.
CHECK_SHEETS <- c("National", "ADM 1", "ZAE")

for (i in seq_len(n)) {
  rule <- triage$assert_rule[i]
  if (is_blank(rule)) next

  m <- regmatches(rule, regexec("^(EQUALS|ONE_MINUS):([A-Za-z0-9_]+)(.*)$", rule))[[1]]
  op <- m[2]; target_row_id <- m[3]; rest <- m[4]
  tol <- parse_tol(rest)
  source_label <- triage$legacy_label[i]
  target_label <- label_by_row_id[[target_row_id]]

  devs <- numeric(0)
  for (cn in COUNTRIES) {
    for (sh in CHECK_SHEETS) {
      df <- wb[[cn]][[sh]]
      sv <- suppressWarnings(as.numeric(get_row_vals(df, source_label)))
      tv <- suppressWarnings(as.numeric(get_row_vals(df, target_label)))
      keep <- !is.na(sv) & !is.na(tv)
      if (!any(keep)) next
      d <- if (op == "EQUALS") abs(sv[keep] - tv[keep]) else abs(sv[keep] - (1 - tv[keep]))
      devs <- c(devs, d)
    }
  }
  if (length(devs) == 0) {
    stop("assert_rule for row ", triage$row_id[i], " matched no comparable cells")
  }
  max_dev <- max(devs)
  if (!(max_dev <= tol + 1e-9)) {
    stop("assert_rule failed for row ", triage$row_id[i], " ('", source_label,
         "'): max deviation ", max_dev, " exceeds tol ", tol)
  }
  ll_notes[i] <- paste0(ll_notes[i], " max deviation ", fmt_num(max_dev))
}

legacy_labels <- data.frame(
  legacy_label = ll_legacy_label,
  sheet = ll_sheet,
  action = ll_action,
  series_id = ll_series_id,
  duplicate_of = ll_duplicate_of,
  scale = ll_scale,
  assert_rule = ll_assert_rule,
  notes = ll_notes,
  stringsAsFactors = FALSE
)

## ---- 4. LEGACY_COLUMNS.csv -------------------------------------------------

lc_ref_area <- character(0)
lc_sheet <- character(0)
lc_column <- character(0)
lc_cut_id <- character(0)
lc_geo <- character(0)
lc_urb <- character(0)
lc_comp <- character(0)
lc_action <- character(0)
lc_notes <- character(0)

nat_matched <- rep(FALSE, nrow(nat_cols_seed))
geo_col_seed <- geo_codes[!is_blank(geo_codes$legacy_sheet) & !is_blank(geo_codes$legacy_column), , drop = FALSE]
geo_matched <- rep(FALSE, nrow(geo_col_seed))

for (cn in COUNTRIES) {
  for (sh in SHEET_ORDER) {
    df <- wb[[cn]][[sh]]
    if (is.null(df)) next
    cols <- setdiff(names(df), "indicator")
    for (col in cols) {
      if (sh == "National") {
        idx <- which(nat_cols_seed$column == col)
        if (length(idx) != 1) {
          stop("National column '", col, "' (", cn, ") has no seed row in legacy_national_columns.csv")
        }
        nat_matched[idx] <- TRUE
        row <- nat_cols_seed[idx, ]
        cut_id <- row$cut_id
        geo <- ""
        urb <- row$URBANISATION
        comp <- row$COMP_BREAKDOWN
        action <- "MAP"
      } else if (sh %in% c("ADM 1", "ZAE")) {
        idx <- which(geo_codes$ref_area == cn & geo_codes$legacy_sheet == sh & geo_codes$legacy_column == col)
        if (length(idx) != 1) {
          stop(sh, " column '", col, "' (", cn, ") has no seed row in geo_codes.csv")
        }
        seed_idx <- which(geo_col_seed$code == geo_codes$code[idx])
        geo_matched[seed_idx] <- TRUE
        row <- geo_codes[idx, ]
        cut_id <- if (sh == "ADM 1") "ADM1" else row$scheme
        geo <- row$code
        urb <- ""
        comp <- ""
        action <- "MAP"
      } else {
        # Departement: SKIP, every mapping column empty (D3).
        cut_id <- ""
        geo <- ""
        urb <- ""
        comp <- ""
        action <- "SKIP"
      }
      lc_ref_area <- c(lc_ref_area, cn)
      lc_sheet <- c(lc_sheet, sh)
      lc_column <- c(lc_column, col)
      lc_cut_id <- c(lc_cut_id, cut_id)
      lc_geo <- c(lc_geo, geo)
      lc_urb <- c(lc_urb, urb)
      lc_comp <- c(lc_comp, comp)
      lc_action <- c(lc_action, action)
      lc_notes <- c(lc_notes, "")
    }
  }
}

if (!all(nat_matched)) {
  stop("legacy_national_columns.csv row(s) with no workbook column: ",
       paste(nat_cols_seed$column[!nat_matched], collapse = ", "))
}
if (!all(geo_matched)) {
  stop("geo_codes.csv row(s) with no workbook column: ",
       paste(geo_col_seed$code[!geo_matched], collapse = ", "))
}

legacy_columns <- data.frame(
  ref_area = lc_ref_area,
  sheet = lc_sheet,
  column = lc_column,
  cut_id = lc_cut_id,
  GEO = lc_geo,
  URBANISATION = lc_urb,
  COMP_BREAKDOWN = lc_comp,
  action = lc_action,
  notes = lc_notes,
  stringsAsFactors = FALSE
)

## ---- 5. LEGACY_OVERRIDES.csv -----------------------------------------------

m <- nrow(overrides_seed)
lo_obs_comment <- character(m)
lo_evidence <- character(m)

for (i in seq_len(m)) {
  ref_area <- overrides_seed$ref_area[i]
  sheet <- overrides_seed$sheet[i]
  column <- overrides_seed$column[i]
  legacy_label <- overrides_seed$legacy_label[i]
  action <- overrides_seed$action[i]
  reason <- overrides_seed$reason[i]

  lo_obs_comment[i] <- if (action == "COMMENT") paste0("LEGACY_SUSPECT: ", reason) else ""

  if (legacy_label == "*" && column != "*" && sheet != "*") {
    # The estimateCapital special case: the whole column is a copy of a
    # ZAE zone column. Compare every label's cell in this column against
    # the corresponding ZAE zone column named in the reason (D5/H18).
    if (!(ref_area == "GNB" && sheet == "National" && column == "estimateCapital")) {
      stop("unrecognized wildcard-label override row: ", ref_area, "/", sheet, "/", column)
    }
    zae_col <- "estimateZonas_Costeiras_do_Sul"
    df_nat <- wb[[ref_area]][["National"]]
    df_zae <- wb[[ref_area]][["ZAE"]]
    if (!identical(df_nat$indicator, df_zae$indicator)) {
      stop("National and ZAE indicator order differ for ", ref_area)
    }
    a <- trimws(df_nat[[column]])
    b <- trimws(df_zae[[zae_col]])
    N <- length(a)
    eq <- (a == b) | (is.na(a) & is.na(b)) | (a == "" & b == "")
    eq[is.na(eq)] <- FALSE
    nn <- sum(eq)
    lo_evidence[i] <- paste0("equal to ZAE ", zae_col, " on ", nn, " of ", N, " labels")
  } else if (column != "*" && sheet != "*") {
    # Single cell.
    df <- wb[[ref_area]][[sheet]]
    if (is.null(df)) stop("no sheet '", sheet, "' for ", ref_area)
    if (!(column %in% names(df))) stop("no column '", column, "' in ", ref_area, "/", sheet)
    v <- get_cell(df, legacy_label, column)
    lo_evidence[i] <- paste0("raw value ", v)
  } else if (sheet == "*" && column == "*") {
    # Whole label: National estimateTotal, plus range over National/ADM 1/ZAE.
    df_nat <- wb[[ref_area]][["National"]]
    v <- get_cell(df_nat, legacy_label, "estimateTotal")
    vals <- numeric(0)
    for (sh in CHECK_SHEETS) {
      df <- wb[[ref_area]][[sh]]
      row_vals <- suppressWarnings(as.numeric(get_row_vals(df, legacy_label)))
      vals <- c(vals, row_vals[!is.na(row_vals)])
    }
    if (length(vals) == 0) stop("label '", legacy_label, "' (", ref_area, ") matched no cells")
    lo_evidence[i] <- paste0("National estimateTotal = ", v, "; range over all cells ",
                              fmt_num(min(vals)), " to ", fmt_num(max(vals)))
  } else {
    stop("unrecognized override row shape: ", ref_area, "/", sheet, "/", column, "/", legacy_label)
  }
}

legacy_overrides <- data.frame(
  ref_area = overrides_seed$ref_area,
  sheet = overrides_seed$sheet,
  column = overrides_seed$column,
  legacy_label = overrides_seed$legacy_label,
  action = overrides_seed$action,
  obs_comment = lo_obs_comment,
  reason = overrides_seed$reason,
  evidence = lo_evidence,
  stringsAsFactors = FALSE
)

## ---- 6. Write --------------------------------------------------------------

write_std_csv(legacy_labels, file.path(out_root, "metadata", "plans", "LEGACY_LABELS.csv"))
write_std_csv(legacy_columns, file.path(out_root, "metadata", "plans", "LEGACY_COLUMNS.csv"))
write_std_csv(legacy_overrides, file.path(out_root, "metadata", "plans", "LEGACY_OVERRIDES.csv"))

cat("LEGACY_LABELS.csv:", nrow(legacy_labels), "rows\n")
cat("LEGACY_COLUMNS.csv:", nrow(legacy_columns), "rows\n")
cat("LEGACY_OVERRIDES.csv:", nrow(legacy_overrides), "rows\n")
