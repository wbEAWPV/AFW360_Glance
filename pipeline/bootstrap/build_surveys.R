#!/usr/bin/env Rscript
# pipeline/bootstrap/build_surveys.R
#
# WP10 (Text, figures and surveys): checks the header of the hand-authored
# pipeline/bootstrap/text/surveys_text.csv against contract/csv_headers.csv,
# then writes it through the standard CSV writer to
# metadata/surveys/SURVEYS.csv. See .docs/transition/packages/WP10.md.
#
# Usage: Rscript pipeline/bootstrap/build_surveys.R [--root <dir>] [--out-root <dir>]

args <- commandArgs(trailingOnly = TRUE)

.arg <- function(args, flag, default) {
  idx <- which(args == flag)
  if (length(idx) == 0 || idx[1] >= length(args)) {
    return(default)
  }
  args[idx[1] + 1]
}

root <- .arg(args, "--root", ".")
source(file.path(root, "pipeline", "R", "io.R"))
out_root <- cli_arg(args, "--out-root", root)

headers <- read_std_csv(repo_path(root, ".docs", "transition", "contract", "csv_headers.csv"))
expected_cols <- headers$column[headers$file == "SURVEYS.csv"]
if (length(expected_cols) == 0) {
  stop("build_surveys: no SURVEYS.csv header found in contract/csv_headers.csv", call. = FALSE)
}

surveys <- read_std_csv(repo_path(root, "pipeline", "bootstrap", "text", "surveys_text.csv"))

if (!identical(names(surveys), expected_cols)) {
  stop(
    "build_surveys: surveys_text.csv header does not match contract/csv_headers.csv for SURVEYS.csv.\n",
    "  expected: ", paste(expected_cols, collapse = ", "), "\n",
    "  found:    ", paste(names(surveys), collapse = ", "),
    call. = FALSE
  )
}

write_std_csv(surveys, repo_path(out_root, "metadata", "surveys", "SURVEYS.csv"))

cat("build_surveys: wrote metadata/surveys/SURVEYS.csv (", nrow(surveys), " rows)\n", sep = "")
