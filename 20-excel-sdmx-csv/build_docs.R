# 20-excel-sdmx-csv/build_docs.R
#
# Writes the tables of the data standard that list the contents of the
# legacy plans (plans/TAB_PLAN.csv, LEGACY_LABELS.csv, LEGACY_COLUMNS.csv,
# LEGACY_OVERRIDES.csv, with their columns from plans/PLAN_COLUMNS.csv) to
# .docs/generated/<id>.md (standard, section "Generated tables", D20). The
# other tables are written by 30-sdmx/pipeline/build_docs.R.
#
# Usage (from 20-excel-sdmx-csv/):
#   Rscript build_docs.R            # rewrite the fragments
#   Rscript build_docs.R --check    # exit 1 if any is stale
# Option: --root <dir> (default: the folder of this script).
#
# The work is done in R/docs.R and R/docs_md.R.

args <- commandArgs(trailingOnly = TRUE)

.script_dir <- function() {
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
  dirname(normalizePath(f, winslash = "/", mustWork = TRUE))
}
source(file.path(.script_dir(), "R", "paths.R"))
paths <- stage_paths_from_args(args, default_root = .script_dir())

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
