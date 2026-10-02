#!/usr/bin/env Rscript
# pipeline/migrations/0.3.0/migrate.R
#
# One-off migration of metadata/ from version 0.2.0 to 0.3.0 (standard v0.6,
# SDMX 3.1 alignment, decisions D27-D46). Runs once: it refuses to run unless
# metadata/VERSION is 0.2.0. See README.md in this folder for what it changes.
#
# Usage: Rscript pipeline/migrations/0.3.0/migrate.R --root <dir> [--out-root <dir>]
#
# Reads the 0.2.0 files under <root>/metadata. Without --out-root the changes
# are applied in place. With --out-root, every file under <root>/metadata is
# first copied to <out-root>/metadata and the changes are applied there, so
# <out-root>/metadata holds the complete 0.3.0 metadata.
#
# All content (the DSD rows, the artefact list, CL_FREQ, the code alignment,
# the new COLUMNS.csv rows and the CHANGELOG entry) comes from inputs/; the
# script only copies and applies it. Every change is computed in memory and
# checked before the first file is written. Output is UTF-8 without BOM, LF,
# RFC 4180 with minimal quoting, and deterministic.

FROM_VERSION <- "0.2.0"
TO_VERSION <- "0.3.0"
OLD_UNIT <- "CL_UNIT"
NEW_UNIT <- "CL_UNIT_MEASURE"

# ---- locate and load the shared I/O helpers ---------------------------------

.script_dir <- function() {
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) == 0) {
    return(normalizePath(file.path("pipeline", "migrations", "0.3.0"), mustWork = FALSE))
  }
  dirname(normalizePath(sub("^--file=", "", file_arg[1]), mustWork = TRUE))
}

source(file.path(.script_dir(), "..", "..", "R", "io.R"))

args <- commandArgs(trailingOnly = TRUE)
root <- cli_arg(args, "--root", ".")
out_root <- cli_arg(args, "--out-root", root)

fail <- function(...) {
  message("migrate 0.3.0: ", ...)
  quit(save = "no", status = 1)
}

# ---- guard ------------------------------------------------------------------

version_path <- file.path(root, "metadata", "VERSION")
if (!file.exists(version_path)) {
  fail("no metadata/VERSION under ", root)
}
current_version <- trimws(paste(readLines(version_path, warn = FALSE), collapse = ""))
if (!identical(current_version, FROM_VERSION)) {
  fail(
    "metadata/VERSION is '", current_version, "', not ", FROM_VERSION,
    ". This migration runs once, on ", FROM_VERSION, " metadata only; nothing was written."
  )
}

# ---- helpers ----------------------------------------------------------------

mpath <- function(...) file.path(root, "metadata", ...)
inp <- function(...) file.path(.script_dir(), "inputs", ...)

# Every column as character, empty cells as "".
read_chr <- function(path) {
  if (!file.exists(path)) fail("missing file: ", path)
  d <- as.data.frame(read_std_csv(path), stringsAsFactors = FALSE)
  d[] <- lapply(d, function(x) {
    x <- as.character(x)
    x[is.na(x)] <- ""
    x
  })
  d
}

read_bytes <- function(path) {
  if (!file.exists(path)) fail("missing file: ", path)
  readBin(path, "raw", file.info(path)$size)
}

need_cols <- function(df, cols, what) {
  miss <- setdiff(cols, names(df))
  if (length(miss) > 0) fail(what, " lacks column(s): ", paste(miss, collapse = ", "))
}

# RFC 4180 with minimal quoting, as the existing metadata CSVs are written.
csv_field <- function(x) {
  x <- enc2utf8(as.character(x))
  q <- grepl("[\",\r\n]", x)
  x[q] <- paste0("\"", gsub("\"", "\"\"", x[q], fixed = TRUE), "\"")
  x
}

csv_bytes <- function(df) {
  lines <- paste(csv_field(names(df)), collapse = ",")
  if (nrow(df) > 0) {
    lines <- c(lines, do.call(paste, c(unname(lapply(df, csv_field)), sep = ",")))
  }
  charToRaw(enc2utf8(paste0(paste(lines, collapse = "\n"), "\n")))
}

text_bytes <- function(lines) charToRaw(enc2utf8(paste0(paste(lines, collapse = "\n"), "\n")))

outputs <- list()   # relative path under metadata/ -> raw bytes
removed <- character(0)  # relative paths under metadata/ to delete

# ---- read the inputs ----------------------------------------------------------

alignment <- read_chr(inp("ALIGNMENT.csv"))
need_cols(alignment, c("codelist", "code_0_2_0", "code_0_3_0", "name_en", "definition_en", "global_urn"),
          "inputs/ALIGNMENT.csv")
new_columns <- read_chr(inp("COLUMNS_0.3.0.csv"))
cl_freq <- read_chr(inp("CL_FREQ.csv"))
changelog_entry <- readLines(inp("CHANGELOG_0.3.0.md"), encoding = "UTF-8", warn = FALSE)

# ---- 2.10 items 1, 2: DSD and ARTEFACTS copied as is ---------------------------

outputs[["structure/DSD_AFW360_HH.csv"]] <- read_bytes(inp("DSD_AFW360_HH.csv"))
if (file.exists(mpath("structure", "ARTEFACTS.csv"))) fail("structure/ARTEFACTS.csv already exists")
outputs[["structure/ARTEFACTS.csv"]] <- read_bytes(inp("ARTEFACTS.csv"))

# ---- 2.10 items 3, 4: codelists -------------------------------------------------

if (file.exists(mpath("codelists", "CL_FREQ.csv"))) fail("codelists/CL_FREQ.csv already exists")
if (file.exists(mpath("codelists", paste0(NEW_UNIT, ".csv")))) fail("codelists/", NEW_UNIT, ".csv already exists")
outputs[["codelists/CL_FREQ.csv"]] <- read_bytes(inp("CL_FREQ.csv"))

# CL_FREQ.csv already carries its name, definition and global_urn; check that it
# agrees with its ALIGNMENT.csv rows instead of applying them.
for (i in which(alignment$codelist == "CL_FREQ")) {
  j <- which(cl_freq$code == alignment$code_0_3_0[i])
  if (length(j) != 1 || cl_freq$global_urn[j] != alignment$global_urn[i] ||
      (nzchar(alignment$name_en[i]) && cl_freq$name_en[j] != alignment$name_en[i])) {
    fail("inputs/CL_FREQ.csv disagrees with ALIGNMENT.csv on code ", alignment$code_0_3_0[i])
  }
}

cl_files <- sort(list.files(mpath("codelists"), pattern = "^CL_.*\\.csv$"), method = "radix")
if (!paste0(OLD_UNIT, ".csv") %in% cl_files) fail("codelists/", OLD_UNIT, ".csv not found")
known_lists <- c(sub("\\.csv$", "", cl_files), "CL_FREQ", NEW_UNIT)
bad <- setdiff(alignment$codelist, known_lists)
if (length(bad) > 0) fail("ALIGNMENT.csv names unknown codelist(s): ", paste(bad, collapse = ", "))

codelist_ncol <- list()  # file name after migration -> column count before global_urn
for (f in cl_files) {
  list_id <- sub("\\.csv$", "", f)
  new_id <- if (list_id == OLD_UNIT) NEW_UNIT else list_id
  cl <- read_chr(mpath("codelists", f))
  need_cols(cl, c("code", "name_en", "definition_en", "status", "version_added"), f)
  if ("global_urn" %in% names(cl)) fail(f, " already has a global_urn column")
  codelist_ncol[[paste0(new_id, ".csv")]] <- ncol(cl)
  cl$global_urn <- ""

  for (i in which(alignment$codelist == new_id)) {
    a <- alignment[i, ]
    if (!nzchar(a$code_0_3_0)) fail("ALIGNMENT.csv row ", i, " has no code_0_3_0")
    if (!nzchar(a$code_0_2_0)) {
      # An added code: name and definition are given; DRAFT, added now.
      if (!nzchar(a$name_en) || !nzchar(a$definition_en)) {
        fail("ALIGNMENT.csv adds ", new_id, ".", a$code_0_3_0, " without name_en and definition_en")
      }
      if (a$code_0_3_0 %in% cl$code) fail(new_id, ".", a$code_0_3_0, " already exists")
      row <- as.data.frame(as.list(stats::setNames(rep("", ncol(cl)), names(cl))),
                           stringsAsFactors = FALSE, check.names = FALSE)
      row$code <- a$code_0_3_0
      row$name_en <- a$name_en
      row$definition_en <- a$definition_en
      row$status <- "DRAFT"
      row$version_added <- TO_VERSION
      row$global_urn <- a$global_urn
      cl <- rbind(cl, row)
    } else {
      j <- which(cl$code == a$code_0_2_0)
      if (length(j) != 1) fail(new_id, ".", a$code_0_2_0, " (ALIGNMENT.csv row ", i, ") not found once")
      if (a$code_0_3_0 != a$code_0_2_0) {
        if (a$code_0_3_0 %in% cl$code) fail(new_id, ".", a$code_0_3_0, " already exists")
        cl$code[j] <- a$code_0_3_0
        for (ref in intersect(c("parent", "replaced_by"), names(cl))) {
          cl[[ref]][cl[[ref]] == a$code_0_2_0] <- a$code_0_3_0
        }
      }
      if (nzchar(a$name_en)) cl$name_en[j] <- a$name_en
      if (nzchar(a$definition_en)) cl$definition_en[j] <- a$definition_en
      cl$global_urn[j] <- a$global_urn
    }
  }

  outputs[[paste0("codelists/", new_id, ".csv")]] <- csv_bytes(cl)
  if (new_id != list_id) removed <- c(removed, paste0("codelists/", f))
}

# ---- 2.10 items 3, 5: COLUMNS.csv -------------------------------------------------

columns <- read_chr(mpath("structure", "COLUMNS.csv"))
need_cols(columns, c("file", "position", "column", "status", "description"), "COLUMNS.csv")
if (!identical(names(new_columns), names(columns))) fail("inputs/COLUMNS_0.3.0.csv header differs from COLUMNS.csv")
if (any(columns$file %in% c("ARTEFACTS.csv", "CL_FREQ.csv"))) fail("COLUMNS.csv already lists ARTEFACTS.csv or CL_FREQ.csv")

old_unit_file <- paste0(OLD_UNIT, ".csv")
columns$file[columns$file == old_unit_file] <- paste0(NEW_UNIT, ".csv")
columns$description <- gsub(paste0("\\b", OLD_UNIT, "\\b"), NEW_UNIT, columns$description, perl = TRUE)

block <- function(file) new_columns[new_columns$file == file, , drop = FALSE]
urn_row <- new_columns[new_columns$file == "CL_FREQ.csv" & new_columns$column == "global_urn", ]
if (nrow(urn_row) != 1) fail("inputs/COLUMNS_0.3.0.csv has no CL_FREQ.csv global_urn row")

pieces <- list()
files_in_order <- unique(columns$file)
first_codelist <- files_in_order[startsWith(files_in_order, "CL_")][1]
for (f in files_in_order) {
  rows <- columns[columns$file == f, , drop = FALSE]
  if (f == first_codelist) pieces <- c(pieces, list(block("CL_FREQ.csv")))
  if (f == "DSD_AFW360_HH.csv") {
    rows <- block(f)
  } else if (f %in% names(codelist_ncol)) {
    n <- codelist_ncol[[f]]
    if (nrow(rows) != n || !identical(rows$position, as.character(seq_len(n)))) {
      fail("COLUMNS.csv rows for ", f, " do not match its ", n, " columns")
    }
    extra <- urn_row
    extra$file <- f
    extra$position <- as.character(n + 1L)
    rows <- rbind(rows, extra)
  }
  pieces <- c(pieces, list(rows))
  if (f == "COLUMNS.csv") pieces <- c(pieces, list(block("ARTEFACTS.csv")))
}
columns_new <- do.call(rbind, pieces)
rownames(columns_new) <- NULL
missing_cl <- setdiff(names(codelist_ncol), columns_new$file)
if (length(missing_cl) > 0) fail("COLUMNS.csv has no rows for ", paste(missing_cl, collapse = ", "))
outputs[["structure/COLUMNS.csv"]] <- csv_bytes(columns_new)

# ---- 2.10 item 6: VERSION and CHANGELOG ---------------------------------------------

outputs[["VERSION"]] <- text_bytes(TO_VERSION)

changelog <- readLines(mpath("CHANGELOG.md"), encoding = "UTF-8", warn = FALSE)
if (any(startsWith(changelog, paste0("## ", TO_VERSION)))) fail("CHANGELOG.md already has a ", TO_VERSION, " entry")
first_entry <- which(startsWith(changelog, "## "))[1]
if (is.na(first_entry)) fail("CHANGELOG.md has no version entry")
while (length(changelog_entry) > 0 && !nzchar(changelog_entry[length(changelog_entry)])) {
  changelog_entry <- changelog_entry[-length(changelog_entry)]
}
changelog <- c(
  changelog[seq_len(first_entry - 1)],
  changelog_entry, "",
  changelog[first_entry:length(changelog)]
)
outputs[["CHANGELOG.md"]] <- text_bytes(changelog)

# ---- write ----------------------------------------------------------------------

target <- file.path(out_root, "metadata")
same_root <- identical(
  normalizePath(root, winslash = "/", mustWork = TRUE),
  normalizePath(out_root, winslash = "/", mustWork = FALSE)
)
if (!same_root) {
  src_files <- list.files(mpath(), recursive = TRUE, all.files = TRUE, no.. = TRUE)
  for (rel in src_files) {
    dest <- file.path(target, rel)
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(mpath(rel), dest, overwrite = TRUE)) fail("could not copy ", rel)
  }
}
for (rel in removed) unlink(file.path(target, rel))
for (rel in names(outputs)) {
  dest <- file.path(target, rel)
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  con <- file(dest, "wb")
  writeBin(outputs[[rel]], con)
  close(con)
}

message("migrate 0.3.0: wrote ", length(outputs), " file(s), removed ", length(removed),
        " under ", target)
