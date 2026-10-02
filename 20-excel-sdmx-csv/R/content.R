# pipeline/R/content.R
#
# Helpers for WP10 (Text, figures and surveys): stripping the Quarto chunk
# and HTML wrappers around a key-message title or body, extracting the
# title/body pairs out of a "## Row Messages" block of index.qmd, and
# splitting a legacy About_<ISO3>.txt file into paragraphs.
# Depends only on base R.

#' Strip the chunk and HTML wrappers from a key-message title or body.
#'
#' Unwraps a `Markdown("...")` call when the whole string is one (the
#' captured text is returned), then removes `<span ...>` and `<b>` tags,
#' and trims whitespace. A string with no wrapper is simply trimmed, so the
#' function is safe to call on both wrapped and already-plain text.
#'
#' @param x A character scalar: one raw line, or an already-captured string.
#' @return The unwrapped, trimmed text.
strip_message_wrappers <- function(x) {
  x <- trimws(x)
  m <- regmatches(x, regexec('^Markdown\\("(.*)"\\)$', x))[[1]]
  if (length(m) == 2) {
    x <- m[2]
  }
  x <- gsub("</?span[^>]*>", "", x, perl = TRUE)
  x <- gsub("</?b>", "", x, perl = TRUE)
  trimws(x)
}

#' Extract up to `n` (title, body) pairs from one "## Row Messages" block.
#'
#' Scans `lines` for `#| title: ...` lines. For each, the next line within
#' `lines` that contains `Markdown(` is taken as its body. Both are passed
#' through [strip_message_wrappers()].
#'
#' @param lines Character vector: the block's raw lines (heading included
#'   or not, it is ignored).
#' @param n Maximum number of pairs to return (default 3).
#' @return A list of lists, each with `title` and `body`, in the order the
#'   titles appear in `lines`.
parse_message_block <- function(lines, n = 3) {
  title_idx <- grep("^#\\|\\s*title:", lines)
  out <- list()
  for (ti in title_idx) {
    if (length(out) >= n) {
      break
    }
    title <- strip_message_wrappers(sub("^#\\|\\s*title:\\s*", "", lines[ti]))
    body <- NA_character_
    if (ti < length(lines)) {
      rest <- lines[(ti + 1):length(lines)]
      md_pos <- which(grepl("Markdown\\(", rest))
      if (length(md_pos) > 0) {
        body <- strip_message_wrappers(rest[md_pos[1]])
      }
    }
    out[[length(out) + 1]] <- list(title = title, body = body)
  }
  out
}

#' Extract the (title, body) triples of every "## Row Messages" block in a
#' Quarto file's text.
#'
#' @param qmd_lines Character vector, the full text of `index.qmd`.
#' @param window Maximum number of lines scanned after each heading, so a
#'   later, unrelated block does not leak into this one.
#' @return A list, one element per "## Row Messages" heading found, each a
#'   list of (title, body) pairs (see [parse_message_block()]), in file
#'   order.
extract_row_messages <- function(qmd_lines, window = 20) {
  starts <- grep("^## Row Messages", qmd_lines)
  lapply(starts, function(s) {
    e <- min(length(qmd_lines), s + window - 1)
    parse_message_block(qmd_lines[s:e])
  })
}

#' Split a legacy `About_<ISO3>.txt` file into its paragraphs.
#'
#' Paragraphs are separated by one or more blank (or whitespace-only)
#' lines; each returned paragraph is trimmed, and empty paragraphs are
#' dropped.
#'
#' @param path Path to the file.
#' @return A character vector of paragraphs, in file order.
read_about_paragraphs <- function(path) {
  raw <- readLines(path, warn = FALSE, encoding = "UTF-8")
  txt <- paste(raw, collapse = "\n")
  paras <- strsplit(txt, "\n[ \t]*\n")[[1]]
  paras <- trimws(paras)
  paras[nzchar(paras)]
}
