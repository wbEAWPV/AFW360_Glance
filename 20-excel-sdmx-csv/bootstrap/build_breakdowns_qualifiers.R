#!/usr/bin/env Rscript
# pipeline/bootstrap/build_breakdowns_qualifiers.R
#
# WP06 (breakdowns-qualifiers): builds the four breakdown/qualifier
# codelists -- CL_BRK_VAR, CL_COMP_BREAKDOWN, CL_QUAL_VAR, CL_QUALIFIER --
# from the seed rows (pipeline/bootstrap/seeds/codes.csv) and
# the text seed written for this package
# (pipeline/bootstrap/text/breakdowns_qualifiers_text.csv).
#
# A breakdown says who is counted, and its categories are subsets of one
# population (CL_BRK_VAR / CL_COMP_BREAKDOWN). A qualifier says what is
# measured, and every category covers the same population again
# (CL_QUAL_VAR / CL_QUALIFIER).
#
# Usage:
#   Rscript pipeline/bootstrap/build_breakdowns_qualifiers.R --root <repo root> [--out-root <dir>]
#
# Reads inputs under --root, writes outputs under --out-root (default:
# --root) at the same relative paths, so a check can rebuild into a
# temporary directory and compare it byte for byte against the committed
# files.

.args <- commandArgs(trailingOnly = TRUE)
.find_arg <- function(args, flag, default) {
  idx <- which(args == flag)
  if (length(idx) == 0 || idx[1] >= length(args)) {
    return(default)
  }
  args[idx[1] + 1]
}
root <- .find_arg(.args, "--root", ".")

source(file.path(root, "pipeline", "R", "io.R"))

out_root <- cli_arg(.args, "--out-root", root)

STATUS_DRAFT <- "DRAFT"
VERSION_ADDED <- "0.1.0"

CODELISTS <- c("CL_BRK_VAR", "CL_COMP_BREAKDOWN", "CL_QUAL_VAR", "CL_QUALIFIER")

seed_path <- file.path(root, "pipeline", "bootstrap", "seeds", "codes.csv")
headers_path <- file.path(root, "pipeline", "bootstrap", "seeds", "csv_headers.csv")
text_path <- file.path(root, "pipeline", "bootstrap", "text", "breakdowns_qualifiers_text.csv")

seed <- read_std_csv(seed_path)
headers <- read_std_csv(headers_path)
text <- read_std_csv(text_path)

seed <- as.data.frame(seed[seed$codelist %in% CODELISTS, , drop = FALSE], stringsAsFactors = FALSE)
text <- as.data.frame(text[text$codelist %in% CODELISTS, , drop = FALSE], stringsAsFactors = FALSE)

# --- the seed and the text seed must hold exactly the same (codelist, code) pairs ---
seed_pairs <- paste(seed$codelist, seed$code, sep = "")
text_pairs <- paste(text$codelist, text$code, sep = "")

if (anyDuplicated(seed_pairs) > 0) {
  stop("build_breakdowns_qualifiers: duplicate (codelist, code) pairs in the seed", call. = FALSE)
}
if (anyDuplicated(text_pairs) > 0) {
  stop("build_breakdowns_qualifiers: duplicate (codelist, code) pairs in the text seed", call. = FALSE)
}

only_seed <- setdiff(seed_pairs, text_pairs)
only_text <- setdiff(text_pairs, seed_pairs)
if (length(only_seed) > 0 || length(only_text) > 0) {
  stop(
    "build_breakdowns_qualifiers: the seed and the text seed disagree on their (codelist, code) pairs.\n",
    "  In the seed but not the text seed (", length(only_seed), "): ",
    paste(head(only_seed, 10), collapse = "; "), "\n",
    "  In the text seed but not the seed (", length(only_text), "): ",
    paste(head(only_text, 10), collapse = "; "),
    call. = FALSE
  )
}

# --- helpers ---------------------------------------------------------------

#' Parse a character vector as numbers, empty string becoming NA.
to_num <- function(x) {
  x <- trimws(x)
  suppressWarnings(as.numeric(x))
}

#' Column names of `file_name`, in `csv_headers.csv` position order.
cols_for <- function(file_name) {
  h <- headers[headers$file == file_name, , drop = FALSE]
  h <- h[order(as.integer(h$position)), , drop = FALSE]
  h$column
}

#' Select and order `df`'s columns to match `csv_headers.csv` for
#' `file_name`. A column listed in `csv_headers.csv` but absent from `df`
#' is added as an empty column, so no text column from another file leaks
#' in and every declared column is present.
select_cols <- function(df, file_name) {
  want <- cols_for(file_name)
  for (nm in want) {
    if (!nm %in% names(df)) {
      df[[nm]] <- ""
    }
  }
  df[, want, drop = FALSE]
}

#' Merge a codelist's seed structural columns with its text seed columns,
#' keeping the seed's row order.
merge_seed_text <- function(codelist_name, seed_cols, text_cols) {
  s <- seed[seed$codelist == codelist_name, c("code", seed_cols), drop = FALSE]
  t <- text[text$codelist == codelist_name, c("code", text_cols), drop = FALSE]
  m <- merge(s, t, by = "code", sort = FALSE)
  m[match(s$code, m$code), , drop = FALSE]
}

# --- CL_BRK_VAR --------------------------------------------------------------
m <- merge_seed_text(
  "CL_BRK_VAR",
  c("describes", "applies_to_units", "partition", "requires", "slot_order"),
  c("name_en", "definition_en", "notes", "universe", "classification", "owner")
)
m$requires_qual <- m$requires
m$status <- STATUS_DRAFT
m$version_added <- VERSION_ADDED
m$replaced_by <- ""
m$slot_order <- to_num(m$slot_order)
brk_var <- select_cols(m, "CL_BRK_VAR.csv")

# --- CL_COMP_BREAKDOWN --------------------------------------------------------
m <- merge_seed_text(
  "CL_COMP_BREAKDOWN",
  c("var_code", "parent", "order"),
  c("name_en", "definition_en", "notes")
)
m$status <- STATUS_DRAFT
m$version_added <- VERSION_ADDED
m$replaced_by <- ""
m$order <- to_num(m$order)
comp_breakdown <- select_cols(m, "CL_COMP_BREAKDOWN.csv")

# --- CL_QUAL_VAR ---------------------------------------------------------------
m <- merge_seed_text(
  "CL_QUAL_VAR",
  c("slot_order", "requires"),
  c("name_en", "definition_en", "notes", "owner")
)
m$status <- STATUS_DRAFT
m$version_added <- VERSION_ADDED
m$replaced_by <- ""
m$slot_order <- to_num(m$slot_order)
qual_var <- select_cols(m, "CL_QUAL_VAR.csv")

# --- CL_QUALIFIER ------------------------------------------------------------
m <- merge_seed_text(
  "CL_QUALIFIER",
  c("var_code", "value", "valid_with", "order"),
  c("name_en", "definition_en", "notes", "basis")
)
m$status <- STATUS_DRAFT
m$version_added <- VERSION_ADDED
m$replaced_by <- ""
m$value <- to_num(m$value)
m$order <- to_num(m$order)
qualifier <- select_cols(m, "CL_QUALIFIER.csv")

# --- write -------------------------------------------------------------------
write_std_csv(brk_var, file.path(out_root, "metadata", "codelists", "CL_BRK_VAR.csv"))
write_std_csv(comp_breakdown, file.path(out_root, "metadata", "codelists", "CL_COMP_BREAKDOWN.csv"))
write_std_csv(qual_var, file.path(out_root, "metadata", "codelists", "CL_QUAL_VAR.csv"))
write_std_csv(qualifier, file.path(out_root, "metadata", "codelists", "CL_QUALIFIER.csv"))

cat(
  "build_breakdowns_qualifiers: wrote CL_BRK_VAR.csv (", nrow(brk_var), " rows), ",
  "CL_COMP_BREAKDOWN.csv (", nrow(comp_breakdown), " rows), ",
  "CL_QUAL_VAR.csv (", nrow(qual_var), " rows), ",
  "CL_QUALIFIER.csv (", nrow(qualifier), " rows)\n",
  sep = ""
)
