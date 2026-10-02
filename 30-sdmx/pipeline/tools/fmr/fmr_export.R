# fmr_export.R: export the AFW 360 structures from a running Fusion Metadata
# Registry (FMR) as an SDMX-ML structure message, for the round trip
#   Rscript pipeline/import_sdmx.R --root . --diff <file>
#
# Usage (from the repository root):
#   Rscript tools/fmr/fmr_export.R --root . --out tmp/fmr/export.xml
#
# It GETs <FMR_BASE>/sdmx/v2/structure/*/WB,WB.AFW360/*/* (every artefact
# maintained by WB or WB.AFW360, latest versions, full detail), asking for
# SDMX-ML 3.1 first and falling back to 3.0 (FMR 12.4 answers 406 to 3.1 and
# serves 3.0). The agency WB owns WB:AGENCIES(1.0), which declares WB.AFW360;
# WB.AFW360 owns everything else. The FMR installation's own SDMX:AGENCIES
# scheme is not exported.
#
# Options:
#   --root <dir>   repository root (default: .)
#   --out <file>   output path, relative to --root (default tmp/fmr/export.xml)
# Environment:
#   FMR_BASE       FMR address (default http://localhost:8080)
#
# Exits 0 when a message was written, 1 otherwise.

args <- commandArgs(trailingOnly = TRUE)
cli_arg <- function(flag, default) {
  i <- which(args == flag)
  if (length(i) > 0 && i[1] < length(args)) args[i[1] + 1] else default
}

root <- normalizePath(cli_arg("--root", "."), winslash = "/", mustWork = TRUE)
out <- cli_arg("--out", "tmp/fmr/export.xml")
out_path <- if (grepl("^([A-Za-z]:)?[/\\\\]", out)) out else file.path(root, out)
dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
base <- sub("/+$", "", Sys.getenv("FMR_BASE", "http://localhost:8080"))
url <- paste0(base, "/sdmx/v2/structure/*/WB,WB.AFW360/*/*?detail=full")

for (v in c("3.1.0", "3.0.0")) {
  h <- curl::new_handle(timeout = 600L)
  curl::handle_setheaders(h,
    "Accept" = sprintf("application/vnd.sdmx.structure+xml;version=%s", v))
  res <- tryCatch(curl::curl_fetch_memory(url, handle = h), error = function(e) e)
  if (inherits(res, "error")) {
    cat("FMR not reachable at", base, ":", conditionMessage(res), "\n", file = stderr())
    quit(status = 1)
  }
  cat(sprintf("GET %s (SDMX-ML %s) -> HTTP %d\n", url, v, res$status_code))
  if (res$status_code == 200) {
    writeBin(res$content, out_path)
    head <- rawToChar(res$content[seq_len(min(2000L, length(res$content)))])
    ns <- regmatches(head, regexpr("schemas/v[0-9]_[0-9]/message", head))
    cat(sprintf("wrote %s (%d bytes, namespace %s)\n", out, length(res$content),
                if (length(ns)) ns else "?"))
    quit(status = 0)
  }
}
cat("FMR offered no SDMX-ML 3.x structure message.\n", file = stderr())
quit(status = 1)
