#!/usr/bin/env Rscript
# Acceptance script for WP02 - Data standard v0.4 (stage A, then stage B).
#
#   Rscript pipeline/acceptance/wp02_standard-v04.R --root .
#
# Standalone: does not source pipeline/R/. Writes only under tempdir().
# Compares against the tag transition-base and against files, never against
# transition/main or the branch's diff.

## ---- 1. Root and check() -----------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
i <- which(args == "--root")
root <- normalizePath(if (length(i) == 1) args[i + 1] else ".", mustWork = TRUE)
contract <- file.path(root, ".docs", "transition", "contract")

.failures <- character(0)
check <- function(id, ok, evidence) {
  cat(sprintf("CHECK %s %s %s\n", id, if (isTRUE(ok)) "PASS" else "FAIL", evidence))
  if (!isTRUE(ok)) .failures[[length(.failures) + 1]] <<- id
  invisible(isTRUE(ok))
}
# Wrap a check that may stop(), so one error does not end the script.
try_check <- function(id, expr) {
  r <- tryCatch(expr, error = function(e) check(id, FALSE, paste("error:", conditionMessage(e))))
  invisible(r)
}

## ---- 2. Helpers ---------------------------------------------------------------
# All columns as character, BOM stripped, "" stays "" (never NA).
read_csv_char <- function(path) {
  raw <- readLines(path, encoding = "UTF-8", warn = FALSE)
  if (length(raw)) raw[1] <- sub("^\ufeff", "", raw[1])
  read.csv(text = paste(raw, collapse = "\n"), colClasses = "character", na.strings = NULL,
           check.names = FALSE, encoding = "UTF-8")
}
# Expected value and tolerance from the contract, by check_id.
expected <- function(check_id) {
  tab <- read_csv_char(file.path(contract, "expected_counts.csv"))
  row <- tab[tab$check_id == check_id, ]
  if (nrow(row) != 1) stop("no unique row in expected_counts.csv for ", check_id)
  list(value = as.numeric(row$expected), tol = as.numeric(row$tolerance))
}
meets <- function(actual, check_id) { e <- expected(check_id); abs(actual - e$value) <= e$tol + 1e-9 }
# The contract's header for one file, in order.
header_of <- function(file) {
  h <- read_csv_char(file.path(contract, "csv_headers.csv")); h <- h[h$file == file, ]
  h$column[order(as.integer(h$position))]
}
# Raw bytes of a committed file (the working copy may differ in line endings).
blob_bytes <- function(path, rev = "HEAD") {
  tmp <- tempfile(); on.exit(unlink(tmp))
  system2("git", c("-C", shQuote(root), "cat-file", "blob", shQuote(paste0(rev, ":", path))), stdout = tmp)
  readBin(tmp, "raw", file.size(tmp))
}
no_bom_no_cr <- function(bytes) !(length(bytes) >= 3 && identical(bytes[1:3], as.raw(c(0xef, 0xbb, 0xbf)))) && !any(bytes == as.raw(0x0d))
# Run a pipeline script; returns its exit status. Output goes to a temp log.
run_script <- function(script, script_args) {
  log <- tempfile(fileext = ".log")
  system2("Rscript", c(shQuote(file.path(root, script)), script_args), stdout = log, stderr = log)
}
same_file <- function(a, b) file.exists(a) && file.exists(b) && identical(unname(tools::md5sum(a)), unname(tools::md5sum(b)))

## ---- WP02-specific helpers ----------------------------------------------------

qmd_path <- file.path(root, ".docs", "data-standard.qmd")
qmd_lines <- readLines(qmd_path, encoding = "UTF-8", warn = FALSE)

# Committed content of the standard at a given rev, as lines (tempfile only).
qmd_lines_at <- function(rev) {
  tmp <- tempfile(fileext = ".qmd")
  system2("git", c("-C", shQuote(root), "show", shQuote(paste0(rev, ":.docs/data-standard.qmd"))),
          stdout = tmp)
  out <- readLines(tmp, encoding = "UTF-8", warn = FALSE)
  unlink(tmp)
  out
}

# Lines of the section that starts at the heading/caption carrying {#anchor},
# up to (excluding) the next heading of the same or a shallower level, or EOF.
section_after <- function(lines, anchor) {
  idx <- grep(paste0("\\{#", anchor, "\\}"), lines, fixed = FALSE)
  if (length(idx) == 0) return(character(0))
  start <- idx[1]
  hm <- regmatches(lines[start], regexpr("^#+", lines[start]))
  n <- length(lines)
  if (length(hm) == 0) return(lines[start:n])
  lvl <- nchar(hm)
  end <- n
  if (start < n) {
    pat <- sprintf("^#{1,%d}\\s", lvl)
    for (j in (start + 1):n) {
      if (grepl(pat, lines[j])) { end <- j - 1; break }
    }
  }
  lines[start:end]
}

# Lines of the pipe table that sits directly above a ": Caption {#anchor}" line.
table_before <- function(lines, anchor) {
  idx <- grep(paste0("\\{#", anchor, "\\}"), lines, fixed = FALSE)
  if (length(idx) == 0) return(character(0))
  j <- idx[1] - 1
  while (j >= 1 && trimws(lines[j]) == "") j <- j - 1
  end <- j
  while (j >= 1 && grepl("^\\s*\\|", lines[j])) j <- j - 1
  start <- j + 1
  if (start > end) return(character(0))
  lines[start:end]
}

# Which of `cols` appear inside backtick spans in `section_lines` (on their
# own, or as one item of a comma/space-separated backticked list).
cols_missing <- function(section_lines, cols) {
  txt <- paste(section_lines, collapse = "\n")
  spans <- regmatches(txt, gregexpr("`([^`]*)`", txt))[[1]]
  spans <- gsub("^`|`$", "", spans)
  pieces <- trimws(unlist(strsplit(spans, "[,[:space:]]+")))
  setdiff(cols, pieces)
}

# First-column cell of every pipe-table row in `section_lines`, excluding the
# header row and the "---" separator row.
row_ids <- function(section_lines) {
  rows <- section_lines[grepl("^\\s*\\|", section_lines)]
  out <- character(0)
  for (r in rows) {
    cell <- sub("^\\s*\\|\\s*([^|]*?)\\s*\\|.*$", "\\1", r)
    if (nzchar(cell) && !grepl("^-+$", cell) && cell != "ID") out <- c(out, cell)
  }
  out
}

# All {#sec-...}, {#tbl-...}, {#lst-...} IDs anywhere in `lines`.
heading_ids <- function(lines) {
  txt <- paste(lines, collapse = "\n")
  m <- regmatches(txt, gregexpr("\\{#(sec|tbl|lst)-[A-Za-z0-9_-]+\\}", txt))[[1]]
  gsub("[{}]", "", m)
}

## ---- 4. Checks ------------------------------------------------------------------

## WP02.A1 -- the render command succeeds for .docs/data-standard.qmd.
try_check("WP02.A1", {
  out_dir <- file.path(tempdir(), "wp02_render_out")
  unlink(out_dir, recursive = TRUE, force = TRUE)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  had_qr <- Sys.getenv("QUARTO_R", unset = NA)
  Sys.unsetenv("QUARTO_R")
  Sys.setenv(QUARTO_PYTHON = "C:/WBG/Python313/python.exe")
  log <- tempfile(fileext = ".log")
  status <- system2("quarto",
                     c("render", shQuote(qmd_path), "--output-dir", shQuote(out_dir)),
                     stdout = log, stderr = log)
  if (!is.na(had_qr)) Sys.setenv(QUARTO_R = had_qr)
  unlink(out_dir, recursive = TRUE, force = TRUE)
  # Quarto's own project cache; inherent to rendering a project file, not a
  # file this script chooses to write. Clean it up regardless.
  unlink(file.path(root, ".docs", ".quarto"), recursive = TRUE, force = TRUE)
  tail_log <- paste(utils::tail(readLines(log, warn = FALSE), 3), collapse = " | ")
  check("WP02.A1", identical(status, 0L), sprintf("quarto render exit=%s (%s)", status, tail_log))
})

## WP02.A2 -- subtitle says v0.4, and {#sec-changes-v04} exists.
try_check("WP02.A2", {
  subtitle_line <- qmd_lines[grepl("^subtitle:", qmd_lines)]
  has_v04 <- length(subtitle_line) > 0 && any(grepl("v0\\.4", subtitle_line, fixed = FALSE))
  has_sec <- any(grepl("\\{#sec-changes-v04\\}", qmd_lines))
  check("WP02.A2", has_v04 && has_sec,
        sprintf("subtitle=%s; has {#sec-changes-v04}=%s",
                if (length(subtitle_line)) subtitle_line[1] else "<missing>", has_sec))
})

## WP02.A3 -- every line that contains "Python" also mentions the dashboard.
try_check("WP02.A3", {
  py_lines <- qmd_lines[grepl("Python", qmd_lines, fixed = TRUE)]
  bad <- py_lines[!grepl("dashboard", py_lines, ignore.case = TRUE)]
  check("WP02.A3", length(bad) == 0,
        sprintf("%d line(s) with 'Python' but no 'dashboard': %s",
                length(bad), if (length(bad)) substr(bad[1], 1, 80) else "none"))
})

## WP02.A4 -- required column names appear in backticks in their sections.
try_check("WP02.A4", {
  series_plan_cols <- header_of("SERIES_PLAN.csv")
  legacy_cols <- c(header_of("LEGACY_LABELS.csv"), header_of("LEGACY_COLUMNS.csv"), header_of("LEGACY_OVERRIDES.csv"))
  findings_cols <- header_of("validator findings (any pipeline/validate.R --out file)")

  sec_series <- section_after(qmd_lines, "sec-series-plan")
  sec_legacy <- section_after(qmd_lines, "sec-legacy-maps")
  sec_valid <- section_after(qmd_lines, "sec-validation")

  miss_series <- cols_missing(sec_series, series_plan_cols)
  miss_legacy <- cols_missing(sec_legacy, legacy_cols)
  miss_findings <- cols_missing(sec_valid, findings_cols)

  ok <- length(sec_series) > 0 && length(sec_legacy) > 0 && length(sec_valid) > 0 &&
    length(miss_series) == 0 && length(miss_legacy) == 0 && length(miss_findings) == 0
  check("WP02.A4", ok,
        sprintf("missing under sec-series-plan: [%s]; under sec-legacy-maps: [%s]; under sec-validation: [%s]",
                paste(miss_series, collapse = ", "), paste(miss_legacy, collapse = ", "), paste(miss_findings, collapse = ", ")))
})

## WP02.A5 -- required tokens appear somewhere in the document.
try_check("WP02.A5", {
  full_txt <- paste(qmd_lines, collapse = "\n")
  tokens <- c("SERIES_PLAN", "LEGACY_COLUMNS", "LEGACY_OVERRIDES", "POP_HH_SH", "POP_HE_SH",
              "LEGACY_EMPTY", "TBD", "AGG_BRACKET", "admits_se", "data_raw/", "pipeline/", "WITHHOLD")
  present <- vapply(tokens, function(t) grepl(t, full_txt, fixed = TRUE), logical(1))
  check("WP02.A5", all(present),
        sprintf("missing: %s", paste(tokens[!present], collapse = ", ")))
})

## WP02.A6 -- POVLINE_PL300 row has no PPP_2017; no example-rows row has Departement.
try_check("WP02.A6", {
  povlines_tbl <- table_before(qmd_lines, "tbl-povlines")
  pl300_row <- povlines_tbl[grepl("POVLINE_PL300", povlines_tbl, fixed = TRUE)]
  pl300_ok <- length(pl300_row) > 0 && !any(grepl("PPP_2017", pl300_row, fixed = TRUE))

  example_tbl <- table_before(qmd_lines, "tbl-example-rows")
  example_ok <- length(example_tbl) > 0 && !any(grepl("Departement", example_tbl, fixed = TRUE))

  check("WP02.A6", pl300_ok && example_ok,
        sprintf("POVLINE_PL300 row found=%s, contains PPP_2017=%s; example-rows table found=%s, contains Departement=%s",
                length(pl300_row) > 0, any(grepl("PPP_2017", pl300_row, fixed = TRUE)),
                length(example_tbl) > 0, any(grepl("Departement", example_tbl, fixed = TRUE))))
})

## WP02.A7 -- the changes table names every D-decision and every gap ID.
try_check("WP02.A7", {
  changes_sec <- section_after(qmd_lines, "sec-changes-v04")
  ids_present <- row_ids(changes_sec)
  needed <- c(paste0("D", c(1, 2, 3, 4, 5, 6, 9, 11)),
              paste0("(", letters, ")"),
              "(aa)")
  missing <- setdiff(needed, ids_present)
  check("WP02.A7", length(missing) == 0,
        sprintf("missing from changes table: %s", paste(missing, collapse = ", ")))
})

## WP02.A8 -- every {#sec-...}, {#tbl-...}, {#lst-...} ID from transition-base still exists.
try_check("WP02.A8", {
  base_ids <- heading_ids(qmd_lines_at("transition-base"))
  now_ids <- heading_ids(qmd_lines)
  missing <- setdiff(base_ids, now_ids)
  check("WP02.A8", length(missing) == 0,
        sprintf("%d base ID(s), %d now; missing: %s",
                length(base_ids), length(now_ids), paste(missing, collapse = ", ")))
})

## ---- 5. Exit ----------------------------------------------------------------------
cat(if (length(.failures)) sprintf("\n%d check(s) failed: %s\n", length(.failures), paste(.failures, collapse = ", ")) else "\nAll checks passed.\n")
quit(status = if (length(.failures)) 1L else 0L, save = "no")
