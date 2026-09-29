# fmr_validate.R: validate each AFW 360 data file against the structures
# loaded in a running Fusion Metadata Registry (FMR).
#
# Usage (from the repository root, after tools/fmr/fmr_load.R):
#   Rscript tools/fmr/fmr_validate.R --root .
#
# Every data/AFW360_HH_*_SURVEY.csv (SDMX-CSV 2.1, sent as is) is POSTed to
# <FMR_BASE>/ws/public/data/validate. FMR answers with a JSON report; it is
# saved as tmp/fmr/<ISO3>_<YEAR>_<SOURCE>_validation.json (for example
# tmp/fmr/SEN_2021_SURVEY_validation.json). The script prints one line per
# file (format FMR detected, dataflow, observation count, error flag and the
# number of reported errors) and exits 0 when every report says
# "Errors": false, 1 otherwise.
#
# Options:
#   --root <dir>   repository root (default: .)
# Environment:
#   FMR_BASE       FMR address (default http://localhost:8080)

args <- commandArgs(trailingOnly = TRUE)
cli_arg <- function(flag, default) {
  i <- which(args == flag)
  if (length(i) > 0 && i[1] < length(args)) args[i[1] + 1] else default
}

root <- normalizePath(cli_arg("--root", "."), winslash = "/", mustWork = TRUE)
base <- sub("/+$", "", Sys.getenv("FMR_BASE", "http://localhost:8080"))
url <- paste0(base, "/ws/public/data/validate")
out_dir <- file.path(root, "tmp/fmr")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

files <- list.files(file.path(root, "data"), pattern = "^AFW360_HH_.*_SURVEY\\.csv$",
                    full.names = TRUE)
if (!length(files)) {
  cat("No data/AFW360_HH_*_SURVEY.csv files found.\n", file = stderr())
  quit(status = 1)
}

# Count the error entries a report lists, wherever FMR puts them.
count_errors <- function(x) {
  if (!is.list(x)) return(0L)
  n <- 0L
  keys <- names(x)
  for (i in seq_along(x)) {
    k <- if (is.null(keys)) "" else keys[i]
    v <- x[[i]]
    if (k %in% c("Errors", "ValidationErrors", "ErrorList") && is.list(v)) {
      n <- n + length(v)
    } else if (is.list(v)) {
      n <- n + count_errors(v)
    }
  }
  n
}
`%||%` <- function(a, b) if (is.null(a)) b else a

ok <- TRUE
for (f in files) {
  tag <- sub("^AFW360_HH_(.*)\\.csv$", "\\1", basename(f))
  report <- file.path(out_dir, paste0(tag, "_validation.json"))
  h <- curl::new_handle()
  curl::handle_setopt(h, post = TRUE,
                      postfields = readBin(f, "raw", file.info(f)$size),
                      timeout = 600L)
  curl::handle_setheaders(h,
    "Content-Type" = "application/vnd.sdmx.data+csv;version=2.1.0",
    "Accept" = "application/json")
  res <- tryCatch(curl::curl_fetch_memory(url, handle = h), error = function(e) e)
  if (inherits(res, "error")) {
    cat("FMR not reachable at", base, ":", conditionMessage(res), "\n", file = stderr())
    quit(status = 1)
  }
  writeBin(res$content, report)
  rel <- sub(paste0(root, "/"), "", report, fixed = TRUE)
  if (res$status_code != 200) {
    cat(sprintf("%s: HTTP %d, report %s\n", basename(f), res$status_code, rel))
    ok <- FALSE
    next
  }
  j <- tryCatch(jsonlite::fromJSON(rawToChar(res$content), simplifyVector = FALSE),
                error = function(e) NULL)
  if (is.null(j)) {
    cat(sprintf("%s: HTTP 200 but the report is not JSON, see %s\n", basename(f), rel))
    ok <- FALSE
    next
  }
  flag <- isTRUE(j$Errors)
  n_err <- count_errors(j)
  ds <- if (length(j$Datasets)) j$Datasets[[1]] else list()
  cat(sprintf("%s: HTTP 200, format %s, dataflow %s, %s observations, Errors: %s, error entries: %d, report %s\n",
              basename(f), j$FileFormat %||% "?", sub(".*=", "", ds$Dataflow %||% "?"),
              ds$ObsCount %||% "?", tolower(flag), n_err, rel))
  if (flag || n_err > 0) ok <- FALSE
}
quit(status = if (ok) 0 else 1)
