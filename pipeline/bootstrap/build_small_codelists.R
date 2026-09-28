#!/usr/bin/env Rscript
# pipeline/bootstrap/build_small_codelists.R
#
# WP04 - Small codelists and CL_AREA.
#
# One-time bootstrap generator (frozen after metadata 0.1.0, see
# pipeline/README.md). Builds the ten small codelists that every other
# metadata file refers to, from:
#   - seeds/codes.csv:  the codelist/code/parent/order seed
#   - pipeline/bootstrap/text/small_codelists_text.csv: the hand-written
#     name_en/definition_en/notes/admits_se/iso2/currency/wb_region text
#
# Usage:
#   Rscript pipeline/bootstrap/build_small_codelists.R --root . --out-root .

args <- commandArgs(trailingOnly = TRUE)

root <- {
  idx <- which(args == "--root")
  if (length(idx) == 0 || idx[1] >= length(args)) "." else args[idx[1] + 1]
}

suppressPackageStartupMessages({
  source(file.path(root, "pipeline", "R", "io.R"))
})

out_root <- cli_arg(args, "--out-root", root)

CODELISTS <- c(
  "CL_SEX", "CL_AGE", "CL_URBANISATION", "CL_OBS_STATUS", "CL_THEME",
  "CL_UNIT", "CL_STAT_UNIT", "CL_STATISTIC", "CL_WEIGHT", "CL_AREA"
)

# Extra columns (beyond the seven common columns) that each codelist's
# csv_headers.csv entry adds.
EXTRA_COLUMNS <- list(
  CL_URBANISATION = "parent",
  CL_STATISTIC = "admits_se",
  CL_AREA = c("iso2", "currency", "wb_region")
)

codes <- read_std_csv(repo_path(root, "pipeline", "bootstrap", "seeds", "codes.csv"))
codes <- codes[codes$codelist %in% CODELISTS, , drop = FALSE]

text <- read_std_csv(repo_path(root, "pipeline", "bootstrap", "text", "small_codelists_text.csv"))

# --- Check the seed and the text file describe exactly the same codes. ---
key <- function(df) paste(df$codelist, df$code, sep = "")
codes_keys <- sort(unique(key(codes)))
text_keys <- sort(unique(key(text)))

if (!identical(codes_keys, text_keys)) {
  only_codes <- setdiff(codes_keys, text_keys)
  only_text <- setdiff(text_keys, codes_keys)
  msg <- c(
    "codes.csv and small_codelists_text.csv do not hold the same (codelist, code) pairs.",
    if (length(only_codes) > 0) paste0("  only in codes.csv: ", paste(only_codes, collapse = ", ")),
    if (length(only_text) > 0) paste0("  only in text file: ", paste(only_text, collapse = ", "))
  )
  stop(paste(msg, collapse = "\n"), call. = FALSE)
}
if (anyDuplicated(key(codes)) > 0) {
  stop("codes.csv has duplicate (codelist, code) pairs among the ten small codelists.", call. = FALSE)
}
if (anyDuplicated(key(text)) > 0) {
  stop("small_codelists_text.csv has duplicate (codelist, code) pairs.", call. = FALSE)
}

headers <- read_std_csv(repo_path(root, "pipeline", "bootstrap", "seeds", "csv_headers.csv"))

for (cl in CODELISTS) {
  file_name <- paste0(cl, ".csv")

  cl_codes <- codes[codes$codelist == cl, , drop = FALSE]
  cl_codes <- cl_codes[order(as.numeric(cl_codes$order)), , drop = FALSE]

  cl_text <- text[text$codelist == cl, , drop = FALSE]

  m <- match(cl_codes$code, cl_text$code)
  stopifnot(!anyNA(m))

  df <- data.frame(
    code = cl_codes$code,
    name_en = cl_text$name_en[m],
    definition_en = cl_text$definition_en[m],
    status = "DRAFT",
    version_added = "0.1.0",
    replaced_by = "",
    notes = cl_text$notes[m],
    stringsAsFactors = FALSE
  )

  extra <- EXTRA_COLUMNS[[cl]]
  if (!is.null(extra)) {
    for (col in extra) {
      if (col == "parent") {
        df$parent <- cl_codes$parent
      } else {
        df[[col]] <- cl_text[[col]][m]
      }
    }
  }

  cols <- headers[headers$file == file_name, , drop = FALSE]
  cols <- cols[order(as.numeric(cols$position)), , drop = FALSE]
  stopifnot(all(cols$column %in% names(df)))
  df <- df[, cols$column, drop = FALSE]

  out_path <- repo_path(out_root, "metadata", "codelists", file_name)
  write_std_csv(df, out_path)
  cat("wrote", nrow(df), "rows to", out_path, "\n")
}
