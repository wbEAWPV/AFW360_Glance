# pipeline/R/validate_docs.R
#
# Validator module DOCS (standard, "Validation checks" > "Documentation";
# D20): every fragment under .docs/generated/ equals what
# pipeline/build_docs.R would write from the current metadata, every
# `{{< include generated/... >}}` in the standard names a fragment that
# exists, and every fragment is included. The work is done by docs_check()
# in pipeline/R/docs.R (needs io.R and dplyr); this module only calls it
# and passes its findings through (check ids DOCS.*, as docs_check()
# names them). validate.R sources docs.R before the modules; when it has
# not been sourced, this module sources it from the root.
#
# A root without .docs/data-standard.qmd (a trimmed copy of the repository
# used by a test) cannot be checked: one INFO DOCS.SKIPPED says so.

#' The DOCS module's findings.
vc_docs_fragments <- function(ctx) {
  empty <- tibble::tibble(
    check_id = character(0), severity = character(0), file = character(0),
    row_key = character(0), message = character(0)
  )
  qmd <- file.path(ctx$root, ".docs", "data-standard.qmd")
  if (!file.exists(qmd)) {
    return(tibble::tibble(
      check_id = "DOCS.SKIPPED", severity = "INFO", file = ".docs/data-standard.qmd",
      row_key = "", message = "the standard is not under this root; the generated tables were not checked"
    ))
  }
  if (!exists("docs_check", mode = "function")) {
    source(file.path(ctx$root, "pipeline", "R", "docs.R"))
  }
  res <- docs_check(ctx$root)
  if (is.null(res) || nrow(res) == 0) return(empty)
  res <- tibble::as_tibble(as.data.frame(res, stringsAsFactors = FALSE))
  res[c("check_id", "severity", "file", "row_key", "message")]
}
