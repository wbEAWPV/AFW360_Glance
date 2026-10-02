# pipeline/R/sdmx_refmeta.R
#
# Reference metadata as SDMX-CSV 2.1 metadata messages (plan 2.7): one
# metadataset per row of SURVEYS.csv, SOURCES.csv, content/TEXT.csv and
# FIGURES.csv, written to sdmx/metadata/MDS_<REGISTRY>.csv against the
# metadataflow MDF_AFW360 of the structure message.
#
# Header: MDSTRUCTURE, MDSTRUCTURE_ID, METADATASET_ID, TARGET_TYPES,
# TARGET_IDS, then one column per child metadata attribute of the
# presentational parent, dotted as <PARENT>.<CHILD> (the parent itself has
# no column). The child list is taken from sdmx_msd_concepts(), so the CSV
# columns are exactly the MSD children written in the structure message.
#
# Depends on pipeline/R/io.R, pipeline/R/sdmx_xml.R and
# pipeline/R/sdmx_structures.R (sourced by the caller).

# One entry per metadata message: MSD parent, source file, id column(s)
# used in METADATASET_ID, target type and target artefact id (plan 2.7).
SDMX_REFMETA_MESSAGES <- list(
  MDS_SURVEYS = list(parent = "SURVEY", file = "metadata/surveys/SURVEYS.csv",
                     prefix = "MDS_SURVEY", id_cols = "survey_id",
                     target_type = "codelist", target_id = "CL_SURVEY"),
  MDS_SOURCES = list(parent = "SOURCE", file = "metadata/registries/SOURCES.csv",
                     prefix = "MDS_SOURCE", id_cols = "source_id",
                     target_type = "codelist", target_id = "CL_SOURCE"),
  MDS_TEXT = list(parent = "TEXT", file = "content/TEXT.csv",
                  prefix = "MDS_TEXT",
                  id_cols = c("slot", "ref_area", "time_period", "order"),
                  target_type = "dataflow", target_id = "AFW360_HH"),
  MDS_FIGURES = list(parent = "FIGURE", file = "metadata/registries/FIGURES.csv",
                     prefix = "MDS_FIGURE", id_cols = "figure_id",
                     target_type = "codelist", target_id = "CL_FIGURE")
)

# Folder holding the Markdown files named in the `file` column of TEXT.csv.
SDMX_TEXT_DIR <- file.path("content", "text")

#' `AGENCY:ID(VERSION)` reference used in MDSTRUCTURE_ID and TARGET_IDS.
sdmx_short_ref <- function(id, version, agency = SDMX_AGENCY) {
  sprintf("%s:%s(%s)", agency, id, version)
}

#' Child metadata attribute ids of an MSD parent, in MSD order.
.sdmx_refmeta_children <- function(concepts, parent) {
  start <- which(concepts$parent & concepts$id == parent)
  if (length(start) != 1) stop("MSD parent not found: ", parent)
  ids <- character(0)
  i <- start + 1
  while (i <= nrow(concepts) && !concepts$parent[i]) {
    ids <- c(ids, concepts$id[i])
    i <- i + 1
  }
  ids
}

#' Read a TEXT.csv Markdown file verbatim (UTF-8, line endings as LF).
.sdmx_read_text_file <- function(root, rel) {
  path <- file.path(root, SDMX_TEXT_DIR, rel)
  if (!file.exists(path)) stop("TEXT.csv file not found: ", path)
  txt <- readChar(path, file.info(path)$size, useBytes = TRUE)
  Encoding(txt) <- "UTF-8"
  gsub("\r\n", "\n", txt, fixed = TRUE)
}

#' Build one metadata message as a data frame of character columns.
#'
#' @param root Repo root.
#' @param spec One entry of SDMX_REFMETA_MESSAGES.
#' @param concepts Output of sdmx_msd_concepts(root).
#' @param version The metadata version.
sdmx_refmeta_message <- function(root, spec, concepts, version) {
  src <- read_std_csv(file.path(root, spec$file))
  if (spec$parent == "TEXT") {
    has_file <- nzchar(src$file)
    src$body[has_file] <- vapply(src$file[has_file], function(f) .sdmx_read_text_file(root, f),
                                 character(1), USE.NAMES = FALSE)
  }
  children <- .sdmx_refmeta_children(concepts, spec$parent)
  cols <- names(src)[match(children, toupper(names(src)))]
  if (anyNA(cols)) {
    stop(spec$file, ": no column for MSD attribute(s) ",
         paste(children[is.na(cols)], collapse = ", "))
  }
  n <- nrow(src)
  key <- do.call(paste, c(unname(as.list(src[spec$id_cols])), sep = "_"))
  out <- data.frame(
    MDSTRUCTURE = rep("metadataflow", n),
    MDSTRUCTURE_ID = rep(sdmx_short_ref("MDF_AFW360", version), n),
    METADATASET_ID = paste0(SDMX_AGENCY, ":", spec$prefix, "_", key),
    TARGET_TYPES = rep(spec$target_type, n),
    TARGET_IDS = rep(sdmx_short_ref(spec$target_id, version), n),
    stringsAsFactors = FALSE
  )
  for (k in seq_along(children)) {
    out[[paste0(spec$parent, ".", children[k])]] <- src[[cols[k]]]
  }
  if (anyDuplicated(out$METADATASET_ID)) {
    stop(spec$file, ": duplicate METADATASET_ID ",
         out$METADATASET_ID[anyDuplicated(out$METADATASET_ID)])
  }
  out
}

#' Build the four metadata messages of plan 2.7.
#'
#' @param root Repo root.
#' @return Named list (MDS_SURVEYS, MDS_SOURCES, MDS_TEXT, MDS_FIGURES) of
#'   data frames.
sdmx_refmeta_messages <- function(root) {
  version <- sdmx_version(root)
  concepts <- sdmx_msd_concepts(root)
  lapply(SDMX_REFMETA_MESSAGES, function(spec) sdmx_refmeta_message(root, spec, concepts, version))
}

#' Write metadata messages as SDMX-CSV 2.1 files: every field quoted
#' (RFC 4180, embedded quotes doubled, line breaks kept inside quotes; NA
#' becomes a quoted empty string, so every field is quoted), UTF-8, LF.
#'
#' @param msgs Output of sdmx_refmeta_messages().
#' @param dir Destination folder (sdmx/metadata).
#' @return The written paths, invisibly.
sdmx_refmeta_write <- function(msgs, dir) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  paths <- file.path(dir, paste0(names(msgs), ".csv"))
  for (i in seq_along(msgs)) {
    df <- msgs[[i]]
    df[] <- lapply(df, function(col) { col <- as.character(col); col[is.na(col)] <- ""; col })
    readr::write_csv(df, paths[i], quote = "all", na = "", eol = "\n")
  }
  invisible(paths)
}
