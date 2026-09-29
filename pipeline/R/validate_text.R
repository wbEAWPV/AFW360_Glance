# pipeline/R/validate_text.R
#
# Checks for content/TEXT.csv and the Markdown files it references
# (COMMON.md wave 3, WP14).
#
# Every check function is named vc_text_<check>(ctx) and returns a tibble
# with columns check_id, severity, file, row_key, message (zero rows means
# pass). `ctx` is the list built by build_ctx() in pipeline/R/ctx.R.
#
# Depends on pipeline/R/ctx.R (build_ctx()) having already been sourced by
# the caller, and on the dplyr package. Text is Markdown limited to
# paragraphs, emphasis, links, lists and footnotes: no raw HTML, no chunk
# syntax. The {{...}} live-number syntax is still a sketch (open decision
# 10): these checks flag it, never resolve it.

.TEXT_CSV_REL <- "content/TEXT.csv"

# ---- private helpers ---------------------------------------------------

#' Build one finding row.
.tf_finding <- function(check_id, severity, file, row_key, message) {
  dplyr::tibble(
    check_id = check_id, severity = severity, file = file,
    row_key = row_key, message = message
  )
}

#' A zero-row findings tibble with the right columns.
.tf_empty <- function() {
  dplyr::tibble(
    check_id = character(0), severity = character(0), file = character(0),
    row_key = character(0), message = character(0)
  )
}

#' Combine a list of single-row findings tibbles (possibly empty).
.tf_bind <- function(rows) {
  if (length(rows) == 0) {
    return(.tf_empty())
  }
  dplyr::bind_rows(rows)
}

#' Cap findings at 20 per file, in row_key order, adding a SUMMARY row
#' (COMMON.md / card "Findings format").
.tf_cap <- function(df) {
  if (nrow(df) == 0) {
    return(df)
  }
  capped <- lapply(split(df, df$file), function(sub) {
    sub <- sub[order(sub$row_key, method = "radix"), , drop = FALSE]
    if (nrow(sub) > 20) {
      kept <- sub[seq_len(20), , drop = FALSE]
      summary_row <- .tf_finding(
        sub$check_id[1], sub$severity[1], sub$file[1], "",
        sprintf("SUMMARY: %d findings in total, 20 shown", nrow(sub))
      )
      dplyr::bind_rows(kept, summary_row)
    } else {
      sub
    }
  })
  out <- dplyr::bind_rows(capped)
  out[order(out$file, out$row_key, method = "radix"), , drop = FALSE]
}

#' The row_key for a content/TEXT.csv row: its four identifying columns.
.tf_row_key <- function(slot, ref_area, time_period, order) {
  sprintf("slot=%s ref_area=%s time_period=%s order=%s", slot, ref_area, time_period, order)
}

#' Whether text (a title, a body, or a whole file's content) contains raw
#' HTML or chunk syntax (TEXT.HTML's rule, word for word).
.tf_has_html <- function(text) {
  if (is.na(text) || !nzchar(text)) {
    return(FALSE)
  }
  if (grepl("<[A-Za-z/]", text)) {
    return(TRUE)
  }
  if (grepl("{python}", text, fixed = TRUE)) {
    return(TRUE)
  }
  if (grepl("Markdown(", text, fixed = TRUE)) {
    return(TRUE)
  }
  lines <- strsplit(text, "\r\n|\n|\r")[[1]]
  any(grepl("^#\\|", lines))
}

#' Every {{...}} reference found in text, as the literal matched tokens.
.tf_references <- function(text) {
  if (is.na(text) || !nzchar(text)) {
    return(character(0))
  }
  m <- gregexpr("\\{\\{[^}]*\\}\\}", text)
  regmatches(text, m)[[1]]
}

#' Read a referenced Markdown file's content as one string, or NA if it
#' does not exist.
.tf_read_file <- function(root, file) {
  full <- file.path(root, "content", "text", file)
  if (!file.exists(full)) {
    return(NA_character_)
  }
  paste(readLines(full, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

# ---- checks --------------------------------------------------------------

#' TEXT.BODY_FILE: a TEXT.csv row does not have exactly one of body and
#' file filled.
vc_text_body_file <- function(ctx) {
  tc <- ctx$meta$TEXT
  rows <- list()

  for (i in seq_len(nrow(tc))) {
    has_body <- nzchar(trimws(tc$body[i]))
    has_file <- nzchar(trimws(tc$file[i]))
    if (has_body == has_file) {
      rows[[length(rows) + 1]] <- .tf_finding(
        "TEXT.BODY_FILE", "ERROR", .TEXT_CSV_REL,
        .tf_row_key(tc$slot[i], tc$ref_area[i], tc$time_period[i], tc$order[i]),
        if (has_body) "Both body and file are filled" else "Neither body nor file is filled"
      )
    }
  }

  .tf_cap(.tf_bind(rows))
}

#' TEXT.FILE_MISSING: the referenced Markdown file does not exist.
vc_text_file_missing <- function(ctx) {
  root <- ctx$root
  tc <- ctx$meta$TEXT
  rows <- list()

  for (i in seq_len(nrow(tc))) {
    if (!nzchar(trimws(tc$file[i]))) {
      next
    }
    rel <- paste0("content/text/", tc$file[i])
    if (!file.exists(file.path(root, "content", "text", tc$file[i]))) {
      rows[[length(rows) + 1]] <- .tf_finding(
        "TEXT.FILE_MISSING", "ERROR", rel,
        .tf_row_key(tc$slot[i], tc$ref_area[i], tc$time_period[i], tc$order[i]),
        sprintf("Referenced file does not exist: %s", rel)
      )
    }
  }

  .tf_cap(.tf_bind(rows))
}

#' TEXT.LINEBREAK: a body contains a line break.
vc_text_linebreak <- function(ctx) {
  tc <- ctx$meta$TEXT
  rows <- list()

  for (i in seq_len(nrow(tc))) {
    if (grepl("[\r\n]", tc$body[i])) {
      rows[[length(rows) + 1]] <- .tf_finding(
        "TEXT.LINEBREAK", "ERROR", .TEXT_CSV_REL,
        .tf_row_key(tc$slot[i], tc$ref_area[i], tc$time_period[i], tc$order[i]),
        "body contains a line break"
      )
    }
  }

  .tf_cap(.tf_bind(rows))
}

#' TEXT.HTML: a title, a body or a referenced file contains raw HTML or
#' chunk syntax.
vc_text_html <- function(ctx) {
  root <- ctx$root
  tc <- ctx$meta$TEXT
  rows <- list()

  for (i in seq_len(nrow(tc))) {
    key <- .tf_row_key(tc$slot[i], tc$ref_area[i], tc$time_period[i], tc$order[i])

    if (.tf_has_html(tc$title[i])) {
      rows[[length(rows) + 1]] <- .tf_finding(
        "TEXT.HTML", "ERROR", .TEXT_CSV_REL, key, "title contains raw HTML or chunk syntax"
      )
    }
    if (.tf_has_html(tc$body[i])) {
      rows[[length(rows) + 1]] <- .tf_finding(
        "TEXT.HTML", "ERROR", .TEXT_CSV_REL, key, "body contains raw HTML or chunk syntax"
      )
    }
    if (nzchar(trimws(tc$file[i]))) {
      content <- .tf_read_file(root, tc$file[i])
      if (!is.na(content) && .tf_has_html(content)) {
        rows[[length(rows) + 1]] <- .tf_finding(
          "TEXT.HTML", "ERROR", paste0("content/text/", tc$file[i]), "",
          "file contains raw HTML or chunk syntax"
        )
      }
    }
  }

  .tf_cap(.tf_bind(rows))
}

#' TEXT.REFERENCE: a {{...}} reference is present; it is reported, not
#' resolved.
vc_text_reference <- function(ctx) {
  root <- ctx$root
  tc <- ctx$meta$TEXT
  rows <- list()

  for (i in seq_len(nrow(tc))) {
    key <- .tf_row_key(tc$slot[i], tc$ref_area[i], tc$time_period[i], tc$order[i])

    refs <- unique(c(.tf_references(tc$title[i]), .tf_references(tc$body[i])))
    if (length(refs) > 0) {
      rows[[length(rows) + 1]] <- .tf_finding(
        "TEXT.REFERENCE", "WARN", .TEXT_CSV_REL, key,
        sprintf("Unresolved reference(s): %s", paste(refs, collapse = " "))
      )
    }
    if (nzchar(trimws(tc$file[i]))) {
      content <- .tf_read_file(root, tc$file[i])
      if (!is.na(content)) {
        frefs <- unique(.tf_references(content))
        if (length(frefs) > 0) {
          rows[[length(rows) + 1]] <- .tf_finding(
            "TEXT.REFERENCE", "WARN", paste0("content/text/", tc$file[i]), "",
            sprintf("Unresolved reference(s): %s", paste(frefs, collapse = " "))
          )
        }
      }
    }
  }

  .tf_cap(.tf_bind(rows))
}

#' TEXT.TBD: a body is TBD.
vc_text_tbd <- function(ctx) {
  tc <- ctx$meta$TEXT
  rows <- list()

  for (i in seq_len(nrow(tc))) {
    if (identical(trimws(tc$body[i]), "TBD")) {
      rows[[length(rows) + 1]] <- .tf_finding(
        "TEXT.TBD", "WARN", .TEXT_CSV_REL,
        .tf_row_key(tc$slot[i], tc$ref_area[i], tc$time_period[i], tc$order[i]),
        "body is TBD"
      )
    }
  }

  .tf_cap(.tf_bind(rows))
}
