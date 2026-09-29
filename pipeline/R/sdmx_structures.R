# pipeline/R/sdmx_structures.R
#
# SDMX-ML 3.1 structures generated from metadata/ (plan 2.1, 2.5, 2.6),
# part 1: the WB:AGENCIES agency scheme, the concept scheme CS_AFW360 and
# the codelists, all driven by metadata/structure/ARTEFACTS.csv.
# Needs pipeline/R/io.R and pipeline/R/sdmx_xml.R.

# Global counterparts of the sentinel codes (plan 2.5, D42, Gate 1 G1-Q4).
# CL_AGE._Z, CL_GEO._T and CL_QUALIFIER._Z have none and carry no GLOBAL_CODE.
SDMX_SENTINEL_GLOBAL <- c(
  "CL_SEX._T" = "urn:sdmx:org.sdmx.infomodel.codelist.Code=SDMX:CL_SEX(2.1)._T",
  "CL_SEX._Z" = "urn:sdmx:org.sdmx.infomodel.codelist.Code=SDMX:CL_SEX(2.1)._Z",
  "CL_AGE._T" = "urn:sdmx:org.sdmx.infomodel.codelist.Code=IAEG-SDGs:CL_AGE(1.25)._T",
  "CL_URBANISATION._T" = "urn:sdmx:org.sdmx.infomodel.codelist.Code=IAEG-SDGs:CL_URBANISATION(1.10)._T",
  "CL_COMP_BREAKDOWN._T" = "urn:sdmx:org.sdmx.infomodel.codelist.Code=IAEG-SDGs:CL_QUANTILE(1.1)._T"
)
SDMX_SENTINEL_NAMES <- c("_T" = "Total", "_Z" = "Not applicable")

# Concepts matching SDMX:CROSS_DOMAIN_CONCEPTS(2.0) (plan 2.6). Every target
# id was checked against the scheme fetched from registry.sdmx.org on
# 2026-09-29; all eleven exist.
SDMX_CROSS_DOMAIN <- c(
  FREQ = "FREQ", REF_AREA = "REF_AREA", TIME_PERIOD = "TIME_PERIOD",
  OBS_VALUE = "OBS_VALUE", OBS_STATUS = "OBS_STATUS",
  UNIT_MEASURE = "UNIT_MEASURE", SEX = "SEX", AGE = "AGE",
  INDICATOR = "INDICATOR", OBS_COMMENT = "COMMENT", SOURCE_ID = "DATA_SOURCE"
)

# Fixed CSV columns of the codelist mapping (plan 2.5, D41).
SDMX_CL_ANNOTATION_TYPES <- c(
  global_urn = "GLOBAL_CODE", status = "AFW_STATUS",
  version_added = "AFW_VERSION_ADDED", replaced_by = "AFW_REPLACED_BY",
  notes = "AFW_NOTES"
)

# Derived codelists (D43 as amended at Gate 1): source file, id column,
# name column, description column ("" for none), whether AFW_STATUS is kept.
SDMX_DERIVED_CODELISTS <- list(
  CL_SOURCE = list(id = "source_id", name = "source_id", desc = "notes", status = TRUE),
  CL_SURVEY = list(id = "survey_id", name = "survey_name", desc = "", status = TRUE),
  CL_FIGURE = list(id = "figure_id", name = "title_en", desc = "", status = FALSE)
)

# Reference metadata parents of MSD_AFW360 (plan 2.7). Children are the
# source file's columns minus the id and status columns; TEXT lists its own.
SDMX_MSD_PARENTS <- list(
  SURVEY = list(file = "metadata/surveys/SURVEYS.csv", id = "survey_id",
                name = "Survey", desc = "Reference metadata of a household survey: one row of SURVEYS.csv."),
  SOURCE = list(file = "metadata/registries/SOURCES.csv", id = "source_id",
                name = "Source", desc = "Reference metadata of a data source: one row of SOURCES.csv."),
  TEXT = list(file = NULL, columns_file = "TEXT.csv",
              children = c("slot", "ref_area", "time_period", "order", "title", "body", "updated_on"),
              name = "Text", desc = "A dashboard text item: one row of TEXT.csv."),
  FIGURE = list(file = "metadata/registries/FIGURES.csv", id = "figure_id",
                name = "Figure", desc = "Reference metadata of a static figure: one row of FIGURES.csv.")
)

#' The metadata version (metadata/VERSION).
sdmx_version <- function(root) {
  trimws(readLines(file.path(root, "metadata", "VERSION"), warn = FALSE)[1])
}

#' Row of ARTEFACTS.csv for an artefact id.
.sdmx_artefact <- function(artefacts, id) {
  row <- artefacts[artefacts$artefact_id == id, , drop = FALSE]
  if (nrow(row) != 1) {
    stop(sprintf("ARTEFACTS.csv has %d rows for %s", nrow(row), id), call. = FALSE)
  }
  row
}

#' Add a maintainable element with its AFW_SOURCE_FILE and
#' AFW_METADATA_VERSION annotations, name and description.
.sdmx_add_maintainable <- function(parent, tag, art, version, fixed_version = FALSE) {
  attrs <- list(agencyID = art$agency_id, id = art$artefact_id)
  if (!fixed_version) {
    attrs$version <- version
  }
  node <- do.call(xml2::xml_add_child, c(list(parent, tag), attrs))
  sdmx_add_annotations(node,
    c("AFW_SOURCE_FILE", "AFW_METADATA_VERSION"),
    c(art$source_file, version)
  )
  sdmx_add_name(node, art$name_en)
  sdmx_add_description(node, art$description_en)
  node
}

#' Add the WB:AGENCIES agency scheme declaring the sub-agency AFW360.
#'
#' @param parent The `str:AgencySchemes` node.
#' @param artefacts ARTEFACTS.csv as a tibble.
#' @param version The metadata version (annotation only; no version attribute).
#' @return The `str:AgencyScheme` node.
sdmx_agency_scheme <- function(parent, artefacts, version) {
  art <- .sdmx_artefact(artefacts, "AGENCIES")
  node <- .sdmx_add_maintainable(parent, "str:AgencyScheme", art, version, fixed_version = TRUE)
  agency <- xml2::xml_add_child(node, "str:Agency", id = "AFW360")
  sdmx_add_name(agency, "West Africa Micro Data 360 (AFW DIP/POV team)")
  node
}

#' Humanise a column name: underscores to spaces, first letter upper-cased.
.sdmx_humanise <- function(x) {
  x <- gsub("_", " ", x, fixed = TRUE)
  paste0(toupper(substr(x, 1, 1)), substr(x, 2, nchar(x)))
}

#' The concepts of the metadata attributes of MSD_AFW360 (plan 2.7):
#' a data frame with id, name, description and `parent` (TRUE for the
#' presentational parents), in parent order, children after their parent.
sdmx_msd_concepts <- function(root) {
  cols <- read_std_csv(file.path(root, "metadata", "structure", "COLUMNS.csv"))
  out <- list()
  for (pid in names(SDMX_MSD_PARENTS)) {
    p <- SDMX_MSD_PARENTS[[pid]]
    out[[length(out) + 1]] <- data.frame(id = pid, name = p$name, description = p$desc, parent = TRUE)
    if (is.null(p$file)) {
      children <- p$children
      cfile <- p$columns_file
    } else {
      hdr <- names(read_std_csv(file.path(root, p$file)))
      children <- setdiff(hdr, c(p$id, "status"))
      cfile <- basename(p$file)
    }
    for (ch in children) {
      d <- cols$description[cols$file == cfile & cols$column == ch]
      out[[length(out) + 1]] <- data.frame(
        id = toupper(ch), name = .sdmx_humanise(ch),
        description = if (length(d)) d[1] else "", parent = FALSE
      )
    }
  }
  do.call(rbind, out)
}

#' Add the concept scheme CS_AFW360 (plan 2.6): one concept per DSD
#' component, then one per metadata attribute not already present.
#'
#' @param parent The `str:ConceptSchemes` node.
#' @param root Repo root.
#' @param artefacts ARTEFACTS.csv as a tibble.
#' @param version The metadata version.
#' @return The `str:ConceptScheme` node.
sdmx_concept_scheme <- function(parent, root, artefacts, version) {
  art <- .sdmx_artefact(artefacts, "CS_AFW360")
  dsd <- read_std_csv(file.path(root, "metadata", "structure", "DSD_AFW360_HH.csv"))
  dsd <- dsd[order(as.integer(dsd$position)), , drop = FALSE]
  node <- .sdmx_add_maintainable(parent, "str:ConceptScheme", art, version)
  add_concept <- function(id, name, description) {
    cn <- xml2::xml_add_child(node, "str:Concept", id = id)
    cdc <- SDMX_CROSS_DOMAIN[id]
    sdmx_add_annotations(cn, "SDMX_CROSS_DOMAIN_CONCEPT",
      if (is.na(cdc)) "" else sdmx_item_urn("conceptscheme", "Concept",
        "CROSS_DOMAIN_CONCEPTS", "2.0", cdc, agency = "SDMX"))
    sdmx_add_name(cn, name)
    sdmx_add_description(cn, description)
    cn
  }
  for (i in seq_len(nrow(dsd))) {
    r <- dsd[i, ]
    cn <- add_concept(r$id, r$name_en, r$description)
    core <- xml2::xml_add_child(cn, "str:CoreRepresentation")
    if (nzchar(r$codelist)) {
      xml2::xml_add_child(core, "str:Enumeration", sdmx_codelist_urn(r$codelist, version))
    } else {
      tf <- xml2::xml_add_child(core, "str:TextFormat", textType = r$data_type)
      if (nzchar(r$min_value)) xml2::xml_set_attr(tf, "minValue", r$min_value)
      if (nzchar(r$max_value)) xml2::xml_set_attr(tf, "maxValue", r$max_value)
    }
  }
  msd <- sdmx_msd_concepts(root)
  seen <- dsd$id
  for (i in seq_len(nrow(msd))) {
    if (msd$id[i] %in% seen) next
    seen <- c(seen, msd$id[i])
    cn <- add_concept(msd$id[i], msd$name[i], msd$description[i])
    if (!msd$parent[i]) {
      core <- xml2::xml_add_child(cn, "str:CoreRepresentation")
      xml2::xml_add_child(core, "str:TextFormat", textType = "String")
    }
  }
  node
}

#' Sentinel codes of a codelist, read from the DSD CSV `sentinel` column.
sdmx_sentinels <- function(dsd, codelist_id) {
  s <- dsd$sentinel[dsd$codelist == codelist_id]
  s <- unlist(strsplit(s[nzchar(s)], " ", fixed = TRUE))
  unique(s[nzchar(s)])
}

#' Add one code with its annotations, name, description and parent.
.sdmx_add_code <- function(parent, id, ann_types, ann_values, name, description = "", code_parent = "") {
  code <- xml2::xml_add_child(parent, "str:Code", id = id)
  sdmx_add_annotations(code, ann_types, ann_values)
  sdmx_add_name(code, name)
  sdmx_add_description(code, description)
  if (nzchar(code_parent)) {
    xml2::xml_add_child(code, "str:Parent", code_parent)
  }
  code
}

#' Add one codelist (plan 2.5): a CSV codelist from metadata/codelists/ or
#' a derived one (CL_SOURCE, CL_SURVEY, CL_FIGURE), plus its sentinels.
#'
#' @param parent The `str:Codelists` node.
#' @param id Codelist id, a row of ARTEFACTS.csv.
#' @param root Repo root.
#' @param artefacts ARTEFACTS.csv as a tibble.
#' @param version The metadata version.
#' @param dsd DSD_AFW360_HH.csv as a tibble (for the sentinels).
#' @return The `str:Codelist` node.
sdmx_codelist <- function(parent, id, root, artefacts, version, dsd) {
  art <- .sdmx_artefact(artefacts, id)
  rows <- read_std_csv(file.path(root, art$source_file))
  node <- .sdmx_add_maintainable(parent, "str:Codelist", art, version)
  derived <- SDMX_DERIVED_CODELISTS[[id]]
  if (!is.null(derived)) {
    for (i in seq_len(nrow(rows))) {
      r <- rows[i, ]
      .sdmx_add_code(node, r[[derived$id]],
        "AFW_STATUS", if (derived$status) r$status else "",
        r[[derived$name]], if (nzchar(derived$desc)) r[[derived$desc]] else ""
      )
    }
  } else {
    extra <- setdiff(names(rows), c("code", "name_en", "definition_en", "parent"))
    types <- ifelse(extra %in% names(SDMX_CL_ANNOTATION_TYPES),
      SDMX_CL_ANNOTATION_TYPES[extra], paste0("AFW_", toupper(extra)))
    geo_scheme <- identical(id, "CL_GEO_SCHEME")
    for (i in seq_len(nrow(rows))) {
      r <- rows[i, ]
      vals <- vapply(extra, function(col) r[[col]], character(1), USE.NAMES = FALSE)
      code_id <- r$code
      t <- types
      if (geo_scheme) {
        code_id <- paste0(r$ref_area, "_", r$code)
        t <- c("AFW_CODE", types)
        vals <- c(r$code, vals)
      }
      .sdmx_add_code(node, code_id, t, vals, r$name_en, r$definition_en,
        if ("parent" %in% names(rows)) r$parent else "")
    }
  }
  for (s in sdmx_sentinels(dsd, id)) {
    g <- SDMX_SENTINEL_GLOBAL[paste0(id, ".", s)]
    .sdmx_add_code(node, s, c("AFW_SENTINEL", "GLOBAL_CODE"),
      c("Y", if (is.na(g)) "" else unname(g)), SDMX_SENTINEL_NAMES[[s]])
  }
  node
}

#' Build the structure message with what exists so far: the agency scheme,
#' the concept scheme and every codelist of ARTEFACTS.csv.
#'
#' @param root Repo root.
#' @param timestamp Value of the header's `mes:Prepared`.
#' @return An xml2 document.
sdmx_structures_message <- function(root, timestamp = SDMX_DEFAULT_TIMESTAMP) {
  version <- sdmx_version(root)
  artefacts <- read_std_csv(file.path(root, "metadata", "structure", "ARTEFACTS.csv"))
  dsd <- read_std_csv(file.path(root, "metadata", "structure", "DSD_AFW360_HH.csv"))
  msg <- sdmx_new_message(timestamp)
  sdmx_agency_scheme(xml2::xml_add_child(msg$structures, "str:AgencySchemes"), artefacts, version)
  sdmx_concept_scheme(xml2::xml_add_child(msg$structures, "str:ConceptSchemes"), root, artefacts, version)
  cls <- xml2::xml_add_child(msg$structures, "str:Codelists")
  for (id in artefacts$artefact_id[artefacts$artefact_type == "Codelist"]) {
    sdmx_codelist(cls, id, root, artefacts, version, dsd)
  }
  msg$doc
}
