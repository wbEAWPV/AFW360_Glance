# pipeline/R/docs.R
#
# Documentation generator for the data standard (.docs/data-standard.qmd,
# section "Generated tables", decision D20).
#
# Every table in the standard that lists the contents of a metadata file is
# written here, from metadata/ and content/ only, to
# .docs/generated/<id>.md. A fragment is exactly one Markdown pipe table, a
# blank line and a caption line `: <caption> {#<id>}`, UTF-8 without a
# byte-order mark, LF line endings, ending with a single newline.
#
# Public functions:
#   docs_fragments(root)          named character vector id -> fragment text
#   docs_build(root, out_dir)     write every fragment into out_dir
#   docs_check(root, gen_dir, qmd_dir)
#                                 findings tibble (check_id, severity, file,
#                                 row_key, message); zero rows means current
#
# Depends on pipeline/R/io.R (read_std_csv()) having been sourced, and on
# the dplyr package (for the findings tibble).

# ---- the fragment list ---------------------------------------------------

# The seven columns every codelist carries (standard, section "Metadata
# files"); the "beyond the common ones" column tables leave them out.
.DOCS_COMMON_COLS <- c(
  "code", "name_en", "definition_en", "status",
  "version_added", "replaced_by", "notes"
)

# The small codelists of @tbl-small-codelists, in the order shown.
.DOCS_SMALL_CODELISTS <- c(
  "CL_SEX", "CL_AGE", "CL_URBANISATION", "CL_ESTIMATION", "CL_OBS_STATUS",
  "CL_THEME", "CL_STAT_UNIT", "CL_STATISTIC", "CL_WEIGHT", "CL_UNIT"
)

# Column tables projected from metadata/structure/COLUMNS.csv:
# fragment id, file in the registry, whether the common codelist columns
# are left out, caption.
.DOCS_COLUMN_TABLES <- data.frame(
  id = c(
    "tbl-cl-indicator", "tbl-cl-brk-var", "tbl-cl-geo-scheme", "tbl-cl-geo",
    "tbl-surveys", "tbl-tab-plan", "tbl-series-plan", "tbl-rules",
    "tbl-indicator-qualifiers", "tbl-qualifier-pairs", "tbl-sources",
    "tbl-legacy-labels", "tbl-legacy-columns-csv", "tbl-legacy-overrides",
    "tbl-text"
  ),
  file = c(
    "CL_INDICATOR.csv", "CL_BRK_VAR.csv", "CL_GEO_SCHEME.csv", "CL_GEO.csv",
    "SURVEYS.csv", "TAB_PLAN.csv", "SERIES_PLAN.csv", "RULES.csv",
    "INDICATOR_QUALIFIERS.csv", "QUALIFIER_PAIRS.csv", "SOURCES.csv",
    "LEGACY_LABELS.csv", "LEGACY_COLUMNS.csv", "LEGACY_OVERRIDES.csv",
    "TEXT.csv"
  ),
  drop_common = c(
    TRUE, TRUE, FALSE, TRUE,
    FALSE, FALSE, FALSE, FALSE,
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
    "Columns of `TAB_PLAN.csv`",
    "Columns of `SERIES_PLAN.csv`",
    "Columns of `RULES.csv`",
    "Columns of `INDICATOR_QUALIFIERS.csv`",
    "Columns of `QUALIFIER_PAIRS.csv`",
    "Columns of `SOURCES.csv`",
    "Columns of `LEGACY_LABELS.csv`",
    "Columns of `LEGACY_COLUMNS.csv`",
    "Columns of `LEGACY_OVERRIDES.csv`",
    "Columns of `TEXT.csv`"
  ),
  stringsAsFactors = FALSE
)

#' The ids of every fragment the generator produces, in document order.
#'
#' @return A character vector of 22 ids.
docs_fragment_ids <- function() {
  c(
    "tbl-columns", "tbl-obs-status", "tbl-brk-vars", "tbl-qual-vars",
    "tbl-povlines", "tbl-small-codelists", "tbl-initial-plan",
    .DOCS_COLUMN_TABLES$id
  )
}

# ---- Markdown helpers ----------------------------------------------------

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
  x <- as.character(x)
  x[is.na(x)] <- ""
  gsub("([][\\\\|<$@*`~^])", "\\\\\\1", x, perl = TRUE)
}

#' Wrap a code in backticks; an empty value stays empty.
#'
#' A code never contains a backtick; `|` is escaped so a cell cannot split.
#'
#' @param x A character vector.
#' @return A character vector.
md_code <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
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

# ---- reading the sources -------------------------------------------------

# Relative paths of every source file, keyed by stem.
.DOCS_SOURCES <- c(
  COLUMNS = "metadata/structure/COLUMNS.csv",
  DSD_AFW360_HH = "metadata/structure/DSD_AFW360_HH.csv",
  QUALIFIER_PAIRS = "metadata/structure/QUALIFIER_PAIRS.csv",
  TAB_PLAN = "metadata/plans/TAB_PLAN.csv",
  CL_BRK_VAR = "metadata/codelists/CL_BRK_VAR.csv",
  CL_COMP_BREAKDOWN = "metadata/codelists/CL_COMP_BREAKDOWN.csv",
  CL_QUAL_VAR = "metadata/codelists/CL_QUAL_VAR.csv",
  CL_QUALIFIER = "metadata/codelists/CL_QUALIFIER.csv",
  CL_OBS_STATUS = "metadata/codelists/CL_OBS_STATUS.csv",
  CL_SEX = "metadata/codelists/CL_SEX.csv",
  CL_AGE = "metadata/codelists/CL_AGE.csv",
  CL_URBANISATION = "metadata/codelists/CL_URBANISATION.csv",
  CL_ESTIMATION = "metadata/codelists/CL_ESTIMATION.csv",
  CL_THEME = "metadata/codelists/CL_THEME.csv",
  CL_STAT_UNIT = "metadata/codelists/CL_STAT_UNIT.csv",
  CL_STATISTIC = "metadata/codelists/CL_STATISTIC.csv",
  CL_WEIGHT = "metadata/codelists/CL_WEIGHT.csv",
  CL_UNIT = "metadata/codelists/CL_UNIT.csv"
)

#' Read one source CSV by stem; stops with the path if it is missing.
.docs_read <- function(root, stem) {
  rel <- .DOCS_SOURCES[[stem]]
  path <- file.path(root, rel)
  if (!file.exists(path)) {
    stop(sprintf("source file not found: %s", rel), call. = FALSE)
  }
  read_std_csv(path)
}

#' Require columns in a source table; stops naming the missing ones.
.docs_need <- function(df, cols, what) {
  miss <- setdiff(cols, names(df))
  if (length(miss) > 0) {
    stop(sprintf("%s lacks column(s): %s", what, paste(miss, collapse = ", ")), call. = FALSE)
  }
  invisible(TRUE)
}

#' Order rows by a numeric `order` column, keeping file order on ties.
.docs_by_order <- function(df) {
  if (nrow(df) == 0 || !"order" %in% names(df)) {
    return(df)
  }
  ord <- suppressWarnings(as.numeric(df$order))
  df[order(ord, seq_len(nrow(df)), na.last = TRUE), , drop = FALSE]
}

# ---- one builder per fragment --------------------------------------------

.docs_tbl_columns <- function(root) {
  dsd <- .docs_read(root, "DSD_AFW360_HH")
  .docs_need(dsd, c("position", "id", "role", "codelist", "required", "sentinel", "description"),
    "DSD_AFW360_HH.csv")
  md_table(
    c("#", "Column", "Role", "Codelist", "Sentinels", "Required", "Description"),
    list(
      md_text(dsd$position), md_code(dsd$id), md_text(dsd$role), md_code(dsd$codelist),
      md_codes(dsd$sentinel), md_text(dsd$required), md_text(dsd$description)
    ),
    "Columns of an `AFW360_HH` data file", "tbl-columns"
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

.docs_tbl_initial_plan <- function(root) {
  plan <- .docs_read(root, "TAB_PLAN")
  cols <- lapply(names(plan), function(nm) md_codes(plan[[nm]]))
  md_table(
    md_code(names(plan)), cols,
    "The current plan, reproducing the legacy Excel tables", "tbl-initial-plan"
  )
}

.docs_tbl_file_columns <- function(root, id, file, drop_common, caption) {
  reg <- .docs_read(root, "COLUMNS")
  .docs_need(reg, c("file", "position", "column", "status", "description"), "COLUMNS.csv")
  rows <- reg[reg$file == file, , drop = FALSE]
  if (nrow(rows) == 0) {
    stop(sprintf("COLUMNS.csv has no rows for %s", file), call. = FALSE)
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

# ---- public API ----------------------------------------------------------

#' Build the text of every fragment.
#'
#' A fragment whose sources are missing or incomplete is left out, with a
#' warning naming the gap; the others are still built.
#'
#' @param root Repo root.
#' @return A named character vector, id -> fragment text, in the order of
#'   [docs_fragment_ids()].
docs_fragments <- function(root) {
  builders <- list(
    "tbl-columns" = function() .docs_tbl_columns(root),
    "tbl-obs-status" = function() .docs_tbl_obs_status(root),
    "tbl-brk-vars" = function() .docs_tbl_brk_vars(root),
    "tbl-qual-vars" = function() .docs_tbl_qual_vars(root),
    "tbl-povlines" = function() .docs_tbl_povlines(root),
    "tbl-small-codelists" = function() .docs_tbl_small_codelists(root),
    "tbl-initial-plan" = function() .docs_tbl_initial_plan(root)
  )
  for (i in seq_len(nrow(.DOCS_COLUMN_TABLES))) {
    local({
      r <- .DOCS_COLUMN_TABLES[i, ]
      builders[[r$id]] <<- function() {
        .docs_tbl_file_columns(root, r$id, r$file, r$drop_common, r$caption)
      }
    })
  }

  out <- character(0)
  for (id in docs_fragment_ids()) {
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

#' Write one file as UTF-8 bytes, no byte-order mark, LF line endings.
.docs_write <- function(text, path) {
  writeBin(charToRaw(enc2utf8(text)), path)
  invisible(path)
}

#' Write every fragment to `<out_dir>/<id>.md`.
#'
#' @param root Repo root (sources are read from metadata/ and content/).
#' @param out_dir Destination folder; created if needed.
#' @return The paths written, invisibly.
docs_build <- function(root, out_dir = file.path(root, ".docs", "generated")) {
  frags <- docs_fragments(root)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  paths <- file.path(out_dir, paste0(names(frags), ".md"))
  for (i in seq_along(frags)) {
    .docs_write(frags[[i]], paths[i])
  }
  invisible(paths)
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

#' Check that the committed fragments are current and all included.
#'
#' Regenerates every fragment into a temporary folder and compares bytes
#' with `gen_dir`. Reports: a fragment that is missing from `gen_dir`
#' (`DOCS.FRAGMENT_MISSING`) or differs from the regenerated one
#' (`DOCS.FRAGMENT_STALE`); a file in `gen_dir` that the generator does not
#' produce (`DOCS.FRAGMENT_UNKNOWN`); a fragment the generator could not
#' build (`DOCS.FRAGMENT_NOT_BUILT`); an include in the standard that names
#' no produced fragment (`DOCS.INCLUDE_UNRESOLVED`); and a produced fragment
#' that no `.qmd` under `qmd_dir` includes (`DOCS.FRAGMENT_NOT_INCLUDED`).
#'
#' @param root Repo root.
#' @param gen_dir Folder holding the committed fragments.
#' @param qmd_dir Folder whose `.qmd` files are searched for includes; the
#'   standard is `<qmd_dir>/data-standard.qmd`.
#' @return A tibble with columns check_id, severity, file, row_key,
#'   message; zero rows means the fragments are current.
docs_check <- function(root,
                       gen_dir = file.path(root, ".docs", "generated"),
                       qmd_dir = file.path(root, ".docs")) {
  rel_gen <- ".docs/generated"
  findings <- list()
  add <- function(...) findings[[length(findings) + 1]] <<- .docs_finding(...)

  frags <- withCallingHandlers(docs_fragments(root), warning = function(w) {
    add("DOCS.FRAGMENT_NOT_BUILT", "", "", conditionMessage(w))
    invokeRestart("muffleWarning")
  })

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
        "fragment missing; run Rscript pipeline/build_docs.R --root .")
      next
    }
    fresh <- readBin(file.path(tmp, fname), "raw", file.info(file.path(tmp, fname))$size)
    old <- readBin(on_disk, "raw", file.info(on_disk)$size)
    if (!identical(fresh, old)) {
      add("DOCS.FRAGMENT_STALE", paste0(rel_gen, "/", fname), id,
        "fragment differs from the metadata; run Rscript pipeline/build_docs.R --root .")
    }
  }

  expected <- c(paste0(docs_fragment_ids(), ".md"))
  if (dir.exists(gen_dir)) {
    extra <- setdiff(sort(list.files(gen_dir, all.files = FALSE)), expected)
    for (f in extra) {
      add("DOCS.FRAGMENT_UNKNOWN", paste0(rel_gen, "/", f), f,
        "file in .docs/generated/ that build_docs.R does not produce")
    }
  }

  standard <- file.path(qmd_dir, "data-standard.qmd")
  if (!file.exists(standard)) {
    add("DOCS.INCLUDE_UNRESOLVED", ".docs/data-standard.qmd", "",
      "the standard .docs/data-standard.qmd was not found")
  } else {
    for (id in unique(docs_includes(standard))) {
      if (!id %in% docs_fragment_ids()) {
        add("DOCS.INCLUDE_UNRESOLVED", ".docs/data-standard.qmd", id,
          sprintf("includes generated/%s.md, which build_docs.R does not produce", id))
      }
    }
  }

  qmds <- list.files(qmd_dir, pattern = "\\.qmd$", full.names = TRUE)
  included <- unique(unlist(lapply(qmds, docs_includes)))
  for (id in setdiff(docs_fragment_ids(), included)) {
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
