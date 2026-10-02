# 20-excel-sdmx-csv/R/paths.R
#
# Every location the Excel-to-SDMX-CSV stage reads or writes, defined once,
# from the stage folder (`20-excel-sdmx-csv/`, the `--root` of every script;
# the default is the folder of the script that runs). Code names a location
# by its kind, `stage_path(root, "data_raw", "tables", ...)`, or by a
# logical path whose first segment is a kind (`metadata/plans/SERIES_PLAN.csv`,
# `data/<file>.csv`, `data_raw/tables/Tables_SEN.xlsx`); only this file maps
# them to disk.
#
# Read (kinds):
#
#   code       R                          the modules
#   plans      plans                      the legacy plans: TAB_PLAN.csv,
#                                         LEGACY_*.csv and their PLAN_COLUMNS.csv
#   bootstrap  bootstrap                  the frozen generators of metadata 0.1.0
#   data_raw   ../10-legacy-pipeline/data_raw
#              the frozen legacy inputs (never written); flag --legacy-dir,
#              env AFW360_LEGACY_DIR
#   sdmx_stage ../30-sdmx                 the SDMX stage; flag --sdmx-dir,
#                                         env AFW360_SDMX_DIR
#   metadata   <sdmx_stage>/data/metadata the standard (codelists, SERIES_PLAN, ...)
#   data       <sdmx_stage>/data          the published data files (reconcile.R)
#   geo        <sdmx_stage>/data/geo      the published boundaries
#   dashboard  ../10-legacy-pipeline/data_dashboard; flag --dashboard-dir,
#                                         env AFW360_DASHBOARD_DIR
#   content    <dashboard>/content        the published TEXT.csv (its key messages
#                                         are the source of build_content.R's)
#   assets     <dashboard>/assets
#   quarto     ../10-legacy-pipeline/AFW360  the dashboard's index.qmd
#                                         (build_content.R --messages-source dashboard)
#   docs       ../.docs                   the documentation site
#
# Written: the builders write only under the output folder (`--out-root`,
# default `output/`, gitignored), laid out like the destinations, and
# publish.R copies it there (PUBLISH_MAP):
#
#   output/data/        -> data       (<sdmx_stage>/data/)
#   output/geo/         -> geo        (<sdmx_stage>/data/geo/)
#   output/registries/  -> metadata/registries
#   output/content/     -> content    (<dashboard>/content/)
#   output/assets/      -> assets     (<dashboard>/assets/)
#
# build_docs.R writes .docs/generated/ directly, like the SDMX stage's.

#' The command-line flag and environment variable of each overridable kind.
STAGE_OVERRIDES <- data.frame(
  kind = c("data_raw", "sdmx_stage", "dashboard"),
  flag = c("--legacy-dir", "--sdmx-dir", "--dashboard-dir"),
  env = c("AFW360_LEGACY_DIR", "AFW360_SDMX_DIR", "AFW360_DASHBOARD_DIR"),
  stringsAsFactors = FALSE
)

#' The logical prefixes that name a kind other than by its own name.
STAGE_PREFIX_KIND <- c(.docs = "docs")

#' The output folders (under `--out-root`) and where publish.R copies each:
#' a kind, and a path under it ("" for the kind's folder itself).
PUBLISH_MAP <- data.frame(
  output = c("data", "geo", "registries", "content", "assets"),
  kind = c("data", "geo", "metadata", "content", "assets"),
  under = c("", "", "registries", "", ""),
  stringsAsFactors = FALSE
)

#' The folders of the stage rooted at `root`.
#'
#' @param root The stage folder (`20-excel-sdmx-csv/`).
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
  sdmx_stage <- pick("sdmx_stage", file.path(up, "30-sdmx"))
  dashboard <- pick("dashboard", file.path(up, "10-legacy-pipeline", "data_dashboard"))
  dirs <- c(
    code = file.path(base, "R"),
    plans = file.path(base, "plans"),
    bootstrap = file.path(base, "bootstrap"),
    output = file.path(base, "output"),
    data_raw = pick("data_raw", file.path(up, "10-legacy-pipeline", "data_raw")),
    sdmx_stage = sdmx_stage,
    metadata = file.path(sdmx_stage, "data", "metadata"),
    data = file.path(sdmx_stage, "data"),
    geo = file.path(sdmx_stage, "data", "geo"),
    dashboard = dashboard,
    content = file.path(dashboard, "content"),
    assets = file.path(dashboard, "assets"),
    quarto = file.path(up, "10-legacy-pipeline", "AFW360"),
    docs = file.path(up, ".docs")
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

#' The file of a logical path (`metadata/...`, `data/<file>.csv`,
#' `data_raw/tables/...`, `plans/TAB_PLAN.csv`, `.docs/...`).
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
#' standard, the legacy plans, and the published dashboard content.
stage_metadata_dirs <- function(root) {
  c(stage_dir(root, "metadata"), stage_dir(root, "plans"), stage_dir(root, "content"))
}

#' The logical prefix of each folder of [stage_metadata_dirs()].
stage_metadata_prefixes <- function() c("metadata", "plans", "content")

#' A path under the output folder `out` (the `--out-root`): one of the
#' folders of [PUBLISH_MAP] (`data`, `geo`, `registries`, `content`,
#' `assets`).
output_path <- function(out, folder, ...) {
  if (!folder %in% PUBLISH_MAP$output) stop("output_path: unknown output folder '", folder, "'", call. = FALSE)
  file.path(out, folder, ...)
}

#' Where publish.R copies one output folder.
publish_destination <- function(root, folder) {
  i <- match(folder, PUBLISH_MAP$output)
  if (is.na(i)) stop("publish_destination: unknown output folder '", folder, "'", call. = FALSE)
  if (nzchar(PUBLISH_MAP$under[i])) {
    stage_path(root, PUBLISH_MAP$kind[i], PUBLISH_MAP$under[i])
  } else {
    stage_dir(root, PUBLISH_MAP$kind[i])
  }
}

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

#' The output folder of a script: `--out-root`, else the stage's output/.
stage_out_root <- function(args, paths) {
  i <- which(args == "--out-root")
  out <- if (length(i) == 0 || i[1] >= length(args)) stage_dir(paths, "output") else args[i[1] + 1]
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  normalizePath(out, winslash = "/", mustWork = TRUE)
}
