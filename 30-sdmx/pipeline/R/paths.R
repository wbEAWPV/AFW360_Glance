# 30-sdmx/pipeline/R/paths.R
#
# Every location the SDMX stage reads or writes, defined once, from the
# stage folder (`30-sdmx/`, the `--root` of every script; the default is the
# stage folder of the script that runs). Code names a location by its kind,
# `stage_path(root, "metadata", "VERSION")`, or by a logical path whose
# first segment is a kind, `stage_rel(root, "metadata/codelists/CL_AGE.csv")`.
# Logical paths are what ARTEFACTS.csv, SOURCES.csv, the SDMX annotations and
# the findings `file` column carry, so they never change when a folder moves;
# only this file maps them to disk. No other code builds a path from the root.
#
# Kinds (the logical prefix is the kind's name, except where noted):
#
#   pipeline   pipeline                   the scripts
#   code       pipeline/R                 the modules
#   xsd        pipeline/xsd               the vendored SDMX-ML 3.1 schemas
#   fmr        pipeline/tools/fmr         the FMR scripts; runtime/ is the local
#                                         install (gitignored)
#   scratch    ../tmp                     the repository's gitignored scratch folder
#                                         (FMR responses and the 3.0 profile)
#   data       data                       SDMX-CSV data messages and manifests
#   metadata   data/metadata              the standard (codelists, DSD, plans, ...)
#   geo        data/geo                   boundaries (geo/boundaries/*.gpkg)
#   sdmx       output                     generated SDMX files (logical prefix sdmx/)
#   docs       ../.docs                   the documentation site (logical prefix .docs/)
#   dashboard  ../10-legacy-pipeline/data_dashboard
#              the dashboard's own files; flag --dashboard-dir, env AFW360_DASHBOARD_DIR
#   content    <dashboard>/content        TEXT.csv and text/ (MDS_TEXT, the TEXT checks)
#   assets     <dashboard>/assets         figures (the ASSET checks)
#   stage20    ../20-excel-sdmx-csv       the Excel stage (its bootstrap seeds are read
#                                         by tests/testthat/test-plan.R when present)
#   plans      <stage20>/plans            the legacy plans (TAB_PLAN.csv, LEGACY_*.csv);
#              optional, flag --plans-dir, env AFW360_PLANS_DIR
#   data_raw   ../10-legacy-pipeline/data_raw
#              the frozen legacy inputs, read only (SOURCES.csv inputs_sha256);
#              optional, flag --legacy-dir, env AFW360_LEGACY_DIR
#
# The reaches outside 30-sdmx/ are `dashboard` (read: the dashboard content
# is kept where the dashboard reads it), `plans` (read: the coverage checks
# need TAB_PLAN.csv and LEGACY_*.csv; without them those checks report
# COVER.SKIPPED) and `data_raw` (read: a missing folder skips the hash check).
# `docs` is where both stages write the generated tables.

#' The command-line flag and environment variable of each overridable kind.
STAGE_OVERRIDES <- data.frame(
  kind = c("dashboard", "plans", "data_raw"),
  flag = c("--dashboard-dir", "--plans-dir", "--legacy-dir"),
  env = c("AFW360_DASHBOARD_DIR", "AFW360_PLANS_DIR", "AFW360_LEGACY_DIR"),
  stringsAsFactors = FALSE
)

#' The logical prefixes that name a kind other than by its own name.
STAGE_PREFIX_KIND <- c(sdmx = "sdmx", .docs = "docs")

#' The folders of the stage rooted at `root`.
#'
#' @param root The stage folder (`30-sdmx/`).
#' @param overrides A named list, kind -> folder, for the kinds of
#'   [STAGE_OVERRIDES]; an absent or empty entry falls back to the
#'   environment variable, then to the default.
#' @return An object of class `stage_paths`: `root` (as given) and `dirs`
#'   (a named character vector, kind -> folder).
stage_paths <- function(root = ".", overrides = list()) {
  base <- normalizePath(root, winslash = "/", mustWork = FALSE)
  up <- dirname(base)
  pick <- function(kind, default) {
    v <- overrides[[kind]]
    if (is.null(v) || !nzchar(v)) v <- Sys.getenv(STAGE_OVERRIDES$env[STAGE_OVERRIDES$kind == kind], "")
    if (nzchar(v)) normalizePath(v, winslash = "/", mustWork = FALSE) else default
  }
  dashboard <- pick("dashboard", file.path(up, "10-legacy-pipeline", "data_dashboard"))
  dirs <- c(
    pipeline = file.path(base, "pipeline"),
    code = file.path(base, "pipeline", "R"),
    xsd = file.path(base, "pipeline", "xsd"),
    fmr = file.path(base, "pipeline", "tools", "fmr"),
    scratch = file.path(up, "tmp"),
    data = file.path(base, "data"),
    metadata = file.path(base, "data", "metadata"),
    geo = file.path(base, "data", "geo"),
    sdmx = file.path(base, "output"),
    docs = file.path(up, ".docs"),
    dashboard = dashboard,
    content = file.path(dashboard, "content"),
    assets = file.path(dashboard, "assets"),
    stage20 = file.path(up, "20-excel-sdmx-csv"),
    plans = pick("plans", file.path(up, "20-excel-sdmx-csv", "plans")),
    data_raw = pick("data_raw", file.path(up, "10-legacy-pipeline", "data_raw"))
  )
  structure(list(root = root, dirs = dirs), class = "stage_paths")
}

#' A `stage_paths` object, built with the defaults from a folder when `x` is
#' a string.
as_stage_paths <- function(x) {
  if (inherits(x, "stage_paths")) x else stage_paths(x)
}

#' The stage folder as given (a string), for messages and comparisons.
stage_root <- function(x) {
  if (inherits(x, "stage_paths")) x$root else x
}

#' The folder of one kind.
stage_dir <- function(root, kind) {
  dirs <- as_stage_paths(root)$dirs
  if (!kind %in% names(dirs)) stop("stage_dir: unknown kind '", kind, "'", call. = FALSE)
  unname(dirs[[kind]])
}

#' A path under the folder of one kind.
stage_path <- function(root, kind, ...) {
  file.path(stage_dir(root, kind), ...)
}

#' The file of a logical path (`metadata/structure/COLUMNS.csv`,
#' `data/<file>.csv`, `sdmx/structures/...`, `content/TEXT.csv`, ...).
stage_rel <- function(root, rel) {
  rel <- gsub("\\\\", "/", rel)
  head <- sub("/.*$", "", rel)
  rest <- if (grepl("/", rel, fixed = TRUE)) sub("^[^/]*/", "", rel) else ""
  kind <- if (head %in% names(STAGE_PREFIX_KIND)) STAGE_PREFIX_KIND[[head]] else head
  if (!kind %in% names(as_stage_paths(root)$dirs)) {
    stop("stage_rel: '", rel, "' does not start with a known folder", call. = FALSE)
  }
  if (nzchar(rest)) stage_path(root, kind, rest) else stage_dir(root, kind)
}

#' The folders whose CSV files load_metadata() reads, in order: the
#' standard, the dashboard content, and the legacy plans when present.
stage_metadata_dirs <- function(root) {
  c(stage_dir(root, "metadata"), stage_dir(root, "content"), stage_dir(root, "plans"))
}

#' The logical prefix of each folder of [stage_metadata_dirs()], used to
#' name a file in a finding (`metadata/...`, `content/...`, `plans/...`).
stage_metadata_prefixes <- function() c("metadata", "content", "plans")

#' Build the paths of a script from its arguments.
#'
#' @param args `commandArgs(trailingOnly = TRUE)`.
#' @param default_root The stage folder used when `--root` is absent.
#' @return A `stage_paths` object.
stage_paths_from_args <- function(args, default_root) {
  val <- function(flag) {
    i <- which(args == flag)
    if (length(i) == 0 || i[1] >= length(args)) "" else args[i[1] + 1]
  }
  root <- val("--root")
  if (!nzchar(root)) root <- default_root
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  ov <- list()
  for (i in seq_len(nrow(STAGE_OVERRIDES))) ov[[STAGE_OVERRIDES$kind[i]]] <- val(STAGE_OVERRIDES$flag[i])
  stage_paths(root, ov)
}

#' The flags of [STAGE_OVERRIDES] and `--root`, `--out-root`, which take a
#' value (for scripts that also take a positional argument).
stage_value_flags <- function() c("--root", "--out-root", STAGE_OVERRIDES$flag)
