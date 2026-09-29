# pipeline/R/ctx.R
#
# Builds the shared context object that every validator check receives.
# Depends on pipeline/R/io.R for read_std_csv() and load_metadata().
#
# Since metadata 0.2.0 the manifest carries no `precision` key (D15): a
# row's rounding unit is its own PRECISION cell, and a row's source kind
# (the reliability-attribute exemption) comes from its SOURCE_ID through
# metadata/registries/SOURCES.csv (D16). ctx therefore carries no
# file-level precision any more.

#' Build the shared pipeline context.
#'
#' @param root Repo root.
#' @param data_files Character vector of paths to standard data CSVs to
#'   load. Defaults to none.
#' @param opts A list of extra options, carried through unchanged.
#' @return A list with:
#'   \describe{
#'     \item{root}{`root`.}
#'     \item{meta}{`load_metadata(root)`.}
#'     \item{data}{A named list of tibbles from [read_std_csv()], keyed by
#'       each data file's base name (without extension).}
#'     \item{manifests}{A named list with the same keys, each a named
#'       character vector (key to value) read from the `<stem>_manifest.csv`
#'       file beside the data file, or an empty character vector when the
#'       manifest is missing.}
#'     \item{version}{The metadata version, the trimmed first line of
#'       `<root>/metadata/VERSION` (for example `"0.3.0"`), or `NA` when the
#'       file is missing; `STRUCTURE_ID` must equal
#'       [structure_id()] of it.}
#'     \item{opts}{`opts`.}
#'   }
build_ctx <- function(root, data_files = character(0), opts = list()) {
  meta <- load_metadata(root)

  data <- list()
  manifests <- list()

  for (f in data_files) {
    key <- tools::file_path_sans_ext(basename(f))
    data[[key]] <- read_std_csv(f)

    manifest_path <- file.path(dirname(f), paste0(key, "_manifest.csv"))
    man_vec <- character(0)
    if (file.exists(manifest_path)) {
      man_df <- read_std_csv(manifest_path)
      if (ncol(man_df) >= 2) {
        man_vec <- stats::setNames(
          as.character(man_df[[2]]),
          as.character(man_df[[1]])
        )
      }
    }
    manifests[[key]] <- man_vec
  }

  version <- NA_character_
  version_path <- file.path(root, "metadata", "VERSION")
  if (file.exists(version_path)) {
    v <- trimws(readLines(version_path, n = 1, warn = FALSE))
    if (length(v) == 1 && nzchar(v)) version <- v
  }

  list(
    root = root,
    meta = meta,
    data = data,
    manifests = manifests,
    version = version,
    opts = opts
  )
}

# ---- accessors shared by the validator modules ---------------------------
#
# Every validate_*.R module reads the same few derived facts: the key
# columns, a row's findings key, the kind of a row's source, the file's
# estimation method and the dataflow's reliability thresholds. They live
# here, beside build_ctx(), so the modules agree on them.

#' The key columns of a data file: the DSD's dimensions and time dimension
#' (19 in DSD 0.3.0, `FREQ` .. `MEASURE_QUAL_5` plus `TIME_PERIOD`), from
#' [dsd_key_columns()]. Stops when the metadata holds no `DSD_AFW360_HH`
#' (no script hard-codes the column list; a validator run reports the stop
#' as a `<MODULE>.CRASH` finding).
#'
#' @param ctx The list from [build_ctx()].
#' @return A character vector of column ids.
ctx_key_columns <- function(ctx) {
  .ctx_require_dsd(ctx)
  dsd_key_columns(ctx$meta)
}

#' The DSD components in data-file order (34 in DSD 0.3.0), from
#' [dsd_columns()]; the three fixed SDMX-CSV columns are not among them.
#'
#' @param ctx The list from [build_ctx()].
#' @return A character vector of column ids.
ctx_dsd_columns <- function(ctx) {
  .ctx_require_dsd(ctx)
  dsd_columns(ctx$meta)
}

#' The full header of an SDMX-CSV 2.1 data file: [SDMX_CSV_FIXED]
#' (`STRUCTURE`, `STRUCTURE_ID`, `ACTION`) followed by [ctx_dsd_columns()]
#' (37 columns in DSD 0.3.0).
#'
#' @param ctx The list from [build_ctx()].
#' @return A character vector of column names.
ctx_data_columns <- function(ctx) {
  c(SDMX_CSV_FIXED, ctx_dsd_columns(ctx))
}

#' Stop unless the metadata holds the DSD table.
.ctx_require_dsd <- function(ctx) {
  if (is.null(ctx$meta$DSD_AFW360_HH)) {
    stop("ctx: metadata table DSD_AFW360_HH is missing (metadata/structure/DSD_AFW360_HH.csv)", call. = FALSE)
  }
  invisible(TRUE)
}

#' The findings `row_key` of each row: its key values joined by one space.
#'
#' @param ctx The list from [build_ctx()].
#' @param df A data frame holding the key columns.
#' @return A character vector, one entry per row.
ctx_row_keys <- function(ctx, df) {
  cols <- ctx_key_columns(ctx)
  cols <- cols[cols %in% names(df)]
  if (length(cols) == 0 || nrow(df) == 0) return(character(0))
  do.call(paste, c(lapply(df[cols], as.character), sep = " "))
}

#' The `kind` of each source id in SOURCES.csv (`LEGACY_CONVERSION` or
#' `PRODUCER`), `NA` for an unknown id.
#'
#' @param ctx The list from [build_ctx()].
#' @param source_ids A character vector of SOURCE_ID values.
#' @return A character vector, the same length.
ctx_source_kind <- function(ctx, source_ids) {
  src <- ctx$meta$SOURCES
  if (is.null(src) || !all(c("source_id", "kind") %in% names(src))) {
    return(rep(NA_character_, length(source_ids)))
  }
  unname(src$kind[match(source_ids, src$source_id)])
}

#' Parse a data file stem `AFW360_HH_<REF_AREA>_<TIME_PERIOD>_<ESTIMATION>`.
#'
#' @param key A data file stem (base name without `.csv`).
#' @return A named character vector (`ref_area`, `time_period`,
#'   `estimation`), or `NULL` when the stem does not follow the pattern.
ctx_parse_file_name <- function(key) {
  re <- paste0("^", DATAFLOW_ID, "_([A-Z]{3})_([0-9]{4})_([A-Z][A-Z0-9_]*)$")
  if (!grepl(re, key)) return(NULL)
  c(
    ref_area = sub(re, "\\1", key),
    time_period = sub(re, "\\2", key),
    estimation = sub(re, "\\3", key)
  )
}

#' A data file's estimation method: the manifest's `estimation`, else the
#' one in its file name, else the single ESTIMATION value of its rows, else
#' `NA`.
#'
#' @param ctx The list from [build_ctx()].
#' @param key A `ctx$data` name (the file's stem).
#' @return A single string or `NA_character_`.
ctx_file_estimation <- function(ctx, key) {
  man <- ctx$manifests[[key]]
  if (!is.null(man) && "estimation" %in% names(man) && nzchar(trimws(man[["estimation"]]))) {
    return(trimws(unname(man[["estimation"]])))
  }
  parsed <- ctx_parse_file_name(key)
  if (!is.null(parsed)) return(unname(parsed[["estimation"]]))
  df <- ctx$data[[key]]
  if (!is.null(df) && "ESTIMATION" %in% names(df)) {
    u <- unique(df$ESTIMATION)
    if (length(u) == 1) return(u)
  }
  NA_character_
}

#' The rows of RULES.csv that are in force (every status but DEPRECATED).
#'
#' @param ctx The list from [build_ctx()].
#' @return A data frame (zero rows when RULES.csv is absent).
ctx_rules <- function(ctx) {
  rules <- ctx$meta$RULES
  if (is.null(rules)) {
    return(data.frame(
      rule_id = character(0), scope = character(0), scope_code = character(0),
      rule = character(0), param = character(0), tolerance = character(0),
      severity = character(0), status = character(0), stringsAsFactors = FALSE
    ))
  }
  rules <- as.data.frame(rules, stringsAsFactors = FALSE)
  if ("status" %in% names(rules)) rules <- rules[rules$status != "DEPRECATED", , drop = FALSE]
  rules
}

#' A dataflow-level threshold from RULES.csv (`RELIABILITY_MIN_NOBS` or
#' `RELIABILITY_MAX_CV`).
#'
#' @param ctx The list from [build_ctx()].
#' @param rule The rule name.
#' @return A list with `value` (numeric, `NA` when the rule is absent or
#'   malformed) and `severity` (`"ERROR"` by default).
ctx_dataflow_threshold <- function(ctx, rule) {
  rules <- ctx_rules(ctx)
  hit <- rules[rules$scope == "DATAFLOW" & rules$rule == rule, , drop = FALSE]
  if (nrow(hit) == 0) return(list(value = NA_real_, severity = "ERROR"))
  sev <- hit$severity[1]
  if (is.na(sev) || !(sev %in% c("ERROR", "WARN"))) sev <- "ERROR"
  list(value = suppressWarnings(as.numeric(hit$param[1])), severity = sev)
}
