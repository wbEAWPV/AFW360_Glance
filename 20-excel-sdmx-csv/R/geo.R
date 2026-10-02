# pipeline/R/geo.R
#
# Shared geometry helpers for WP05 (Geography). Turns the legacy COD-AB
# admin boundary shapefiles (data_raw/shp/{sen,gnb}_admin{0,1}.shp) into
# the standard boundary layers used by pipeline/build_geo.R and
# pipeline/bootstrap/build_geo_codelists.R.
#
# GEOS, not S2, is this pipeline's validity engine (.docs/data-standard.qmd): SN01 is
# invalid only under S2, and SN13 is invalid under GEOS as delivered but
# fixed by st_make_valid(). Sourcing this file switches S2 off so every
# script that uses these helpers reads and builds under GEOS.
sf::sf_use_s2(FALSE)

#' Read one legacy admin boundary layer.
#'
#' Reads `path` and keeps the fields the pipeline needs, normalized to
#' generic names: the pcode as `geo_code`, the name as `name`, plus
#' `valid_on` and `version` (read from the `version` field in the SEN
#' layers or `cod_versio` in the GNB layers). No validity fix or CRS
#' assignment is done here; see [make_boundary_layer()].
#'
#' @param path Path to a `.shp` file.
#' @param level `"adm0"` or `"adm1"`; picks the `<level>_pcode` and
#'   `<level>_name` fields.
#' @return An `sf` object with columns `geo_code`, `name`, `valid_on`,
#'   `version` and the geometry, in the shapefile's original row order.
read_admin_layer <- function(path, level) {
  if (!level %in% c("adm0", "adm1")) {
    stop("read_admin_layer: level must be 'adm0' or 'adm1', got: ", level, call. = FALSE)
  }
  x <- sf::st_read(path, quiet = TRUE)

  pcode_col <- paste0(level, "_pcode")
  name_col <- paste0(level, "_name")
  version_col <- if ("version" %in% names(x)) {
    "version"
  } else if ("cod_versio" %in% names(x)) {
    "cod_versio"
  } else {
    stop("read_admin_layer: no version field ('version' or 'cod_versio') in ", path, call. = FALSE)
  }
  for (col in c(pcode_col, name_col, "valid_on", version_col)) {
    if (!col %in% names(x)) {
      stop("read_admin_layer: missing field '", col, "' in ", path, call. = FALSE)
    }
  }

  x$geo_code <- as.character(x[[pcode_col]])
  x$name <- as.character(x[[name_col]])
  x$version <- as.character(x[[version_col]])
  x[, c("geo_code", "name", "valid_on", "version")]
}

#' Build a standard boundary layer.
#'
#' Sets `ref_area` and `scheme`, assigns EPSG:4326 (the `.prj` files
#' declare WGS 84 without an EPSG code, so this only assigns the code; it
#' never reprojects), and makes every geometry valid with
#' [sf::st_make_valid()] under GEOS (`sf::sf_use_s2(FALSE)`, set when this
#' file is sourced). Keeps only `geo_code`, `ref_area`, `scheme`, `name`
#' and the geometry, sorted by `geo_code` for a deterministic layer order.
#'
#' @param sf_obj An `sf` object from [read_admin_layer()].
#' @param ref_area Country code, e.g. `"SEN"`.
#' @param scheme `CL_GEO_SCHEME` code for this layer, e.g. `"ADM0"` or
#'   `"ADM1"`.
#' @return An `sf` object with columns `geo_code`, `ref_area`, `scheme`,
#'   `name` and the geometry.
make_boundary_layer <- function(sf_obj, ref_area, scheme) {
  x <- sf_obj
  x$ref_area <- ref_area
  x$scheme <- scheme
  sf::st_crs(x) <- 4326
  x <- sf::st_make_valid(x)
  x <- x[, c("geo_code", "ref_area", "scheme", "name")]
  x[order(x$geo_code), ]
}
