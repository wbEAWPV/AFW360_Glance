# docs_md.R
#
# Shared module: an identical copy lives in 20-excel-sdmx-csv/R/ and in
# 30-sdmx/pipeline/R/; change both together (20-excel-sdmx-csv's
# tests/testthat/test-shared-modules.R fails when they differ).
#
# The Markdown side of the generated tables of the data standard
# (.docs/data-standard.qmd, section "Generated tables", decision D20): the
# cell and table writers, the column tables projected from a COLUMNS-style
# register, and the check that a stage's committed fragments under
# .docs/generated/ are current and included. Each stage's R/docs.R lists
# the fragments it builds and calls these functions: the SDMX stage
# (30-sdmx/pipeline/build_docs.R) builds the tables of the standard's
# metadata, the Excel stage (20-excel-sdmx-csv/build_docs.R) those of the
# legacy plans. Both write into the same .docs/generated/ folder.
#
# A fragment is exactly one Markdown pipe table, a blank line and a caption
# line `: <caption> {#<id>}`, UTF-8 without a byte-order mark, LF line
# endings, ending with a single newline.
#
# Depends on io.R (read_std_csv()) having been sourced, and on the dplyr
# package (for the findings tibble).

# The eight columns every codelist carries (standard, section "Metadata
# files"); the "beyond the common ones" column tables leave them out.
.DOCS_COMMON_COLS <- c(
  "code", "name_en", "definition_en", "status",
  "version_added", "replaced_by", "notes", "global_urn"
)

# ---- Markdown helpers ----------------------------------------------------

#' Make a cell value one line: `NA` becomes "", and each line break (CRLF,
#' CR or LF) becomes a single space, so one table row stays one line.
#'
#' @param x A character vector.
#' @return A character vector.
md_oneline <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  gsub("\r\n|[\r\n]", " ", x, perl = TRUE)
}

#' Escape free text for a pipe-table cell.
#'
#' Escapes the characters that would otherwise change the cell's meaning in
#' Pandoc Markdown: `|` (cell boundary), `<` (raw HTML: a description such
#' as `<series_id>` would vanish), `$` (TeX math), `@` (citations), `*`,
#' `[`, `]`, `` ` ``, `~`, `^` (inline markup) and `\` itself. The rendered
#' text is unchanged.
#'
#' @param x A character vector.
#' @return A character vector.
md_text <- function(x) {
  x <- md_oneline(x)
  gsub("([][\\\\|<$@*`~^])", "\\\\\\1", x, perl = TRUE)
}

#' Wrap a code in backticks; an empty value stays empty.
#'
#' A code never contains a backtick; `|` is escaped so a cell cannot split.
#'
#' @param x A character vector.
#' @return A character vector.
md_code <- function(x) {
  x <- md_oneline(x)
  out <- ifelse(x == "", "", paste0("`", gsub("|", "\\|", x, fixed = TRUE), "`"))
  unname(out)
}

#' Wrap each space-separated code of a multi-valued field in backticks.
#'
#' The field keeps its single-space separators, so it reads as given:
#' `CAP OU R` becomes `` `CAP` `OU` `R` ``.
#'
#' @param x A character vector.
#' @return A character vector.
md_codes <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  vapply(x, function(v) {
    toks <- strsplit(v, " ", fixed = TRUE)[[1]]
    toks <- toks[toks != ""]
    if (length(toks) == 0) {
      return("")
    }
    paste(md_code(toks), collapse = " ")
  }, character(1), USE.NAMES = FALSE)
}

#' Render one fragment: a pipe table, a blank line and the caption.
#'
#' @param header Character vector of column headers (already Markdown).
#' @param rows A data frame or list of character columns, one per header,
#'   already Markdown.
#' @param caption Caption text (Markdown).
#' @param id Fragment id, used as the cross-reference label.
#' @return A single string ending with one newline.
md_table <- function(header, rows, caption, id) {
  cols <- lapply(unname(as.list(rows)), function(v) {
    v <- as.character(v)
    v[is.na(v)] <- ""
    v
  })
  if (length(cols) != length(header)) {
    stop(sprintf("md_table(%s): %d headers but %d columns", id, length(header), length(cols)),
      call. = FALSE
    )
  }
  n <- unique(vapply(cols, length, integer(1)))
  if (length(n) != 1) {
    stop(sprintf("md_table(%s): columns of unequal length", id), call. = FALSE)
  }
  line <- function(cells) paste0("| ", paste(cells, collapse = " | "), " |")
  lines <- c(
    line(header),
    paste0("|", paste(rep("---", length(header)), collapse = "|"), "|")
  )
  if (n > 0) {
    # An empty cell is written as "|  |", which Pandoc reads as empty.
    body <- do.call(paste, c(cols, sep = " | "))
    lines <- c(lines, paste0("| ", body, " |"))
  }
  paste0(paste(c(lines, "", sprintf(": %s {#%s}", caption, id)), collapse = "\n"), "\n")
}

#' Categories of a variable as shown in the variable tables.
#'
#' Codes in backticks joined by ", "; more than 6 categories are cut to the
#' first 3 followed by "… (n)".
#'
#' @param codes Category codes in display order.
#' @return A single string.
md_categories <- function(codes) {
  n <- length(codes)
  if (n == 0) {
    return("")
  }
  if (n > 6) {
    return(paste0(paste(md_code(codes[1:3]), collapse = ", "), ", … (", n, ")"))
  }
  paste(md_code(codes), collapse = ", ")
}

# ---- shared builders ----------------------------------------------------

#' Require columns in a source table; stops naming the missing ones.
.docs_need <- function(df, cols, what) {
  miss <- setdiff(cols, names(df))
  if (length(miss) > 0) {
    stop(sprintf("%s lacks column(s): %s", what, paste(miss, collapse = ", ")), call. = FALSE)
  }
  invisible(TRUE)
}

#' Order rows by an integer column (`order`, `position`, `slot_order`),
#' keeping file order on ties; a non-integer value sorts last.
.docs_by_order <- function(df, col = "order") {
  if (nrow(df) == 0 || !col %in% names(df)) {
    return(df)
  }
  ord <- suppressWarnings(as.integer(df[[col]]))
  df[order(ord, seq_len(nrow(df)), na.last = TRUE), , drop = FALSE]
}

#' One column table: the rows of a COLUMNS-style register for one file.
#'
#' @param reg The register (columns file, position, column, status,
#'   description), e.g. metadata/structure/COLUMNS.csv.
#' @param id,file,drop_common,caption One row of a stage's column-table list.
#' @param what The register's file name, for error messages.
.docs_tbl_file_columns <- function(reg, id, file, drop_common, caption, what = "COLUMNS.csv") {
  .docs_need(reg, c("file", "position", "column", "status", "description"), what)
  rows <- reg[reg$file == file, , drop = FALSE]
  if (nrow(rows) == 0) {
    stop(sprintf("%s has no rows for %s", what, file), call. = FALSE)
  }
  rows <- rows[order(suppressWarnings(as.integer(rows$position)), seq_len(nrow(rows))), , drop = FALSE]
  if (drop_common) {
    rows <- rows[!rows$column %in% .DOCS_COMMON_COLS, , drop = FALSE]
  }
  md_table(
    c("Column", "Status", "Description"),
    list(md_code(rows$column), md_text(rows$status), md_text(rows$description)),
    caption, id
  )
}

# ---- writing and checking -----------------------------------------------

#' Write one file as UTF-8 bytes, no byte-order mark, LF line endings.
.docs_write <- function(text, path) {
  writeBin(charToRaw(enc2utf8(text)), path)
  invisible(path)
}

#' Fragment ids named by `{{< include generated/<id>.md >}}` in a file.
#'
#' @param path A .qmd file.
#' @return A character vector of ids (possibly with duplicates).
docs_includes <- function(path) {
  txt <- readLines(path, encoding = "UTF-8", warn = FALSE)
  m <- regmatches(txt, gregexpr("\\{\\{<\\s*include\\s+generated/[^ >]+\\.md\\s*>\\}\\}", txt, perl = TRUE))
  hits <- unlist(m)
  sub("^.*generated/([^ >]+)\\.md.*$", "\\1", hits)
}

.docs_finding <- function(check_id, file, row_key, message) {
  dplyr::tibble(
    check_id = check_id, severity = "ERROR", file = file,
    row_key = row_key, message = message
  )
}

#' Check that a stage's committed fragments are current and included.
#'
#' Compares `frags` (freshly built) with the files in `gen_dir`, byte for
#' byte. Reports: a fragment that is missing from `gen_dir`
#' (`DOCS.FRAGMENT_MISSING`) or differs from the fresh one
#' (`DOCS.FRAGMENT_STALE`); a fragment the stage could not build
#' (`DOCS.FRAGMENT_NOT_BUILT`, from `not_built`); a file in `gen_dir` that
#' neither this stage nor the other produces (`DOCS.FRAGMENT_UNKNOWN`); an
#' include in the standard that names neither (`DOCS.INCLUDE_UNRESOLVED`);
#' and a fragment of `own_ids` that no `.qmd` under `qmd_dir` includes
#' (`DOCS.FRAGMENT_NOT_INCLUDED`). `other_ids` are the fragments the other
#' stage writes into the same folder: they are known, never checked here.
#'
#' @param frags Named character vector id -> fragment text.
#' @param own_ids Ids this stage produces.
#' @param other_ids Ids the other stage produces.
#' @param gen_dir Folder holding the committed fragments.
#' @param qmd_dir Folder whose `.qmd` files are searched for includes; the
#'   standard is `<qmd_dir>/data-standard.qmd`.
#' @param rebuild The command that rebuilds this stage's fragments, quoted
#'   in the messages.
#' @param not_built Messages of fragments that could not be built.
#' @return A tibble with columns check_id, severity, file, row_key,
#'   message; zero rows means the fragments are current.
docs_check_fragments <- function(frags, own_ids, other_ids, gen_dir, qmd_dir, rebuild,
                                 not_built = character(0)) {
  rel_gen <- ".docs/generated"
  findings <- list()
  add <- function(...) findings[[length(findings) + 1]] <<- .docs_finding(...)
  for (m in not_built) add("DOCS.FRAGMENT_NOT_BUILT", "", "", m)

  tmp <- tempfile(pattern = "afw360_docs_")
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  dir.create(tmp, recursive = TRUE)
  for (id in names(frags)) {
    .docs_write(frags[[id]], file.path(tmp, paste0(id, ".md")))
  }

  for (id in names(frags)) {
    fname <- paste0(id, ".md")
    on_disk <- file.path(gen_dir, fname)
    if (!file.exists(on_disk)) {
      add("DOCS.FRAGMENT_MISSING", paste0(rel_gen, "/", fname), id,
        paste0("fragment missing; run ", rebuild))
      next
    }
    fresh <- readBin(file.path(tmp, fname), "raw", file.info(file.path(tmp, fname))$size)
    old <- readBin(on_disk, "raw", file.info(on_disk)$size)
    if (!identical(fresh, old)) {
      add("DOCS.FRAGMENT_STALE", paste0(rel_gen, "/", fname), id,
        paste0("fragment differs from the metadata; run ", rebuild))
    }
  }

  known <- c(own_ids, other_ids)
  if (dir.exists(gen_dir)) {
    extra <- setdiff(sort(list.files(gen_dir, all.files = FALSE)), paste0(known, ".md"))
    for (f in extra) {
      add("DOCS.FRAGMENT_UNKNOWN", paste0(rel_gen, "/", f), f,
        "file in .docs/generated/ that neither stage's build_docs.R produces")
    }
  }

  standard <- file.path(qmd_dir, "data-standard.qmd")
  if (!file.exists(standard)) {
    add("DOCS.INCLUDE_UNRESOLVED", ".docs/data-standard.qmd", "",
      "the standard .docs/data-standard.qmd was not found")
  } else {
    for (id in unique(docs_includes(standard))) {
      if (!id %in% known) {
        add("DOCS.INCLUDE_UNRESOLVED", ".docs/data-standard.qmd", id,
          sprintf("includes generated/%s.md, which neither stage's build_docs.R produces", id))
      }
    }
  }

  qmds <- list.files(qmd_dir, pattern = "\\.qmd$", full.names = TRUE)
  included <- unique(unlist(lapply(qmds, docs_includes)))
  for (id in setdiff(own_ids, included)) {
    add("DOCS.FRAGMENT_NOT_INCLUDED", paste0(rel_gen, "/", id, ".md"), id,
      "fragment is produced but no .qmd under .docs/ includes it")
  }

  if (length(findings) == 0) {
    return(dplyr::tibble(
      check_id = character(0), severity = character(0), file = character(0),
      row_key = character(0), message = character(0)
    ))
  }
  dplyr::bind_rows(findings)
}

#' Build a stage's fragments, keeping the ones that fail out.
#'
#' A fragment whose sources are missing or incomplete is left out, with a
#' warning naming the gap; the others are still built.
#'
#' @param builders Named list id -> function() returning the fragment text.
#' @param ids The ids to build, in order.
#' @return A named character vector, id -> fragment text, in the order of
#'   `ids`.
docs_run_builders <- function(builders, ids) {
  out <- character(0)
  for (id in ids) {
    txt <- tryCatch(builders[[id]](), error = function(e) {
      warning(sprintf("fragment %s not built: %s", id, conditionMessage(e)), call. = FALSE)
      NULL
    })
    if (!is.null(txt)) {
      out[[id]] <- txt
    }
  }
  out
}

#' Build a stage's fragments for a check, turning warnings into messages.
#'
#' @param fragments_fn A function of no argument returning the fragments
#'   (it may warn, see [docs_run_builders()]).
#' @return A list: `frags` and `not_built` (the warning messages).
docs_collect <- function(fragments_fn) {
  not_built <- character(0)
  frags <- withCallingHandlers(fragments_fn(), warning = function(w) {
    not_built <<- c(not_built, conditionMessage(w))
    invokeRestart("muffleWarning")
  })
  list(frags = frags, not_built = not_built)
}
