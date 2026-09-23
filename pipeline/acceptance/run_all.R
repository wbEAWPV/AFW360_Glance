#!/usr/bin/env Rscript
# pipeline/acceptance/run_all.R
#
# Runs every pipeline/acceptance/wp*.R script (in name order) as
#   Rscript <script> --root <root>
# printing each script's CHECK lines followed by one summary line per
# script. Exits 0 only if every script exits 0; also exits 0 when there
# are no such scripts to run.
#
# Usage:
#   Rscript pipeline/acceptance/run_all.R --root <repo root>

args <- commandArgs(trailingOnly = TRUE)

.this_root <- {
  idx <- which(args == "--root")
  if (length(idx) == 1 && idx < length(args)) args[idx + 1] else "."
}

acc_dir <- file.path(.this_root, "pipeline", "acceptance")
scripts <- sort(list.files(acc_dir, pattern = "^wp.*\\.R$", full.names = FALSE))

overall_ok <- TRUE

for (s in scripts) {
  script_path <- file.path(acc_dir, s)
  res <- suppressWarnings(system2(
    "Rscript",
    args = c(script_path, "--root", .this_root),
    stdout = TRUE,
    stderr = TRUE
  ))
  status <- attr(res, "status")
  if (is.null(status)) status <- 0L

  check_lines <- grep("^CHECK", res, value = TRUE)
  if (length(check_lines) > 0) {
    cat(paste(check_lines, collapse = "\n"), "\n", sep = "")
  }

  ok <- identical(as.integer(status), 0L)
  overall_ok <- overall_ok && ok
  cat(sprintf("SUMMARY %s: %s (exit %s)\n", s, if (ok) "PASS" else "FAIL", status))
}

if (length(scripts) == 0) {
  cat("SUMMARY run_all: no acceptance scripts found\n")
}

quit(status = if (overall_ok) 0L else 1L, save = "no")
