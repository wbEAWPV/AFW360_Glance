# pipeline/R/validate_values.R
#
# Value checks (WP12): that OBS_VALUE and its attributes on every row of a
# data file are well formed - plain-decimal, in the indicator's plausible
# range, consistent with OBS_STATUS, carrying the D9 LEGACY_EMPTY comment
# where required, and (where filled) a sane STD_ERR / CI / N_OBS / N_POP.
#
# Depends on `ctx` built by build_ctx() (pipeline/R/ctx.R), which needs
# pipeline/R/io.R, and on ctx$meta$CL_INDICATOR for valid_min/valid_max.
# Callers source those before this file; this file does not source
# anything itself (.docs/transition/packages/WP12.md).
#
# Findings format is the same as pipeline/R/validate_coverage.R's checks
# (word for word the same on WP11-WP14); see that file's header for the
# column and row_key conventions, and .vc_apply_cap() for the 20-finding
# cap. The small private helpers below are duplicated there on purpose,
# so this file stays independently sourceable.

# The 18 KEY_COLUMNS, in their contract order (contract/csv_headers.csv,
# AFW360_HH_<ISO3>_<YEAR>.csv, positions 1-18).
.VC_KEY_COLS <- c(
  "DATAFLOW", "REF_AREA", "GEO", "TIME_PERIOD", "INDICATOR", "SEX", "AGE",
  "URBANISATION", "COMP_BREAKDOWN_1", "COMP_BREAKDOWN_2", "COMP_BREAKDOWN_3",
  "COMP_BREAKDOWN_4", "COMP_BREAKDOWN_5", "MEASURE_QUAL_1", "MEASURE_QUAL_2",
  "MEASURE_QUAL_3", "MEASURE_QUAL_4", "MEASURE_QUAL_5"
)

#' Build the findings row_key for each row of a data frame.
#'
#' @param df A data frame holding (a subset of) `cols`.
#' @param cols The key columns to join, in order.
#' @return A character vector, one entry per row of `df`.
.vc_row_key <- function(df, cols) {
  cols <- cols[cols %in% names(df)]
  if (length(cols) == 0 || nrow(df) == 0) {
    return(character(0))
  }
  do.call(paste, c(df[cols], sep = " "))
}

#' The findings `file` value for a data key.
#'
#' @param key A `ctx$data` / `ctx$manifests` list name (the file's stem).
#' @return `"data/<key>.csv"`.
.vc_file_path <- function(key) paste0("data/", key, ".csv")

#' An empty findings frame, with the right columns and types.
.vc_empty <- function() {
  data.frame(
    check_id = character(0), severity = character(0), file = character(0),
    row_key = character(0), message = character(0),
    stringsAsFactors = FALSE
  )
}

#' Cap findings at 20 per check_id/file pair (WP12.md "Findings format").
#'
#' @param findings A findings data frame, any number of rows.
#' @return `findings`, with each check_id/file group cut to its first 20
#'   rows in row_key order plus one SUMMARY row when it had more.
.vc_apply_cap <- function(findings) {
  if (nrow(findings) == 0) {
    return(findings)
  }
  group_key <- paste(findings$check_id, findings$file, sep = "")
  groups <- split(seq_len(nrow(findings)), group_key)
  groups <- groups[order(names(groups), method = "radix")]
  parts <- vector("list", length(groups))
  for (i in seq_along(groups)) {
    grp <- findings[groups[[i]], , drop = FALSE]
    grp <- grp[order(grp$row_key, method = "radix"), , drop = FALSE]
    n <- nrow(grp)
    if (n > 20) {
      kept <- grp[seq_len(20), , drop = FALSE]
      summary_row <- kept[1, , drop = FALSE]
      summary_row$row_key <- ""
      summary_row$message <- sprintf("SUMMARY: %d findings in total, 20 shown", n)
      grp <- rbind(kept, summary_row)
    }
    parts[[i]] <- grp
  }
  result <- do.call(rbind, parts)
  rownames(result) <- NULL
  result
}

#' Bind a list of findings frames into one findings tibble.
#'
#' @param parts A list of data frames (as built by the `vc_*` functions),
#'   possibly empty or with empty members.
#' @return A tibble with zero or more findings, capped (`.vc_apply_cap()`).
.vc_bind <- function(parts) {
  parts <- parts[vapply(parts, function(x) !is.null(x) && nrow(x) > 0, logical(1))]
  if (length(parts) == 0) {
    return(dplyr::as_tibble(.vc_empty()))
  }
  result <- do.call(rbind, parts)
  rownames(result) <- NULL
  dplyr::as_tibble(.vc_apply_cap(result))
}

# A plain decimal number: optional leading '-', digits, optional '.digits'.
# No scientific notation, no leading '+', no thousands separator.
.VC_NUMERIC_RE <- "^-?[0-9]+(\\.[0-9]+)?$"

#' The precision (`"EXACT"` or `"ROUNDED_2DP"`) recorded for a data key.
#'
#' @param ctx The list from [build_ctx()].
#' @param key A `ctx$data` list name.
#' @return A single string; `"EXACT"` when unrecorded.
.vc_precision <- function(ctx, key) {
  if (key %in% names(ctx$precision)) ctx$precision[[key]] else "EXACT"
}

#' VALUE.NUMERIC: a filled OBS_VALUE is not a plain decimal number.
#'
#' @param ctx The list from [build_ctx()].
#' @return A findings tibble.
vc_value_numeric <- function(ctx) {
  out <- list()
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (nrow(df) == 0 || !("OBS_VALUE" %in% names(df))) next

    raw <- trimws(df$OBS_VALUE)
    filled <- raw != ""
    bad <- which(filled & !grepl(.VC_NUMERIC_RE, raw))
    if (length(bad) > 0) {
      out[[length(out) + 1]] <- data.frame(
        check_id = "VALUE.NUMERIC", severity = "ERROR", file = .vc_file_path(key),
        row_key = .vc_row_key(df[bad, , drop = FALSE], .VC_KEY_COLS),
        message = paste0("OBS_VALUE '", raw[bad], "' is not a plain decimal number."),
        stringsAsFactors = FALSE
      )
    }
  }
  .vc_bind(out)
}

#' VALUE.RANGE: OBS_VALUE lies outside the indicator's valid_min/valid_max.
#'
#' @param ctx The list from [build_ctx()].
#' @return A findings tibble.
vc_value_range <- function(ctx) {
  out <- list()
  cl_indicator <- ctx$meta$CL_INDICATOR
  if (is.null(cl_indicator)) {
    return(.vc_bind(out))
  }

  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (nrow(df) == 0 || !all(c("OBS_VALUE", "INDICATOR") %in% names(df))) next

    val <- suppressWarnings(as.numeric(trimws(df$OBS_VALUE)))
    has_val <- trimws(df$OBS_VALUE) != "" & !is.na(val)
    if (!any(has_val)) next

    bounds <- cl_indicator[match(df$INDICATOR, cl_indicator$code), c("valid_min", "valid_max")]
    min_v <- suppressWarnings(as.numeric(trimws(bounds$valid_min)))
    max_v <- suppressWarnings(as.numeric(trimws(bounds$valid_max)))

    below <- has_val & !is.na(min_v) & val < min_v
    above <- has_val & !is.na(max_v) & val > max_v
    bad <- which(below | above)
    if (length(bad) > 0) {
      out[[length(out) + 1]] <- data.frame(
        check_id = "VALUE.RANGE", severity = "ERROR", file = .vc_file_path(key),
        row_key = .vc_row_key(df[bad, , drop = FALSE], .VC_KEY_COLS),
        message = sprintf(
          "OBS_VALUE %s lies outside the indicator's valid range [%s, %s].",
          trimws(df$OBS_VALUE[bad]),
          ifelse(is.na(min_v[bad]), "", as.character(min_v[bad])),
          ifelse(is.na(max_v[bad]), "", as.character(max_v[bad]))
        ),
        stringsAsFactors = FALSE
      )
    }
  }
  .vc_bind(out)
}

#' VALUE.STATUS_EMPTY: OBS_VALUE is empty although OBS_STATUS is A or E,
#' or filled although it is O or M.
#'
#' @param ctx The list from [build_ctx()].
#' @return A findings tibble.
vc_value_status_empty <- function(ctx) {
  out <- list()
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (nrow(df) == 0 || !all(c("OBS_VALUE", "OBS_STATUS") %in% names(df))) next

    filled <- trimws(df$OBS_VALUE) != ""
    status <- trimws(df$OBS_STATUS)

    bad_empty <- status %in% c("A", "E") & !filled
    bad_filled <- status %in% c("O", "M") & filled
    bad <- which(bad_empty | bad_filled)
    if (length(bad) > 0) {
      msg <- ifelse(
        bad_empty[bad],
        paste0("OBS_STATUS '", status[bad], "' requires OBS_VALUE, but it is empty."),
        paste0("OBS_STATUS '", status[bad], "' requires OBS_VALUE to be empty, but it is filled.")
      )
      out[[length(out) + 1]] <- data.frame(
        check_id = "VALUE.STATUS_EMPTY", severity = "ERROR", file = .vc_file_path(key),
        row_key = .vc_row_key(df[bad, , drop = FALSE], .VC_KEY_COLS),
        message = msg,
        stringsAsFactors = FALSE
      )
    }
  }
  .vc_bind(out)
}

#' VALUE.LEGACY_EMPTY: in a ROUNDED_2DP file, an O row whose OBS_COMMENT
#' does not start with `"LEGACY_EMPTY:"` (decision D9).
#'
#' @param ctx The list from [build_ctx()].
#' @return A findings tibble.
vc_value_legacy_empty <- function(ctx) {
  out <- list()
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (nrow(df) == 0) next
    if (!identical(.vc_precision(ctx, key), "ROUNDED_2DP")) next
    if (!all(c("OBS_STATUS", "OBS_COMMENT") %in% names(df))) next

    is_o <- trimws(df$OBS_STATUS) == "O"
    comment <- ifelse(is.na(df$OBS_COMMENT), "", df$OBS_COMMENT)
    has_prefix <- substr(comment, 1, 13) == "LEGACY_EMPTY:"
    bad <- which(is_o & !has_prefix)
    if (length(bad) > 0) {
      out[[length(out) + 1]] <- data.frame(
        check_id = "VALUE.LEGACY_EMPTY", severity = "ERROR", file = .vc_file_path(key),
        row_key = .vc_row_key(df[bad, , drop = FALSE], .VC_KEY_COLS),
        message = "OBS_COMMENT on an O row in a ROUNDED_2DP file does not start with 'LEGACY_EMPTY:' (D9).",
        stringsAsFactors = FALSE
      )
    }
  }
  .vc_bind(out)
}

#' VALUE.SE_CI: STD_ERR < 0, or OBS_VALUE lies outside CI_LOWER to
#' CI_UPPER, where these are filled.
#'
#' @param ctx The list from [build_ctx()].
#' @return A findings tibble.
vc_value_se_ci <- function(ctx) {
  out <- list()
  needed <- c("OBS_VALUE", "STD_ERR", "CI_LOWER", "CI_UPPER")
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (nrow(df) == 0 || !all(needed %in% names(df))) next

    se_raw <- trimws(df$STD_ERR)
    se <- suppressWarnings(as.numeric(se_raw))
    bad_se <- which(se_raw != "" & !is.na(se) & se < 0)

    val <- suppressWarnings(as.numeric(trimws(df$OBS_VALUE)))
    lo <- suppressWarnings(as.numeric(trimws(df$CI_LOWER)))
    hi <- suppressWarnings(as.numeric(trimws(df$CI_UPPER)))
    ci_filled <- trimws(df$CI_LOWER) != "" & trimws(df$CI_UPPER) != "" & trimws(df$OBS_VALUE) != ""
    bad_ci <- which(ci_filled & !is.na(val) & !is.na(lo) & !is.na(hi) & (val < lo | val > hi))

    bad <- sort(union(bad_se, bad_ci))
    if (length(bad) > 0) {
      msg <- ifelse(
        bad %in% bad_se & bad %in% bad_ci,
        "STD_ERR is negative and OBS_VALUE lies outside CI_LOWER to CI_UPPER.",
        ifelse(
          bad %in% bad_se,
          "STD_ERR is negative.",
          "OBS_VALUE lies outside CI_LOWER to CI_UPPER."
        )
      )
      out[[length(out) + 1]] <- data.frame(
        check_id = "VALUE.SE_CI", severity = "ERROR", file = .vc_file_path(key),
        row_key = .vc_row_key(df[bad, , drop = FALSE], .VC_KEY_COLS),
        message = msg,
        stringsAsFactors = FALSE
      )
    }
  }
  .vc_bind(out)
}

#' VALUE.N: in an EXACT file, N_OBS/N_POP well-formedness; in a
#' ROUNDED_2DP file, one INFO finding per file noting the exemption.
#'
#' @param ctx The list from [build_ctx()].
#' @return A findings tibble.
vc_value_n <- function(ctx) {
  out <- list()
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (nrow(df) == 0) next
    file <- .vc_file_path(key)

    if (identical(.vc_precision(ctx, key), "ROUNDED_2DP")) {
      out[[length(out) + 1]] <- data.frame(
        check_id = "VALUE.N", severity = "INFO", file = file, row_key = "",
        message = "N_OBS and N_POP are exempt in ROUNDED_2DP files.",
        stringsAsFactors = FALSE
      )
      next
    }

    if (!all(c("N_OBS", "N_POP", "OBS_STATUS") %in% names(df))) next

    n_obs_raw <- trimws(df$N_OBS)
    n_obs <- suppressWarnings(as.numeric(n_obs_raw))
    bad_obs <- which(n_obs_raw == "" | is.na(n_obs) | n_obs < 0 | n_obs != floor(n_obs))

    n_pop_raw <- trimws(df$N_POP)
    n_pop <- suppressWarnings(as.numeric(n_pop_raw))
    bad_pop <- which(n_pop_raw == "" | is.na(n_pop) | n_pop < 0)

    zero_not_o <- which(!is.na(n_obs) & n_obs == 0 & trimws(df$OBS_STATUS) != "O")

    if (length(bad_obs) > 0) {
      out[[length(out) + 1]] <- data.frame(
        check_id = "VALUE.N", severity = "ERROR", file = file,
        row_key = .vc_row_key(df[bad_obs, , drop = FALSE], .VC_KEY_COLS),
        message = "N_OBS is missing or not a non-negative integer.",
        stringsAsFactors = FALSE
      )
    }
    if (length(bad_pop) > 0) {
      out[[length(out) + 1]] <- data.frame(
        check_id = "VALUE.N", severity = "ERROR", file = file,
        row_key = .vc_row_key(df[bad_pop, , drop = FALSE], .VC_KEY_COLS),
        message = "N_POP is missing or negative.",
        stringsAsFactors = FALSE
      )
    }
    if (length(zero_not_o) > 0) {
      out[[length(out) + 1]] <- data.frame(
        check_id = "VALUE.N", severity = "ERROR", file = file,
        row_key = .vc_row_key(df[zero_not_o, , drop = FALSE], .VC_KEY_COLS),
        message = "N_OBS = 0 requires OBS_STATUS = O.",
        stringsAsFactors = FALSE
      )
    }
  }
  .vc_bind(out)
}
