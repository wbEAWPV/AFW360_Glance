# pipeline/R/sdmx_import.R
#
# Reverse importer for the FMR round trip (plan 2.5, 2.13; WP6): reads an
# SDMX-ML 3.0 or 3.1 structure message and rebuilds the metadata CSVs it was
# generated from. For every codelist whose AFW_SOURCE_FILE annotation names
# a CSV under metadata/codelists/, the CSV rows are rebuilt from the code id,
# name, description, parent and annotations (the inverse of plan 2.5, D41);
# sentinel codes (AFW_SENTINEL = Y, D42) are dropped and the column order
# comes from metadata/structure/COLUMNS.csv. Derived codelists (D43) are
# reported, never written. Names and descriptions of every maintainable go
# back to metadata/structure/ARTEFACTS.csv (D44).
# Needs pipeline/R/io.R, pipeline/R/sdmx_xml.R and pipeline/R/sdmx_structures.R.

# Message namespaces accepted (SDMX-ML 3.0 and 3.1).
SDMX_IMPORT_MESSAGE_NS <- c(
  "3.0" = "http://www.sdmx.org/resources/sdmxml/schemas/v3_0/message",
  "3.1" = "http://www.sdmx.org/resources/sdmxml/schemas/v3_1/message"
)

# Annotation types that are not a CSV column of a codelist.
SDMX_IMPORT_STRUCTURAL_TYPES <- c(
  "AFW_SOURCE_FILE", "AFW_METADATA_VERSION", "AFW_SENTINEL", "AFW_CODE",
  "SDMX_CROSS_DOMAIN_CONCEPT"
)

# CSV columns carried by the code itself rather than by an annotation.
SDMX_IMPORT_CODE_COLUMNS <- c("code", "name_en", "definition_en", "parent")

#' Children of `node` with local name `name` (namespace-agnostic).
.imp_kids <- function(node, name) {
  xml2::xml_find_all(node, sprintf("./*[local-name()='%s']", name))
}

#' Text of the English (else first) localised child `name`; "" when absent.
.imp_text <- function(node, name) {
  kids <- .imp_kids(node, name)
  if (length(kids) == 0) {
    return("")
  }
  lang <- xml2::xml_attr(kids, "lang", ns = c(xml = "http://www.w3.org/XML/1998/namespace"))
  pick <- which(!is.na(lang) & lang == "en")
  xml2::xml_text(kids[[if (length(pick) > 0) pick[1] else 1]])
}

#' Annotations of `node` as a named character vector (type = value).
.imp_annotations <- function(node, where) {
  anns <- xml2::xml_find_all(node, "./*[local-name()='Annotations']/*[local-name()='Annotation']")
  types <- character(0)
  vals <- character(0)
  for (a in anns) {
    t <- .imp_text(a, "AnnotationType")
    if (!nzchar(t)) t <- xml2::xml_attr(a, "id")
    v <- if (length(.imp_kids(a, "AnnotationValue")) > 0) {
      .imp_text(a, "AnnotationValue")
    } else {
      .imp_text(a, "AnnotationTitle")
    }
    if (t %in% types) {
      stop(sprintf("%s: annotation type %s occurs twice", where, t), call. = FALSE)
    }
    types <- c(types, t)
    vals <- c(vals, v)
  }
  stats::setNames(vals, types)
}

#' Annotation type of a codelist CSV column (plan 2.5 mapping).
.imp_column_type <- function(col) {
  ifelse(col %in% names(SDMX_CL_ANNOTATION_TYPES),
    SDMX_CL_ANNOTATION_TYPES[col], paste0("AFW_", toupper(col)))
}

#' Read a structure message and check it is SDMX-ML 3.0 or 3.1.
#'
#' @param x Path to an XML file, or an xml2 document.
#' @return The xml2 document.
sdmx_read_structures <- function(x) {
  doc <- if (inherits(x, "xml_document")) x else xml2::read_xml(x)
  uri <- xml2::xml_find_chr(doc, "string(namespace-uri(/*))")
  if (!uri %in% SDMX_IMPORT_MESSAGE_NS || xml2::xml_name(xml2::xml_root(doc)) != "Structure") {
    stop(sprintf("not an SDMX-ML 3.0 or 3.1 structure message (root namespace %s)", uri), call. = FALSE)
  }
  doc
}

#' Rows of one CSV codelist rebuilt from its `str:Codelist` node.
#'
#' @param node The codelist node.
#' @param id Codelist id.
#' @param columns CSV column names in COLUMNS.csv order.
#' @return A tibble of character columns, sentinels dropped.
.imp_codelist_rows <- function(node, id, columns) {
  ann_cols <- setdiff(columns, SDMX_IMPORT_CODE_COLUMNS)
  col_types <- .imp_column_type(ann_cols)
  geo_scheme <- identical(id, "CL_GEO_SCHEME")
  allowed <- c(col_types, "AFW_SENTINEL", if (geo_scheme) "AFW_CODE")
  codes <- .imp_kids(node, "Code")
  out <- list()
  for (code in codes) {
    cid <- xml2::xml_attr(code, "id")
    where <- paste0(id, ".", cid)
    ann <- .imp_annotations(code, where)
    bad <- setdiff(names(ann), allowed)
    if (length(bad) > 0) {
      stop(sprintf("%s: unknown annotation type %s", where, paste(bad, collapse = ", ")), call. = FALSE)
    }
    if (identical(unname(ann["AFW_SENTINEL"]), "Y")) {
      next
    }
    row <- stats::setNames(rep("", length(columns)), columns)
    if (geo_scheme) {
      row["code"] <- if (!is.na(ann["AFW_CODE"])) ann[["AFW_CODE"]] else sub("^[^_]*_", "", cid)
      if ("ref_area" %in% columns) row["ref_area"] <- sub("_.*$", "", cid)
    } else {
      row["code"] <- cid
    }
    if ("name_en" %in% columns) row["name_en"] <- .imp_text(code, "Name")
    if ("definition_en" %in% columns) row["definition_en"] <- .imp_text(code, "Description")
    if ("parent" %in% columns) {
      p <- .imp_kids(code, "Parent")
      row["parent"] <- if (length(p) > 0) xml2::xml_text(p[[1]]) else ""
    } else if (length(.imp_kids(code, "Parent")) > 0) {
      stop(sprintf("%s: has a Parent but the CSV has no parent column", where), call. = FALSE)
    }
    for (k in seq_along(ann_cols)) {
      v <- ann[col_types[k]]
      if (!is.na(v)) row[ann_cols[k]] <- v
    }
    out[[length(out) + 1]] <- row
  }
  m <- matrix(unlist(out), ncol = length(columns), byrow = TRUE,
    dimnames = list(NULL, columns))
  tibble::as_tibble(as.data.frame(m, stringsAsFactors = FALSE))
}

#' Standard CSV text of a data frame (as write_std_csv writes it).
.imp_csv_text <- function(df) {
  enc2utf8(readr::format_csv(df, na = "", eol = "\n"))
}

#' Current text of a repository file; "" when it does not exist.
.imp_file_text <- function(path) {
  if (!file.exists(path)) {
    return("")
  }
  txt <- rawToChar(readBin(path, "raw", file.size(path)))
  Encoding(txt) <- "UTF-8"
  txt
}

#' Plan the import of a structure message against the metadata under `root`.
#'
#' @param x Path to the structure message, or an xml2 document.
#' @param root Repo root holding metadata/.
#' @return A list: `files`, a list of `list(path, old, new)` (repository
#'   paths and file texts), and `reports`, a character vector of notes
#'   (derived codelists and artefacts not in ARTEFACTS.csv).
sdmx_import_plan <- function(x, root) {
  doc <- sdmx_read_structures(x)
  cols <- read_std_csv(file.path(root, "metadata", "structure", "COLUMNS.csv"))
  files <- list()
  reports <- character(0)

  # Every annotation type in the message must be known.
  cl_files <- unique(cols$file[grepl("^CL_.*[.]csv$", cols$file)])
  known <- c(SDMX_IMPORT_STRUCTURAL_TYPES, "AFW_STATUS", "GLOBAL_CODE",
    .imp_column_type(setdiff(cols$column[cols$file %in% cl_files], SDMX_IMPORT_CODE_COLUMNS)))
  all_types <- xml2::xml_text(xml2::xml_find_all(doc, "//*[local-name()='AnnotationType']"))
  bad <- setdiff(unique(all_types), known)
  if (length(bad) > 0) {
    stop(sprintf("unknown annotation type %s", paste(bad, collapse = ", ")), call. = FALSE)
  }

  for (node in xml2::xml_find_all(doc, "//*[local-name()='Codelists']/*[local-name()='Codelist']")) {
    id <- xml2::xml_attr(node, "id")
    ann <- .imp_annotations(node, id)
    src <- unname(ann["AFW_SOURCE_FILE"])
    if (is.na(src) || !nzchar(src)) {
      stop(sprintf("%s: codelist has no AFW_SOURCE_FILE annotation", id), call. = FALSE)
    }
    if (!grepl("^metadata/codelists/[^/]+[.]csv$", src)) {
      reports <- c(reports, sprintf("%s: derived from %s; reported, not written", id, src))
      next
    }
    spec <- cols[cols$file == basename(src), , drop = FALSE]
    if (nrow(spec) == 0) {
      stop(sprintf("%s: COLUMNS.csv has no rows for %s", id, basename(src)), call. = FALSE)
    }
    columns <- spec$column[order(as.integer(spec$position))]
    rows <- .imp_codelist_rows(node, id, columns)
    files[[length(files) + 1]] <- list(path = src,
      old = .imp_file_text(file.path(root, src)), new = .imp_csv_text(rows))
  }

  # Names and descriptions of the maintainables back to ARTEFACTS.csv.
  art_path <- "metadata/structure/ARTEFACTS.csv"
  artefacts <- read_std_csv(file.path(root, art_path))
  for (node in xml2::xml_find_all(doc, "/*/*[local-name()='Structures']/*/*[@id]")) {
    id <- xml2::xml_attr(node, "id")
    i <- which(artefacts$artefact_id == id)
    if (length(i) != 1) {
      reports <- c(reports, sprintf("%s: not in ARTEFACTS.csv; name and description not written", id))
      next
    }
    artefacts$name_en[i] <- .imp_text(node, "Name")
    artefacts$description_en[i] <- .imp_text(node, "Description")
  }
  files[[length(files) + 1]] <- list(path = art_path,
    old = .imp_file_text(file.path(root, art_path)), new = .imp_csv_text(artefacts))

  list(files = files, reports = reports)
}

#' Split a file text into lines (the final newline ends the last line).
.imp_lines <- function(txt) {
  if (!nzchar(txt)) character(0) else strsplit(txt, "\n", fixed = TRUE)[[1]]
}

#' Unified diff of two texts, three lines of context.
#'
#' @param old,new File texts.
#' @param path Repository path used in the `---`/`+++` headers.
#' @return Character vector of diff lines; empty when the texts are equal.
sdmx_unified_diff <- function(old, new, path) {
  if (identical(old, new)) {
    return(character(0))
  }
  a <- .imp_lines(old)
  b <- .imp_lines(new)
  n <- length(a)
  m <- length(b)
  L <- matrix(0L, n + 1, m + 1)
  for (i in rev(seq_len(n))) {
    for (j in rev(seq_len(m))) {
      L[i, j] <- if (a[i] == b[j]) L[i + 1, j + 1] + 1L else max(L[i + 1, j], L[i, j + 1])
    }
  }
  op <- character(0)
  ai <- integer(0)
  bi <- integer(0)
  i <- 1
  j <- 1
  while (i <= n || j <= m) {
    if (i <= n && j <= m && a[i] == b[j]) {
      op <- c(op, " "); ai <- c(ai, i); bi <- c(bi, j); i <- i + 1; j <- j + 1
    } else if (j > m || (i <= n && L[i + 1, j] >= L[i, j + 1])) {
      op <- c(op, "-"); ai <- c(ai, i); bi <- c(bi, j); i <- i + 1
    } else {
      op <- c(op, "+"); ai <- c(ai, i); bi <- c(bi, j); j <- j + 1
    }
  }
  text <- ifelse(op == "+", b[pmin(bi, max(m, 1))], a[pmin(ai, max(n, 1))])
  ch <- which(op != " ")
  ctx <- 3
  out <- c(paste0("--- a/", path), paste0("+++ b/", path))
  k <- 1
  while (k <= length(ch)) {
    e <- k
    while (e < length(ch) && ch[e + 1] - ch[e] <= 2 * ctx + 1) e <- e + 1
    s_op <- max(1, ch[k] - ctx)
    e_op <- min(length(op), ch[e] + ctx)
    idx <- s_op:e_op
    n_old <- sum(op[idx] != "+")
    n_new <- sum(op[idx] != "-")
    a_start <- ai[s_op] - if (n_old == 0) 1 else 0
    b_start <- bi[s_op] - if (n_new == 0) 1 else 0
    out <- c(out, sprintf("@@ -%d,%d +%d,%d @@", a_start, n_old, b_start, n_new),
      paste0(op[idx], text[idx]))
    k <- e + 1
  }
  out
}

#' Unified diff of a whole import plan.
sdmx_import_diff <- function(plan) {
  unlist(lapply(plan$files, function(f) sdmx_unified_diff(f$old, f$new, f$path)))
}

#' Write every file of an import plan under `out_root` (UTF-8, LF).
#'
#' @return The repository paths whose content changed, invisibly.
sdmx_import_apply <- function(plan, out_root) {
  changed <- character(0)
  for (f in plan$files) {
    target <- file.path(out_root, f$path)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    con <- file(target, open = "wb")
    writeBin(charToRaw(f$new), con)
    close(con)
    if (!identical(f$old, f$new)) changed <- c(changed, f$path)
  }
  invisible(changed)
}
