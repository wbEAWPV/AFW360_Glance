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
