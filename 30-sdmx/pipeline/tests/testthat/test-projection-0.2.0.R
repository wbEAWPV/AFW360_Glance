# pipeline/tests/testthat/test-projection-0.2.0.R
#
# WP3b - Old-layout projection. Every published data file (SDMX-CSV 2.1,
# 37 columns, DSD 0.3.0) is projected onto the 31 columns of DSD 0.2.0 and
# compared cell by cell with the same file at commit a32096c (the last
# 0.2.0 data). Values are compared as numbers where both cells parse as
# numbers and as strings otherwise. The only differences allowed are:
#   - the 0.2.0 column DATAFLOW, which the new layout drops;
#   - OBS_VALUE "NaN" (new) versus "" (old) on rows whose OBS_STATUS is O.
# The columns the new layout adds must carry no information the old files
# lacked: the three fixed columns are constant, FREQ is A, and the three
# new measures are empty.

.proj_commit <- "a32096c"

# The 31 DSD 0.2.0 columns, in order.
.proj_old_cols <- c(
  "DATAFLOW", "REF_AREA", "GEO", "TIME_PERIOD", "ESTIMATION", "INDICATOR",
  "SEX", "AGE", "URBANISATION", paste0("COMP_BREAKDOWN_", 1:5),
  paste0("MEASURE_QUAL_", 1:5),
  "SERIES_ID", "OBS_VALUE", "UNIT_MEASURE", "PRECISION", "OBS_STATUS",
  "STD_ERR", "CI_LOWER", "CI_UPPER", "N_OBS", "N_POP", "SOURCE_ID", "OBS_COMMENT"
)
# The 0.2.0 row key without DATAFLOW (18 columns), used to align rows.
.proj_key <- .proj_old_cols[2:19]

.proj_read <- function(path) {
  readr::read_csv(
    path,
    col_types = readr::cols(.default = readr::col_character()),
    na = character(0), trim_ws = FALSE, progress = FALSE,
    show_col_types = FALSE
  )
}

#' Read data/<file> as it was at .proj_commit, through a temp file.
.proj_read_old <- function(root, file) {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)
  status <- system2(
    "git", c("-C", shQuote(root), "show", paste0(.proj_commit, ":data/", file)),
    stdout = tmp, stderr = FALSE
  )
  if (!identical(as.integer(status), 0L)) {
    stop("git show ", .proj_commit, ":data/", file, " failed (status ", status, ")",
         call. = FALSE)
  }
  .proj_read(tmp)
}

#' Cell-wise equality: numeric where both parse as numbers, else string.
.proj_same <- function(a, b) {
  na <- suppressWarnings(as.numeric(a))
  nb <- suppressWarnings(as.numeric(b))
  num <- !is.na(na) & !is.na(nb)
  out <- a == b
  out[num] <- abs(na[num] - nb[num]) <= 1e-12 * pmax(1, abs(nb[num]))
  out
}

test_that("each data file projects onto its 0.2.0 version with only the allowed differences", {
  if (!nzchar(Sys.which("git"))) skip("git is not available")
  root <- find_root()

  files <- basename(Sys.glob(file.path(root, "data", "AFW360_HH_*_SURVEY.csv")))
  expect_gt(length(files), 0)

  for (f in files) {
    new <- .proj_read(file.path(root, "data", f))
    old <- .proj_read_old(root, f)

    # Old layout is exactly the 31 columns; the new one drops only DATAFLOW.
    expect_equal(names(old), .proj_old_cols, info = f)
    expect_true(all(setdiff(.proj_old_cols, "DATAFLOW") %in% names(new)), info = f)
    expect_equal(nrow(new), nrow(old), info = f)

    # New-only columns carry nothing the old file lacked.
    expect_true(all(new$STRUCTURE == "dataflow"), info = f)
    expect_equal(length(unique(new$STRUCTURE_ID)), 1L, info = f)
    expect_true(all(new$ACTION == "R"), info = f)
    expect_true(all(new$FREQ == "A"), info = f)
    for (m in c("N_OBS_NUM", "DEFF", "DF")) {
      expect_true(all(new[[m]] == ""), info = paste(f, m))
    }

    # Project onto the 0.2.0 columns (DATAFLOW taken from the old file:
    # the dropped column is the one allowed difference) and align rows on
    # the 0.2.0 key.
    proj <- new
    proj$DATAFLOW <- old$DATAFLOW[1]
    proj <- as.data.frame(proj[.proj_old_cols], stringsAsFactors = FALSE)
    old <- as.data.frame(old, stringsAsFactors = FALSE)
    key_new <- do.call(paste, c(proj[.proj_key], sep = "|"))
    key_old <- do.call(paste, c(old[.proj_key], sep = "|"))
    expect_false(anyDuplicated(key_new) > 0, info = f)
    expect_false(anyDuplicated(key_old) > 0, info = f)
    idx <- match(key_old, key_new)
    expect_false(anyNA(idx), info = paste(f, "rows of the 0.2.0 file missing"))
    if (anyNA(idx)) next
    proj <- proj[idx, , drop = FALSE]

    # The one allowed value difference: NaN (new) vs empty (old) on O rows.
    o_rows <- old$OBS_STATUS == "O"
    nan_ok <- o_rows & proj$OBS_VALUE == "NaN" & old$OBS_VALUE == ""
    expect_true(all(nan_ok[o_rows]), info = paste(f, "O rows must be NaN vs empty"))
    expect_true(all(proj$OBS_VALUE[!o_rows] != "NaN"), info = f)

    n_diff <- 0L
    for (col in setdiff(.proj_old_cols, "DATAFLOW")) {
      same <- .proj_same(proj[[col]], old[[col]])
      if (col == "OBS_VALUE") same <- same | nan_ok
      bad <- which(!same)
      n_diff <- n_diff + length(bad)
      expect_equal(
        length(bad), 0L,
        info = if (length(bad) > 0) {
          paste0(f, " ", col, " row ", bad[1], ": new '", proj[[col]][bad[1]],
                 "' vs old '", old[[col]][bad[1]], "'")
        } else {
          paste(f, col)
        }
      )
    }
    expect_equal(n_diff, 0L, info = f)
  }
})
