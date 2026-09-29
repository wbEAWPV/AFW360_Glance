# pipeline/build_sdmx.R
#
# Writes the SDMX-ML 3.1 structure message sdmx/structures/AFW360_structures.xml
# from metadata/ (plan 2.5, 2.6): the WB:AGENCIES agency scheme, the concept
# scheme CS_AFW360 and every codelist of ARTEFACTS.csv. The message is
# validated against pipeline/xsd/sdmx-ml-3.1/SDMXMessage.xsd before it is
# written. Output is deterministic: the same input gives the same bytes.
#
# Usage (from the repo root):
#   Rscript pipeline/build_sdmx.R --root .            # rewrite the message
#   Rscript pipeline/build_sdmx.R --root . --check    # exit 1 if it is stale
# Options:
#   --out-root <dir>    where sdmx/ is written or checked (default: --root)
#   --timestamp <ts>    header mes:Prepared (default 2026-01-01T00:00:00Z)
#
# The work is done in pipeline/R/sdmx_xml.R and pipeline/R/sdmx_structures.R.

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

if (cli_flag(args, "--check")) {
  tmp <- tempfile(fileext = ".xml")
  on.exit(unlink(tmp))
  sdmx_write(doc, tmp)
  current <- file.exists(target) &&
    identical(readBin(tmp, "raw", file.info(tmp)$size),
              readBin(target, "raw", file.info(target)$size))
  if (current) {
    cat(sprintf("%s is current\n", rel_path))
    quit(status = 0)
  }
  cat(sprintf("%s is stale or missing; run Rscript pipeline/build_sdmx.R --root .\n", rel_path))
  quit(status = 1)
}

sdmx_write(doc, target)
n_cl <- length(xml2::xml_find_all(doc, "//str:Codelist", xml2::xml_ns(doc)))
cat(sprintf("wrote %s (1 agency scheme, 1 concept scheme, %d codelists)\n", rel_path, n_cl))
