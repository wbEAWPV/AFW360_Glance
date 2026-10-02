# 30-sdmx/pipeline/build_docs.R
#
# Writes the tables of the data standard that list the contents of a file
# of the standard's metadata (data/metadata/) or of the dashboard's
# content/TEXT.csv to .docs/generated/<id>.md (standard, section "Generated
# tables", D20). The tables of the legacy plans are written by
# 20-excel-sdmx-csv/build_docs.R into the same folder.
#
# Usage (from 30-sdmx/):
#   Rscript pipeline/build_docs.R            # rewrite the fragments
#   Rscript pipeline/build_docs.R --check    # exit 1 if any is stale
# Options: --root <dir> (default: the 30-sdmx/ of this script),
# --dashboard-dir <dir> (where content/TEXT.csv is; see pipeline/R/paths.R).
#
# The work is done in pipeline/R/docs.R and docs_md.R; the validator calls
# docs_check() from there directly.

args <- commandArgs(trailingOnly = TRUE)

.script_dir <- function() {
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
  dirname(normalizePath(f, winslash = "/", mustWork = TRUE))
}
source(file.path(.script_dir(), "R", "paths.R"))
paths <- stage_paths_from_args(args, default_root = dirname(.script_dir()))

source(stage_path(paths, "code", "io.R"))
source(stage_path(paths, "code", "docs_md.R"))
source(stage_path(paths, "code", "docs.R"))

if (cli_flag(args, "--check")) {
  findings <- docs_check(paths)
  if (nrow(findings) == 0) {
    cat("generated tables are current\n")
    quit(status = 0)
  }
  for (i in seq_len(nrow(findings))) {
    cat(sprintf(
      "%s %s %s: %s\n", findings$severity[i], findings$check_id[i],
      if (nzchar(findings$file[i])) findings$file[i] else findings$row_key[i],
      findings$message[i]
    ))
  }
  quit(status = 1)
}

out_dir <- stage_path(paths, "docs", "generated")
paths_written <- withCallingHandlers(docs_build(paths, out_dir), warning = function(w) {
  message("warning: ", conditionMessage(w))
  invokeRestart("muffleWarning")
})
cat(sprintf("wrote %d fragments to .docs/generated/\n", length(paths_written)))
if (length(paths_written) != length(docs_fragment_ids())) {
  quit(status = 1)
}
