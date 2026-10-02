# 30-sdmx/pipeline/R/docs.R
#
# Documentation generator for the data standard (.docs/data-standard.qmd,
# section "Generated tables", decision D20), SDMX stage.
#
# Every table in the standard that lists the contents of a file of the
# standard's metadata (or of the dashboard's content/TEXT.csv) is written
# here to .docs/generated/<id>.md. The tables of the legacy plans
# (TAB_PLAN.csv, LEGACY_*.csv) are written by 20-excel-sdmx-csv/build_docs.R
# into the same folder; their ids are listed in .DOCS_OTHER_STAGE_IDS so the
# check knows them. The Markdown writers and the check itself are in
# docs_md.R (shared with 20-excel-sdmx-csv).
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

# ---- the fragment list ---------------------------------------------------

# The small codelists of @tbl-small-codelists, in the order shown.
.DOCS_SMALL_CODELISTS <- c(
  "CL_FREQ", "CL_SEX", "CL_AGE", "CL_URBANISATION", "CL_ESTIMATION",
  "CL_OBS_STATUS", "CL_THEME", "CL_STAT_UNIT", "CL_STATISTIC", "CL_WEIGHT",
  "CL_UNIT_MEASURE"
)

# Column tables projected from metadata/structure/COLUMNS.csv:
# fragment id, file in the registry, whether the common codelist columns
# are left out, caption.
.DOCS_COLUMN_TABLES <- data.frame(
  id = c(
    "tbl-cl-indicator", "tbl-cl-brk-var", "tbl-cl-geo-scheme", "tbl-cl-geo",
    "tbl-surveys", "tbl-series-plan", "tbl-rules",
    "tbl-indicator-qualifiers", "tbl-qualifier-pairs", "tbl-sources",
    "tbl-text"
  ),
  file = c(
    "CL_INDICATOR.csv", "CL_BRK_VAR.csv", "CL_GEO_SCHEME.csv", "CL_GEO.csv",
    "SURVEYS.csv", "SERIES_PLAN.csv", "RULES.csv",
    "INDICATOR_QUALIFIERS.csv", "QUALIFIER_PAIRS.csv", "SOURCES.csv",
    "TEXT.csv"
  ),
  drop_common = c(
    TRUE, TRUE, FALSE, TRUE,
    FALSE, FALSE, FALSE,
    FALSE, FALSE, FALSE,
    FALSE
  ),
  caption = c(
    "Columns of `CL_INDICATOR.csv`, beyond the common ones",
    "Columns of `CL_BRK_VAR.csv`, beyond the common ones",
    "Columns of `CL_GEO_SCHEME.csv`",
    "Columns of `CL_GEO.csv`, beyond the common ones",
    "Columns of `SURVEYS.csv`",
    "Columns of `SERIES_PLAN.csv`",
    "Columns of `RULES.csv`",
    "Columns of `INDICATOR_QUALIFIERS.csv`",
    "Columns of `QUALIFIER_PAIRS.csv`",
    "Columns of `SOURCES.csv`",
    "Columns of `TEXT.csv`"
  ),
  stringsAsFactors = FALSE
)

#' The ids of every fragment this stage produces, in document order.
#'
#' @return A character vector of 17 ids.
docs_fragment_ids <- function() {
  c(
    "tbl-columns", "tbl-obs-status", "tbl-brk-vars", "tbl-qual-vars",
    "tbl-povlines", "tbl-small-codelists",
    .DOCS_COLUMN_TABLES$id
  )
}

#' The ids 20-excel-sdmx-csv/build_docs.R writes into .docs/generated/ (the
#' tables of the legacy plans): known to the check, never built here.
.DOCS_OTHER_STAGE_IDS <- c(
  "tbl-initial-plan", "tbl-tab-plan", "tbl-legacy-labels",
  "tbl-legacy-columns-csv", "tbl-legacy-overrides"
)

# ---- reading the sources -------------------------------------------------

# Logical paths (R/paths.R) of every source file, keyed by stem.
.DOCS_SOURCES <- c(
  COLUMNS = "metadata/structure/COLUMNS.csv",
  DSD_AFW360_HH = "metadata/structure/DSD_AFW360_HH.csv",
  QUALIFIER_PAIRS = "metadata/structure/QUALIFIER_PAIRS.csv",
  CL_BRK_VAR = "metadata/codelists/CL_BRK_VAR.csv",
  CL_COMP_BREAKDOWN = "metadata/codelists/CL_COMP_BREAKDOWN.csv",
  CL_QUAL_VAR = "metadata/codelists/CL_QUAL_VAR.csv",
  CL_QUALIFIER = "metadata/codelists/CL_QUALIFIER.csv",
  CL_OBS_STATUS = "metadata/codelists/CL_OBS_STATUS.csv",
  CL_FREQ = "metadata/codelists/CL_FREQ.csv",
  CL_SEX = "metadata/codelists/CL_SEX.csv",
  CL_AGE = "metadata/codelists/CL_AGE.csv",
  CL_URBANISATION = "metadata/codelists/CL_URBANISATION.csv",
  CL_ESTIMATION = "metadata/codelists/CL_ESTIMATION.csv",
  CL_THEME = "metadata/codelists/CL_THEME.csv",
  CL_STAT_UNIT = "metadata/codelists/CL_STAT_UNIT.csv",
  CL_STATISTIC = "metadata/codelists/CL_STATISTIC.csv",
  CL_WEIGHT = "metadata/codelists/CL_WEIGHT.csv",
  CL_UNIT_MEASURE = "metadata/codelists/CL_UNIT_MEASURE.csv"
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

# ---- one builder per fragment --------------------------------------------

.docs_tbl_columns <- function(root) {
  dsd <- .docs_read(root, "DSD_AFW360_HH")
  .docs_need(dsd, c(
    "position", "id", "component", "role", "codelist", "data_type", "usage",
    "relationship", "measure_relationship", "required", "sentinel",
    "min_value", "max_value", "description"
  ), "DSD_AFW360_HH.csv")
  dsd <- .docs_by_order(dsd, "position")
  # Data type with its bounds, e.g. "Double, min 0".
  dtype <- dsd$data_type
  has_min <- dsd$min_value != ""
  has_max <- dsd$max_value != ""
  dtype[has_min] <- paste0(dtype[has_min], ", min ", dsd$min_value[has_min])
  dtype[has_max] <- paste0(dtype[has_max], ", max ", dsd$max_value[has_max])
  # Attachment: "observation" as text, a dimension list as codes, then the
  # measure relationship if any.
  rel <- ifelse(dsd$relationship == "observation", "observation", md_codes(dsd$relationship))
  has_mr <- dsd$measure_relationship != ""
  rel[has_mr] <- paste0(rel[has_mr], "; measure ", md_codes(dsd$measure_relationship[has_mr]))
  md_table(
    c(
      "#", "Component", "Type", "Role", "Codelist", "Data type", "Usage",
      "Relationship", "Sentinels", "Required", "Description"
    ),
    list(
      md_text(dsd$position), md_code(dsd$id), md_text(dsd$component), md_text(dsd$role),
      md_code(dsd$codelist), md_text(dtype), md_text(dsd$usage), rel,
      md_codes(dsd$sentinel), md_text(dsd$required), md_text(dsd$description)
    ),
    "Components of the `DSD_AFW360_HH` data structure, in data-file order", "tbl-columns"
  )
}

.docs_tbl_obs_status <- function(root) {
  cl <- .docs_read(root, "CL_OBS_STATUS")
  .docs_need(cl, c("code", "name_en", "definition_en"), "CL_OBS_STATUS.csv")
  md_table(
    c("Code", "Meaning", "Definition"),
    list(md_code(cl$code), md_text(cl$name_en), md_text(cl$definition_en)),
    "Observation status codes", "tbl-obs-status"
  )
}

.docs_tbl_brk_vars <- function(root) {
  vars <- .docs_read(root, "CL_BRK_VAR")
  cats <- .docs_read(root, "CL_COMP_BREAKDOWN")
  .docs_need(vars, c("code", "describes", "universe", "slot_order", "status"), "CL_BRK_VAR.csv")
  .docs_need(cats, c("code", "var_code", "order"), "CL_COMP_BREAKDOWN.csv")
  vars <- .docs_by_order(vars, "slot_order")
  categories <- vapply(vars$code, function(v) {
    md_categories(.docs_by_order(cats[cats$var_code == v, , drop = FALSE])$code)
  }, character(1), USE.NAMES = FALSE)
  md_table(
    c("`var_code`", "Describes", "Universe", "Categories", "`slot_order`", "Status"),
    list(
      md_code(vars$code), md_codes(vars$describes), md_text(vars$universe), categories,
      md_text(vars$slot_order), md_code(vars$status)
    ),
    "Registered breakdown variables", "tbl-brk-vars"
  )
}

.docs_tbl_qual_vars <- function(root) {
  vars <- .docs_read(root, "CL_QUAL_VAR")
  cats <- .docs_read(root, "CL_QUALIFIER")
  .docs_need(vars, c("code", "name_en", "slot_order"), "CL_QUAL_VAR.csv")
  .docs_need(cats, c("code", "var_code", "order"), "CL_QUALIFIER.csv")
  vars <- .docs_by_order(vars, "slot_order")
  categories <- vapply(vars$code, function(v) {
    md_categories(.docs_by_order(cats[cats$var_code == v, , drop = FALSE])$code)
  }, character(1), USE.NAMES = FALSE)
  md_table(
    c("`var_code`", "What it says", "Categories", "`slot_order`"),
    list(md_code(vars$code), md_text(vars$name_en), categories, md_text(vars$slot_order)),
    "Registered qualifier variables", "tbl-qual-vars"
  )
}

.docs_tbl_povlines <- function(root) {
  q <- .docs_read(root, "CL_QUALIFIER")
  pairs <- .docs_read(root, "QUALIFIER_PAIRS")
  .docs_need(q, c("code", "var_code", "value", "basis", "order"), "CL_QUALIFIER.csv")
  .docs_need(pairs, c("qualifier", "with_var", "allowed"), "QUALIFIER_PAIRS.csv")
  pl <- .docs_by_order(q[q$var_code == "POVLINE", , drop = FALSE])
  ppp <- pairs[pairs$with_var == "PPP", , drop = FALSE]
  allowed <- vapply(pl$code, function(cd) {
    hit <- ppp$allowed[ppp$qualifier == cd]
    if (length(hit) == 0) "" else md_codes(paste(hit, collapse = " "))
  }, character(1), USE.NAMES = FALSE)
  md_table(
    c("`code`", "`value`", "`basis`", "Allowed `PPP`"),
    list(md_code(pl$code), md_text(pl$value), md_text(pl$basis), allowed),
    "Poverty lines", "tbl-povlines"
  )
}

.docs_tbl_small_codelists <- function(root) {
  codes <- vapply(.DOCS_SMALL_CODELISTS, function(stem) {
    cl <- .docs_read(root, stem)
    .docs_need(cl, "code", paste0(stem, ".csv"))
    shown <- md_code(cl$code)
    if ("parent" %in% names(cl)) {
      has <- cl$parent != ""
      shown[has] <- paste0(shown[has], " (parent = ", md_code(cl$parent[has]), ")")
    }
    paste(shown, collapse = ", ")
  }, character(1), USE.NAMES = FALSE)
  md_table(
    c("Codelist", "Codes"),
    list(md_code(.DOCS_SMALL_CODELISTS), codes),
    "Small codelists and their codes", "tbl-small-codelists"
  )
}

# ---- public API ----------------------------------------------------------

#' Build the text of every fragment.
#'
#' A fragment whose sources are missing or incomplete is left out, with a
#' warning naming the gap; the others are still built.
#'
#' @param root The stage folder, or a `stage_paths` object (R/paths.R).
#' @return A named character vector, id -> fragment text, in the order of
#'   [docs_fragment_ids()].
docs_fragments <- function(root) {
  builders <- list(
    "tbl-columns" = function() .docs_tbl_columns(root),
    "tbl-obs-status" = function() .docs_tbl_obs_status(root),
    "tbl-brk-vars" = function() .docs_tbl_brk_vars(root),
    "tbl-qual-vars" = function() .docs_tbl_qual_vars(root),
    "tbl-povlines" = function() .docs_tbl_povlines(root),
    "tbl-small-codelists" = function() .docs_tbl_small_codelists(root)
  )
  for (i in seq_len(nrow(.DOCS_COLUMN_TABLES))) {
    local({
      r <- .DOCS_COLUMN_TABLES[i, ]
      builders[[r$id]] <<- function() {
        .docs_tbl_file_columns(.docs_read(root, "COLUMNS"), r$id, r$file, r$drop_common, r$caption)
      }
    })
  }
  docs_run_builders(builders, docs_fragment_ids())
}

#' Write every fragment to `<out_dir>/<id>.md`.
#'
#' @param root The stage folder, or a `stage_paths` object (sources are
#'   read from its metadata/ and content/).
#' @param out_dir Destination folder; created if needed. Default: the
#'   stage's .docs/generated/.
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
#' @param qmd_dir Folder whose `.qmd` files are searched for includes; the
#'   standard is `<qmd_dir>/data-standard.qmd`.
#' @return A tibble with columns check_id, severity, file, row_key,
#'   message; zero rows means the fragments are current.
docs_check <- function(root,
                       gen_dir = stage_path(root, "docs", "generated"),
                       qmd_dir = stage_dir(root, "docs")) {
  got <- docs_collect(function() docs_fragments(root))
  docs_check_fragments(
    got$frags, docs_fragment_ids(), .DOCS_OTHER_STAGE_IDS, gen_dir, qmd_dir,
    "Rscript pipeline/build_docs.R (from 30-sdmx/)", got$not_built
  )
}
