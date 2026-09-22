#!/usr/bin/env Rscript
# Acceptance script for WP10 - Text, figures and surveys.
#
#   Rscript pipeline/acceptance/wp10_content.R --root .
#
# Standalone: does not source pipeline/R/ directly (WP10.A8 runs the unit
# tests, which are about those functions, in a separate Rscript subprocess).
# Expected numbers, where any exist, come from contract/expected_counts.csv
# by check_id. Writes only under tempdir(). Compares against the tag
# transition-base's inputs (data_raw/, index.qmd) and against files on disk,
# never against transition/main.
#
# WP10.A2 greps only content/TEXT.csv and the .md files under content/text/,
# so it can never match this script's own source (which lives under
# pipeline/acceptance/, is not named TEXT.csv, and is not a .md file).

## ---- 1. Root and check() -----------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
i <- which(args == "--root")
root <- normalizePath(if (length(i) == 1) args[i + 1] else ".", mustWork = TRUE)
contract <- file.path(root, ".docs", "transition", "contract")

j <- which(args == "--messages-source")
MESSAGES_SOURCE <- if (length(j) == 1) args[j + 1] else "dashboard"  # matches the orchestrator's note for this run

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
  if (length(raw)) raw[1] <- sub("^﻿", "", raw[1])
  read.csv(text = paste(raw, collapse = "\n"), colClasses = "character", na.strings = NULL,
           check.names = FALSE, encoding = "UTF-8")
}
# The contract's header for one file, in order.
header_of <- function(file) {
  h <- read_csv_char(file.path(contract, "csv_headers.csv")); h <- h[h$file == file, ]
  h$column[order(as.integer(h$position))]
}
required_cols <- function(file) {
  h <- read_csv_char(file.path(contract, "csv_headers.csv")); h <- h[h$file == file, ]
  h$column[h$status == "R"]
}
read_text_utf8 <- function(path) paste(readLines(path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
norm_ws <- function(x) trimws(gsub("[ \t\r\n]+", " ", x))
strip_wrapper <- function(x) {
  x <- gsub("<span[^>]*>", "", x, perl = TRUE)
  x <- gsub("</span>", "", x, perl = TRUE)
  x <- gsub("</?b>", "", x, perl = TRUE)
  trimws(x)
}
placeholder_count <- function(s) lengths(regmatches(s, gregexpr("##", s, fixed = TRUE)))
same_bytes <- function(a, b) {
  file.exists(a) && file.exists(b) &&
    identical(readBin(a, "raw", file.size(a)), readBin(b, "raw", file.size(b)))
}
# Run a pipeline script; returns its exit status. Output goes to a temp log.
run_script <- function(script, script_args) {
  log <- tempfile(fileext = ".log")
  status <- system2("Rscript", c(shQuote(file.path(root, script)), script_args), stdout = log, stderr = log)
  list(status = status, log = tryCatch(readLines(log, warn = FALSE), error = function(e) character(0)))
}
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || is.na(a)) b else a

## ---- 3. Message-block extraction (dashboard / files) ---------------------------
extract_dashboard_messages <- function(root) {
  qmd_lines <- readLines(file.path(root, "index.qmd"), encoding = "UTF-8", warn = FALSE)
  hits <- grep("^## Row Messages", qmd_lines)
  if (length(hits) < 2) stop("expected 2 '## Row Messages' blocks in index.qmd, found ", length(hits))
  block_lines <- function(start) {
    upper <- min(length(qmd_lines), start + 40)
    rest <- (start + 1):upper
    nh <- rest[grepl("^## ", qmd_lines[rest])]
    end <- if (length(nh)) min(nh) - 1 else upper
    qmd_lines[start:end]
  }
  parse_block <- function(bl) {
    tm <- regmatches(bl, regexec("^#\\|\\s*title:\\s*<b>(.*)</b>\\s*$", bl, perl = TRUE))
    titles <- vapply(tm, function(x) if (length(x) >= 2) x[2] else NA_character_, character(1))
    titles <- trimws(titles[!is.na(titles)])
    bm <- regmatches(bl, regexec('Markdown\\("(.*)"\\)\\s*$', bl, perl = TRUE))
    braw <- vapply(bm, function(x) if (length(x) >= 2) x[2] else NA_character_, character(1))
    braw <- braw[!is.na(braw)]
    bodies <- unname(vapply(braw, strip_wrapper, character(1)))
    list(titles = titles, bodies = bodies)
  }
  list(sen = parse_block(block_lines(hits[1])), gnb = parse_block(block_lines(hits[2])))
}
extract_files_messages <- function(root) {
  sen_lines <- readLines(file.path(root, "data_raw", "text", "Messages_SEN.txt"), encoding = "UTF-8", warn = FALSE)
  tm <- regmatches(sen_lines, regexec('^#\\|\\s*title:\\s*"(.*)"\\s*$', sen_lines, perl = TRUE))
  titles <- vapply(tm, function(x) if (length(x) >= 2) x[2] else NA_character_, character(1))
  titles <- trimws(titles[!is.na(titles)])
  bm <- regmatches(sen_lines, regexec('Markdown\\("(.*)"\\)\\s*$', sen_lines, perl = TRUE))
  braw <- vapply(bm, function(x) if (length(x) >= 2) x[2] else NA_character_, character(1))
  braw <- braw[!is.na(braw)]
  bodies <- unname(vapply(braw, strip_wrapper, character(1)))
  gnb_lines <- readLines(file.path(root, "data_raw", "text", "Messages_GNB.txt"), encoding = "UTF-8", warn = FALSE)
  gm <- regmatches(gnb_lines, regexec("^[0-9]+\\.\\s*(.*)$", gnb_lines, perl = TRUE))
  gtitles <- vapply(gm, function(x) if (length(x) >= 2) x[2] else NA_character_, character(1))
  gtitles <- trimws(gtitles[!is.na(gtitles) & nzchar(trimws(gtitles))])
  list(sen = list(titles = titles, bodies = bodies), gnb = list(titles = gtitles, bodies = character(0)))
}
message_source <- function(root) {
  if (identical(MESSAGES_SOURCE, "files")) extract_files_messages(root) else extract_dashboard_messages(root)
}

## ---- 4. Checks ------------------------------------------------------------------

# WP10.A1 -------------------------------------------------------------------------
try_check("WP10.A1", {
  tx <- read_csv_char(file.path(root, "content", "TEXT.csv"))
  expected_keys <- data.frame(
    slot     = c("about", "messages", "messages", "messages", "about", "messages", "messages", "messages"),
    ref_area = c("SEN",   "SEN",      "SEN",      "SEN",      "GNB",   "GNB",      "GNB",      "GNB"),
    order    = c(1L, 1L, 2L, 3L, 1L, 1L, 2L, 3L),
    stringsAsFactors = FALSE
  )
  tx_keys <- data.frame(slot = tx$slot, ref_area = tx$ref_area, order = suppressWarnings(as.integer(tx$order)),
                         stringsAsFactors = FALSE)
  key_str <- function(d) paste(d$slot, d$ref_area, d$order, sep = "|")
  keys_ok <- nrow(tx) == nrow(expected_keys) &&
    setequal(key_str(tx_keys), key_str(expected_keys)) &&
    !any(duplicated(key_str(tx_keys)))

  has_body <- !is.na(tx$body) & nzchar(trimws(tx$body))
  has_file <- !is.na(tx$file) & nzchar(trimws(tx$file))
  exactly_one <- xor(has_body, has_file)

  files_exist <- mapply(function(f, use) {
    if (!use) return(TRUE)
    file.exists(file.path(root, "content", "text", trimws(f)))
  }, tx$file, has_file)

  row_val <- function(slot, ref_area, order, col) {
    r <- tx[tx$slot == slot & tx$ref_area == ref_area & suppressWarnings(as.integer(tx$order)) == order, ]
    if (nrow(r) != 1) return(NA_character_)
    trimws(r[[col]])
  }
  content_ok <- identical(row_val("about", "SEN", 1, "file"), "SEN/about.md") &&
    identical(row_val("about", "GNB", 1, "body"), "TBD") &&
    all(vapply(1:3, function(o) identical(row_val("messages", "GNB", o, "body"), "TBD"), logical(1)))

  ok <- keys_ok && all(exactly_one) && all(files_exist) && content_ok
  check("WP10.A1", ok,
        sprintf("rows=%d keys_ok=%s exactly_one=%s files_exist=%s content_ok=%s",
                nrow(tx), keys_ok, all(exactly_one), all(files_exist), content_ok))
})

# WP10.A2 -------------------------------------------------------------------------
try_check("WP10.A2", {
  tx <- read_csv_char(file.path(root, "content", "TEXT.csv"))
  forbidden <- c("<", "\\{python\\}", "Markdown\\(", "#\\|")
  fields <- c(tx$title, tx$body)
  fields <- fields[!is.na(fields) & nzchar(fields)]
  bad_field <- fields[vapply(fields, function(t) any(vapply(forbidden, grepl, logical(1), x = t, perl = TRUE)), logical(1))]
  linebreak_bad <- tx$body[!is.na(tx$body) & grepl("[\r\n]", tx$body)]

  md_dir <- file.path(root, "content", "text")
  md_files <- if (dir.exists(md_dir)) list.files(md_dir, pattern = "\\.md$", recursive = TRUE, full.names = TRUE) else character(0)
  bad_md <- character(0)
  for (f in md_files) {
    txt <- read_text_utf8(f)
    if (any(vapply(forbidden, grepl, logical(1), x = txt, perl = TRUE))) bad_md <- c(bad_md, f)
  }
  ok <- length(bad_field) == 0 && length(linebreak_bad) == 0 && length(bad_md) == 0
  check("WP10.A2", ok,
        sprintf("bad_fields=%d linebreak_bodies=%d bad_md=%s",
                length(bad_field), length(linebreak_bad), paste(basename(bad_md), collapse = ",")))
})

# WP10.A3 -------------------------------------------------------------------------
try_check("WP10.A3", {
  about_md <- norm_ws(read_text_utf8(file.path(root, "content", "text", "SEN", "about.md")))
  about_src <- norm_ws(read_text_utf8(file.path(root, "data_raw", "text", "About_SEN.txt")))
  ok <- identical(about_md, about_src)
  check("WP10.A3", ok, sprintf("about.md len=%d source len=%d equal=%s", nchar(about_md), nchar(about_src), ok))
})

# WP10.A4 -------------------------------------------------------------------------
try_check("WP10.A4", {
  src <- message_source(root)
  tx <- read_csv_char(file.path(root, "content", "TEXT.csv"))
  sen_rows <- tx[tx$slot == "messages" & tx$ref_area == "SEN", ]
  sen_rows <- sen_rows[order(suppressWarnings(as.integer(sen_rows$order))), ]
  gnb_rows <- tx[tx$slot == "messages" & tx$ref_area == "GNB", ]
  gnb_rows <- gnb_rows[order(suppressWarnings(as.integer(gnb_rows$order))), ]

  shape_ok <- nrow(sen_rows) == 3 && nrow(gnb_rows) == 3 &&
    length(src$sen$titles) == 3 && length(src$sen$bodies) == 3 && length(src$gnb$titles) == 3

  sen_titles_ok <- shape_ok && all(norm_ws(sen_rows$title) == norm_ws(src$sen$titles))
  sen_bodies_ok <- shape_ok && all(norm_ws(sen_rows$body) == norm_ws(src$sen$bodies))
  placeholders_ok <- shape_ok && all(placeholder_count(sen_rows$body) == placeholder_count(src$sen$bodies))
  gnb_titles_ok <- shape_ok && all(norm_ws(gnb_rows$title) == norm_ws(src$gnb$titles))

  ok <- shape_ok && sen_titles_ok && sen_bodies_ok && placeholders_ok && gnb_titles_ok
  check("WP10.A4", ok,
        sprintf("source=%s shape_ok=%s sen_titles_ok=%s sen_bodies_ok=%s placeholders_ok=%s gnb_titles_ok=%s",
                MESSAGES_SOURCE, shape_ok, sen_titles_ok, sen_bodies_ok, placeholders_ok, gnb_titles_ok))
})

# WP10.A5 -------------------------------------------------------------------------
try_check("WP10.A5", {
  png_out <- file.path(root, "assets", "figures", "SEN", "SEN_FISCAL_EQUITY.png")
  png_raw <- file.path(root, "data_raw", "figures", "Fiscal Equity SEN.png")
  h_out <- if (file.exists(png_out)) digest::digest(file = png_out, algo = "sha256") else NA_character_
  h_raw <- if (file.exists(png_raw)) digest::digest(file = png_raw, algo = "sha256") else NA_character_
  bytes_ok <- !is.na(h_out) && !is.na(h_raw) && identical(h_out, h_raw)

  figs <- read_csv_char(file.path(root, "metadata", "registries", "FIGURES.csv"))
  row <- figs[figs$figure_id == "SEN_FISCAL_EQUITY", ]
  sha_ok <- nrow(row) == 1 && bytes_ok && identical(tolower(trimws(row$sha256)), tolower(h_out))
  alt_len <- if (nrow(row) == 1) nchar(trimws(row$alt_text_en)) else -1L
  alt_ok <- nrow(row) == 1 && alt_len > 40

  ok <- bytes_ok && sha_ok && alt_ok
  check("WP10.A5", ok, sprintf("bytes_ok=%s sha_match=%s alt_len=%d", bytes_ok, sha_ok, alt_len))
})

# WP10.A6 -------------------------------------------------------------------------
try_check("WP10.A6", {
  sv <- read_csv_char(file.path(root, "metadata", "surveys", "SURVEYS.csv"))
  sen <- sv[sv$survey_id == "SEN_EHCVM_2021", ]
  gnb <- sv[sv$survey_id == "GNB_EHCVM_2021", ]
  keys_ok <- nrow(sen) == 1 && nrow(gnb) == 1

  sen_fields_ok <- keys_ok &&
    identical(trimws(sen$sample_hh), "7100") &&
    identical(trimws(sen$npl_value), "519.8") &&
    identical(trimws(sen$fieldwork_start), "2021-11") &&
    identical(trimws(sen$fieldwork_end), "2022-09") &&
    identical(trimws(sen$producer_agency), "ANSD") &&
    identical(trimws(sen$npl_currency), "XOF")

  tp_status_ok <- keys_ok &&
    identical(trimws(sen$time_period), "2021") && identical(trimws(sen$status), "DRAFT") &&
    identical(trimws(gnb$time_period), "2021") && identical(trimws(gnb$status), "DRAFT")

  ok <- keys_ok && sen_fields_ok && tp_status_ok
  check("WP10.A6", ok, sprintf("keys_ok=%s sen_fields_ok=%s tp_status_ok=%s", keys_ok, sen_fields_ok, tp_status_ok))
})

# WP10.A7 -------------------------------------------------------------------------
try_check("WP10.A7", {
  files <- c(TEXT.csv = file.path(root, "content", "TEXT.csv"),
             FIGURES.csv = file.path(root, "metadata", "registries", "FIGURES.csv"),
             SURVEYS.csv = file.path(root, "metadata", "surveys", "SURVEYS.csv"))
  per_file <- lapply(names(files), function(fn) {
    d <- read_csv_char(files[[fn]])
    hdr_ok <- identical(names(d), header_of(fn))
    req <- intersect(required_cols(fn), names(d))
    filled_ok <- length(req) > 0 && all(vapply(req, function(cn) all(nzchar(trimws(d[[cn]]))), logical(1)))
    list(hdr_ok = hdr_ok, filled_ok = filled_ok)
  })
  names(per_file) <- names(files)
  ok <- all(vapply(per_file, function(r) r$hdr_ok && r$filled_ok, logical(1)))
  check("WP10.A7", ok,
        paste(sprintf("%s(hdr=%s,filled=%s)", names(per_file),
                       vapply(per_file, `[[`, logical(1), "hdr_ok"),
                       vapply(per_file, `[[`, logical(1), "filled_ok")),
              collapse = "; "))
})

# WP10.A8 -------------------------------------------------------------------------
try_check("WP10.A8", {
  tmp1 <- file.path(tempdir(), paste0("wp10_content_", as.integer(Sys.time())))
  tmp2 <- file.path(tempdir(), paste0("wp10_surveys_", as.integer(Sys.time())))
  dir.create(tmp1, recursive = TRUE, showWarnings = FALSE)
  dir.create(tmp2, recursive = TRUE, showWarnings = FALSE)

  r1 <- run_script("pipeline/build_content.R", c("--root", shQuote(root), "--out-root", shQuote(tmp1)))
  r2 <- run_script("pipeline/bootstrap/build_surveys.R", c("--root", shQuote(root), "--out-root", shQuote(tmp2)))

  content_rel <- c(file.path("content", "TEXT.csv"),
                    file.path("content", "text", "SEN", "about.md"),
                    file.path("assets", "figures", "SEN", "SEN_FISCAL_EQUITY.png"),
                    file.path("metadata", "registries", "FIGURES.csv"))
  survey_rel <- file.path("metadata", "surveys", "SURVEYS.csv")

  content_match <- vapply(content_rel, function(p) same_bytes(file.path(tmp1, p), file.path(root, p)), logical(1))
  survey_match <- vapply(survey_rel, function(p) same_bytes(file.path(tmp2, p), file.path(root, p)), logical(1))

  # Run the unit tests in a subprocess (they are about pipeline/R/content.R's
  # wrapper-stripping helpers, so sourcing there is in scope for this check).
  test_script <- tempfile(fileext = ".R")
  test_file <- file.path(root, "pipeline", "tests", "testthat", "test-content.R")
  r_lit <- function(p) encodeString(p, quote = '"')
  writeLines(c(
    "suppressPackageStartupMessages(library(testthat))",
    sprintf("helpers <- list.files(%s, pattern='^helper-.*\\\\.R$', full.names=TRUE)",
            r_lit(file.path(root, "pipeline", "tests", "testthat"))),
    "for (h in helpers) sys.source(h, envir = globalenv())",
    sprintf("res <- as.data.frame(test_file(%s, reporter = 'silent'))", r_lit(test_file)),
    "cat('TESTS_FAILED=', sum(res$failed), '\\n', sep='')",
    "cat('TESTS_ERROR=', sum(as.logical(res$error) %in% TRUE), '\\n', sep='')"
  ), test_script)
  tlog <- tempfile(fileext = ".log")
  tstatus <- if (file.exists(test_file)) {
    system2("Rscript", shQuote(test_script), stdout = tlog, stderr = tlog)
  } else 1L
  tlines <- tryCatch(readLines(tlog, warn = FALSE), error = function(e) character(0))
  tests_ok <- file.exists(test_file) && tstatus == 0 &&
    any(grepl("^TESTS_FAILED=0$", tlines)) && any(grepl("^TESTS_ERROR=0$", tlines))

  ok <- r1$status == 0 && r2$status == 0 && all(content_match) && all(survey_match) && tests_ok
  check("WP10.A8", ok,
        sprintf("build_content exit=%s match=%s; build_surveys exit=%s match=%s; tests_ok=%s (%s)",
                r1$status, all(content_match), r2$status, all(survey_match), tests_ok,
                paste(tail(tlines, 3), collapse = " | ")))
})

## ---- 5. Exit ----------------------------------------------------------------------
cat(if (length(.failures)) sprintf("\n%d check(s) failed: %s\n", length(.failures), paste(.failures, collapse = ", ")) else "\nAll checks passed.\n")
quit(status = if (length(.failures)) 1L else 0L, save = "no")
