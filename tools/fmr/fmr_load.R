# fmr_load.R: load the AFW 360 structures into a running Fusion Metadata
# Registry (FMR) through its structure submission web service.
#
# Usage (from the repository root):
#   Rscript tools/fmr/fmr_load.R --root .
#   Rscript tools/fmr/fmr_load.R --root . --file <message.xml>
#
# Without --file the script
#   1. checks that FMR answers at FMR_BASE;
#   2. registers the top-level agency WB in FMR's SDMX:AGENCIES(1.0) scheme
#      when it is missing, by submitting tools/fmr/agencies_bootstrap.xml
#      (FMR cannot resolve WB:AGENCIES(1.0), which declares WB.AFW360,
#      without it); nothing is sent when WB is already there;
#   3. builds the SDMX-ML 3.0 profile into tmp/fmr/v30/ with
#      Rscript pipeline/build_sdmx.R --root . --sdmx-ml-version 3.0 --out-root tmp/fmr/v30
#      (FMR 12.4 rejects SDMX-ML 3.1 with error 150; the 3.1 file under
#      sdmx/ stays the canonical committed output);
#   4. POSTs tmp/fmr/v30/sdmx/structures/AFW360_structures.xml.
# With --file only steps 1 and 4 run, for the given message.
#
# Options:
#   --root <dir>     repository root (default: .)
#   --file <path>    message to load, relative to --root
#   --action <mode>  FMR ACTION header: APPEND, REPLACE (default), MERGE,
#                    FULLREPLACE or DELETE
#
# Environment:
#   FMR_BASE      FMR address (default http://localhost:8080)
#   FMR_USER      FMR account with agency or admin rights
#   FMR_PASSWORD  its password
# When FMR_USER or FMR_PASSWORD is unset, the values FMR_ADMIN_USER and
# FMR_ADMIN_PASSWORD are read from tools/fmr/runtime/secrets.txt (written by
# the local install, gitignored).
#
# Response bodies are saved under tmp/fmr/ (load_response.xml, and
# agencies_response.xml when WB is registered). The script prints the HTTP
# status line and exits 0 on HTTP 200, 1 otherwise (after printing the FMR
# error text).

args <- commandArgs(trailingOnly = TRUE)
cli_arg <- function(flag, default) {
  i <- which(args == flag)
  if (length(i) > 0 && i[1] < length(args)) args[i[1] + 1] else default
}

root <- normalizePath(cli_arg("--root", "."), winslash = "/", mustWork = TRUE)
file <- cli_arg("--file", NA_character_)
action <- toupper(cli_arg("--action", "REPLACE"))
base <- sub("/+$", "", Sys.getenv("FMR_BASE", "http://localhost:8080"))
out_dir <- file.path(root, "tmp/fmr")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

fmr_credentials <- function(root) {
  user <- Sys.getenv("FMR_USER")
  pass <- Sys.getenv("FMR_PASSWORD")
  secrets <- file.path(root, "tools/fmr/runtime/secrets.txt")
  if ((!nzchar(user) || !nzchar(pass)) && file.exists(secrets)) {
    kv <- readLines(secrets, warn = FALSE)
    get <- function(key) {
      hit <- grep(paste0("^", key, "="), kv, value = TRUE)
      if (length(hit)) sub("^[^=]*=", "", hit[1]) else ""
    }
    if (!nzchar(user)) user <- get("FMR_ADMIN_USER")
    if (!nzchar(pass)) pass <- get("FMR_ADMIN_PASSWORD")
  }
  if (!nzchar(user) || !nzchar(pass)) {
    cat("No FMR credentials: set FMR_USER and FMR_PASSWORD.\n", file = stderr())
    quit(status = 1)
  }
  paste0(user, ":", pass)
}

fetch <- function(url, handle) {
  res <- tryCatch(curl::curl_fetch_memory(url, handle = handle),
                  error = function(e) e)
  if (inherits(res, "error")) {
    cat("FMR not reachable at", base, ":", conditionMessage(res), "\n", file = stderr())
    quit(status = 1)
  }
  res
}

# POST a structure message; save the response; return TRUE on HTTP 200.
post_structures <- function(path, label, response_file) {
  url <- paste0(base, "/ws/secure/sdmxapi/rest/")
  h <- curl::new_handle()
  curl::handle_setopt(h,
    post = TRUE, postfields = readBin(path, "raw", file.info(path)$size),
    httpauth = 1L, userpwd = fmr_credentials(root), timeout = 600L
  )
  curl::handle_setheaders(h, "Content-Type" = "application/xml", "ACTION" = action)
  res <- fetch(url, h)
  writeBin(res$content, file.path(out_dir, response_file))
  txt <- rawToChar(res$content)
  cat(sprintf("POST %s (%s, ACTION: %s) -> HTTP %d\n", url, label, action, res$status_code))
  if (res$status_code == 200) {
    cat(if (grepl("Success", txt, fixed = TRUE)) "Success\n" else "HTTP 200\n")
    return(TRUE)
  }
  err <- regmatches(txt, regexpr("<com:Text>[^<]*", txt))
  if (length(err)) {
    err <- gsub("&lt;", "<", sub("<com:Text>", "", err), fixed = TRUE)
    cat("FMR error:", substr(err, 1, 300), "\n")
  }
  cat("Full response: tmp/fmr/", response_file, "\n", sep = "")
  FALSE
}

# 1. Is FMR up?
up <- fetch(paste0(base, "/"), curl::new_handle(timeout = 60L))
if (up$status_code != 200) {
  cat(sprintf("FMR at %s answered HTTP %d; start it first (see .docs/fmr-guide.qmd).\n",
              base, up$status_code), file = stderr())
  quit(status = 1)
}
cat(sprintf("FMR is up at %s\n", base))

if (!is.na(file)) {
  path <- file.path(root, file)
  if (!file.exists(path)) {
    cat("Structure message not found:", path, "\n", file = stderr())
    quit(status = 1)
  }
  quit(status = if (post_structures(path, file, "load_response.xml")) 0 else 1)
}

# 2. Register WB in SDMX:AGENCIES(1.0) when missing.
h <- curl::new_handle(timeout = 60L)
curl::handle_setheaders(h, "Accept" = "application/vnd.sdmx.structure+xml;version=3.0.0")
ag <- fetch(paste0(base, "/sdmx/v2/structure/agencyscheme/SDMX/AGENCIES/1.0"), h)
has_wb <- ag$status_code == 200 &&
  grepl("Agency=SDMX:AGENCIES(1.0).WB\"", rawToChar(ag$content), fixed = TRUE)
if (has_wb) {
  cat("Agency WB already in SDMX:AGENCIES(1.0)\n")
} else {
  cat("Agency WB missing from SDMX:AGENCIES(1.0); registering it\n")
  boot <- file.path(root, "tools/fmr/agencies_bootstrap.xml")
  if (!post_structures(boot, "tools/fmr/agencies_bootstrap.xml", "agencies_response.xml")) {
    quit(status = 1)
  }
}

# 3. Build the SDMX-ML 3.0 profile.
v30_root <- "tmp/fmr/v30"
rscript <- file.path(R.home("bin"), "Rscript")
status <- system2(rscript, c(shQuote(file.path(root, "pipeline/build_sdmx.R")), "--root", shQuote(root),
                             "--sdmx-ml-version", "3.0",
                             "--out-root", shQuote(file.path(root, v30_root))))
if (!identical(status, 0L)) {
  cat("build_sdmx.R --sdmx-ml-version 3.0 failed with exit", status, "\n", file = stderr())
  quit(status = 1)
}

# 4. Load it.
rel <- file.path(v30_root, "sdmx/structures/AFW360_structures.xml")
quit(status = if (post_structures(file.path(root, rel), rel, "load_response.xml")) 0 else 1)
