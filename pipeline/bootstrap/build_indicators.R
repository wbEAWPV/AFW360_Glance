#!/usr/bin/env Rscript
# pipeline/bootstrap/build_indicators.R
#
# WP07 -- Indicator dictionary. Builds metadata/codelists/CL_INDICATOR.csv
# from two inputs:
#   - .docs/transition/contract/label_triage.csv: the mechanical columns
#     (stat_unit, statistic, weight, ref_period, unit_measure, unit_denom,
#     unit_time, price_basis, display_as, decimals, valid_min, valid_max)
#     and the qualifier codes each indicator's series use (MEASURE_QUALS),
#     taken from the rows with action == "MAP".
#   - pipeline/bootstrap/text/indicators_text.csv: the hand-written text
#     columns (name_en, definition_en, universe_filter, ...).
#
# `theme`, `universe_unit`, `qualifiers` and `checks` are derived by rule
# (see .docs/transition/packages/WP07.md); every other mechanical column is
# copied from the triage, after checking it is identical across every label
# of a given indicator code. The two inputs' code sets must match exactly.
#
# Usage:
#   Rscript pipeline/bootstrap/build_indicators.R --root <repo root> [--out-root <dir>]

args <- commandArgs(trailingOnly = TRUE)

get_arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (length(i) == 0 || i[1] >= length(args)) {
    return(default)
  }
  args[i[1] + 1]
}

root <- get_arg("--root", ".")

source(file.path(root, "pipeline", "R", "io.R"))
source(file.path(root, "pipeline", "R", "constants.R"))

root <- cli_arg(args, "--root", ".")
out_root <- cli_arg(args, "--out-root", root)

## ---- paths ------------------------------------------------------------

contract_dir <- file.path(root, ".docs", "transition", "contract")
triage_path <- file.path(contract_dir, "label_triage.csv")
codes_path <- file.path(contract_dir, "codes.csv")
headers_path <- file.path(contract_dir, "csv_headers.csv")
text_path <- file.path(root, "pipeline", "bootstrap", "text", "indicators_text.csv")
out_path <- file.path(out_root, "metadata", "codelists", "CL_INDICATOR.csv")

## ---- read inputs --------------------------------------------------------

triage <- read_std_csv(triage_path)
codes <- read_std_csv(codes_path)
headers <- read_std_csv(headers_path)
text <- read_std_csv(text_path)

map_rows <- triage[triage$action == "MAP", , drop = FALSE]
if (nrow(map_rows) == 0) {
  stop("build_indicators: no rows with action == 'MAP' in label_triage.csv", call. = FALSE)
}

indicator_codes <- sort(unique(map_rows$INDICATOR))

## ---- mechanical columns: copy from the triage, asserting consistency ----

mech_cols <- c(
  "stat_unit", "statistic", "weight", "ref_period", "unit_measure",
  "unit_denom", "unit_time", "price_basis", "display_as", "decimals",
  "valid_min", "valid_max"
)

mech_rows <- lapply(indicator_codes, function(cd) {
  rows <- map_rows[map_rows$INDICATOR == cd, , drop = FALSE]
  vals <- list(code = cd)
  for (col in mech_cols) {
    u <- unique(rows[[col]])
    if (length(u) != 1) {
      stop(sprintf(
        "build_indicators: column '%s' is not identical across all labels of indicator '%s' (values: %s)",
        col, cd, paste(u, collapse = " | ")
      ), call. = FALSE)
    }
    vals[[col]] <- u
  }
  as.data.frame(vals, stringsAsFactors = FALSE)
})
mech_df <- do.call(rbind, mech_rows)

## ---- qualifier codes used by each indicator's series ---------------------

qual_codes_of <- stats::setNames(
  lapply(indicator_codes, function(cd) {
    rows <- map_rows[map_rows$INDICATOR == cd, , drop = FALSE]
    q <- unlist(strsplit(rows$MEASURE_QUALS, "\\s+"))
    q <- q[!is.na(q) & nzchar(trimws(q))]
    unique(q)
  }),
  indicator_codes
)

qualifier_rows <- codes[codes$codelist == "CL_QUALIFIER", , drop = FALSE]
qualvar_rows <- codes[codes$codelist == "CL_QUAL_VAR", , drop = FALSE]
slot_of_var <- stats::setNames(
  suppressWarnings(as.integer(qualvar_rows$slot_order)),
  qualvar_rows$code
)

build_qualifiers <- function(qcodes) {
  if (length(qcodes) == 0) {
    return("_Z")
  }
  rows <- qualifier_rows[qualifier_rows$code %in% qcodes, , drop = FALSE]
  missing <- setdiff(qcodes, rows$code)
  if (length(missing) > 0) {
    stop(
      "build_indicators: qualifier code(s) not found in CL_QUALIFIER: ",
      paste(missing, collapse = ", "), call. = FALSE
    )
  }
  rows$order_n <- suppressWarnings(as.integer(rows$order))
  rows <- rows[order(rows$order_n), , drop = FALSE]

  vars_present <- unique(rows$var_code)
  missing_var <- setdiff(vars_present, names(slot_of_var))
  if (length(missing_var) > 0) {
    stop(
      "build_indicators: qualifier variable(s) not found in CL_QUAL_VAR: ",
      paste(missing_var, collapse = ", "), call. = FALSE
    )
  }
  vars_present <- vars_present[order(slot_of_var[vars_present])]

  parts <- vapply(vars_present, function(v) {
    cs <- rows$code[rows$var_code == v]
    paste0(v, ":", paste(cs, collapse = ","))
  }, character(1))
  paste(parts, collapse = " ")
}

qualifiers_of <- vapply(
  indicator_codes,
  function(cd) build_qualifiers(qual_codes_of[[cd]]),
  character(1)
)

## ---- checks tokens ---------------------------------------------------

build_checks <- function(cd, unit_measure, valid_min, statistic, qcodes) {
  tokens <- character(0)

  if (identical(unit_measure, "SHARE")) {
    tokens <- c(tokens, "RANGE_0_1")
  } else {
    vm <- suppressWarnings(as.numeric(valid_min))
    if (!is.na(vm) && vm == 0) {
      tokens <- c(tokens, "RANGE_NONNEG")
    }
  }

  if (!identical(cd, "EN_OUTAGE_DUR_CODE")) {
    if (identical(statistic, "TOTAL")) {
      tokens <- c(tokens, "AGG_SUM")
    } else {
      tokens <- c(tokens, "AGG_BRACKET")
    }
  }

  if (any(grepl("^POVLINE_", qcodes))) {
    tokens <- c(tokens, "MONOTONE_IN:POVLINE")
  }

  if (identical(cd, "CONS_SH")) {
    tokens <- c(tokens, "SUM_TO_1_OVER:COICOP")
  }

  if (cd %in% c("POP_SH", "POP_HH_SH", "POP_HE_SH")) {
    tokens <- c(tokens, "SUM_TO_1_OVER_BRK")
  }

  if (length(tokens) == 0) {
    return("NONE")
  }
  paste(tokens, collapse = " ")
}

## ---- theme -----------------------------------------------------------

theme_of <- function(cd) {
  if (cd %in% c("POV_HC", "POV_NUM")) {
    return("POV")
  }
  if (identical(cd, "CONS_SH")) {
    return("CONS")
  }
  if (cd %in% c("POP_SH", "POP_HH_SH", "POP_HE_SH")) {
    return("POP")
  }
  strsplit(cd, "_", fixed = TRUE)[[1]][1]
}

## ---- assemble the derived (mechanical) columns ---------------------------

derived <- mech_df
derived$universe_unit <- derived$stat_unit
derived$theme <- vapply(derived$code, theme_of, character(1))
derived$qualifiers <- unname(qualifiers_of[derived$code])
derived$excluded_breakdowns <- ""
derived$price_ref_year <- ""
derived$replaced_by <- ""
derived$owner <- "AFW DIP/POV team"
derived$status <- "DRAFT"
derived$version_added <- "0.1.0"
derived$checks <- vapply(seq_len(nrow(derived)), function(i) {
  build_checks(
    derived$code[i], derived$unit_measure[i], derived$valid_min[i],
    derived$statistic[i], qual_codes_of[[derived$code[i]]]
  )
}, character(1))

## ---- join the hand-written text, asserting the code sets match -----------

if (anyDuplicated(text$code) != 0) {
  stop(
    "build_indicators: duplicate code(s) in indicators_text.csv: ",
    paste(unique(text$code[duplicated(text$code)]), collapse = ", "), call. = FALSE
  )
}

text_codes <- sort(unique(text$code))
derived_codes <- sort(unique(derived$code))
if (!identical(text_codes, derived_codes)) {
  only_text <- setdiff(text_codes, derived_codes)
  only_derived <- setdiff(derived_codes, text_codes)
  stop(sprintf(
    paste0(
      "build_indicators: code sets differ between indicators_text.csv and the ",
      "label_triage.csv MAP rows.\n  only in indicators_text.csv: %s\n",
      "  only in label_triage.csv: %s"
    ),
    paste(only_text, collapse = ", "),
    paste(only_derived, collapse = ", ")
  ), call. = FALSE)
}

out <- merge(derived, text, by = "code", all = FALSE, sort = FALSE)
if (nrow(out) != length(indicator_codes)) {
  stop("build_indicators: join of derived columns and text produced an unexpected row count", call. = FALSE)
}

## ---- order columns per csv_headers.csv and write -------------------------

header_rows <- headers[headers$file == "CL_INDICATOR.csv", , drop = FALSE]
header_rows <- header_rows[order(as.integer(header_rows$position)), , drop = FALSE]
col_order <- header_rows$column

missing_cols <- setdiff(col_order, names(out))
if (length(missing_cols) > 0) {
  stop(
    "build_indicators: missing column(s) required by csv_headers.csv: ",
    paste(missing_cols, collapse = ", "), call. = FALSE
  )
}

out <- out[, col_order, drop = FALSE]
out <- out[order(out$code), , drop = FALSE]
rownames(out) <- NULL

write_std_csv(out, out_path)

cat(sprintf("build_indicators: wrote %d rows to %s\n", nrow(out), out_path))
