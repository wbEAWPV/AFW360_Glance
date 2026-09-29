# pipeline/R/sdmx_xml.R
#
# xml2 helpers for writing SDMX-ML 3.1 structure messages (plan 2.1, 2.5;
# sdmx-ml-cheatsheet.md sections 1 to 4, 11): namespaces, the message
# envelope with its header, annotations, localised names and descriptions,
# URN builders, deterministic serialisation and XSD validation.

SDMX_NS <- c(
  mes = "http://www.sdmx.org/resources/sdmxml/schemas/v3_1/message",
  str = "http://www.sdmx.org/resources/sdmxml/schemas/v3_1/structure",
  com = "http://www.sdmx.org/resources/sdmxml/schemas/v3_1/common",
  xsi = "http://www.w3.org/2001/XMLSchema-instance"
)
SDMX_SCHEMA_LOCATION <- paste(
  "http://www.sdmx.org/resources/sdmxml/schemas/v3_1/message",
  "https://xml.sdmx.org/3.1/SDMXMessage.xsd"
)
SDMX_AGENCY <- "WB.AFW360"
SDMX_SENDER_ID <- "WB_AFW360"
SDMX_SENDER_NAME <- "AFW DIP/POV team"
SDMX_DEFAULT_TIMESTAMP <- "2026-01-01T00:00:00Z"

#' URN of a maintainable artefact.
#'
#' @param package Information-model package, e.g. `"codelist"`.
#' @param class Class name, e.g. `"Codelist"`.
#' @param id Artefact id.
#' @param version Version string, e.g. `"0.3.0"`.
#' @param agency Agency id (default `WB.AFW360`).
#' @return A URN string.
sdmx_urn <- function(package, class, id, version, agency = SDMX_AGENCY) {
  sprintf("urn:sdmx:org.sdmx.infomodel.%s.%s=%s:%s(%s)", package, class, agency, id, version)
}

#' URN of an item (code, concept, agency) inside a maintainable.
#'
#' @inheritParams sdmx_urn
#' @param item Item id appended after a dot.
#' @return A URN string.
sdmx_item_urn <- function(package, class, id, version, item, agency = SDMX_AGENCY) {
  paste0(sdmx_urn(package, class, id, version, agency), ".", item)
}

#' URN of a codelist of the project agency.
sdmx_codelist_urn <- function(id, version) {
  sdmx_urn("codelist", "Codelist", id, version)
}

#' Create an empty structure message with its header.
#'
#' @param timestamp Value of `mes:Prepared`.
#' @param message_id Value of `mes:ID` (an IDType, no dot).
#' @return A list with the document (`doc`) and its `mes:Structures` node
#'   (`structures`).
sdmx_new_message <- function(timestamp = SDMX_DEFAULT_TIMESTAMP,
                             message_id = "AFW360_STRUCTURES") {
  doc <- xml2::xml_new_root("mes:Structure",
    "xmlns:mes" = SDMX_NS[["mes"]],
    "xmlns:str" = SDMX_NS[["str"]],
    "xmlns:com" = SDMX_NS[["com"]],
    "xmlns:xsi" = SDMX_NS[["xsi"]],
    "xsi:schemaLocation" = SDMX_SCHEMA_LOCATION
  )
  header <- xml2::xml_add_child(doc, "mes:Header")
  xml2::xml_add_child(header, "mes:ID", message_id)
  xml2::xml_add_child(header, "mes:Test", "false")
  xml2::xml_add_child(header, "mes:Prepared", timestamp)
  sender <- xml2::xml_add_child(header, "mes:Sender", id = SDMX_SENDER_ID)
  sdmx_add_name(sender, SDMX_SENDER_NAME)
  structures <- xml2::xml_add_child(doc, "mes:Structures")
  list(doc = doc, structures = structures)
}

#' Add a `com:Annotations` block holding one annotation per non-empty value.
#'
#' Each annotation is `<com:Annotation id="type">` with `AnnotationType` =
#' type and `AnnotationValue` = value. Must be called before any Name is
#' added, since annotations come first (cheatsheet section 4).
#'
#' @param node Parent node.
#' @param types Character vector of annotation types.
#' @param values Character vector of values, same length as `types`.
#' @return `node`, invisibly.
sdmx_add_annotations <- function(node, types, values) {
  stopifnot(length(types) == length(values))
  keep <- !is.na(values) & nzchar(values)
  if (!any(keep)) {
    return(invisible(node))
  }
  anns <- xml2::xml_add_child(node, "com:Annotations")
  for (i in which(keep)) {
    a <- xml2::xml_add_child(anns, "com:Annotation", id = types[i])
    xml2::xml_add_child(a, "com:AnnotationType", types[i])
    xml2::xml_add_child(a, "com:AnnotationValue", values[i])
  }
  invisible(node)
}

#' Add a localised `com:Name`.
sdmx_add_name <- function(node, text, lang = "en") {
  n <- xml2::xml_add_child(node, "com:Name", text)
  xml2::xml_set_attr(n, "xml:lang", lang)
  invisible(n)
}

#' Add a localised `com:Description`; nothing when `text` is empty.
sdmx_add_description <- function(node, text, lang = "en") {
  if (length(text) == 0 || is.na(text) || !nzchar(text)) {
    return(invisible(NULL))
  }
  n <- xml2::xml_add_child(node, "com:Description", text)
  xml2::xml_set_attr(n, "xml:lang", lang)
  invisible(n)
}

#' Serialise a message to a string: UTF-8, LF, two-space indentation, and
#' each `com:Annotation` on one line (so that line counts per annotation
#' type are counts of annotations).
#'
#' @param doc An xml2 document.
#' @return A single string ending in a newline.
sdmx_serialise <- function(doc) {
  txt <- as.character(doc, options = "format")
  txt <- gsub("\r\n", "\n", txt, fixed = TRUE)
  txt <- gsub(
    "(<com:Annotation [^>]*>|</com:Annotation(Title|Type|URL|Text|Value)>)\n *(<)",
    "\\1\\3", txt,
    perl = TRUE
  )
  if (!endsWith(txt, "\n")) {
    txt <- paste0(txt, "\n")
  }
  txt
}

#' Write a message to `path` byte-for-byte deterministically (UTF-8, LF).
#'
#' @param doc An xml2 document.
#' @param path Destination path; parent directories are created.
#' @return `path`, invisibly.
sdmx_write <- function(doc, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  txt <- enc2utf8(sdmx_serialise(doc))
  con <- file(path, open = "wb")
  on.exit(close(con))
  writeBin(charToRaw(txt), con)
  invisible(path)
}

#' Validate a message against the vendored SDMX-ML 3.1 XSD.
#'
#' @param doc An xml2 document (or a path to an XML file).
#' @param root Repo root holding `pipeline/xsd/sdmx-ml-3.1/`.
#' @return `TRUE` or `FALSE`, with the libxml2 errors in attribute `errors`.
sdmx_validate <- function(doc, root = ".") {
  if (is.character(doc)) {
    doc <- xml2::read_xml(doc)
  }
  xsd_path <- file.path(root, "pipeline", "xsd", "sdmx-ml-3.1", "SDMXMessage.xsd")
  schema <- xml2::read_xml(xsd_path)
  # Re-parse the serialised text so the result reflects the written bytes.
  parsed <- xml2::read_xml(sdmx_serialise(doc))
  xml2::xml_validate(parsed, schema)
}
