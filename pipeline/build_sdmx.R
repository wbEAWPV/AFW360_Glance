# pipeline/build_sdmx.R
#
# Writes the SDMX-ML 3.1 structure message sdmx/structures/AFW360_structures.xml
# from metadata/ (plan 2.4 to 2.8): the WB:AGENCIES agency scheme, the data
# and metadata provider schemes, the concept scheme CS_AFW360, every codelist
# of ARTEFACTS.csv, the data structure DSD_AFW360_HH and dataflow AFW360_HH,
# the metadata structure MSD_AFW360 and metadataflow MDF_AFW360, and the
# provision agreements PA_AFW360_HH and MPA_AFW360. The message is
# validated against pipeline/xsd/sdmx-ml-3.1/SDMXMessage.xsd before it is
# written. It also writes the four reference-metadata messages of plan 2.7
# (SDMX-CSV 2.1 metadata messages) to sdmx/metadata/MDS_SURVEYS.csv,
# MDS_SOURCES.csv, MDS_TEXT.csv and MDS_FIGURES.csv, one metadataset per
# row of SURVEYS.csv, SOURCES.csv, content/TEXT.csv and FIGURES.csv.
# Output is deterministic: the same input gives the same bytes.
#
# Usage (from the repo root):
#   Rscript pipeline/build_sdmx.R --root .            # rewrite the message and metadata
#   Rscript pipeline/build_sdmx.R --root . --check    # exit 1 if any file is stale
# Options:
#   --out-root <dir>    where sdmx/ is written or checked (default: --root)
#   --timestamp <ts>    header mes:Prepared (default 2026-01-01T00:00:00Z)
#   --sdmx-ml-version <v>  3.1 (default, the canonical committed output) or
#                       3.0: the output profile for FMR 12.4 (plan 2.13),
#                       with v3_0 namespaces and without the metadata
#                       structure, metadataflow and metadata provision
#                       agreement. 3.0 writes only the structure message,
#                       only under an --out-root other than --root, and
#                       cannot be combined with --check.
#
#   Rscript pipeline/build_sdmx.R --root . --sdmx-ml-version 3.0 --out-root tmp/v30
#
# The work is done in pipeline/R/sdmx_xml.R, pipeline/R/sdmx_structures.R
# and pipeline/R/sdmx_refmeta.R.

args <- commandArgs(trailingOnly = TRUE)

root_arg <- "."
idx <- which(args == "--root")
if (length(idx) > 0 && idx[1] < length(args)) {
  root_arg <- args[idx[1] + 1]
}
root <- normalizePath(root_arg, winslash = "/", mustWork = TRUE)

source(file.path(root, "pipeline", "R", "io.R"))
source(file.path(root, "pipeline", "R", "sdmx_xml.R"))
source(file.path(root, "pipeline", "R", "sdmx_structures.R"))
source(file.path(root, "pipeline", "R", "sdmx_refmeta.R"))

out_root <- cli_arg(args, "--out-root", root)
timestamp <- cli_arg(args, "--timestamp", SDMX_DEFAULT_TIMESTAMP)
rel_path <- file.path("sdmx", "structures", "AFW360_structures.xml")
target <- file.path(out_root, rel_path)

doc <- sdmx_structures_message(root, timestamp)
ok <- sdmx_validate(doc, root)
if (!isTRUE(ok)) {
  errs <- attr(ok, "errors")
  cat("SDMX-ML structure message is not valid against SDMXMessage.xsd:\n")
  cat(paste0("  ", utils::head(errs, 20), "\n"), sep = "")
  quit(status = 1)
}

ml_version <- cli_arg(args, "--sdmx-ml-version", "3.1")
if (!ml_version %in% c("3.1", "3.0")) {
  cat(sprintf("--sdmx-ml-version must be 3.1 or 3.0, not %s\n", ml_version))
  quit(status = 1)
}
if (ml_version == "3.0") {
  out_norm <- normalizePath(out_root, winslash = "/", mustWork = FALSE)
  if (cli_flag(args, "--check") || identical(out_norm, root)) {
    cat("--sdmx-ml-version 3.0 needs an --out-root other than --root and no --check;",
      "the committed message stays SDMX-ML 3.1\n")
    quit(status = 1)
  }
  doc30 <- sdmx_as_v30(doc)
  sdmx_write_v30(doc30, target)
  n30 <- function(tag) length(xml2::xml_find_all(doc30, paste0("//mes:Structures/*/", tag), xml2::xml_ns(doc30)))
  cat(sprintf(paste("wrote %s in the SDMX-ML 3.0 profile (%d codelists, %d data structure,",
    "%d dataflow, %d provision agreement; no metadata structure, metadataflow",
    "or metadata provision agreement)\n"),
    target, n30("str:Codelist"), n30("str:DataStructure"), n30("str:Dataflow"),
    n30("str:ProvisionAgreement")))
  quit(status = 0)
}

msgs <- sdmx_refmeta_messages(root)
md_rel <- file.path("sdmx", "metadata", paste0(names(msgs), ".csv"))

same_bytes <- function(a, b) {
  file.exists(b) &&
    identical(readBin(a, "raw", file.info(a)$size), readBin(b, "raw", file.info(b)$size))
}

if (cli_flag(args, "--check")) {
  tmp <- tempfile("sdmx_check_")
  dir.create(tmp)
  sdmx_write(doc, file.path(tmp, rel_path))
  sdmx_refmeta_write(msgs, file.path(tmp, "sdmx", "metadata"))
  stale <- 0
  for (p in c(rel_path, md_rel)) {
    if (same_bytes(file.path(tmp, p), file.path(out_root, p))) {
      cat(sprintf("%s is current\n", p))
    } else {
      cat(sprintf("%s is stale or missing; run Rscript pipeline/build_sdmx.R --root .\n", p))
      stale <- stale + 1
    }
  }
  unlink(tmp, recursive = TRUE)
  quit(status = if (stale == 0) 0 else 1)
}

sdmx_write(doc, target)
n_of <- function(tag) length(xml2::xml_find_all(doc, paste0("//mes:Structures/*/", tag), xml2::xml_ns(doc)))
cat(sprintf(paste("wrote %s (1 agency scheme, 1 concept scheme, %d codelists,",
  "%d data structure, %d dataflow, %d metadata structure, %d metadataflow,",
  "2 provider schemes, %d provision agreement, %d metadata provision agreement)\n"),
  rel_path, n_of("str:Codelist"), n_of("str:DataStructure"), n_of("str:Dataflow"),
  n_of("str:MetadataStructure"), n_of("str:Metadataflow"),
  n_of("str:ProvisionAgreement"), n_of("str:MetadataProvisionAgreement")))
sdmx_refmeta_write(msgs, file.path(out_root, "sdmx", "metadata"))
for (i in seq_along(msgs)) {
  cat(sprintf("wrote %s (%d metadatasets)\n", md_rel[i], nrow(msgs[[i]])))
}
