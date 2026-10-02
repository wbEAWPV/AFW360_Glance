root <- find_root()
source(file.path(root, "pipeline", "R", "io.R"))
source(file.path(root, "pipeline", "R", "sdmx_xml.R"))
source(file.path(root, "pipeline", "R", "sdmx_structures.R"))
source(file.path(root, "pipeline", "R", "sdmx_import.R"))

# The structure message built from the tracked metadata, as text.
msg_text <- sdmx_serialise(sdmx_structures_message(root))

import_text <- function(txt) {
  sdmx_import_plan(xml2::read_xml(txt), root)
}

test_that("build then import gives byte-identical CSVs", {
  plan <- import_text(msg_text)
  paths <- vapply(plan$files, function(f) f$path, character(1))
  expect_setequal(paths, c(
    file.path("metadata", "codelists", list.files(file.path(root, "metadata", "codelists"))),
    "metadata/structure/ARTEFACTS.csv"
  ))
  expect_length(sdmx_import_diff(plan), 0)
  expect_equal(sum(grepl("derived", plan$reports)), 3)

  out <- withr::local_tempdir()
  expect_length(sdmx_import_apply(plan, out), 0)
  for (p in paths) {
    expect_identical(
      readBin(file.path(out, p), "raw", file.size(file.path(out, p))),
      readBin(file.path(root, p), "raw", file.size(file.path(root, p))),
      info = p
    )
  }
})

test_that("an SDMX-ML 3.0 message imports the same", {
  plan <- import_text(gsub("/v3_1/", "/v3_0/", msg_text, fixed = TRUE))
  expect_length(sdmx_import_diff(plan), 0)
})

test_that("a renamed code name in the XML appears in the diff", {
  mod <- sub('<com:Name xml:lang="en">Female</com:Name>',
    '<com:Name xml:lang="en">Femalx</com:Name>', msg_text, fixed = TRUE)
  d <- sdmx_import_diff(import_text(mod))
  expect_equal(sum(grepl("^[-+][^-+]", d)), 2)
  expect_equal(sum(grepl("Femalx", d, fixed = TRUE)), 1)
})

test_that("an unknown annotation type errors", {
  mod <- sub("AnnotationType>AFW_NOTES<", "AnnotationType>AFW_BOGUS<", msg_text, fixed = TRUE)
  expect_error(import_text(mod), "AFW_BOGUS")
})

test_that("a codelist without a source file errors", {
  mod <- sub(
    '<com:Annotation id="AFW_SOURCE_FILE"><com:AnnotationType>AFW_SOURCE_FILE</com:AnnotationType><com:AnnotationValue>metadata/codelists/CL_SEX.csv</com:AnnotationValue></com:Annotation>',
    "", msg_text, fixed = TRUE)
  expect_false(identical(mod, msg_text))
  expect_error(import_text(mod), "CL_SEX: codelist has no AFW_SOURCE_FILE")
})
