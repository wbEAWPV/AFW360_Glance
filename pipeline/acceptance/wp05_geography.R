#!/usr/bin/env Rscript
# Acceptance script for WP05 -- Geography.
#
#   Rscript pipeline/acceptance/wp05_geography.R --root .
#
# Standalone: does not source pipeline/R/. Expected numbers come from
# contract/expected_counts.csv by check_id. Writes only to tempdir().

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
  library(digest)
})

read_csv_char <- function(path) {
  raw <- readLines(path, encoding = "UTF-8", warn = FALSE)
  if (length(raw)) raw[1] <- sub("^﻿", "", raw[1])
  read.csv(text = paste(raw, collapse = "\n"), colClasses = "character", na.strings = NULL,
           check.names = FALSE, encoding = "UTF-8")
}
expected <- function(check_id) {
  tab <- read_csv_char(file.path(contract, "expected_counts.csv"))
  row <- tab[tab$check_id == check_id, ]
  if (nrow(row) != 1) stop("no unique row in expected_counts.csv for ", check_id)
  list(value = as.numeric(row$expected), tol = as.numeric(row$tolerance))
}
meets <- function(actual, check_id) { e <- expected(check_id); abs(actual - e$value) <= e$tol + 1e-9 }
header_of <- function(file) {
  h <- read_csv_char(file.path(contract, "csv_headers.csv")); h <- h[h$file == file, ]
  h$column[order(as.integer(h$position))]
}
req_cols_of <- function(file) {
  h <- read_csv_char(file.path(contract, "csv_headers.csv")); h <- h[h$file == file, ]
  h$column[h$status == "R"]
}
run_script <- function(script, script_args) {
  log <- tempfile(fileext = ".log")
  status <- system2("Rscript", c(shQuote(file.path(root, script)), script_args), stdout = log, stderr = log)
  list(status = status, log = log)
}
same_file <- function(a, b) file.exists(a) && file.exists(b) && identical(unname(tools::md5sum(a)), unname(tools::md5sum(b)))
sha256_file <- function(path) digest::digest(file = path, algo = "sha256")

suppressWarnings(sf::sf_use_s2(FALSE))

## ---- 3. Fixtures ---------------------------------------------------------------
geo_codes <- read_csv_char(file.path(contract, "geo_codes.csv"))

cl_scheme_path <- file.path(root, "metadata", "codelists", "CL_GEO_SCHEME.csv")
cl_geo_path <- file.path(root, "metadata", "codelists", "CL_GEO.csv")
geo_sources_path <- file.path(root, "metadata", "registries", "GEO_SOURCES.csv")

gpkg_paths <- c(
  SEN = file.path(root, "geo", "boundaries", "SEN_CODAB_v02.gpkg"),
  GNB = file.path(root, "geo", "boundaries", "GNB_CODAB_V01.gpkg")
)

shp_paths <- list(
  SEN = list(adm0 = file.path(root, "data_raw", "shp", "sen_admin0.shp"),
             adm1 = file.path(root, "data_raw", "shp", "sen_admin1.shp")),
  GNB = list(adm0 = file.path(root, "data_raw", "shp", "gnb_admin0.shp"),
             adm1 = file.path(root, "data_raw", "shp", "gnb_admin1.shp"))
)
pcode_col <- list(adm0 = "adm0_pcode", adm1 = "adm1_pcode")
layer_scheme <- list(adm0 = "ADM0", adm1 = "ADM1")

## ---- 4. Checks ------------------------------------------------------------------

# WP05.A1: each GeoPackage has exactly layers adm0/adm1, with the feature
# counts from GEOM.* in expected_counts.csv.
try_check("WP05.A1", {
  ok_all <- TRUE
  ev <- character(0)
  for (ref in names(gpkg_paths)) {
    p <- gpkg_paths[[ref]]
    if (!file.exists(p)) { ok_all <- FALSE; ev <- c(ev, sprintf("%s missing", p)); next }
    lyr_names <- sf::st_layers(p)$name
    has_layers <- setequal(lyr_names, c("adm0", "adm1")) && length(lyr_names) == 2
    n_adm0 <- if ("adm0" %in% lyr_names) nrow(sf::st_read(p, layer = "adm0", quiet = TRUE)) else NA_integer_
    n_adm1 <- if ("adm1" %in% lyr_names) nrow(sf::st_read(p, layer = "adm1", quiet = TRUE)) else NA_integer_
    ok0 <- !is.na(n_adm0) && meets(n_adm0, sprintf("GEOM.%s.ADM0", ref))
    ok1 <- !is.na(n_adm1) && meets(n_adm1, sprintf("GEOM.%s.ADM1", ref))
    ok_all <- ok_all && has_layers && ok0 && ok1
    ev <- c(ev, sprintf("%s: layers=%s adm0=%s adm1=%s", ref, paste(sort(lyr_names), collapse = ","), n_adm0, n_adm1))
  }
  check("WP05.A1", ok_all, paste(ev, collapse = "; "))
})

# WP05.A2: per country and layer, geo_code set equals CL_GEO codes of that
# scheme, one feature per code, every feature carries the right ref_area/scheme.
try_check("WP05.A2", {
  cl_geo <- read_csv_char(cl_geo_path)
  ok_all <- TRUE
  ev <- character(0)
  for (ref in names(gpkg_paths)) {
    p <- gpkg_paths[[ref]]
    for (lyr in c("adm0", "adm1")) {
      scheme <- layer_scheme[[lyr]]
      expected_codes <- sort(cl_geo$code[cl_geo$ref_area == ref & cl_geo$scheme == scheme])
      feat <- sf::st_drop_geometry(sf::st_read(p, layer = lyr, quiet = TRUE))
      has_cols <- all(c("geo_code", "ref_area", "scheme") %in% names(feat))
      if (!has_cols) { ok_all <- FALSE; ev <- c(ev, sprintf("%s/%s: missing geo_code/ref_area/scheme column", ref, lyr)); next }
      actual_codes <- sort(feat$geo_code)
      codes_match <- identical(actual_codes, expected_codes) && !anyDuplicated(feat$geo_code)
      ref_match <- all(feat$ref_area == ref)
      scheme_match <- all(feat$scheme == scheme)
      ok_all <- ok_all && codes_match && ref_match && scheme_match
      ev <- c(ev, sprintf("%s/%s: n=%d codes_match=%s ref_match=%s scheme_match=%s", ref, lyr, nrow(feat), codes_match, ref_match, scheme_match))
    }
  }
  check("WP05.A2", ok_all, paste(ev, collapse = "; "))
})

# WP05.A3: every layer is EPSG:4326 and every geometry valid under GEOS.
try_check("WP05.A3", {
  ok_all <- TRUE
  ev <- character(0)
  for (ref in names(gpkg_paths)) {
    p <- gpkg_paths[[ref]]
    for (lyr in c("adm0", "adm1")) {
      feat <- sf::st_read(p, layer = lyr, quiet = TRUE)
      epsg <- suppressWarnings(sf::st_crs(feat)$epsg)
      crs_ok <- !is.null(epsg) && !is.na(epsg) && epsg == 4326
      valid_ok <- all(sf::st_is_valid(feat))
      ok_all <- ok_all && crs_ok && valid_ok
      ev <- c(ev, sprintf("%s/%s: epsg=%s all_valid=%s", ref, lyr, epsg, valid_ok))
    }
  }
  check("WP05.A3", ok_all, paste(ev, collapse = "; "))
})

# WP05.A4: CL_GEO 35 rows match geo_codes.csv on the listed columns; CL_GEO_SCHEME
# has the 6 rows with has_geometry/partition/nests_in by the rule.
try_check("WP05.A4", {
  cols <- c("code", "ref_area", "scheme", "name_en", "source_id", "geom_layer")
  cl_geo <- read_csv_char(cl_geo_path)
  n_ok <- nrow(cl_geo) == 35 && nrow(geo_codes) == 35
  cols_match <- n_ok && all(vapply(cols, function(cn) identical(cl_geo[[cn]], geo_codes[[cn]]), logical(1)))
  ev <- sprintf("CL_GEO: rows=%d (expected 35) cols_match=%s", nrow(cl_geo), cols_match)

  cl_scheme <- read_csv_char(cl_scheme_path)
  expected_schemes <- data.frame(
    ref_area = c("SEN", "SEN", "SEN", "GNB", "GNB", "GNB"),
    code = c("ADM0", "ADM1", "ZONES", "ADM0", "ADM1", "AEZ"),
    has_geometry = c("Y", "Y", "N", "Y", "Y", "N"),
    stringsAsFactors = FALSE
  )
  scheme_n_ok <- nrow(cl_scheme) == 6
  scheme_ok <- scheme_n_ok
  if (scheme_n_ok) {
    for (k in seq_len(nrow(expected_schemes))) {
      row <- cl_scheme[cl_scheme$ref_area == expected_schemes$ref_area[k] & cl_scheme$code == expected_schemes$code[k], ]
      ok_row <- nrow(row) == 1 &&
        identical(row$has_geometry[1], expected_schemes$has_geometry[k]) &&
        identical(trimws(row$nests_in[1]), "") &&
        identical(row$partition[1], "Y")
      scheme_ok <- scheme_ok && ok_row
      if (!ok_row) ev <- c(ev, sprintf("scheme %s/%s not matching rule", expected_schemes$ref_area[k], expected_schemes$code[k]))
    }
  }
  ev <- c(ev, sprintf("CL_GEO_SCHEME: rows=%d (expected 6) rule_ok=%s", nrow(cl_scheme), scheme_ok))
  check("WP05.A4", cols_match && scheme_ok, paste(ev, collapse = "; "))
})

# WP05.A5: GEO_SOURCES has 2 rows, each sha256 equals the committed file's sha256.
try_check("WP05.A5", {
  gs <- read_csv_char(geo_sources_path)
  n_ok <- nrow(gs) == 2
  ok_all <- n_ok
  ev <- character(0)
  if (n_ok) {
    for (k in seq_len(nrow(gs))) {
      p <- file.path(root, "geo", "boundaries", gs$file[k])
      actual_sha <- if (file.exists(p)) sha256_file(p) else NA_character_
      match_ok <- !is.na(actual_sha) && identical(tolower(actual_sha), tolower(gs$sha256[k]))
      ok_all <- ok_all && match_ok
      ev <- c(ev, sprintf("%s: recorded=%s actual=%s match=%s", gs$source_id[k], gs$sha256[k], actual_sha, match_ok))
    }
  } else {
    ev <- c(ev, sprintf("GEO_SOURCES rows=%d (expected 2)", nrow(gs)))
  }
  check("WP05.A5", ok_all, paste(ev, collapse = "; "))
})

# WP05.A6: headers equal csv_headers.csv; every R column filled; TBD appears
# only in valid_from (CL_GEO), licence and attribution (GEO_SOURCES).
try_check("WP05.A6", {
  files <- list(
    "CL_GEO_SCHEME.csv" = cl_scheme_path,
    "CL_GEO.csv" = cl_geo_path,
    "GEO_SOURCES.csv" = geo_sources_path
  )
  allowed_tbd <- list(
    "CL_GEO_SCHEME.csv" = character(0),
    "CL_GEO.csv" = c("valid_from"),
    "GEO_SOURCES.csv" = c("licence", "attribution")
  )
  ok_all <- TRUE
  ev <- character(0)
  for (fn in names(files)) {
    df <- read_csv_char(files[[fn]])
    hdr <- header_of(fn)
    header_ok <- identical(names(df), hdr)
    req_cols <- req_cols_of(fn)
    req_filled <- all(vapply(req_cols, function(cn) cn %in% names(df) && all(trimws(df[[cn]]) != ""), logical(1)))
    bad_tbd_cols <- character(0)
    for (cn in names(df)) {
      if (any(df[[cn]] == "TBD") && !(cn %in% allowed_tbd[[fn]])) bad_tbd_cols <- c(bad_tbd_cols, cn)
    }
    tbd_ok <- length(bad_tbd_cols) == 0
    ok_all <- ok_all && header_ok && req_filled && tbd_ok
    ev <- c(ev, sprintf("%s: header_ok=%s req_filled=%s tbd_ok=%s%s", fn, header_ok, req_filled, tbd_ok,
                         if (length(bad_tbd_cols)) paste0(" bad_tbd_cols=", paste(bad_tbd_cols, collapse = ",")) else ""))
  }
  check("WP05.A6", ok_all, paste(ev, collapse = "; "))
})

# WP05.A7: rebuilding into a tempdir reproduces the codelists byte for byte,
# and reproduces the gpkg layers/geo_code/counts, with st_equals_exact at 1e-9.
try_check("WP05.A7", {
  ev <- character(0)

  tmp1 <- file.path(tempdir(), paste0("wp05_codelists_", as.integer(Sys.time())))
  dir.create(tmp1, recursive = TRUE)
  res1 <- run_script("pipeline/bootstrap/build_geo_codelists.R", c("--root", shQuote(root), "--out-root", shQuote(tmp1)))
  codelist_ok <- res1$status == 0
  if (!codelist_ok) {
    ev <- c(ev, sprintf("build_geo_codelists.R exit=%s log=%s", res1$status, paste(readLines(res1$log, warn = FALSE), collapse = " | ")))
  } else {
    same_scheme <- same_file(file.path(tmp1, "metadata", "codelists", "CL_GEO_SCHEME.csv"), cl_scheme_path)
    same_geo <- same_file(file.path(tmp1, "metadata", "codelists", "CL_GEO.csv"), cl_geo_path)
    codelist_ok <- same_scheme && same_geo
    ev <- c(ev, sprintf("codelists byte-identical: scheme=%s geo=%s", same_scheme, same_geo))
  }

  tmp2 <- file.path(tempdir(), paste0("wp05_geo_", as.integer(Sys.time())))
  dir.create(tmp2, recursive = TRUE)
  res2 <- run_script("pipeline/build_geo.R", c("--root", shQuote(root), "--out-root", shQuote(tmp2)))
  geo_ok <- res2$status == 0
  if (!geo_ok) {
    ev <- c(ev, sprintf("build_geo.R exit=%s log=%s", res2$status, paste(readLines(res2$log, warn = FALSE), collapse = " | ")))
  } else {
    for (ref in names(gpkg_paths)) {
      fname <- basename(gpkg_paths[[ref]])
      p_rebuilt <- file.path(tmp2, "geo", "boundaries", fname)
      if (!file.exists(p_rebuilt)) { geo_ok <- FALSE; ev <- c(ev, sprintf("%s: rebuilt gpkg missing", ref)); next }
      layers_rebuilt <- sort(sf::st_layers(p_rebuilt)$name)
      layers_committed <- sort(sf::st_layers(gpkg_paths[[ref]])$name)
      layers_ok <- identical(layers_rebuilt, layers_committed)
      for (lyr in c("adm0", "adm1")) {
        f_new <- sf::st_read(p_rebuilt, layer = lyr, quiet = TRUE)
        f_old <- sf::st_read(gpkg_paths[[ref]], layer = lyr, quiet = TRUE)
        count_ok <- nrow(f_new) == nrow(f_old)
        codes_ok <- count_ok && identical(sort(f_new$geo_code), sort(f_old$geo_code))
        geom_ok <- FALSE
        if (codes_ok) {
          f_new_o <- f_new[order(f_new$geo_code), ]
          f_old_o <- f_old[order(f_old$geo_code), ]
          per_feature <- vapply(seq_len(nrow(f_new_o)), function(k) {
            m <- sf::st_equals_exact(sf::st_geometry(f_new_o)[k], sf::st_geometry(f_old_o)[k], par = 1e-9, sparse = FALSE)
            isTRUE(m[1, 1])
          }, logical(1))
          geom_ok <- all(per_feature)
        }
        layer_ok <- layers_ok && count_ok && codes_ok && geom_ok
        geo_ok <- geo_ok && layer_ok
        ev <- c(ev, sprintf("%s/%s: layers_ok=%s count_ok=%s codes_ok=%s geom_ok=%s", ref, lyr, layers_ok, count_ok, codes_ok, geom_ok))
      }
    }
  }
  check("WP05.A7", codelist_ok && geo_ok, paste(ev, collapse = "; "))
})

# WP05.A8: for every unit, the gpkg polygon area is within 0.1% of the area of
# the source shapefile polygon after st_make_valid.
try_check("WP05.A8", {
  ok_all <- TRUE
  ev <- character(0)
  max_pct <- 0
  for (ref in names(gpkg_paths)) {
    for (lyr in c("adm0", "adm1")) {
      src <- sf::st_make_valid(sf::st_read(shp_paths[[ref]][[lyr]], quiet = TRUE))
      src_df <- sf::st_drop_geometry(src)
      built <- sf::st_read(gpkg_paths[[ref]], layer = lyr, quiet = TRUE)
      for (k in seq_len(nrow(src))) {
        code <- src_df[[pcode_col[[lyr]]]][k]
        src_area <- as.numeric(sf::st_area(sf::st_geometry(src)[k]))
        built_row <- built[built$geo_code == code, ]
        if (nrow(built_row) != 1) { ok_all <- FALSE; ev <- c(ev, sprintf("%s (%s/%s): not found once in built layer (n=%d)", code, ref, lyr, nrow(built_row))); next }
        built_area <- as.numeric(sf::st_area(sf::st_geometry(built_row)))
        pct <- if (src_area == 0) NA else abs(built_area - src_area) / src_area * 100
        if (is.na(pct) || pct > 0.1) { ok_all <- FALSE; ev <- c(ev, sprintf("%s (%s/%s): area diff %.4f%%", code, ref, lyr, pct)) }
        max_pct <- max(max_pct, pct, na.rm = TRUE)
      }
    }
  }
  if (ok_all) ev <- c(ev, sprintf("all 25 units within tolerance; max diff = %.6f%%", max_pct))
  check("WP05.A8", ok_all, paste(ev, collapse = "; "))
})

## ---- 5. Exit ----------------------------------------------------------------------
cat(if (length(.failures)) sprintf("\n%d check(s) failed: %s\n", length(.failures), paste(.failures, collapse = ", ")) else "\nAll checks passed.\n")
quit(status = if (length(.failures)) 1L else 0L, save = "no")
