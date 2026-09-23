#!/usr/bin/env Rscript
# pipeline/build_geo.R
#
# WP05 - Geography. Builds the two GeoPackages (layers `adm0`, `adm1`) from
# the legacy COD-AB shapefiles, and metadata/registries/GEO_SOURCES.csv.
#
#   Rscript pipeline/build_geo.R --root . --out-root .
#
# Run from the repo root. Reads data_raw/shp/{sen,gnb}_admin{0,1}.shp under
# --root. Writes geo/boundaries/<source_id>.gpkg and
# metadata/registries/GEO_SOURCES.csv under --out-root, at the same
# relative paths, replacing any existing GeoPackage of the same name.

.args <- commandArgs(trailingOnly = TRUE)
.root_idx <- which(.args == "--root")
root <- normalizePath(
  if (length(.root_idx) == 1) .args[.root_idx + 1] else ".",
  winslash = "/", mustWork = TRUE
)

source(file.path(root, "pipeline", "R", "io.R"))
source(file.path(root, "pipeline", "R", "constants.R"))
source(file.path(root, "pipeline", "R", "geo.R"))

out_root <- cli_arg(.args, "--out-root", root)
dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
out_root <- normalizePath(out_root, winslash = "/", mustWork = TRUE)

countries <- list(
  list(
    ref_area = "SEN", source_id = "SEN_CODAB_v02",
    adm0_shp = file.path(root, "data_raw", "shp", "sen_admin0.shp"),
    adm1_shp = file.path(root, "data_raw", "shp", "sen_admin1.shp")
  ),
  list(
    ref_area = "GNB", source_id = "GNB_CODAB_V01",
    adm0_shp = file.path(root, "data_raw", "shp", "gnb_admin0.shp"),
    adm1_shp = file.path(root, "data_raw", "shp", "gnb_admin1.shp")
  )
)

sources <- vector("list", length(countries))

for (i in seq_along(countries)) {
  ctry <- countries[[i]]

  raw_adm0 <- read_admin_layer(ctry$adm0_shp, "adm0")
  raw_adm1 <- read_admin_layer(ctry$adm1_shp, "adm1")

  adm0 <- make_boundary_layer(raw_adm0, ctry$ref_area, "ADM0")
  adm1 <- make_boundary_layer(raw_adm1, ctry$ref_area, "ADM1")

  gpkg_path <- file.path(out_root, "geo", "boundaries", paste0(ctry$source_id, ".gpkg"))
  dir.create(dirname(gpkg_path), recursive = TRUE, showWarnings = FALSE)
  if (file.exists(gpkg_path)) unlink(gpkg_path)

  sf::st_write(adm0, gpkg_path, layer = "adm0", quiet = TRUE)
  sf::st_write(adm1, gpkg_path, layer = "adm1", quiet = TRUE)

  version <- unique(raw_adm1$version)
  valid_on <- unique(raw_adm1$valid_on)
  if (length(version) != 1 || length(valid_on) != 1) {
    stop(
      "build_geo: ", ctry$ref_area,
      " adm1 layer does not carry one uniform version/valid_on", call. = FALSE
    )
  }

  # sha256 is computed after the build that is committed (COMMON.md /
  # WP05.md): a GeoPackage's bytes change on every build, so the hash is
  # taken from the file just written, not fixed in advance.
  sources[[i]] <- data.frame(
    source_id = ctry$source_id,
    ref_area = ctry$ref_area,
    provider = "OCHA COD-AB",
    version = version,
    valid_on = format(valid_on, "%Y-%m-%d"),
    url = "",
    download_date = "",
    licence = TBD,
    attribution = TBD,
    crs = "EPSG:4326",
    file = paste0(ctry$source_id, ".gpkg"),
    layers = "adm0 adm1",
    sha256 = sha256_file(gpkg_path),
    status = "DRAFT",
    version_added = "0.1.0",
    notes = "",
    stringsAsFactors = FALSE
  )
}

geo_sources <- do.call(rbind, sources)

geo_sources_cols <- c(
  "source_id", "ref_area", "provider", "version", "valid_on", "url",
  "download_date", "licence", "attribution", "crs", "file", "layers",
  "sha256", "status", "version_added", "notes"
)
geo_sources <- geo_sources[, geo_sources_cols]

write_std_csv(geo_sources, file.path(out_root, "metadata", "registries", "GEO_SOURCES.csv"))

cat(
  "build_geo: wrote", nrow(geo_sources), "GEO_SOURCES rows and",
  length(countries), "GeoPackages\n"
)
