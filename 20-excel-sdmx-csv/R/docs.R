# 20-excel-sdmx-csv/R/docs.R
#
# Documentation generator for the data standard (.docs/data-standard.qmd,
# section "Generated tables", decision D20), Excel stage: the tables of the
# legacy plans under plans/ (TAB_PLAN.csv and LEGACY_*.csv, with their
# columns from plans/PLAN_COLUMNS.csv), written to .docs/generated/<id>.md.
# The other tables of the standard are written by 30-sdmx/pipeline/build_docs.R
# into the same folder; their ids are listed in .DOCS_OTHER_STAGE_IDS so the
# check knows them. The Markdown writers and the check itself are in
# docs_md.R (shared with 30-sdmx).
#
# Public functions:
#   docs_fragment_ids()           the ids this stage produces
#   docs_fragments(root)          named character vector id -> fragment text
#   docs_build(root, out_dir)     write every fragment into out_dir
#   docs_check(root, gen_dir, qmd_dir)
#                                 findings tibble (check_id, severity, file,
#                                 row_key, message); zero rows means current
#
# Depends on io.R (read_std_csv()), paths.R and docs_md.R having been
# sourced, and on the dplyr package (for the findings tibble).

# Column tables projected from plans/PLAN_COLUMNS.csv: fragment id, file in
# the register, whether the common codelist columns are left out, caption.
.DOCS_COLUMN_TABLES <- data.frame(
  id = c("tbl-tab-plan", "tbl-legacy-labels", "tbl-legacy-columns-csv", "tbl-legacy-overrides"),
  file = c("TAB_PLAN.csv", "LEGACY_LABELS.csv", "LEGACY_COLUMNS.csv", "LEGACY_OVERRIDES.csv"),
  drop_common = c(FALSE, FALSE, FALSE, FALSE),
  caption = c(
    "Columns of `TAB_PLAN.csv`",
    "Columns of `LEGACY_LABELS.csv`",
    "Columns of `LEGACY_COLUMNS.csv`",
    "Columns of `LEGACY_OVERRIDES.csv`"
  ),
  stringsAsFactors = FALSE
)

#' The ids of every fragment this stage produces, in document order.
#'
#' @return A character vector of 5 ids.
docs_fragment_ids <- function() {
  c("tbl-initial-plan", .DOCS_COLUMN_TABLES$id)
}

#' The ids 30-sdmx/pipeline/build_docs.R writes into .docs/generated/:
#' known to the check, never built here.
.DOCS_OTHER_STAGE_IDS <- c(
  "tbl-columns", "tbl-obs-status", "tbl-brk-vars", "tbl-qual-vars",
  "tbl-povlines", "tbl-small-codelists", "tbl-cl-indicator", "tbl-cl-brk-var",
  "tbl-cl-geo-scheme", "tbl-cl-geo", "tbl-surveys", "tbl-series-plan",
  "tbl-rules", "tbl-indicator-qualifiers", "tbl-qualifier-pairs",
  "tbl-sources", "tbl-text"
)

# Logical paths (R/paths.R) of every source file, keyed by stem.
.DOCS_SOURCES <- c(
  PLAN_COLUMNS = "plans/PLAN_COLUMNS.csv",
  TAB_PLAN = "plans/TAB_PLAN.csv"
)

#' Read one source CSV by stem; stops with the path if it is missing.
.docs_read <- function(root, stem) {
  rel <- .DOCS_SOURCES[[stem]]
  path <- stage_rel(root, rel)
  if (!file.exists(path)) {
    stop(sprintf("source file not found: %s", rel), call. = FALSE)
  }
  read_std_csv(path)
}

.docs_tbl_initial_plan <- function(root) {
  plan <- .docs_read(root, "TAB_PLAN")
  cols <- lapply(names(plan), function(nm) md_codes(plan[[nm]]))
  md_table(
    md_code(names(plan)), cols,
    "The current plan, reproducing the legacy Excel tables", "tbl-initial-plan"
  )
}

#' Build the text of every fragment.
#'
#' A fragment whose sources are missing or incomplete is left out, with a
#' warning naming the gap; the others are still built.
#'
#' @param root The stage folder, or a `stage_paths` object (R/paths.R).
#' @return A named character vector, id -> fragment text, in the order of
#'   [docs_fragment_ids()].
docs_fragments <- function(root) {
  builders <- list("tbl-initial-plan" = function() .docs_tbl_initial_plan(root))
  for (i in seq_len(nrow(.DOCS_COLUMN_TABLES))) {
    local({
      r <- .DOCS_COLUMN_TABLES[i, ]
      builders[[r$id]] <<- function() {
        .docs_tbl_file_columns(
          .docs_read(root, "PLAN_COLUMNS"), r$id, r$file, r$drop_common, r$caption,
          what = "PLAN_COLUMNS.csv"
        )
      }
    })
  }
  docs_run_builders(builders, docs_fragment_ids())
}

#' Write every fragment to `<out_dir>/<id>.md`.
#'
#' @param root The stage folder, or a `stage_paths` object.
#' @param out_dir Destination folder; created if needed. Default: .docs/generated/.
#' @return The paths written, invisibly.
docs_build <- function(root, out_dir = stage_path(root, "docs", "generated")) {
  frags <- docs_fragments(root)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  paths <- file.path(out_dir, paste0(names(frags), ".md"))
  for (i in seq_along(frags)) {
    .docs_write(frags[[i]], paths[i])
  }
  invisible(paths)
}

#' Check that the committed fragments of this stage are current and
#' included (see [docs_check_fragments()] in docs_md.R).
#'
#' @param root The stage folder, or a `stage_paths` object.
#' @param gen_dir Folder holding the committed fragments.
#' @param qmd_dir Folder whose `.qmd` files are searched for includes.
#' @return A tibble with columns check_id, severity, file, row_key,
#'   message; zero rows means the fragments are current.
docs_check <- function(root,
                       gen_dir = stage_path(root, "docs", "generated"),
                       qmd_dir = stage_dir(root, "docs")) {
  got <- docs_collect(function() docs_fragments(root))
  docs_check_fragments(
    got$frags, docs_fragment_ids(), .DOCS_OTHER_STAGE_IDS, gen_dir, qmd_dir,
    "Rscript build_docs.R (from 20-excel-sdmx-csv/)", got$not_built
  )
}
