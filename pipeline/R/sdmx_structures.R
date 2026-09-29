# pipeline/R/sdmx_structures.R
#
# SDMX-ML 3.1 structures generated from metadata/ (plan 2.1, 2.4 to 2.8),
# all driven by metadata/structure/ARTEFACTS.csv. Part 1: the WB:AGENCIES
# agency scheme, the concept scheme CS_AFW360 and the codelists. Part 2:
# the data structure DSD_AFW360_HH, the dataflow AFW360_HH, the data
# provider scheme and provision agreement, the metadata structure
# MSD_AFW360, the metadataflow MDF_AFW360, the metadata provider scheme and
# metadata provision agreement.
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

# ---------------------------------------------------------------------------
# Part 2: data structure, dataflow, providers, metadata structure,
# metadataflow (plan 2.4, 2.7, 2.8; sdmx-ml-cheatsheet.md sections 5, 8 to 10)
# ---------------------------------------------------------------------------

# Provider of the data and the reference metadata (plan 2.8).
SDMX_PROVIDER_ID <- "AFW_POV"
SDMX_PROVIDER_NAME <- "AFW DIP/POV team"

# Fixed version of the organisation schemes in URNs (XSD patterns
# DataProviderUrnType and MetadataProviderUrnType; plan 2.8).
SDMX_FIXED_VERSION <- "1.0"

# Explicit targets of the metadataflow MDF_AFW360 (plan 2.7): the three
# derived codelists and the dataflow.
SDMX_MDF_TARGETS <- list(
  list(package = "codelist", class = "Codelist", id = "CL_SURVEY"),
  list(package = "codelist", class = "Codelist", id = "CL_SOURCE"),
  list(package = "codelist", class = "Codelist", id = "CL_FIGURE"),
  list(package = "datastructure", class = "Dataflow", id = "AFW360_HH")
)

#' URN of a concept of CS_AFW360.
.sdmx_concept_urn <- function(id, version) {
  sdmx_item_urn("conceptscheme", "Concept", "CS_AFW360", version, id)
}

#' Add `str:ConceptIdentity` and `str:LocalRepresentation` of a DSD
#' component from its DSD CSV row: a codelist enumeration when `codelist` is
#' set, otherwise a `TextFormat` with `data_type`, `min_value`, `max_value`.
.sdmx_add_component_body <- function(node, r, version) {
  xml2::xml_add_child(node, "str:ConceptIdentity", .sdmx_concept_urn(r$id, version))
  lr <- xml2::xml_add_child(node, "str:LocalRepresentation")
  if (nzchar(r$codelist)) {
    xml2::xml_add_child(lr, "str:Enumeration", sdmx_codelist_urn(r$codelist, version))
  } else {
    tf <- xml2::xml_add_child(lr, "str:TextFormat", textType = r$data_type)
    if (nzchar(r$min_value)) xml2::xml_set_attr(tf, "minValue", r$min_value)
    if (nzchar(r$max_value)) xml2::xml_set_attr(tf, "maxValue", r$max_value)
  }
  node
}

#' Add the data structure DSD_AFW360_HH (plan 2.4) from the DSD CSV:
#' `DimensionList` (dimensions without `position`, then the time dimension),
#' `AttributeList` (relationships from the `relationship` column:
#' `observation` or a space-separated dimension list; `MeasureRelationship`
#' from `measure_relationship`), then `MeasureList` (with `usage`). No MSD
#' link.
#'
#' @param parent The `str:DataStructures` node.
#' @param root Repo root.
#' @param artefacts ARTEFACTS.csv as a tibble.
#' @param version The metadata version.
#' @return The `str:DataStructure` node.
sdmx_data_structure <- function(parent, root, artefacts, version) {
  art <- .sdmx_artefact(artefacts, "DSD_AFW360_HH")
  dsd <- read_std_csv(file.path(root, "metadata", "structure", "DSD_AFW360_HH.csv"))
  dsd <- dsd[order(as.integer(dsd$position)), , drop = FALSE]
  node <- .sdmx_add_maintainable(parent, "str:DataStructure", art, version)
  comps <- xml2::xml_add_child(node, "str:DataStructureComponents")

  dl <- xml2::xml_add_child(comps, "str:DimensionList", id = "DimensionDescriptor")
  for (i in which(dsd$component == "dimension")) {
    .sdmx_add_component_body(xml2::xml_add_child(dl, "str:Dimension", id = dsd$id[i]), dsd[i, ], version)
  }
  for (i in which(dsd$component == "time_dimension")) {
    .sdmx_add_component_body(xml2::xml_add_child(dl, "str:TimeDimension", id = dsd$id[i]), dsd[i, ], version)
  }

  al <- xml2::xml_add_child(comps, "str:AttributeList", id = "AttributeDescriptor")
  for (i in which(dsd$component == "attribute")) {
    r <- dsd[i, ]
    a <- xml2::xml_add_child(al, "str:Attribute", id = r$id, usage = r$usage)
    .sdmx_add_component_body(a, r, version)
    rel <- xml2::xml_add_child(a, "str:AttributeRelationship")
    if (identical(r$relationship, "observation")) {
      xml2::xml_add_child(rel, "str:Observation")
    } else {
      for (d in strsplit(r$relationship, " ", fixed = TRUE)[[1]]) {
        xml2::xml_add_child(rel, "str:Dimension", d)
      }
    }
    if (nzchar(r$measure_relationship)) {
      mr <- xml2::xml_add_child(a, "str:MeasureRelationship")
      for (m in strsplit(r$measure_relationship, " ", fixed = TRUE)[[1]]) {
        xml2::xml_add_child(mr, "str:Measure", m)
      }
    }
  }

  ml <- xml2::xml_add_child(comps, "str:MeasureList", id = "MeasureDescriptor")
  for (i in which(dsd$component == "measure")) {
    r <- dsd[i, ]
    .sdmx_add_component_body(xml2::xml_add_child(ml, "str:Measure", id = r$id, usage = r$usage), r, version)
  }
  node
}

#' Add the dataflow AFW360_HH over DSD_AFW360_HH (plan 2.4).
sdmx_dataflow <- function(parent, artefacts, version) {
  node <- .sdmx_add_maintainable(parent, "str:Dataflow", .sdmx_artefact(artefacts, "AFW360_HH"), version)
  xml2::xml_add_child(node, "str:Structure",
    sdmx_urn("datastructure", "DataStructure", "DSD_AFW360_HH", version))
  node
}

#' Add a fixed-version provider scheme holding the provider AFW_POV.
.sdmx_provider_scheme <- function(parent, artefacts, version, scheme_id, tag, item_tag) {
  node <- .sdmx_add_maintainable(parent, tag, .sdmx_artefact(artefacts, scheme_id), version,
                                 fixed_version = TRUE)
  prov <- xml2::xml_add_child(node, item_tag, id = SDMX_PROVIDER_ID)
  sdmx_add_name(prov, SDMX_PROVIDER_NAME)
  node
}

#' Add the data provider scheme DATA_PROVIDERS (plan 2.8; no version).
sdmx_data_provider_scheme <- function(parent, artefacts, version) {
  .sdmx_provider_scheme(parent, artefacts, version, "DATA_PROVIDERS",
                        "str:DataProviderScheme", "str:DataProvider")
}

#' Add the metadata provider scheme METADATA_PROVIDERS (plan 2.7; no version).
sdmx_metadata_provider_scheme <- function(parent, artefacts, version) {
  .sdmx_provider_scheme(parent, artefacts, version, "METADATA_PROVIDERS",
                        "str:MetadataProviderScheme", "str:MetadataProvider")
}

#' Add the provision agreement PA_AFW360_HH: dataflow plus data provider,
#' referenced as DATA_PROVIDERS(1.0).AFW_POV (plan 2.8).
sdmx_provision_agreement <- function(parent, artefacts, version) {
  node <- .sdmx_add_maintainable(parent, "str:ProvisionAgreement",
                                 .sdmx_artefact(artefacts, "PA_AFW360_HH"), version)
  xml2::xml_add_child(node, "str:Dataflow",
    sdmx_urn("datastructure", "Dataflow", "AFW360_HH", version))
  xml2::xml_add_child(node, "str:DataProvider",
    sdmx_item_urn("base", "DataProvider", "DATA_PROVIDERS", SDMX_FIXED_VERSION, SDMX_PROVIDER_ID))
  node
}

#' Add the metadata provision agreement MPA_AFW360: metadataflow plus
#' metadata provider, referenced as METADATA_PROVIDERS(1.0).AFW_POV.
sdmx_metadata_provision_agreement <- function(parent, artefacts, version) {
  node <- .sdmx_add_maintainable(parent, "str:MetadataProvisionAgreement",
                                 .sdmx_artefact(artefacts, "MPA_AFW360"), version)
  xml2::xml_add_child(node, "str:Metadataflow",
    sdmx_urn("metadatastructure", "Metadataflow", "MDF_AFW360", version))
  xml2::xml_add_child(node, "str:MetadataProvider",
    sdmx_item_urn("base", "MetadataProvider", "METADATA_PROVIDERS", SDMX_FIXED_VERSION, SDMX_PROVIDER_ID))
  node
}

#' Add the metadata structure MSD_AFW360 (plan 2.7): four presentational
#' parents (SURVEY, SOURCE, TEXT, FIGURE; `minOccurs="0"`, `maxOccurs="1"`,
#' no representation), each with one `String` child per source column minus
#' the id and status columns (`minOccurs="0"`, `maxOccurs="1"`). Every
#' attribute's concept is the CS_AFW360 concept of the same id (part 1).
#'
#' @param parent The `str:MetadataStructures` node.
#' @param root Repo root.
#' @param artefacts ARTEFACTS.csv as a tibble.
#' @param version The metadata version.
#' @return The `str:MetadataStructure` node.
sdmx_metadata_structure <- function(parent, root, artefacts, version) {
  node <- .sdmx_add_maintainable(parent, "str:MetadataStructure",
                                 .sdmx_artefact(artefacts, "MSD_AFW360"), version)
  comps <- xml2::xml_add_child(node, "str:MetadataStructureComponents")
  mal <- xml2::xml_add_child(comps, "str:MetadataAttributeList", id = "MetadataAttributeDescriptor")
  concepts <- sdmx_msd_concepts(root)
  current <- NULL
  for (i in seq_len(nrow(concepts))) {
    id <- concepts$id[i]
    if (concepts$parent[i]) {
      current <- xml2::xml_add_child(mal, "str:MetadataAttribute", id = id,
        minOccurs = "0", maxOccurs = "1", isPresentational = "true")
      xml2::xml_add_child(current, "str:ConceptIdentity", .sdmx_concept_urn(id, version))
    } else {
      ch <- xml2::xml_add_child(current, "str:MetadataAttribute", id = id,
        minOccurs = "0", maxOccurs = "1")
      xml2::xml_add_child(ch, "str:ConceptIdentity", .sdmx_concept_urn(id, version))
      lr <- xml2::xml_add_child(ch, "str:LocalRepresentation")
      xml2::xml_add_child(lr, "str:TextFormat", textType = "String")
    }
  }
  node
}

#' Add the metadataflow MDF_AFW360 over MSD_AFW360 with its four explicit
#' targets (plan 2.7).
sdmx_metadataflow <- function(parent, artefacts, version) {
  node <- .sdmx_add_maintainable(parent, "str:Metadataflow",
                                 .sdmx_artefact(artefacts, "MDF_AFW360"), version)
  xml2::xml_add_child(node, "str:Structure",
    sdmx_urn("metadatastructure", "MetadataStructure", "MSD_AFW360", version))
  for (t in SDMX_MDF_TARGETS) {
    xml2::xml_add_child(node, "str:Target", sdmx_urn(t$package, t$class, t$id, version))
  }
  node
}

#' Build the complete structure message: agency, data provider and
#' metadata provider schemes, the concept scheme, every codelist of
#' ARTEFACTS.csv, the data structure and dataflow, the metadata structure
#' and metadataflow, and the two provision agreements.
#'
#' @param root Repo root.
#' @param timestamp Value of the header's `mes:Prepared`.
#' @return An xml2 document.
sdmx_structures_message <- function(root, timestamp = SDMX_DEFAULT_TIMESTAMP) {
  version <- sdmx_version(root)
  artefacts <- read_std_csv(file.path(root, "metadata", "structure", "ARTEFACTS.csv"))
  dsd <- read_std_csv(file.path(root, "metadata", "structure", "DSD_AFW360_HH.csv"))
  msg <- sdmx_new_message(timestamp)
  s <- msg$structures
  add <- function(tag) xml2::xml_add_child(s, tag)
  sdmx_agency_scheme(add("str:AgencySchemes"), artefacts, version)
  sdmx_data_provider_scheme(add("str:DataProviderSchemes"), artefacts, version)
  sdmx_metadata_provider_scheme(add("str:MetadataProviderSchemes"), artefacts, version)
  sdmx_concept_scheme(add("str:ConceptSchemes"), root, artefacts, version)
  cls <- add("str:Codelists")
  for (id in artefacts$artefact_id[artefacts$artefact_type == "Codelist"]) {
    sdmx_codelist(cls, id, root, artefacts, version, dsd)
  }
  sdmx_data_structure(add("str:DataStructures"), root, artefacts, version)
  sdmx_dataflow(add("str:Dataflows"), artefacts, version)
  sdmx_metadata_structure(add("str:MetadataStructures"), root, artefacts, version)
  sdmx_metadataflow(add("str:Metadataflows"), artefacts, version)
  sdmx_provision_agreement(add("str:ProvisionAgreements"), artefacts, version)
  sdmx_metadata_provision_agreement(add("str:MetadataProvisionAgreements"), artefacts, version)
  msg$doc
}
