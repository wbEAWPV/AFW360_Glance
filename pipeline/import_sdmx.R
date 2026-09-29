# pipeline/import_sdmx.R
#
# Reads an SDMX-ML 3.0 or 3.1 structure message (for example an FMR export,
# plan 2.13 step 4) and rebuilds the metadata CSVs it was generated from:
# every codelist whose AFW_SOURCE_FILE names a CSV under metadata/codelists/
# and the names and descriptions in metadata/structure/ARTEFACTS.csv.
# Sentinel codes are dropped; derived codelists (CL_SOURCE, CL_SURVEY,
# CL_FIGURE) are reported on stderr, never written. Unknown annotation
# types and codelists without a source file stop the import.
#
# Usage (from the repo root):
#   Rscript pipeline/import_sdmx.R --root . --diff <message.xml>    # unified diff on stdout
#   Rscript pipeline/import_sdmx.R --root . --apply <message.xml>   # write the CSVs
# Options:
#   --out-root <dir>    where --apply writes metadata/ (default: --root)
# Without --diff or --apply the diff is printed.
#
# The work is done in pipeline/R/sdmx_import.R.

args <- commandArgs(trailingOnly = TRUE)

root_arg <- "."
idx <- which(args == "--root")
if (length(idx) > 0 && idx[1] < length(args)) {
  root_arg <- args[idx[1] + 1]
}
root <- normalizePath(root_arg, winslash = "/", mustWork = TRUE)

source(file.path(root, "pipeline", "R", "io.R"))
source(file.path(root, "pipeline", "R", "sdmx_xml.R"))
source(file.path(root, "pipeline", "R", "sdmx_structures.R"))
source(file.path(root, "pipeline", "R", "sdmx_import.R"))

out_root <- cli_arg(args, "--out-root", root)
do_apply <- cli_flag(args, "--apply")
if (do_apply && cli_flag(args, "--diff")) {
  cat("Use either --diff or --apply, not both.\n", file = stderr())
  quit(status = 2)
}

# The positional argument: whatever is not an option or an option value.
drop <- which(args %in% c("--diff", "--apply"))
for (flag in c("--root", "--out-root")) {
  i <- which(args == flag)
  drop <- c(drop, i, i + 1)
}
rest <- args[setdiff(seq_along(args), drop)]
if (length(rest) != 1) {
  cat("Usage: Rscript pipeline/import_sdmx.R --root . [--out-root <dir>] [--diff | --apply] <structure-message.xml>\n",
    file = stderr())
  quit(status = 2)
}

plan <- tryCatch(sdmx_import_plan(rest, root), error = function(e) {
  cat("import_sdmx: ", conditionMessage(e), "\n", sep = "", file = stderr())
  quit(status = 1)
})
for (r in plan$reports) cat(r, "\n", sep = "", file = stderr())

if (do_apply) {
  changed <- sdmx_import_apply(plan, out_root)
  cat(sprintf("Wrote %d files under %s; %d differ from %s.\n",
    length(plan$files), out_root, length(changed), root), file = stderr())
  for (p in changed) cat("  changed: ", p, "\n", sep = "", file = stderr())
} else {
  d <- sdmx_import_diff(plan)
  if (length(d) > 0) {
    con <- stdout()
    writeLines(enc2utf8(d), con, useBytes = TRUE)
  }
}
quit(status = 0)
