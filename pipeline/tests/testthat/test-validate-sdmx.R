# pipeline/tests/testthat/test-validate-sdmx.R
#
# The SDMX validator module (pipeline/R/validate_sdmx.R, WP5d): the five
# checks SDMX.STALE, SDMX.XSD, SDMX.URN, SDMX.IDENT and SDMX.CSV_HEADER are
# clean on the repository and each fires on an injected fault. Faults are
# injected into temp copies, never into sdmx/ or metadata/.

.root <- find_root()
source(file.path(.root, "pipeline", "R", "constants.R"))
source(file.path(.root, "pipeline", "R", "ctx.R"))
source(file.path(.root, "pipeline", "R", "sdmx_xml.R"))
source(file.path(.root, "pipeline", "R", "sdmx_structures.R"))
source(file.path(.root, "pipeline", "R", "sdmx_refmeta.R"))
source(file.path(.root, "pipeline", "R", "validate_sdmx.R"))

.struct_rel <- "sdmx/structures/AFW360_structures.xml"

#' A temp root with metadata/, content/ and sdmx/, plus pipeline/xsd/ (the
#' XSD check resolves the schema from the root).
.sdmx_root <- function() {
  tmp <- make_temp_root(.root, include = c("metadata", "content", "sdmx"))
  dir.create(file.path(tmp, "pipeline"))
  file.copy(file.path(.root, "pipeline", "xsd"), file.path(tmp, "pipeline"), recursive = TRUE)
  tmp
}

#' Replace text in the temp root's structure message (fixed strings).
.sub_xml <- function(tmp, from, to, all = TRUE) {
  path <- file.path(tmp, .struct_rel)
  txt <- readChar(path, file.info(path)$size, useBytes = TRUE)
  new <- if (all) gsub(from, to, txt, fixed = TRUE) else sub(from, to, txt, fixed = TRUE)
  stopifnot(!identical(new, txt))
  writeBin(charToRaw(new), path)
  invisible(path)
}

.ids <- function(res) unique(res$check_id)

test_that("the five checks give no finding on the repository", {
  data_file <- Sys.glob(file.path(.root, "data", "AFW360_HH_*.csv"))
  data_file <- data_file[!grepl("_manifest[.]csv$", data_file)][1]
  ctx <- build_ctx(.root, data_files = data_file)
  expect_equal(nrow(vc_sdmx_stale(ctx)), 0)
  expect_equal(nrow(vc_sdmx_xsd(ctx)), 0)
  expect_equal(nrow(vc_sdmx_urn(ctx)), 0)
  expect_equal(nrow(vc_sdmx_ident(ctx)), 0)
  expect_equal(nrow(vc_sdmx_csv_header(ctx)), 0)
})

test_that("a root without sdmx/ gives one INFO SDMX.SKIPPED and nothing else", {
  tmp <- make_temp_root(.root, include = c("metadata"))
  ctx <- build_ctx(tmp)
  res <- vc_sdmx_stale(ctx)
  expect_equal(res$check_id, "SDMX.SKIPPED")
  expect_equal(res$severity, "INFO")
  expect_equal(nrow(vc_sdmx_xsd(ctx)), 0)
  expect_equal(nrow(vc_sdmx_urn(ctx)), 0)
  expect_equal(nrow(vc_sdmx_ident(ctx)), 0)
})

test_that("SDMX.STALE flags a changed codelist, a missing output and a stray file", {
  tmp <- .sdmx_root()
  cl <- file.path(tmp, "metadata", "codelists", "CL_SEX.csv")
  lines <- readLines(cl, encoding = "UTF-8")
  lines[2] <- sub("Female", "Femal", lines[2], fixed = TRUE)
  writeLines(lines, cl, useBytes = TRUE)
  file.remove(file.path(tmp, "sdmx", "metadata", "MDS_FIGURES.csv"))
  writeLines("x", file.path(tmp, "sdmx", "metadata", "MDS_EXTRA.csv"))
  res <- vc_sdmx_stale(build_ctx(tmp))
  expect_equal(.ids(res), "SDMX.STALE")
  expect_true(all(res$severity == "ERROR"))
  expect_setequal(res$file, c(.struct_rel, "sdmx/metadata/MDS_FIGURES.csv", "sdmx/metadata/MDS_EXTRA.csv"))
  expect_match(res$message[res$file == .struct_rel], "differs from what build_sdmx.R writes")
  expect_match(res$message[res$file == "sdmx/metadata/MDS_FIGURES.csv"], "missing")
  expect_match(res$message[res$file == "sdmx/metadata/MDS_EXTRA.csv"], "does not write")
  # sdmx/README.md is hand-written and never flagged
  expect_false(any(grepl("README", res$file)))
})

test_that("SDMX.XSD flags an attribute the schema does not allow, and a broken file", {
  tmp <- .sdmx_root()
  .sub_xml(tmp, 'id="CL_SEX" version=', 'bogus="1" id="CL_SEX" version=')
  res <- vc_sdmx_xsd(build_ctx(tmp))
  expect_equal(.ids(res), "SDMX.XSD")
  expect_gte(nrow(res), 1)
  writeLines("<not-closed>", file.path(tmp, .struct_rel))
  res <- vc_sdmx_xsd(build_ctx(tmp))
  expect_equal(.ids(res), "SDMX.XSD")
  expect_match(res$message, "not well-formed")
  file.remove(file.path(tmp, .struct_rel))
  expect_match(vc_sdmx_xsd(build_ctx(tmp))$message, "missing")
})

test_that("SDMX.URN flags an unresolved reference", {
  tmp <- .sdmx_root()
  .sub_xml(tmp, "CL_SEX(0.3.0)", "CL_SEXX(0.3.0)")
  res <- vc_sdmx_urn(build_ctx(tmp))
  expect_equal(.ids(res), "SDMX.URN")
  expect_true(all(grepl("CL_SEXX", res$row_key)))
  expect_true(all(grepl("does not resolve", res$message)))
})

test_that("SDMX.URN flags an unresolved code reference and a missing Parent", {
  tmp <- .sdmx_root()
  doc <- xml2::read_xml(file.path(tmp, .struct_rel))
  parent <- xml2::xml_find_first(doc, "//*[local-name()='Parent']")
  xml2::xml_text(parent) <- "NO_SUCH_CODE"
  xml2::write_xml(doc, file.path(tmp, .struct_rel))
  res <- vc_sdmx_urn(build_ctx(tmp))
  expect_equal(.ids(res), "SDMX.URN")
  expect_true(any(grepl("Parent 'NO_SUCH_CODE'", res$message)))
})

test_that("SDMX.URN flags an undeclared sub-agency", {
  tmp <- .sdmx_root()
  .sub_xml(tmp, '<str:Agency id="AFW360">', '<str:Agency id="AFW361">')
  res <- vc_sdmx_urn(build_ctx(tmp))
  expect_equal(.ids(res), "SDMX.URN")
  expect_true(any(res$row_key == "WB.AFW360" & grepl("not declared", res$message)))
})

test_that("SDMX.URN flags a semver artefact referencing a non-semver one, and exempts (1.0) organisation items", {
  tmp <- .sdmx_root()
  .sub_xml(tmp, 'id="CL_SEX" version="0.3.0"', 'id="CL_SEX" version="1.0"')
  .sub_xml(tmp, "CL_SEX(0.3.0)", "CL_SEX(1.0)")
  res <- vc_sdmx_urn(build_ctx(tmp))
  expect_equal(.ids(res), "SDMX.URN")
  expect_true(all(grepl("CL_SEX[(]1[.]0[)]", res$row_key)))
  expect_true(all(grepl("non-semver version", res$message)))
  # the clean message references DataProvider and MetadataProvider items at
  # (1.0) from semver provision agreements and gives no finding (first test)
  expect_false(any(grepl("DataProvider|MetadataProvider", res$row_key)))
})

test_that("SDMX.IDENT flags agency, version, id and name faults", {
  tmp <- .sdmx_root()
  .sub_xml(tmp, 'agencyID="WB.AFW360" id="CL_AGE"', 'agencyID="WB.OTHER" id="CL_AGE"')
  .sub_xml(tmp, 'id="CL_SEX" version="0.3.0"', 'id="CL_SEX" version="0.3"')
  .sub_xml(tmp, 'id="CL_GEO" version="0.3.0"', 'id="CL_GEO" version="0.4.0"')
  .sub_xml(tmp, 'id="DATA_PROVIDERS"', 'id="DATA_PROVIDERS" version="1.0"')
  .sub_xml(tmp, 'id="CL_FREQ" version=', 'id="CL FREQ" version=')
  doc <- xml2::read_xml(file.path(tmp, .struct_rel))
  cl <- xml2::xml_find_first(doc, "//*[local-name()='Codelist'][@id='CL_AREA']")
  nm <- xml2::xml_find_first(cl, "./*[local-name()='Name']")
  xml2::xml_set_attr(nm, "xml:lang", "fr")
  xml2::write_xml(doc, file.path(tmp, .struct_rel))
  res <- vc_sdmx_ident(build_ctx(tmp))
  expect_equal(.ids(res), "SDMX.IDENT")
  msg_for <- function(rk) paste(res$message[res$row_key == rk], collapse = " | ")
  expect_match(msg_for("Codelist CL_AGE"), "agencyID is 'WB.OTHER'")
  expect_match(msg_for("Codelist CL_SEX"), "not semver")
  expect_match(msg_for("Codelist CL_GEO"), "differs from metadata/VERSION")
  expect_match(msg_for("DataProviderScheme DATA_PROVIDERS"), "must have none")
  expect_match(msg_for("Codelist CL FREQ"), "IDType")
  expect_match(msg_for("Codelist CL_AREA"), "com:Name")
  expect_equal(nrow(res), 6)
})

test_that("SDMX.CSV_HEADER flags a missing column, a wrong order and a wrong STRUCTURE_ID version", {
  tmp <- make_temp_root(.root, include = c("metadata", "data"))
  src <- Sys.glob(file.path(tmp, "data", "AFW360_HH_*.csv"))
  src <- src[!grepl("_manifest[.]csv$", src)][1]
  df <- utils::head(read_std_csv(src), 5)

  gone <- names(df)[10]
  missing_col <- df[setdiff(names(df), gone)]
  p1 <- file.path(tmp, "data", "AFW360_HH_T1.csv")
  write_std_csv(missing_col, p1)

  swapped <- df[c(names(df)[c(1, 2, 3, 5, 4)], names(df)[-(1:5)])]
  p2 <- file.path(tmp, "data", "AFW360_HH_T2.csv")
  write_std_csv(swapped, p2)

  old <- df
  old$STRUCTURE_ID[1] <- "WB.AFW360:AFW360_HH(0.2.0)"
  p3 <- file.path(tmp, "data", "AFW360_HH_T3.csv")
  write_std_csv(old, p3)

  ctx <- build_ctx(tmp, data_files = c(p1, p2, p3))
  res <- vc_sdmx_csv_header(ctx)
  expect_equal(.ids(res), "SDMX.CSV_HEADER")
  expect_equal(nrow(res), 3)
  expect_match(res$message[res$file == "data/AFW360_HH_T1.csv"], paste0("missing: ", gone))
  expect_match(res$message[res$file == "data/AFW360_HH_T2.csv"], "out of order")
  expect_match(res$message[res$file == "data/AFW360_HH_T3.csv"], "version '0.2.0'")
  expect_equal(res$row_key[res$file == "data/AFW360_HH_T3.csv"], "STRUCTURE_ID WB.AFW360:AFW360_HH(0.2.0)")
})
