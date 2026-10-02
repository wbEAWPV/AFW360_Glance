#!/usr/bin/env Rscript
# 20-excel-sdmx-csv/publish.R
#
# Copies the output folder of this stage to its destinations (PUBLISH_MAP,
# R/paths.R):
#
#   output/data/        -> 30-sdmx/data/
#   output/geo/         -> 30-sdmx/data/geo/
#   output/registries/  -> 30-sdmx/data/metadata/registries/
#   output/content/     -> 10-legacy-pipeline/data_dashboard/content/
#   output/assets/      -> 10-legacy-pipeline/data_dashboard/assets/
#
# Only files the builders wrote are copied, and only when they differ;
# GeoPackages are compared by content (R/publish.R), and an unchanged
# GeoPackage keeps its published file and sha256. Nothing at a destination
# is deleted and nothing is written under the legacy inputs.
#
# Usage (from 20-excel-sdmx-csv/):
#   Rscript publish.R            # copy what differs
#   Rscript publish.R --check    # write nothing; exit 1 if any destination differs
# Options: --out-root <dir> (the output folder, default output/), --root,
# --sdmx-dir, --dashboard-dir (R/paths.R).
#
# After publishing, regenerate and check the SDMX stage from 30-sdmx/:
# Rscript pipeline/build_sdmx.R, pipeline/build_docs.R, pipeline/validate.R.

args <- commandArgs(trailingOnly = TRUE)

.script_dir <- function() {
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
  dirname(normalizePath(f, winslash = "/", mustWork = TRUE))
}
source(file.path(.script_dir(), "R", "paths.R"))
paths <- stage_paths_from_args(args, default_root = .script_dir())

source(stage_path(paths, "code", "io.R"))
source(stage_path(paths, "code", "publish.R"))

out_root <- stage_out_root(args, paths)
check <- cli_flag(args, "--check")

plan <- publish_plan(paths, out_root)
if (nrow(plan) == 0) {
  cat("publish: nothing under ", out_root, "; run the builders first\n", sep = "")
  quit(status = if (check) 1 else 0, save = "no")
}

for (k in seq_len(nrow(plan))) {
  cat(sprintf("%-9s %s/%s -> %s (%s)\n", plan$status[k], plan$output[k], plan$rel[k],
    plan$dest[k], plan$how[k]))
}
n_diff <- sum(plan$status != "unchanged")

if (check) {
  cat(sprintf("publish --check: %d of %d file(s) differ from their destination\n", n_diff, nrow(plan)))
  quit(status = if (n_diff == 0) 0 else 1, save = "no")
}

publish_apply(plan)
cat(sprintf("publish: copied %d of %d file(s)\n", n_diff, nrow(plan)))
