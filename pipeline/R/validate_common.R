# pipeline/R/validate_common.R
#
# The findings helpers every validator module shares, defined once here
# (they were duplicated across validate_*.R, and the last file sourced
# won). validate.R sources this file before the modules, and so does any
# test that sources a module on its own. The findings format: a tibble
# with columns check_id, severity, file, row_key, message; `file` is the
# path relative to the root with forward slashes; more than 20 findings
# for one check_id/file pair are capped to the first 20 in row_key order
# plus one SUMMARY finding.

#' One findings row (or several, when the arguments are vectors).
.vc_finding <- function(check_id, severity, file, row_key, message) {
  tibble::tibble(
    check_id = check_id,
    severity = severity,
    file = file,
    row_key = row_key,
    message = message
  )
}

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
  parts <- lapply(parts, as.data.frame, stringsAsFactors = FALSE)
  result <- do.call(rbind, parts)
  rownames(result) <- NULL
  dplyr::as_tibble(.vc_apply_cap(result))
}
