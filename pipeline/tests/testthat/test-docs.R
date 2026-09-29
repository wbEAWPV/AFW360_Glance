root <- find_root()
source(file.path(root, "pipeline", "R", "io.R"))
source(file.path(root, "pipeline", "R", "docs.R"))

expected_ids <- c(
  "tbl-brk-vars", "tbl-cl-brk-var", "tbl-cl-geo", "tbl-cl-geo-scheme",
  "tbl-cl-indicator", "tbl-columns", "tbl-indicator-qualifiers",
  "tbl-initial-plan", "tbl-legacy-columns-csv", "tbl-legacy-labels",
  "tbl-legacy-overrides", "tbl-obs-status", "tbl-povlines",
  "tbl-qualifier-pairs", "tbl-qual-vars", "tbl-rules", "tbl-series-plan",
  "tbl-small-codelists", "tbl-sources", "tbl-surveys", "tbl-tab-plan",
  "tbl-text"
)

build_into_temp <- function() {
  out <- tempfile(pattern = "afw360_docs_test_")
  docs_build(root, out)
  out
}

test_that("the generator writes exactly the 22 fragments", {
  out <- build_into_temp()
  on.exit(unlink(out, recursive = TRUE), add = TRUE)
  expect_setequal(sub("\\.md$", "", list.files(out)), expected_ids)
  expect_length(list.files(out), 22)
})

test_that("every fragment is one pipe table, a blank line and its caption", {
  out <- build_into_temp()
  on.exit(unlink(out, recursive = TRUE), add = TRUE)
  for (id in expected_ids) {
    path <- file.path(out, paste0(id, ".md"))
    raw <- readBin(path, "raw", file.info(path)$size)
    expect_false(identical(raw[1:3], as.raw(c(0xef, 0xbb, 0xbf))), info = id)
    expect_false(any(raw == as.raw(0x0d)), info = id)
    txt <- rawToChar(raw)
    Encoding(txt) <- "UTF-8"
    expect_true(endsWith(txt, "\n") && !endsWith(txt, "\n\n"), info = id)
    lines <- strsplit(sub("\n$", "", txt), "\n", fixed = TRUE)[[1]]
    n <- length(lines)
    expect_gte(n, 5)
    table_lines <- lines[setdiff(seq_len(n - 2), 2)]
    expect_true(all(grepl("^\\| .* \\|$", table_lines)), info = id)
    expect_match(lines[2], "^\\|(---\\|)+$", info = id)
    expect_identical(lines[n - 1], "", info = id)
    expect_match(lines[n], paste0("^: .+ \\{#", id, "\\}$"), info = id)
  }
})

test_that("tbl-columns has one row per DSD component, positions 1 to 34", {
  out <- build_into_temp()
  on.exit(unlink(out, recursive = TRUE), add = TRUE)
  lines <- readLines(file.path(out, "tbl-columns.md"), encoding = "UTF-8")
  rows <- lines[grepl("^\\| [0-9]+ \\|", lines)]
  expect_length(rows, 34)
  expect_identical(as.integer(sub("^\\| ([0-9]+) \\|.*$", "\\1", rows)), 1:34)
  expect_match(rows[1], "^\\| 1 \\| `FREQ` \\|")
  expect_false(any(grepl("DATAFLOW", lines, fixed = TRUE)))
})

test_that("docs_check finds nothing on a fresh set and one finding when a fragment is deleted", {
  out <- build_into_temp()
  on.exit(unlink(out, recursive = TRUE), add = TRUE)
  expect_equal(nrow(docs_check(root, gen_dir = out)), 0)

  file.remove(file.path(out, "tbl-povlines.md"))
  f <- docs_check(root, gen_dir = out)
  expect_equal(nrow(f), 1)
  expect_identical(f$check_id, "DOCS.FRAGMENT_MISSING")
  expect_identical(f$row_key, "tbl-povlines")
  expect_named(f, c("check_id", "severity", "file", "row_key", "message"))
})

test_that("docs_check reports a stale fragment and an unknown file", {
  out <- build_into_temp()
  on.exit(unlink(out, recursive = TRUE), add = TRUE)
  cat("extra\n", file = file.path(out, "tbl-columns.md"), append = TRUE)
  writeLines("x", file.path(out, "tbl-orphan.md"))
  f <- docs_check(root, gen_dir = out)
  expect_setequal(f$check_id, c("DOCS.FRAGMENT_STALE", "DOCS.FRAGMENT_UNKNOWN"))
})

test_that("fragment row order follows position and slot_order, not the file's row order", {
  tmp <- make_temp_root(root, include = c("metadata", "content"))
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  set.seed(20260928)
  for (rel in c(
    "metadata/structure/DSD_AFW360_HH.csv",
    "metadata/codelists/CL_BRK_VAR.csv",
    "metadata/codelists/CL_QUAL_VAR.csv"
  )) {
    df <- read_std_csv(file.path(tmp, rel))
    df <- df[rev(seq_len(nrow(df))), , drop = FALSE] # reversed: every row moves
    df <- df[sample(nrow(df)), , drop = FALSE]
    write_std_csv(df, file.path(tmp, rel))
  }
  ids <- c("tbl-columns", "tbl-brk-vars", "tbl-qual-vars")
  expect_identical(docs_fragments(tmp)[ids], docs_fragments(root)[ids])
})

test_that("a line break inside a cell becomes one space", {
  expect_identical(md_text("a\r\nb\nc\rd"), "a b c d")
})

test_that("md_text escapes the characters that would change a cell", {
  expect_identical(md_text("a | b <x> $1 *y*"), "a \\| b \\<x> \\$1 \\*y\\*")
  expect_identical(md_code(c("POV_HC", "")), c("`POV_HC`", ""))
  expect_identical(md_codes("CAP OU R"), "`CAP` `OU` `R`")
})
