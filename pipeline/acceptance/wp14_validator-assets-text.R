#!/usr/bin/env Rscript
# Acceptance script for WP14 -- Validator: assets and text.
#
#   Rscript pipeline/acceptance/wp14_validator-assets-text.R --root .
#
# Standalone: sources pipeline/R/io.R, ctx.R, validate_assets.R and
# validate_text.R because the checks below are about those functions
# (vc_asset_<check>(ctx) / vc_text_<check>(ctx), per WP14.md's Interface).
# Writes only to tempdir(). Compares against files on disk, never against
# transition/main.

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
try_check <- function(id, expr) {
  r <- tryCatch(expr, error = function(e) check(id, FALSE, paste("error:", conditionMessage(e))))
  invisible(r)
}

## ---- 2. Helpers ---------------------------------------------------------------
suppressPackageStartupMessages({
  library(sf)
})
sf::sf_use_s2(FALSE)

# All columns as character, BOM stripped, "" stays "" (never NA). Same shape
# as the template's read_csv_char(), used only for reading small registries
# and codelists that the checks below reason about directly (not through
# the pipeline's own I/O layer).
read_csv_char <- function(path) {
  raw <- readLines(path, encoding = "UTF-8", warn = FALSE)
  if (length(raw)) raw[1] <- sub("^﻿", "", raw[1])
  read.csv(text = paste(raw, collapse = "\n"), colClasses = "character", na.strings = NULL,
           check.names = FALSE, encoding = "UTF-8")
}

# Source the modules under test. The checks in this script are about these
# functions, so sourcing pipeline/R/ is required (COMMON.md / the card's
# acceptance-script rules allow it for exactly this reason).
.src_ok <- TRUE
.src_err <- ""
tryCatch({
  source(file.path(root, "pipeline", "R", "io.R"))
  source(file.path(root, "pipeline", "R", "ctx.R"))
  source(file.path(root, "pipeline", "R", "validate_assets.R"))
  source(file.path(root, "pipeline", "R", "validate_text.R"))
}, error = function(e) {
  .src_ok <<- FALSE
  .src_err <<- conditionMessage(e)
})

# Copy metadata/content/geo/assets (WP14's inputs; no data/ needed -- data
# checks are out of scope) into a fresh temp root. Mirrors the shape of
# pipeline/tests/testthat/helper-temp-root.R's make_temp_root(), reimplemented
# here so this script stays standalone (it must not depend on a testthat
# helper to build its own fixtures).
copy_subset <- function(src_root, include = c("metadata", "content", "geo", "assets")) {
  tmp <- tempfile(pattern = "wp14_root_")
  dir.create(tmp, recursive = TRUE)
  for (nm in include) {
    src <- file.path(src_root, nm)
    if (dir.exists(src)) file.copy(src, tmp, recursive = TRUE)
  }
  tmp
}

# Recompute and write back a GeoPackage's sha256 into the temp copy's
# GEO_SOURCES.csv, so a geometry-only mutation does not also trip
# ASSET.SHA256 (WP14.md step 2 and the Verifier focus).
update_geo_sha <- function(tmp_root, filename) {
  reg_path <- file.path(tmp_root, "metadata", "registries", "GEO_SOURCES.csv")
  df <- read_std_csv(reg_path)
  idx <- which(df$file == filename)
  df$sha256[idx] <- sha256_file(file.path(tmp_root, "geo", "boundaries", filename))
  write_std_csv(df, reg_path)
}

# Run every vc_asset_<check>()/vc_text_<check>() found in the global env
# (per the card's Interface: "Your functions are named vc_asset_<check>(ctx)
# and vc_text_<check>(ctx)") against a ctx built from tmp_root, and rbind
# their findings tibbles. This is this script's own harness -- WP14 does not
# own pipeline/validate.R (WP11) and this script does not write one.
run_all_checks <- function(tmp_root) {
  ctx <- build_ctx(tmp_root, data_files = character(0), opts = list())
  fn_names <- ls(envir = .GlobalEnv)
  fn_names <- fn_names[grepl("^vc_(asset|text)_", fn_names)]
  fn_names <- fn_names[vapply(fn_names, function(n) is.function(get(n, envir = .GlobalEnv)), logical(1))]
  cols <- c("check_id", "severity", "file", "row_key", "message")
  if (length(fn_names) == 0) {
    return(as.data.frame(setNames(replicate(5, character(0), simplify = FALSE), cols)))
  }
  out <- lapply(fn_names, function(n) {
    r <- get(n, envir = .GlobalEnv)(ctx)
    r <- as.data.frame(r, stringsAsFactors = FALSE)
    if (!all(cols %in% names(r))) {
      stop(sprintf("%s() did not return columns %s", n, paste(cols, collapse = ", ")))
    }
    if (nrow(r) == 0) return(NULL)
    r[, cols]
  })
  out <- out[!vapply(out, is.null, logical(1))]
  if (length(out) == 0) return(as.data.frame(setNames(replicate(5, character(0), simplify = FALSE), cols)))
  do.call(rbind, out)
}

err_ids <- function(res) sort(unique(res$check_id[res$severity == "ERROR"]))

## ---- 3. Mutations (WP14.md step 2 / WP14.A2) ----------------------------------
m_geopkg_byte <- function() {
  tmp <- copy_subset(root)
  gpkg <- file.path(tmp, "geo", "boundaries", "SEN_CODAB_v02.gpkg")
  con <- file(gpkg, "ab")
  writeBin(as.raw(0L), con)
  close(con)
  tmp
}
m_geo_code <- function() {
  tmp <- copy_subset(root)
  gpkg <- file.path(tmp, "geo", "boundaries", "SEN_CODAB_v02.gpkg")
  lyr <- sf::st_read(gpkg, layer = "adm1", quiet = TRUE)
  lyr$geo_code[1] <- "SN99"
  sf::st_write(lyr, gpkg, layer = "adm1", delete_layer = TRUE, quiet = TRUE)
  update_geo_sha(tmp, "SEN_CODAB_v02.gpkg")
  tmp
}
m_missing_geom <- function() {
  tmp <- copy_subset(root)
  gpkg <- file.path(tmp, "geo", "boundaries", "SEN_CODAB_v02.gpkg")
  lyr <- sf::st_read(gpkg, layer = "adm1", quiet = TRUE)
  lyr <- lyr[-1, ]
  sf::st_write(lyr, gpkg, layer = "adm1", delete_layer = TRUE, quiet = TRUE)
  update_geo_sha(tmp, "SEN_CODAB_v02.gpkg")
  tmp
}
m_dup_feature <- function() {
  tmp <- copy_subset(root)
  gpkg <- file.path(tmp, "geo", "boundaries", "SEN_CODAB_v02.gpkg")
  lyr <- sf::st_read(gpkg, layer = "adm1", quiet = TRUE)
  lyr <- rbind(lyr, lyr[1, ])
  sf::st_write(lyr, gpkg, layer = "adm1", delete_layer = TRUE, quiet = TRUE)
  update_geo_sha(tmp, "SEN_CODAB_v02.gpkg")
  tmp
}
m_bowtie <- function() {
  tmp <- copy_subset(root)
  gpkg <- file.path(tmp, "geo", "boundaries", "SEN_CODAB_v02.gpkg")
  lyr <- sf::st_read(gpkg, layer = "adm1", quiet = TRUE)
  bowtie <- sf::st_polygon(list(rbind(c(0, 0), c(1, 1), c(1, 0), c(0, 1), c(0, 0))))
  # The layer's geometry column is sfc_MULTIPOLYGON; st_write() to GPKG
  # rejects a column with a mixed POLYGON/MULTIPOLYGON type ("Not a
  # matrix."), so cast the bow-tie to match the column's type. Casting
  # does not repair the self-intersection -- it stays invalid.
  bowtie <- sf::st_cast(sf::st_sfc(bowtie, crs = sf::st_crs(lyr)), "MULTIPOLYGON")[[1]]
  g <- sf::st_geometry(lyr)
  g[[1]] <- bowtie
  sf::st_geometry(lyr) <- g
  sf::st_write(lyr, gpkg, layer = "adm1", delete_layer = TRUE, quiet = TRUE)
  update_geo_sha(tmp, "SEN_CODAB_v02.gpkg")
  tmp
}
m_figure_missing <- function() {
  tmp <- copy_subset(root)
  unlink(file.path(tmp, "assets", "figures", "SEN", "SEN_FISCAL_EQUITY.png"))
  tmp
}
m_text_both <- function() {
  tmp <- copy_subset(root)
  path <- file.path(tmp, "content", "TEXT.csv")
  df <- read_std_csv(path)
  idx <- which(df$slot == "about" & df$ref_area == "SEN")
  df$body[idx] <- "Test body text for the WP14 acceptance mutation."
  write_std_csv(df, path)
  tmp
}
m_text_file_missing <- function() {
  tmp <- copy_subset(root)
  unlink(file.path(tmp, "content", "text", "SEN", "about.md"))
  tmp
}
m_text_html <- function() {
  tmp <- copy_subset(root)
  path <- file.path(tmp, "content", "TEXT.csv")
  df <- read_std_csv(path)
  idx <- which(df$slot == "messages" & df$ref_area == "SEN" & df$order == "1")
  df$body[idx] <- paste0(df$body[idx], " <b>x</b>")
  write_std_csv(df, path)
  tmp
}

mutations <- list(
  list(id = "ASSET.SHA256", fn = m_geopkg_byte, exclusive = TRUE),
  list(id = "ASSET.GEO_CODE", fn = m_geo_code, exclusive = FALSE),
  list(id = "ASSET.MISSING_GEOMETRY", fn = m_missing_geom, exclusive = FALSE),
  list(id = "ASSET.DUPLICATE_FEATURE", fn = m_dup_feature, exclusive = FALSE),
  list(id = "ASSET.INVALID_GEOMETRY", fn = m_bowtie, exclusive = FALSE),
  list(id = "ASSET.FILE_MISSING", fn = m_figure_missing, exclusive = FALSE),
  list(id = "TEXT.BODY_FILE", fn = m_text_both, exclusive = FALSE),
  list(id = "TEXT.FILE_MISSING", fn = m_text_file_missing, exclusive = FALSE),
  list(id = "TEXT.HTML", fn = m_text_html, exclusive = FALSE)
)

## ---- 4. Checks ------------------------------------------------------------------

if (!.src_ok) {
  check("WP14.A1", FALSE, paste("could not source validate_assets.R/validate_text.R:", .src_err))
  check("WP14.A2", FALSE, "skipped: sourcing failed")
  check("WP14.A3", FALSE, "skipped: sourcing failed")
  check("WP14.A4", FALSE, "skipped: sourcing failed")
} else {

  # WP14.A1: on the unmodified temporary copy, 0 ERROR.
  try_check("WP14.A1", {
    tmp1 <- copy_subset(root)
    res1 <- run_all_checks(tmp1)
    e1 <- err_ids(res1)
    check("WP14.A1", length(e1) == 0,
          sprintf("%d ERROR finding(s) on unmodified temp copy: %s", nrow(res1[res1$severity == "ERROR", ]), paste(e1, collapse = ", ")))
  })

  # WP14.A2: each mutation gives (at least) exactly its check_id; the
  # checksum-only mutation gives ONLY ASSET.SHA256 (Verifier focus).
  try_check("WP14.A2", {
    mut_results <- lapply(mutations, function(m) {
      tryCatch({
        tmp <- m$fn()
        res <- run_all_checks(tmp)
        e <- err_ids(res)
        ok <- if (isTRUE(m$exclusive)) identical(e, m$id) else (m$id %in% e)
        list(id = m$id, ok = ok, actual = paste(e, collapse = "|"))
      }, error = function(err) list(id = m$id, ok = FALSE, actual = paste("error:", conditionMessage(err))))
    })
    a2_ok <- all(vapply(mut_results, `[[`, logical(1), "ok"))
    a2_evi <- paste(sprintf("%s->[%s]%s", vapply(mut_results, `[[`, character(1), "id"),
                             vapply(mut_results, `[[`, character(1), "actual"),
                             ifelse(vapply(mut_results, `[[`, logical(1), "ok"), "", "(FAIL)")),
                     collapse = "; ")
    check("WP14.A2", a2_ok, a2_evi)
  })

  # WP14.A3: on the real repository root, 0 ERROR, or every ERROR is listed
  # in the implementer's report as an asset defect (file + rule). Rows with
  # body == "TBD" give WARN TEXT.TBD.
  try_check("WP14.A3", {
    res_real <- run_all_checks(root)
    err_real <- res_real[res_real$severity == "ERROR", , drop = FALSE]
    report_path <- file.path(root, ".docs", "transition", "reports", "WP14-implementer.md")
    if (nrow(err_real) == 0) {
      a3a_ok <- TRUE
      a3a_evi <- "0 ERROR findings on real root"
    } else if (file.exists(report_path)) {
      report_txt <- paste(readLines(report_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
      listed <- vapply(seq_len(nrow(err_real)), function(k) {
        cid <- err_real$check_id[k]; f <- err_real$file[k]
        grepl(cid, report_txt, fixed = TRUE) && (identical(f, "") || grepl(f, report_txt, fixed = TRUE))
      }, logical(1))
      a3a_ok <- all(listed)
      a3a_evi <- sprintf("%d ERROR finding(s) on real root; all listed with file+rule in WP14-implementer.md = %s",
                          nrow(err_real), a3a_ok)
    } else {
      a3a_ok <- FALSE
      a3a_evi <- sprintf("%d ERROR finding(s) on real root but %s not found", nrow(err_real), report_path)
    }

    text_csv <- read_csv_char(file.path(root, "content", "TEXT.csv"))
    tbd_rows <- text_csv[text_csv$body == "TBD", , drop = FALSE]
    warn_tbd <- res_real[res_real$severity == "WARN" & res_real$check_id == "TEXT.TBD", , drop = FALSE]
    a3b_ok <- nrow(tbd_rows) > 0 && nrow(warn_tbd) == nrow(tbd_rows)
    a3b_evi <- sprintf("%d body=TBD row(s) in TEXT.csv, %d WARN TEXT.TBD finding(s)", nrow(tbd_rows), nrow(warn_tbd))

    check("WP14.A3", a3a_ok && a3b_ok, paste(a3a_evi, "; ", a3b_evi))
  })

  # WP14.A4: a scheme with has_geometry = N produces no finding (referencing
  # one of its CL_GEO codes).
  try_check("WP14.A4", {
    res_real2 <- run_all_checks(root)
    cl_scheme <- read_csv_char(file.path(root, "metadata", "codelists", "CL_GEO_SCHEME.csv"))
    cl_geo <- read_csv_char(file.path(root, "metadata", "codelists", "CL_GEO.csv"))
    no_geom <- cl_scheme[cl_scheme$has_geometry == "N", c("ref_area", "code")]
    key_scheme <- paste(cl_geo$ref_area, cl_geo$scheme)
    key_no_geom <- paste(no_geom$ref_area, no_geom$code)
    no_geom_codes <- unique(cl_geo$code[key_scheme %in% key_no_geom])
    hit <- res_real2[vapply(res_real2$row_key, function(rk) {
      any(vapply(no_geom_codes, function(cd) grepl(paste0("geo_code=", cd, "(\\s|$)"), rk), logical(1)))
    }, logical(1)), , drop = FALSE]
    check("WP14.A4", nrow(hit) == 0,
          sprintf("%d finding(s) reference a has_geometry=N code (checked %d code(s)); e.g. %s",
                  nrow(hit), length(no_geom_codes),
                  if (nrow(hit) > 0) paste(head(hit$check_id, 3), collapse = ",") else "none"))
  })
}

# WP14.A5: the unit tests pass. Runs regardless of .src_ok, since test_file()
# sources everything it needs itself.
try_check("WP14.A5", {
  suppressPackageStartupMessages(library(testthat))
  test_path <- file.path(root, "pipeline", "tests", "testthat", "test-validate-assets-text.R")
  if (!file.exists(test_path)) {
    check("WP14.A5", FALSE, sprintf("test file not found: %s", test_path))
  } else {
    old_env <- Sys.getenv("TESTTHAT_PROBLEMS", unset = NA)
    Sys.setenv(TESTTHAT_PROBLEMS = "false")
    old_wd <- getwd()
    setwd(root)
    res_t <- tryCatch(
      testthat::test_file(test_path, reporter = "check"),
      error = function(e) e
    )
    setwd(old_wd)
    if (is.na(old_env)) Sys.unsetenv("TESTTHAT_PROBLEMS") else Sys.setenv(TESTTHAT_PROBLEMS = old_env)
    if (inherits(res_t, "error")) {
      check("WP14.A5", FALSE, paste("error running tests:", conditionMessage(res_t)))
    } else {
      d <- as.data.frame(res_t)
      n_fail <- sum(d$failed)
      n_err <- sum(vapply(d$error, function(x) isTRUE(x) || (is.numeric(x) && x > 0), logical(1)))
      check("WP14.A5", n_fail == 0 && n_err == 0,
            sprintf("%d test(s), %d failed, %d errored", sum(d$nb), n_fail, n_err))
    }
  }
})

## ---- 5. Exit ----------------------------------------------------------------------
cat(if (length(.failures)) sprintf("\n%d check(s) failed: %s\n", length(.failures), paste(.failures, collapse = ", ")) else "\nAll checks passed.\n")
quit(status = if (length(.failures)) 1L else 0L, save = "no")
