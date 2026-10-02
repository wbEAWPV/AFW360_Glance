# pipeline/tests/testthat/test-migrate-0.2.0.R
#
# Runs pipeline/migrations/0.2.0/migrate.R on the frozen 0.1.0 fixture
# (fixtures/metadata-0.1.0/, a copy of the 0.1.0 metadata taken before the
# migration ran on the repository) with --out-root, and checks the 0.2.0
# result against SPEC section 2.

root <- find_root()
fixture <- file.path(root, "pipeline", "tests", "testthat", "fixtures", "metadata-0.1.0")
script <- file.path(root, "pipeline", "migrations", "0.2.0", "migrate.R")
rscript <- file.path(R.home("bin"), "Rscript")

run_migration <- function(in_root, out_root) {
  out <- suppressWarnings(system2(
    rscript,
    c(shQuote(script), "--root", shQuote(in_root), "--out-root", shQuote(out_root)),
    stdout = TRUE, stderr = TRUE
  ))
  status <- attr(out, "status")
  list(status = if (is.null(status)) 0L else status, output = out)
}

out_root <- tempfile("afw360_migrate_")
dir.create(out_root)
res <- run_migration(fixture, out_root)

fx <- function(...) read_std_csv(file.path(fixture, "metadata", ...))
new <- function(...) read_std_csv(file.path(out_root, "metadata", ...))

test_that("the migration runs cleanly on the 0.1.0 fixture", {
  expect_equal(res$status, 0L, info = paste(res$output, collapse = "\n"))
})

test_that("VERSION is 0.2.0 and CHANGELOG has a 0.2.0 entry listing D12-D26", {
  expect_equal(readLines(file.path(out_root, "metadata", "VERSION")), "0.2.0")
  cl <- readLines(file.path(out_root, "metadata", "CHANGELOG.md"), encoding = "UTF-8")
  expect_true(any(grepl("^## 0\\.2\\.0", cl)))
  for (d in 12:26) expect_true(any(grepl(paste0("^- D", d, ":"), cl)), info = paste0("D", d))
})

test_that("the DSD has the 31 columns of SPEC section 1, in order", {
  dsd <- new("structure", "DSD_AFW360_HH.csv")
  expected <- c(
    "DATAFLOW", "REF_AREA", "GEO", "TIME_PERIOD", "ESTIMATION", "INDICATOR", "SEX", "AGE",
    "URBANISATION", paste0("COMP_BREAKDOWN_", 1:5), paste0("MEASURE_QUAL_", 1:5),
    "SERIES_ID", "OBS_VALUE", "UNIT_MEASURE", "PRECISION", "OBS_STATUS", "STD_ERR",
    "CI_LOWER", "CI_UPPER", "N_OBS", "N_POP", "SOURCE_ID", "OBS_COMMENT"
  )
  expect_equal(nrow(dsd), 31L)
  expect_equal(dsd$id, expected)
  expect_equal(dsd$position, as.character(1:31))
  expect_equal(dsd$role[dsd$id == "ESTIMATION"], "reference")
  expect_equal(dsd$codelist[dsd$id == "ESTIMATION"], "CL_ESTIMATION")
  expect_equal(dsd$required[dsd$id %in% c("N_OBS", "N_POP")], c("C", "C"))
})

test_that("CL_INDICATOR lacks checks and qualifiers; CL_QUALIFIER lacks valid_with", {
  expect_false(any(c("checks", "qualifiers") %in% names(new("codelists", "CL_INDICATOR.csv"))))
  expect_false("valid_with" %in% names(new("codelists", "CL_QUALIFIER.csv")))
  # Every other column is carried over unchanged.
  old <- fx("codelists", "CL_INDICATOR.csv")
  ind <- new("codelists", "CL_INDICATOR.csv")
  expect_equal(as.data.frame(old[names(ind)]), as.data.frame(ind))
})

test_that("RULES has one row per checks token (minus NONE, EQUALS_NPOP_RATIO) plus 2", {
  old <- fx("codelists", "CL_INDICATOR.csv")
  tokens <- unlist(strsplit(trimws(old$checks), "[[:space:]]+"))
  tokens <- tokens[nzchar(tokens) & !(tokens %in% c("NONE", "EQUALS_NPOP_RATIO"))]
  rules <- new("rules", "RULES.csv")
  expect_equal(nrow(rules), length(tokens) + 2L)
  expect_equal(rules$rule_id[1:2], c("AFW360_HH.RELIABILITY_MIN_NOBS", "AFW360_HH.RELIABILITY_MAX_CV"))
  expect_equal(rules$scope[1:2], c("DATAFLOW", "DATAFLOW"))
  expect_equal(rules$param[1:2], c("30", "0.3"))
  expect_true(all(rules$scope[-(1:2)] == "INDICATOR"))
  expect_false(anyDuplicated(rules$rule_id) > 0)
  mono <- rules[rules$scope_code == "POV_HC" & rules$rule == "MONOTONE_IN", ]
  expect_equal(mono$param, "POVLINE")
  expect_equal(mono$rule_id, "POV_HC.MONOTONE_IN.POVLINE")
})

test_that("INDICATOR_QUALIFIERS reproduces every fixture qualifiers field", {
  old <- fx("codelists", "CL_INDICATOR.csv")
  iq <- new("structure", "INDICATOR_QUALIFIERS.csv")
  for (i in seq_len(nrow(old))) {
    rows <- iq[iq$indicator == old$code[i], , drop = FALSE]
    rebuilt <- if (nrow(rows) == 0) {
      "_Z"
    } else {
      paste(paste0(rows$qual_var, ":", gsub(" ", ",", rows$allowed, fixed = TRUE)), collapse = " ")
    }
    expect_equal(rebuilt, trimws(old$qualifiers[i]), info = old$code[i])
  }
})

test_that("QUALIFIER_PAIRS has the 8 POVLINE rows paired with PPP", {
  qp <- new("structure", "QUALIFIER_PAIRS.csv")
  expect_equal(nrow(qp), 8L)
  expect_true(all(startsWith(qp$qualifier, "POVLINE_")))
  expect_true(all(qp$with_var == "PPP"))
  expect_equal(qp$allowed[qp$qualifier == "POVLINE_NPL"], "_Z")
  expect_equal(qp$allowed[qp$qualifier == "POVLINE_PL300"], "PPP_2021")
})

test_that("SERIES_PLAN has a non-empty name_en and estimation SURVEY on every row", {
  sp <- new("plans", "SERIES_PLAN.csv")
  old <- fx("plans", "SERIES_PLAN.csv")
  expect_equal(nrow(sp), nrow(old))
  expect_equal(sp$series_id, old$series_id)
  expect_true(all(nzchar(sp$name_en)))
  expect_true(all(sp$estimation == "SURVEY"))
})

test_that("SOURCES has 2 rows whose inputs_sha256 equal CHECKSUMS.sha256", {
  src <- new("registries", "SOURCES.csv")
  expect_equal(nrow(src), 2L)
  expect_equal(src$source_id, c("SEN_EHCVM2021_LEGACY_v1", "GNB_EHCVM2021_LEGACY_v1"))
  lines <- readLines(file.path(fixture, "data_raw", "CHECKSUMS.sha256"))
  sums <- stats::setNames(sub("^(\\S+)\\s+.*$", "\\1", lines), sub("^\\S+\\s+", "", lines))
  expect_equal(src$inputs_sha256, unname(sums[src$inputs]))
})

test_that("every written CSV's header matches its COLUMNS.csv rows in order", {
  cols <- new("structure", "COLUMNS.csv")
  files <- list.files(file.path(out_root, "metadata"), pattern = "\\.csv$",
                      recursive = TRUE, full.names = TRUE)
  expect_length(files, 11L)
  for (f in files) {
    reg <- cols[cols$file == basename(f), , drop = FALSE]
    expect_equal(names(read_std_csv(f)), reg$column, info = basename(f))
    expect_equal(reg$position, as.character(seq_len(nrow(reg))), info = basename(f))
  }
})

test_that("the migration is deterministic", {
  again <- tempfile("afw360_migrate_")
  dir.create(again)
  on.exit(unlink(again, recursive = TRUE))
  expect_equal(run_migration(fixture, again)$status, 0L)
  a <- sort(list.files(file.path(out_root, "metadata"), recursive = TRUE))
  b <- sort(list.files(file.path(again, "metadata"), recursive = TRUE))
  expect_equal(a, b)
  for (f in a) {
    expect_identical(
      readBin(file.path(out_root, "metadata", f), "raw", 1e7),
      readBin(file.path(again, "metadata", f), "raw", 1e7),
      info = f
    )
  }
})

test_that("the guard refuses to run on metadata that is not 0.1.0", {
  refused <- tempfile("afw360_migrate_")
  dir.create(refused)
  on.exit(unlink(refused, recursive = TRUE))
  r <- run_migration(out_root, refused)
  expect_equal(r$status, 1L)
  expect_true(any(grepl("not 0.1.0", r$output)))
  expect_length(list.files(refused, recursive = TRUE), 0L)
})
