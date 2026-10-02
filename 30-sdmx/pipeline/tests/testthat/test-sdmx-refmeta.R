root <- find_root()
source(file.path(root, "pipeline", "R", "sdmx_xml.R"))
source(file.path(root, "pipeline", "R", "sdmx_structures.R"))
source(file.path(root, "pipeline", "R", "sdmx_refmeta.R"))

src_files <- c(
  MDS_SURVEYS = "metadata/surveys/SURVEYS.csv",
  MDS_SOURCES = "metadata/registries/SOURCES.csv",
  MDS_TEXT = "content/TEXT.csv",
  MDS_FIGURES = "metadata/registries/FIGURES.csv"
)

read_back <- function(path) {
  readr::read_csv(path, col_types = readr::cols(.default = readr::col_character()),
                  na = character(0), show_col_types = FALSE, progress = FALSE)
}

test_that("one metadataset per source row, with the plan 2.7 ids and targets", {
  msgs <- sdmx_refmeta_messages(root)
  expect_named(msgs, names(src_files))
  version <- sdmx_version(root)
  for (nm in names(src_files)) {
    src <- read_std_csv(file.path(root, src_files[[nm]]))
    expect_equal(nrow(msgs[[nm]]), nrow(src), info = nm)
    expect_true(all(msgs[[nm]]$MDSTRUCTURE == "metadataflow"))
    expect_true(all(msgs[[nm]]$MDSTRUCTURE_ID == sprintf("WB.AFW360:MDF_AFW360(%s)", version)))
    expect_false(anyDuplicated(msgs[[nm]]$METADATASET_ID) > 0)
  }
  s <- read_std_csv(file.path(root, src_files[["MDS_SURVEYS"]]))
  expect_equal(msgs$MDS_SURVEYS$METADATASET_ID, paste0("WB.AFW360:MDS_SURVEY_", s$survey_id))
  expect_true(all(msgs$MDS_SURVEYS$TARGET_TYPES == "codelist"))
  expect_true(all(msgs$MDS_SURVEYS$TARGET_IDS == sprintf("WB.AFW360:CL_SURVEY(%s)", version)))
  f <- read_std_csv(file.path(root, src_files[["MDS_FIGURES"]]))
  expect_equal(msgs$MDS_FIGURES$METADATASET_ID, paste0("WB.AFW360:MDS_FIGURE_", f$figure_id))
  t <- read_std_csv(file.path(root, src_files[["MDS_TEXT"]]))
  expect_equal(msgs$MDS_TEXT$METADATASET_ID,
               paste0("WB.AFW360:MDS_TEXT_", t$slot, "_", t$ref_area, "_", t$time_period, "_", t$order))
  expect_true(all(msgs$MDS_TEXT$TARGET_TYPES == "dataflow"))
  expect_true(all(msgs$MDS_TEXT$TARGET_IDS == sprintf("WB.AFW360:AFW360_HH(%s)", version)))
})

test_that("headers are the five fixed columns then dotted MSD children", {
  msgs <- sdmx_refmeta_messages(root)
  fixed <- c("MDSTRUCTURE", "MDSTRUCTURE_ID", "METADATASET_ID", "TARGET_TYPES", "TARGET_IDS")
  parents <- c(MDS_SURVEYS = "SURVEY", MDS_SOURCES = "SOURCE", MDS_TEXT = "TEXT", MDS_FIGURES = "FIGURE")
  concepts <- sdmx_msd_concepts(root)
  for (nm in names(msgs)) {
    h <- names(msgs[[nm]])
    expect_equal(h[1:5], fixed)
    attr_cols <- h[-(1:5)]
    expect_true(all(startsWith(attr_cols, paste0(parents[[nm]], "."))), info = nm)
    expect_equal(sub("^[^.]*[.]", "", attr_cols), .sdmx_refmeta_children(concepts, parents[[nm]]))
  }
  expect_false(any(c("SURVEY.SURVEY_ID", "SURVEY.STATUS") %in% names(msgs$MDS_SURVEYS)))
  expect_false(any(c("TEXT.FILE", "TEXT.STATUS") %in% names(msgs$MDS_TEXT)))
  expect_equal(names(msgs$MDS_TEXT)[-(1:5)],
               paste0("TEXT.", c("SLOT", "REF_AREA", "TIME_PERIOD", "ORDER", "TITLE", "BODY", "UPDATED_ON")))
})

test_that("BODY is inlined from the file column when it is set", {
  tmp <- make_temp_root(root, include = c("metadata", "content"))
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  dir.create(file.path(tmp, "content", "text", "XXX"), recursive = TRUE, showWarnings = FALSE)
  md <- "# Title\r\n\r\nLine with \"quotes\", a comma\r\nand a second line.\r\n"
  writeBin(charToRaw(md), file.path(tmp, "content", "text", "XXX", "note.md"))
  edit_csv(file.path(tmp, "content", "TEXT.csv"), function(df) {
    extra <- df[1, ]
    extra[1, ] <- ""
    extra$slot <- "about"; extra$ref_area <- "XXX"; extra$time_period <- "2021"
    extra$order <- "1"; extra$body <- "ignored"; extra$file <- "XXX/note.md"
    extra$status <- "DRAFT"; extra$updated_on <- "2026-09-29"
    rbind(df, extra)
  })
  msgs <- sdmx_refmeta_messages(tmp)
  row <- msgs$MDS_TEXT[msgs$MDS_TEXT$METADATASET_ID == "WB.AFW360:MDS_TEXT_about_XXX_2021_1", ]
  expect_equal(nrow(row), 1)
  expect_equal(row$TEXT.BODY, "# Title\n\nLine with \"quotes\", a comma\nand a second line.\n")
  src <- read_std_csv(file.path(root, "content", "TEXT.csv"))
  inline <- which(!nzchar(src$file))
  expect_equal(sdmx_refmeta_messages(root)$MDS_TEXT$TEXT.BODY[inline], src$body[inline])
})

test_that("files quote every field and keep multi-line bodies as RFC 4180 fields", {
  msgs <- list(MDS_TEXT = data.frame(
    MDSTRUCTURE = "metadataflow", MDSTRUCTURE_ID = "WB.AFW360:MDF_AFW360(0.3.0)",
    METADATASET_ID = "WB.AFW360:MDS_TEXT_about_XXX_2021_1", TARGET_TYPES = "dataflow",
    TARGET_IDS = "WB.AFW360:AFW360_HH(0.3.0)", TEXT.BODY = "a \"b\",\nc", TEXT.TITLE = NA_character_,
    check.names = FALSE, stringsAsFactors = FALSE
  ))
  dir <- tempfile("refmeta_")
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  path <- sdmx_refmeta_write(msgs, dir)
  bytes <- readChar(path, file.info(path)$size, useBytes = TRUE)
  expect_false(grepl("\r", bytes, fixed = TRUE))
  lines <- strsplit(bytes, "\n", fixed = TRUE)[[1]]
  expect_equal(lines[1], paste0('"MDSTRUCTURE","MDSTRUCTURE_ID","METADATASET_ID","TARGET_TYPES",',
                                '"TARGET_IDS","TEXT.BODY","TEXT.TITLE"'))
  expect_match(bytes, '"a ""b"",\nc",""\n', fixed = TRUE)
  back <- read_back(path)
  expect_equal(nrow(back), 1)
  expect_equal(back$TEXT.BODY, "a \"b\",\nc")
})

test_that("the committed messages are current and read back row for row", {
  msgs <- sdmx_refmeta_messages(root)
  dir <- tempfile("refmeta_")
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  paths <- sdmx_refmeta_write(msgs, dir)
  for (p in paths) {
    committed <- file.path(root, "sdmx", "metadata", basename(p))
    expect_true(file.exists(committed), info = basename(p))
    expect_identical(readBin(p, "raw", file.info(p)$size),
                     readBin(committed, "raw", file.info(committed)$size))
    back <- read_back(committed)
    nm <- sub("[.]csv$", "", basename(p))
    expect_equal(nrow(back), nrow(msgs[[nm]]))
    expect_equal(as.data.frame(back), msgs[[nm]], ignore_attr = TRUE)
  }
})
