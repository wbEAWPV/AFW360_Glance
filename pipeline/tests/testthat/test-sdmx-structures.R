root <- find_root()
source(file.path(root, "pipeline", "R", "io.R"))
source(file.path(root, "pipeline", "R", "sdmx_xml.R"))
source(file.path(root, "pipeline", "R", "sdmx_structures.R"))

ns <- c(
  str = "http://www.sdmx.org/resources/sdmxml/schemas/v3_1/structure",
  com = "http://www.sdmx.org/resources/sdmxml/schemas/v3_1/common"
)

# Build one codelist into a fresh message and re-read the serialised bytes.
codelist_round_trip <- function(id) {
  version <- sdmx_version(root)
  artefacts <- read_std_csv(file.path(root, "metadata", "structure", "ARTEFACTS.csv"))
  dsd <- read_std_csv(file.path(root, "metadata", "structure", "DSD_AFW360_HH.csv"))
  msg <- sdmx_new_message()
  cls <- xml2::xml_add_child(msg$structures, "str:Codelists")
  sdmx_codelist(cls, id, root, artefacts, version, dsd)
  xml2::read_xml(sdmx_serialise(msg$doc))
}

ann_value <- function(code, type) {
  xml2::xml_text(xml2::xml_find_all(code, sprintf(
    "com:Annotations/com:Annotation[com:AnnotationType='%s']/com:AnnotationValue", type
  ), ns))
}

test_that("a CSV codelist round-trips to SDMX-ML: codes, annotations, parents, sentinels", {
  csv <- read_std_csv(file.path(root, "metadata", "codelists", "CL_URBANISATION.csv"))
  doc <- codelist_round_trip("CL_URBANISATION")
  cl <- xml2::xml_find_first(doc, "//str:Codelist", ns)
  expect_equal(xml2::xml_attr(cl, "id"), "CL_URBANISATION")
  expect_equal(xml2::xml_attr(cl, "agencyID"), "WB.AFW360")
  expect_equal(xml2::xml_attr(cl, "version"), sdmx_version(root))
  expect_equal(
    xml2::xml_text(xml2::xml_find_first(cl, "com:Annotations/com:Annotation[@id='AFW_SOURCE_FILE']/com:AnnotationValue", ns)),
    "metadata/codelists/CL_URBANISATION.csv"
  )

  codes <- xml2::xml_find_all(cl, "str:Code", ns)
  ids <- xml2::xml_attr(codes, "id")
  expect_equal(length(codes), nrow(csv) + 1)
  expect_equal(ids[seq_len(nrow(csv))], csv$code)

  extra <- setdiff(names(csv), c("code", "name_en", "definition_en", "parent"))
  for (i in seq_len(nrow(csv))) {
    code <- codes[[i]]
    n_filled <- sum(nzchar(unlist(csv[i, extra])))
    n_ann <- length(xml2::xml_find_all(code, "com:Annotations/com:Annotation", ns))
    expect_equal(n_ann, n_filled, info = csv$code[i])
    expect_equal(xml2::xml_text(xml2::xml_find_first(code, "com:Name", ns)), csv$name_en[i])
    parent <- xml2::xml_text(xml2::xml_find_all(code, "str:Parent", ns))
    expect_equal(parent, if (nzchar(csv$parent[i])) csv$parent[i] else character(0), info = csv$code[i])
    if (nzchar(csv$global_urn[i])) {
      expect_equal(ann_value(code, "GLOBAL_CODE"), csv$global_urn[i])
    }
  }
  expect_true(any(nzchar(csv$parent)))

  sentinel <- codes[[which(ids == "_T")]]
  expect_equal(ann_value(sentinel, "AFW_SENTINEL"), "Y")
  expect_equal(ann_value(sentinel, "GLOBAL_CODE"),
               "urn:sdmx:org.sdmx.infomodel.codelist.Code=IAEG-SDGs:CL_URBANISATION(1.10)._T")
})

test_that("sentinels follow the DSD sentinel column; own-list-less ones carry no GLOBAL_CODE", {
  doc <- codelist_round_trip("CL_AGE")
  z <- xml2::xml_find_first(doc, "//str:Code[@id='_Z']", ns)
  expect_equal(ann_value(z, "AFW_SENTINEL"), "Y")
  expect_length(ann_value(z, "GLOBAL_CODE"), 0)
  doc <- codelist_round_trip("CL_SEX")
  expect_equal(ann_value(xml2::xml_find_first(doc, "//str:Code[@id='_Z']", ns), "GLOBAL_CODE"),
               "urn:sdmx:org.sdmx.infomodel.codelist.Code=SDMX:CL_SEX(2.1)._Z")
})

test_that("CL_GEO_SCHEME code ids join ref_area and code", {
  csv <- read_std_csv(file.path(root, "metadata", "codelists", "CL_GEO_SCHEME.csv"))
  doc <- codelist_round_trip("CL_GEO_SCHEME")
  ids <- xml2::xml_attr(xml2::xml_find_all(doc, "//str:Code", ns), "id")
  expect_equal(ids, paste0(csv$ref_area, "_", csv$code))
})

test_that("the structure message is XSD-valid and deterministic", {
  doc <- sdmx_structures_message(root)
  ok <- sdmx_validate(doc, root)
  expect_true(isTRUE(ok), info = paste(utils::head(attr(ok, "errors"), 5), collapse = "\n"))
  expect_length(xml2::xml_find_all(doc, "//str:Codelist", ns), 22)
  expect_length(xml2::xml_find_all(doc, "//str:AgencyScheme[@agencyID='WB'][@id='AGENCIES'][not(@version)]", ns), 1)
  txt <- sdmx_serialise(doc)
  expect_identical(txt, sdmx_serialise(sdmx_structures_message(root)))
  expect_false(grepl("\r", txt, fixed = TRUE))
})

# The complete structure message, built once for the part-2 tests.
full_doc <- function() xml2::read_xml(sdmx_serialise(sdmx_structures_message(root)))

test_that("the message holds every artefact of ARTEFACTS.csv once", {
  doc <- full_doc()
  artefacts <- read_std_csv(file.path(root, "metadata", "structure", "ARTEFACTS.csv"))
  tags <- c(DataStructure = "DataStructure", Dataflow = "Dataflow",
            MetadataStructure = "MetadataStructure", Metadataflow = "Metadataflow",
            DataProviderScheme = "DataProviderScheme", ProvisionAgreement = "ProvisionAgreement",
            MetadataProviderScheme = "MetadataProviderScheme",
            MetadataProvisionAgreement = "MetadataProvisionAgreement",
            Codelist = "Codelist", ConceptScheme = "ConceptScheme", AgencyScheme = "AgencyScheme")
  found <- xml2::xml_find_all(doc, "//*[local-name()='Structures']/*/*")
  expect_equal(length(found), nrow(artefacts))
  expect_setequal(xml2::xml_attr(found, "id"), artefacts$artefact_id)
  expect_setequal(xml2::xml_name(found), unname(tags[artefacts$artefact_type]))
  for (s in c("DATA_PROVIDERS", "METADATA_PROVIDERS")) {
    node <- xml2::xml_find_first(doc, sprintf("//*[@id='%s']", s))
    expect_true(is.na(xml2::xml_attr(node, "version")), info = s)
    expect_equal(xml2::xml_attr(xml2::xml_child(node, "*[@id='AFW_POV']"), "id"), "AFW_POV")
  }
})

test_that("the DSD has the components of the DSD CSV, attributes before measures", {
  doc <- full_doc()
  dsd <- read_std_csv(file.path(root, "metadata", "structure", "DSD_AFW360_HH.csv"))
  comps <- xml2::xml_find_first(doc, "//str:DataStructure/str:DataStructureComponents", ns)
  expect_equal(xml2::xml_name(xml2::xml_children(comps)),
               c("DimensionList", "AttributeList", "MeasureList"))
  dims <- xml2::xml_find_all(comps, "str:DimensionList/str:Dimension", ns)
  expect_length(dims, 18)
  expect_equal(xml2::xml_attr(dims, "id"), dsd$id[dsd$component == "dimension"])
  expect_true(all(is.na(xml2::xml_attr(dims, "position"))))
  td <- xml2::xml_find_all(comps, "str:DimensionList/str:TimeDimension", ns)
  expect_length(td, 1)
  expect_equal(xml2::xml_attr(xml2::xml_find_first(td[[1]], "str:LocalRepresentation/str:TextFormat", ns),
                              "textType"), "GregorianYear")
  meas <- xml2::xml_find_all(comps, "str:MeasureList/str:Measure", ns)
  expect_length(meas, 9)
  expect_equal(xml2::xml_attr(meas, "usage"), dsd$usage[dsd$component == "measure"])
  atts <- xml2::xml_find_all(comps, "str:AttributeList/str:Attribute", ns)
  expect_length(atts, 6)
  expect_equal(xml2::xml_attr(atts, "id"), dsd$id[dsd$component == "attribute"])
  expect_equal(xml2::xml_attr(atts, "usage"), dsd$usage[dsd$component == "attribute"])
  ci <- xml2::xml_text(xml2::xml_find_all(comps, ".//str:ConceptIdentity", ns))
  expect_equal(sub(".*[)][.]", "", ci), dsd$id[c(which(dsd$component %in% c("dimension", "time_dimension")),
                                                  which(dsd$component == "attribute"),
                                                  which(dsd$component == "measure"))])
})

test_that("attribute relationships and the OBS_STATUS measure relationship follow the DSD CSV", {
  doc <- full_doc()
  att <- function(id) xml2::xml_find_first(doc, sprintf("//str:Attribute[@id='%s']", id), ns)
  rel_dims <- function(id) xml2::xml_text(xml2::xml_find_all(att(id), "str:AttributeRelationship/str:Dimension", ns))
  expect_equal(rel_dims("SERIES_ID"),
               c("INDICATOR", paste0("COMP_BREAKDOWN_", 1:5), paste0("MEASURE_QUAL_", 1:5)))
  expect_equal(rel_dims("UNIT_MEASURE"), c("REF_AREA", "INDICATOR"))
  for (id in c("PRECISION", "OBS_STATUS", "SOURCE_ID", "OBS_COMMENT")) {
    expect_length(xml2::xml_find_all(att(id), "str:AttributeRelationship/str:Observation", ns), 1)
  }
  expect_length(xml2::xml_find_all(doc, "//str:MeasureRelationship", ns), 1)
  expect_equal(xml2::xml_text(xml2::xml_find_all(att("OBS_STATUS"), "str:MeasureRelationship/str:Measure", ns)),
               "OBS_VALUE")
  expect_equal(xml2::xml_attr(xml2::xml_find_first(att("SERIES_ID"), "str:LocalRepresentation/str:TextFormat", ns),
                              "textType"), "String")
  expect_match(xml2::xml_text(xml2::xml_find_first(att("SOURCE_ID"), "str:LocalRepresentation/str:Enumeration", ns)),
               "Codelist=WB[.]AFW360:CL_SOURCE[(]")
})

test_that("the MSD has four presentational parents with optional String children", {
  doc <- full_doc()
  concepts <- sdmx_msd_concepts(root)
  mal <- xml2::xml_find_first(doc, "//str:MetadataStructure//str:MetadataAttributeList", ns)
  parents <- xml2::xml_find_all(mal, "str:MetadataAttribute", ns)
  expect_equal(xml2::xml_attr(parents, "id"), c("SURVEY", "SOURCE", "TEXT", "FIGURE"))
  expect_true(all(xml2::xml_attr(parents, "isPresentational") == "true"))
  expect_true(all(xml2::xml_attr(parents, "minOccurs") == "0"))
  expect_length(xml2::xml_find_all(mal, "str:MetadataAttribute/str:LocalRepresentation", ns), 0)
  children <- xml2::xml_find_all(mal, "str:MetadataAttribute/str:MetadataAttribute", ns)
  expect_equal(length(children), sum(!concepts$parent))
  expect_true(all(xml2::xml_attr(children, "minOccurs") == "0"))
  expect_true(all(xml2::xml_attr(children, "maxOccurs") == "1"))
  tt <- xml2::xml_attr(xml2::xml_find_all(children, "str:LocalRepresentation/str:TextFormat", ns), "textType")
  expect_equal(tt, rep("String", length(children)))
  text_children <- xml2::xml_attr(xml2::xml_find_all(parents[[3]], "str:MetadataAttribute", ns), "id")
  expect_equal(text_children, c("SLOT", "REF_AREA", "TIME_PERIOD", "ORDER", "TITLE", "BODY", "UPDATED_ON"))
  # Every MSD concept identity resolves to a concept of CS_AFW360.
  cs_ids <- xml2::xml_attr(xml2::xml_find_all(doc, "//str:ConceptScheme/str:Concept", ns), "id")
  ci <- xml2::xml_text(xml2::xml_find_all(mal, ".//str:ConceptIdentity", ns))
  expect_true(all(sub(".*[)][.]", "", ci) %in% cs_ids))
})

test_that("the metadataflow targets three codelists and the dataflow; agreements reference providers", {
  doc <- full_doc()
  v <- sdmx_version(root)
  targets <- xml2::xml_text(xml2::xml_find_all(doc, "//str:Metadataflow/str:Target", ns))
  expect_equal(targets, c(
    sdmx_urn("codelist", "Codelist", "CL_SURVEY", v),
    sdmx_urn("codelist", "Codelist", "CL_SOURCE", v),
    sdmx_urn("codelist", "Codelist", "CL_FIGURE", v),
    sdmx_urn("datastructure", "Dataflow", "AFW360_HH", v)
  ))
  expect_equal(xml2::xml_text(xml2::xml_find_first(doc, "//str:Dataflow/str:Structure", ns)),
               sdmx_urn("datastructure", "DataStructure", "DSD_AFW360_HH", v))
  expect_equal(xml2::xml_text(xml2::xml_find_first(doc, "//str:ProvisionAgreement/str:DataProvider", ns)),
               "urn:sdmx:org.sdmx.infomodel.base.DataProvider=WB.AFW360:DATA_PROVIDERS(1.0).AFW_POV")
  expect_equal(xml2::xml_text(xml2::xml_find_first(doc, "//str:MetadataProvisionAgreement/str:MetadataProvider", ns)),
               "urn:sdmx:org.sdmx.infomodel.base.MetadataProvider=WB.AFW360:METADATA_PROVIDERS(1.0).AFW_POV")
  expect_equal(xml2::xml_text(xml2::xml_find_first(doc, "//str:MetadataProvisionAgreement/str:Metadataflow", ns)),
               sdmx_urn("metadatastructure", "Metadataflow", "MDF_AFW360", v))
})
