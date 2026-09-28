# pipeline/build_docs.R
#
# Writes the tables of the data standard that list the contents of a
# metadata file to .docs/generated/<id>.md (standard, section "Generated
# tables", D20). Reads only metadata/ and content/.
#
# Usage (from the repo root):
#   Rscript pipeline/build_docs.R --root .           # rewrite the fragments
#   Rscript pipeline/build_docs.R --root . --check   # exit 1 if any is stale
#
# The work is done in pipeline/R/docs.R; the validator calls docs_check()
# from there directly.

args <- commandArgs(trailingOnly = TRUE)

root_arg <- "."
idx <- which(args == "--root")
if (length(idx) > 0 && idx[1] < length(args)) {
  root_arg <- args[idx[1] + 1]
}
root <- normalizePath(root_arg, winslash = "/", mustWork = TRUE)

source(file.path(root, "pipeline", "R", "io.R"))
source(file.path(root, "pipeline", "R", "docs.R"))

if (cli_flag(args, "--check")) {
  findings <- docs_check(root)
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

out_dir <- file.path(root, ".docs", "generated")
paths <- withCallingHandlers(docs_build(root, out_dir), warning = function(w) {
  message("warning: ", conditionMessage(w))
  invokeRestart("muffleWarning")
})
cat(sprintf("wrote %d fragments to .docs/generated/\n", length(paths)))
if (length(paths) != length(docs_fragment_ids())) {
  quit(status = 1)
}
