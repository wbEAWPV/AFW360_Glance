# pipeline/R/validate_assets.R
#
# Checks for the two asset registries (GEO_SOURCES, FIGURES) and the
# GeoPackage boundary files they point at (.docs/data-standard.qmd).
#
# Every check function is named vc_asset_<check>(ctx) and returns a tibble
# with columns check_id, severity, file, row_key, message (zero rows means
# pass). `ctx` is the list built by build_ctx() in pipeline/R/ctx.R.
#
# Depends on pipeline/R/io.R (sha256_file()) and pipeline/R/ctx.R
# (build_ctx()) having already been sourced by the caller, and on the sf
# and dplyr packages.

# ---- private helpers ---------------------------------------------------

#' Build one finding row.
.af_finding <- function(check_id, severity, file, row_key, message) {
  dplyr::tibble(
    check_id = check_id, severity = severity, file = file,
    row_key = row_key, message = message
  )
}

#' A zero-row findings tibble with the right columns.
.af_empty <- function() {
  dplyr::tibble(
    check_id = character(0), severity = character(0), file = character(0),
    row_key = character(0), message = character(0)
  )
}

#' Combine a list of single-row findings tibbles (possibly empty).
.af_bind <- function(rows) {
  if (length(rows) == 0) {
    return(.af_empty())
  }
  dplyr::bind_rows(rows)
}

#' Cap findings at 20 per file, in row_key order, adding a SUMMARY row
#' (see .docs/data-standard.qmd).
.af_cap <- function(df) {
  if (nrow(df) == 0) {
    return(df)
  }
  capped <- lapply(split(df, df$file), function(sub) {
    sub <- sub[order(sub$row_key, method = "radix"), , drop = FALSE]
    if (nrow(sub) > 20) {
      kept <- sub[seq_len(20), , drop = FALSE]
      summary_row <- .af_finding(
        sub$check_id[1], sub$severity[1], sub$file[1], "",
        sprintf("SUMMARY: %d findings in total, 20 shown", nrow(sub))
      )
      dplyr::bind_rows(kept, summary_row)
    } else {
      sub
    }
  })
  out <- dplyr::bind_rows(capped)
  out[order(out$file, out$row_key, method = "radix"), , drop = FALSE]
}

#' Whether a registered file exists and matches its registered sha256.
#'
#' @param root Repo root.
#' @param sub_dir Registry's base directory, relative to root
#'   ("geo/boundaries" or "assets/figures").
#' @param file The registry row's `file` value.
#' @param sha256 The registry row's `sha256` value.
.af_file_status <- function(root, sub_dir, file, sha256) {
  rel <- paste0(sub_dir, "/", file)
  full <- file.path(root, sub_dir, file)
  exists <- file.exists(full)
  hash_ok <- exists && identical(sha256_file(full), sha256)
  list(rel = rel, full = full, exists = exists, hash_ok = hash_ok, ok = exists && hash_ok)
}

#' Read every layer of every GEO_SOURCES row whose file exists and whose
#' sha256 matches the registry (a mismatch or a missing file is already
#' covered by ASSET.FILE_MISSING / ASSET.SHA256, so it is skipped here to
#' avoid a second, unrelated finding on the same broken file).
#'
#' @return A list of entries, each `list(source_id, file_rel, layer, sf, epsg)`.
.af_read_layers <- function(ctx) {
  root <- ctx$root
  gs <- ctx$meta$GEO_SOURCES
  sf::sf_use_s2(FALSE)

  out <- list()
  for (i in seq_len(nrow(gs))) {
    st <- .af_file_status(root, "geo/boundaries", gs$file[i], gs$sha256[i])
    if (!st$ok) {
      next
    }
    actual_layers <- tryCatch(sf::st_layers(st$full)$name, error = function(e) character(0))
    expected_layers <- strsplit(gs$layers[i], " ", fixed = TRUE)[[1]]
    for (ly in intersect(expected_layers, actual_layers)) {
      lyr <- tryCatch(sf::st_read(st$full, layer = ly, quiet = TRUE), error = function(e) NULL)
      if (is.null(lyr)) {
        next
      }
      epsg <- sf::st_crs(lyr)$epsg
      out[[length(out) + 1]] <- list(
        source_id = gs$source_id[i], file_rel = st$rel, layer = ly, sf = lyr,
        epsg = if (is.null(epsg) || is.na(epsg)) NA_character_ else as.character(epsg)
      )
    }
  }
  out
}

# ---- checks --------------------------------------------------------------

#' ASSET.FILE_MISSING: a GEO_SOURCES or FIGURES row points at a file that
#' does not exist.
vc_asset_file_missing <- function(ctx) {
  root <- ctx$root
  rows <- list()

  gs <- ctx$meta$GEO_SOURCES
  for (i in seq_len(nrow(gs))) {
    st <- .af_file_status(root, "geo/boundaries", gs$file[i], gs$sha256[i])
    if (!st$exists) {
      rows[[length(rows) + 1]] <- .af_finding(
        "ASSET.FILE_MISSING", "ERROR", st$rel, paste0("source_id=", gs$source_id[i]),
        sprintf("GEO_SOURCES file does not exist: %s", st$rel)
      )
    }
  }

  fg <- ctx$meta$FIGURES
  for (i in seq_len(nrow(fg))) {
    st <- .af_file_status(root, "assets/figures", fg$file[i], fg$sha256[i])
    if (!st$exists) {
      rows[[length(rows) + 1]] <- .af_finding(
        "ASSET.FILE_MISSING", "ERROR", st$rel, paste0("figure_id=", fg$figure_id[i]),
        sprintf("FIGURES file does not exist: %s", st$rel)
      )
    }
  }

  .af_cap(.af_bind(rows))
}

#' ASSET.SHA256: the file's sha256 differs from the registry's.
vc_asset_sha256 <- function(ctx) {
  root <- ctx$root
  rows <- list()

  gs <- ctx$meta$GEO_SOURCES
  for (i in seq_len(nrow(gs))) {
    st <- .af_file_status(root, "geo/boundaries", gs$file[i], gs$sha256[i])
    if (!st$exists) {
      next # ASSET.FILE_MISSING already covers this
    }
    if (!st$hash_ok) {
      rows[[length(rows) + 1]] <- .af_finding(
        "ASSET.SHA256", "ERROR", st$rel, paste0("source_id=", gs$source_id[i]),
        sprintf("sha256 %s does not match registry value %s", sha256_file(st$full), gs$sha256[i])
      )
    }
  }

  fg <- ctx$meta$FIGURES
  for (i in seq_len(nrow(fg))) {
    st <- .af_file_status(root, "assets/figures", fg$file[i], fg$sha256[i])
    if (!st$exists) {
      next
    }
    if (!st$hash_ok) {
      rows[[length(rows) + 1]] <- .af_finding(
        "ASSET.SHA256", "ERROR", st$rel, paste0("figure_id=", fg$figure_id[i]),
        sprintf("sha256 %s does not match registry value %s", sha256_file(st$full), fg$sha256[i])
      )
    }
  }

  .af_cap(.af_bind(rows))
}

#' ASSET.LAYERS: the GeoPackage's layers differ from the row's layers field.
vc_asset_layers <- function(ctx) {
  root <- ctx$root
  rows <- list()

  gs <- ctx$meta$GEO_SOURCES
  for (i in seq_len(nrow(gs))) {
    st <- .af_file_status(root, "geo/boundaries", gs$file[i], gs$sha256[i])
    if (!st$ok) {
      next # ASSET.FILE_MISSING / ASSET.SHA256 already cover this
    }
    expected <- sort(strsplit(gs$layers[i], " ", fixed = TRUE)[[1]], method = "radix")
    actual <- sort(tryCatch(sf::st_layers(st$full)$name, error = function(e) character(0)), method = "radix")
    if (!identical(expected, actual)) {
      rows[[length(rows) + 1]] <- .af_finding(
        "ASSET.LAYERS", "ERROR", st$rel, paste0("source_id=", gs$source_id[i]),
        sprintf(
          "Expected layers [%s], found [%s]",
          paste(expected, collapse = " "), paste(actual, collapse = " ")
        )
      )
    }
  }

  .af_cap(.af_bind(rows))
}

#' ASSET.CRS: a layer is not EPSG:4326.
vc_asset_crs <- function(ctx) {
  layers <- .af_read_layers(ctx)
  rows <- list()

  for (entry in layers) {
    if (is.na(entry$epsg) || !identical(entry$epsg, "4326")) {
      rows[[length(rows) + 1]] <- .af_finding(
        "ASSET.CRS", "ERROR", entry$file_rel, paste0("layer=", entry$layer),
        sprintf(
          "Layer '%s' has CRS %s, expected EPSG:4326", entry$layer,
          if (is.na(entry$epsg)) "unknown" else paste0("EPSG:", entry$epsg)
        )
      )
    }
  }

  .af_cap(.af_bind(rows))
}

#' ASSET.GEO_CODE: a feature's geo_code is not in CL_GEO with the same
#' ref_area and scheme.
vc_asset_geo_code <- function(ctx) {
  layers <- .af_read_layers(ctx)
  cl_geo <- ctx$meta$CL_GEO
  rows <- list()

  for (entry in layers) {
    dd <- sf::st_drop_geometry(entry$sf)
    if (nrow(dd) == 0) {
      next
    }
    for (i in seq_len(nrow(dd))) {
      hit <- cl_geo$code == dd$geo_code[i] &
        cl_geo$ref_area == dd$ref_area[i] &
        cl_geo$scheme == dd$scheme[i]
      if (!any(hit)) {
        rows[[length(rows) + 1]] <- .af_finding(
          "ASSET.GEO_CODE", "ERROR", entry$file_rel,
          paste0("layer=", entry$layer, " geo_code=", dd$geo_code[i]),
          sprintf(
            "geo_code '%s' (ref_area=%s scheme=%s) is not in CL_GEO",
            dd$geo_code[i], dd$ref_area[i], dd$scheme[i]
          )
        )
      }
    }
  }

  .af_cap(.af_bind(rows))
}

#' ASSET.MISSING_GEOMETRY: a CL_GEO code of a scheme with has_geometry = Y
#' has no feature in its source_id file and geom_layer.
vc_asset_missing_geometry <- function(ctx) {
  root <- ctx$root
  cl_geo <- ctx$meta$CL_GEO
  scheme <- ctx$meta$CL_GEO_SCHEME
  gs <- ctx$meta$GEO_SOURCES
  sf::sf_use_s2(FALSE)
  rows <- list()

  key <- paste(cl_geo$ref_area, cl_geo$scheme)
  skey <- paste(scheme$ref_area, scheme$code)
  has_geom <- scheme$has_geometry[match(key, skey)]

  need <- cl_geo[
    !is.na(has_geom) & has_geom == "Y" &
      nzchar(cl_geo$source_id) & nzchar(cl_geo$geom_layer),
    ,
    drop = FALSE
  ]
  if (nrow(need) == 0) {
    return(.af_empty())
  }

  combos <- unique(need[, c("source_id", "geom_layer")])
  for (j in seq_len(nrow(combos))) {
    sid <- combos$source_id[j]
    gly <- combos$geom_layer[j]

    gsi <- which(gs$source_id == sid)
    if (length(gsi) == 0) {
      next # CL_GEO references an unknown source_id: not this check's rule
    }
    gsi <- gsi[1]
    st <- .af_file_status(root, "geo/boundaries", gs$file[gsi], gs$sha256[gsi])
    if (!st$ok) {
      next # ASSET.FILE_MISSING / ASSET.SHA256 already cover this
    }

    lyr <- tryCatch(sf::st_read(st$full, layer = gly, quiet = TRUE), error = function(e) NULL)
    present <- if (is.null(lyr)) character(0) else sf::st_drop_geometry(lyr)$geo_code

    sub <- need[need$source_id == sid & need$geom_layer == gly, , drop = FALSE]
    for (i in seq_len(nrow(sub))) {
      if (!(sub$code[i] %in% present)) {
        rows[[length(rows) + 1]] <- .af_finding(
          "ASSET.MISSING_GEOMETRY", "ERROR", st$rel, paste0("code=", sub$code[i]),
          sprintf("CL_GEO code '%s' has no feature in %s layer '%s'", sub$code[i], st$rel, gly)
        )
      }
    }
  }

  .af_cap(.af_bind(rows))
}

#' ASSET.DUPLICATE_FEATURE: two features share one geo_code in a layer.
vc_asset_duplicate_feature <- function(ctx) {
  layers <- .af_read_layers(ctx)
  rows <- list()

  for (entry in layers) {
    dd <- sf::st_drop_geometry(entry$sf)
    if (nrow(dd) == 0) {
      next
    }
    dup_codes <- unique(dd$geo_code[duplicated(dd$geo_code)])
    for (code in dup_codes) {
      n <- sum(dd$geo_code == code)
      rows[[length(rows) + 1]] <- .af_finding(
        "ASSET.DUPLICATE_FEATURE", "ERROR", entry$file_rel,
        paste0("layer=", entry$layer, " geo_code=", code),
        sprintf("geo_code '%s' appears %d times in layer '%s'", code, n, entry$layer)
      )
    }
  }

  .af_cap(.af_bind(rows))
}

#' ASSET.INVALID_GEOMETRY: a geometry is not valid (GEOS validity).
vc_asset_invalid_geometry <- function(ctx) {
  layers <- .af_read_layers(ctx)
  rows <- list()

  for (entry in layers) {
    dd <- sf::st_drop_geometry(entry$sf)
    if (nrow(dd) == 0) {
      next
    }
    valid <- sf::st_is_valid(entry$sf)
    reasons <- sf::st_is_valid(entry$sf, reason = TRUE)
    bad <- which(!valid | is.na(valid))
    for (i in bad) {
      rows[[length(rows) + 1]] <- .af_finding(
        "ASSET.INVALID_GEOMETRY", "ERROR", entry$file_rel,
        paste0("layer=", entry$layer, " geo_code=", dd$geo_code[i]),
        sprintf("Invalid geometry for geo_code '%s': %s", dd$geo_code[i], reasons[i])
      )
    }
  }

  .af_cap(.af_bind(rows))
}

#' ASSET.NAME_MISMATCH: a feature's name differs from CL_GEO.name_en.
vc_asset_name_mismatch <- function(ctx) {
  layers <- .af_read_layers(ctx)
  cl_geo <- ctx$meta$CL_GEO
  rows <- list()

  for (entry in layers) {
    dd <- sf::st_drop_geometry(entry$sf)
    if (nrow(dd) == 0) {
      next
    }
    for (i in seq_len(nrow(dd))) {
      hit <- which(
        cl_geo$code == dd$geo_code[i] &
          cl_geo$ref_area == dd$ref_area[i] &
          cl_geo$scheme == dd$scheme[i]
      )
      if (length(hit) == 0) {
        next # ASSET.GEO_CODE already covers an unknown code
      }
      expected_name <- cl_geo$name_en[hit[1]]
      if (!identical(dd$name[i], expected_name)) {
        rows[[length(rows) + 1]] <- .af_finding(
          "ASSET.NAME_MISMATCH", "WARN", entry$file_rel,
          paste0("layer=", entry$layer, " geo_code=", dd$geo_code[i]),
          sprintf("Feature name '%s' differs from CL_GEO.name_en '%s'", dd$name[i], expected_name)
        )
      }
    }
  }

  .af_cap(.af_bind(rows))
}
