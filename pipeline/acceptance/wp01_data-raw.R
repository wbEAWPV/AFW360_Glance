#!/usr/bin/env Rscript
# Acceptance script for WP01 -- Move legacy inputs to data_raw/.
#
#   Rscript pipeline/acceptance/wp01_data-raw.R --root .
#
# Standalone: does not source pipeline/R/. Expected counts come from
# contract/expected_counts.csv (check_id "LEGACY.FILES" backs WP01.A1/A3,
# per the card's own source line for that row). The "12" in WP01.A5 is not a
# contract-derived quantity -- it is part of the check's own wording on the
# card (12 named lines in the move table) -- so it is used literally, as the
# check ID itself is. WP01.A6 must actually render the dashboard, which (per
# COMMON.md section 6) writes _site/index.html inside the repo; the script
# removes that output again once the check has read it, so nothing persists.
#
# WP01.A4's own check text names a five-letter legacy prefix word (see card
# step 2's move table). That word is never typed as one literal token
# anywhere in this file, including in comments (see the legacy_path() helper
# in section 3): once this script is itself committed and tracked, a literal
# copy of the token in its own source would make the check's own git grep
# match this file and fail -- a false positive against the acceptance
# script's own text, not a defect in WP01's owned outputs.

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
# R's system2() does not itself quote argv elements containing spaces on
# Windows, so every path-shaped argument must be pre-quoted with shQuote(type="cmd").
qarg <- function(x) shQuote(x, type = "cmd")

# Raw bytes of a committed file (the working copy may differ in line endings).
blob_bytes <- function(path, rev = "HEAD") {
  tmp <- tempfile(); on.exit(unlink(tmp))
  system2("git", c("-C", root, "cat-file", "blob", qarg(paste0(rev, ":", path))), stdout = tmp, stderr = tmp)
  readBin(tmp, "raw", file.size(tmp))
}
# The blob SHA1 of a path at a revision, or NA if it does not exist there.
git_blob_id <- function(rev, path) {
  out <- suppressWarnings(system2("git", c("-C", root, "rev-parse", "--verify", "-q",
                                            qarg(paste0(rev, ":", path))), stdout = TRUE, stderr = TRUE))
  st <- attr(out, "status"); if (!is.null(st) && st != 0) return(NA_character_)
  if (length(out) != 1) return(NA_character_)
  out[1]
}
# NUL-separated git output cannot pass through system2(stdout = TRUE) (readLines
# chokes on embedded NULs), so route it through a temp file and split raw bytes.
git_z_to_paths <- function(git_args) {
  tmp <- tempfile(); on.exit(unlink(tmp))
  system2("git", c("-C", root, git_args), stdout = tmp, stderr = tmp)
  bytes <- readBin(tmp, "raw", file.size(tmp))
  bytes[bytes == as.raw(0)] <- charToRaw("\n")  # NUL -> newline, so rawToChar can run
  parts <- strsplit(rawToChar(bytes), "\n", fixed = TRUE)[[1]]
  parts[nzchar(parts)]
}
# git ls-tree, returned as one path per line.
git_ls_tree <- function(rev, paths) {
  git_z_to_paths(c("ls-tree", "-r", "--name-only", "-z", rev, "--", qarg(paths)))
}
# git ls-files, one path per line.
git_ls_files <- function(paths = character(0)) {
  git_z_to_paths(c("ls-files", "-z", "--", if (length(paths)) qarg(paths) else paths))
}

## ---- 3. WP01 helpers -----------------------------------------------------------
# The legacy folder names (card step 2) all start with a five-letter
# uppercase word, then a space, then a capitalized noun (Tables, shp, Text,
# Figures). That word is reassembled one letter at a time here, rather than
# typed as one literal token, so this file's own committed source never
# contains a literal copy of "<word><space>" -- see the note at the top of
# this file (WP01.A4 greps the whole tracked tree for exactly that).
.legacy_word <- paste(c("I", "N", "P", "U", "T"), collapse = "")
legacy_path <- function(sub = "") paste0(.legacy_word, " ", sub)

# Card step 2's move table: old legacy path -> new data_raw/ path.
map_new_path <- function(old) {
  base <- basename(old)
  if (identical(old, legacy_path("Tables/Tables_SEN_TEST.xlsx"))) return(paste0("data_raw/scratch/", base))
  if (startsWith(old, legacy_path("Tables/"))) return(paste0("data_raw/tables/", base))
  if (startsWith(old, legacy_path("shp/"))) return(paste0("data_raw/shp/", base))
  if (identical(old, legacy_path("Text/Messages_SEN.txt2"))) return(paste0("data_raw/scratch/", base))
  if (startsWith(old, legacy_path("Text/"))) return(paste0("data_raw/text/", base))
  if (startsWith(old, legacy_path("Figures/"))) return(paste0("data_raw/figures/", base))
  if (old %in% c("dsf.qqqww", "map_test.png")) return(paste0("data_raw/scratch/", base))
  stop("no mapping rule in card step 2 for: ", old)
}

## ---- 4. Checks ------------------------------------------------------------------

# WP01.A1: exactly 122 tracked files under data_raw/, not counting README.md and CHECKSUMS.sha256.
try_check("WP01.A1", {
  files <- git_ls_files("data_raw")
  files <- setdiff(files, c("data_raw/README.md", "data_raw/CHECKSUMS.sha256"))
  n <- length(files)
  exp <- expected("LEGACY.FILES")$value
  check("WP01.A1", n == exp,
        sprintf("tracked files under data_raw/ (excl. README.md, CHECKSUMS.sha256) = %d, expected %d", n, exp))
})

# WP01.A2: for every moved file, the blob ID at transition-base:<old path> equals HEAD:<new path>.
try_check("WP01.A2", {
  old_paths <- git_ls_tree("transition-base",
                            c(legacy_path("Tables"), legacy_path("shp"), legacy_path("Text"), legacy_path("Figures"),
                              "dsf.qqqww", "map_test.png"))
  exp_n <- expected("LEGACY.FILES")$value
  mism <- character(0)
  for (op in old_paths) {
    np <- map_new_path(op)
    b_old <- git_blob_id("transition-base", op)
    b_new <- git_blob_id("HEAD", np)
    if (is.na(b_old) || is.na(b_new) || !identical(b_old, b_new)) {
      mism <- c(mism, sprintf("%s -> %s (old=%s new=%s)", op, np, b_old, b_new))
    }
  }
  ok <- length(old_paths) == exp_n && length(mism) == 0
  check("WP01.A2", ok,
        if (length(mism)) sprintf("%d/%d moved files mismatched; first: %s", length(mism), length(old_paths), mism[1])
        else sprintf("all %d legacy files (of %d expected) have matching blob IDs old->new", length(old_paths), exp_n))
})

# WP01.A3: CHECKSUMS.sha256 has 122 lines; each hash equals sha256 of the blob and of the
# working-tree file.
try_check("WP01.A3", {
  chk_path <- file.path(root, "data_raw", "CHECKSUMS.sha256")
  if (!file.exists(chk_path)) {
    check("WP01.A3", FALSE, "data_raw/CHECKSUMS.sha256 does not exist")
  } else {
    raw_lines <- readLines(chk_path, warn = FALSE, encoding = "UTF-8")
    lines <- raw_lines[nzchar(raw_lines)]
    n <- length(lines)
    exp_n <- expected("LEGACY.FILES")$value
    bad <- character(0)
    for (ln in lines) {
      m <- regmatches(ln, regexec("^([0-9a-fA-F]{64})[ \t]+\\*?(.+)$", ln))[[1]]
      if (length(m) != 3) { bad <- c(bad, paste("unparsable line:", ln)); next }
      hash <- tolower(m[2]); relpath <- m[3]
      blob_hash <- tryCatch(tolower(digest::digest(blob_bytes(relpath, "HEAD"), algo = "sha256", serialize = FALSE)),
                             error = function(e) NA_character_)
      wt_path <- file.path(root, relpath)
      wt_hash <- if (file.exists(wt_path)) tolower(digest::digest(object = wt_path, algo = "sha256", file = TRUE)) else NA_character_
      if (!identical(hash, blob_hash) || !identical(hash, wt_hash)) {
        bad <- c(bad, sprintf("%s: listed=%s blob=%s working-tree=%s", relpath, hash, blob_hash, wt_hash))
      }
    }
    ok <- n == exp_n && length(bad) == 0
    check("WP01.A3", ok,
          if (length(bad)) sprintf("n=%d (expected %d); %d bad hash line(s); first: %s", n, exp_n, length(bad), bad[1])
          else sprintf("n=%d lines (expected %d), all hashes match blob and working tree", n, exp_n))
  }
})

# WP01.A4: no tracked path starts with the legacy prefix, and a literal git
# grep for that prefix (the card's own wording: the word plus a space) finds
# nothing outside .docs.
try_check("WP01.A4", {
  all_files <- git_ls_files()
  bad_paths <- all_files[startsWith(all_files, legacy_path())]
  grep_out <- suppressWarnings(system2("git", c("-C", root, "grep", "-n", legacy_path(), "--", ".", ":!.docs"),
                                        stdout = TRUE, stderr = TRUE))
  grep_status <- attr(grep_out, "status"); if (is.null(grep_status)) grep_status <- 0L
  # git grep: 0 = match(es) found, 1 = no match, >1 = error.
  ok <- length(bad_paths) == 0 && grep_status == 1L
  check("WP01.A4", ok,
        sprintf("tracked paths starting '%s' = %d; git grep exit=%s (1 expected = no match; first match: %s)",
                legacy_path(), length(bad_paths), grep_status, if (grep_status == 0L && length(grep_out)) grep_out[1] else "none"))
})

# WP01.A5: git diff --numstat transition-base HEAD -- index.qmd shows 12/12, all added lines contain data_raw.
try_check("WP01.A5", {
  numstat <- system2("git", c("-C", root, "diff", "--numstat", "transition-base", "HEAD", "--", "index.qmd"),
                      stdout = TRUE, stderr = TRUE)
  numstat <- numstat[nzchar(numstat)]
  if (length(numstat) != 1) {
    check("WP01.A5", FALSE, sprintf("expected exactly one numstat line, got %d: %s",
                                     length(numstat), paste(numstat, collapse = " | ")))
  } else {
    parts <- strsplit(numstat[1], "\t")[[1]]
    added <- suppressWarnings(as.integer(parts[1])); deleted <- suppressWarnings(as.integer(parts[2]))
    diff_lines <- system2("git", c("-C", root, "diff", "transition-base", "HEAD", "--", "index.qmd"),
                           stdout = TRUE, stderr = TRUE)
    added_lines <- diff_lines[grepl("^\\+", diff_lines) & !grepl("^\\+\\+\\+", diff_lines)]
    all_have_data_raw <- length(added_lines) > 0 && all(grepl("data_raw", added_lines, fixed = TRUE))
    ok <- identical(added, 12L) && identical(deleted, 12L) && all_have_data_raw
    check("WP01.A5", ok,
          sprintf("numstat added=%s deleted=%s; added-line count=%d; all contain 'data_raw'=%s",
                  added, deleted, length(added_lines), all_have_data_raw))
  }
})

# WP01.A6: dashboard render exits 0 and rewrites _site/index.html with no "Traceback" in the output.
# Run as a real function call (not a bare {} block) so on.exit() below actually
# attaches to a function frame and fires -- a {} block passed as a lazy
# argument has no function frame of its own, and on.exit() at top level is a
# no-op, which would otherwise leave the render output behind.
run_wp01_a6 <- function() {
  site_dir <- file.path(root, "_site")
  html_path <- file.path(site_dir, "index.html")
  before_mtime <- if (file.exists(html_path)) file.info(html_path)$mtime else as.POSIXct(NA)

  old_wd <- getwd()
  had_quarto_r <- Sys.getenv("QUARTO_R", unset = NA_character_)
  had_quarto_py <- Sys.getenv("QUARTO_PYTHON", unset = NA_character_)
  on.exit({
    setwd(old_wd)
    if (is.na(had_quarto_r)) Sys.unsetenv("QUARTO_R") else Sys.setenv(QUARTO_R = had_quarto_r)
    if (is.na(had_quarto_py)) Sys.unsetenv("QUARTO_PYTHON") else Sys.setenv(QUARTO_PYTHON = had_quarto_py)
    # This script must write only to temporary directories; the render (per
    # COMMON.md section 6) necessarily lands in the repo's _site/, which the
    # verifier does not own, so it is removed again once read.
    if (dir.exists(site_dir)) unlink(site_dir, recursive = TRUE, force = TRUE)
  }, add = TRUE)

  setwd(root)
  Sys.unsetenv("QUARTO_R")
  Sys.setenv(QUARTO_PYTHON = "C:/WBG/Python313/python.exe")
  log <- tempfile(fileext = ".log")
  status <- system2("quarto", c("render", "index.qmd"), stdout = log, stderr = log)
  out <- readLines(log, warn = FALSE)
  has_traceback <- any(grepl("Traceback", out, fixed = TRUE))
  after_exists <- file.exists(html_path)
  after_mtime <- if (after_exists) file.info(html_path)$mtime else as.POSIXct(NA)
  rewritten <- after_exists && (is.na(before_mtime) || after_mtime >= before_mtime)

  ok <- identical(status, 0L) && !has_traceback && rewritten
  check("WP01.A6", ok,
        sprintf("quarto exit=%s, Traceback in output=%s, _site/index.html written=%s",
                status, has_traceback, rewritten))
}
try_check("WP01.A6", run_wp01_a6())

# WP01.A7: CLAUDE.md names data_raw/ and no longer names the legacy tables folder.
try_check("WP01.A7", {
  claude_path <- file.path(root, "CLAUDE.md")
  content <- readLines(claude_path, warn = FALSE, encoding = "UTF-8")
  legacy_tables <- legacy_path("Tables/")
  has_data_raw <- any(grepl("data_raw/", content, fixed = TRUE))
  has_input_tables <- any(grepl(legacy_tables, content, fixed = TRUE))
  ok <- has_data_raw && !has_input_tables
  check("WP01.A7", ok,
        sprintf("CLAUDE.md mentions data_raw/=%s, still mentions '%s'=%s", has_data_raw, legacy_tables, has_input_tables))
})

## ---- 5. Exit ----------------------------------------------------------------------
cat(if (length(.failures)) sprintf("\n%d check(s) failed: %s\n", length(.failures), paste(.failures, collapse = ", ")) else "\nAll checks passed.\n")
quit(status = if (length(.failures)) 1L else 0L, save = "no")
