#!/usr/bin/env Rscript
# pipeline/bootstrap/build_geo_codelists.R
#
# WP05 - Geography. One-time bootstrap script (frozen after metadata 0.1.0,
# decision D11): writes metadata/codelists/CL_GEO_SCHEME.csv and
# metadata/codelists/CL_GEO.csv from pipeline/bootstrap/text/geo_schemes_text.csv
# and the seed pipeline/bootstrap/seeds/geo_codes.csv, reading `valid_from`
# for ADM0/ADM1 units from the legacy shapefiles.
#
#   Rscript pipeline/bootstrap/build_geo_codelists.R --root . --out-root .
#
# Run from the repo root. Reads data_raw/shp/{sen,gnb}_admin{0,1}.shp and
# pipeline/bootstrap/seeds/geo_codes.csv under --root. Writes both
# codelists under --out-root, at the same relative paths.

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

## ---- CL_GEO_SCHEME --------------------------------------------------------

text <- read_std_csv(file.path(root, "pipeline", "bootstrap", "text", "geo_schemes_text.csv"))

scheme <- text
scheme$status <- "DRAFT"
scheme$version_added <- "0.1.0"
scheme$replaced_by <- ""
scheme$has_geometry <- ifelse(scheme$code %in% c("ADM0", "ADM1"), "Y", "N")
scheme$nests_in <- ""
scheme$partition <- "Y"

scheme_cols <- c(
  "code", "name_en", "definition_en", "status", "version_added",
  "replaced_by", "notes", "ref_area", "local_name_en", "has_geometry",
  "nests_in", "partition"
)
scheme <- scheme[, scheme_cols]

write_std_csv(scheme, file.path(out_root, "metadata", "codelists", "CL_GEO_SCHEME.csv"))

## ---- CL_GEO ----------------------------------------------------------------

seed <- read_std_csv(file.path(root, "pipeline", "bootstrap", "seeds", "geo_codes.csv"))

shp_path <- function(ref_area, level) {
  iso2 <- if (ref_area == "SEN") "sen" else "gnb"
  file.path(root, "data_raw", "shp", paste0(iso2, "_admin", substr(level, 4, 4), ".shp"))
}

# valid_from for ADM0/ADM1 is the boundary vintage (valid_on), read once per
# country x level - every unit in a layer shares the same valid_on.
valid_on_of <- function(ref_area, level) {
  layer <- read_admin_layer(shp_path(ref_area, level), level)
  v <- unique(layer$valid_on)
  if (length(v) != 1) {
    stop("build_geo_codelists: ", ref_area, " ", level,
         " does not carry one uniform valid_on value", call. = FALSE)
  }
  format(v, "%Y-%m-%d")
}

valid_from_cache <- list(
  SEN_ADM0 = valid_on_of("SEN", "adm0"),
  SEN_ADM1 = valid_on_of("SEN", "adm1"),
  GNB_ADM0 = valid_on_of("GNB", "adm0"),
  GNB_ADM1 = valid_on_of("GNB", "adm1")
)

has_source <- nzchar(seed$source_id)

geo <- seed
geo$definition_en <- ifelse(
  has_source,
  paste0(seed$scheme, " unit of ", seed$ref_area, " in boundary source ", seed$source_id),
  paste0(seed$scheme, " unit of ", seed$ref_area, ", as used in the legacy tables")
)
geo$status <- "DRAFT"
geo$version_added <- "0.1.0"
geo$replaced_by <- ""
geo$parent <- ""
geo$valid_to <- ""
geo$valid_from <- vapply(seq_len(nrow(seed)), function(i) {
  if (seed$scheme[i] %in% c("ADM0", "ADM1")) {
    valid_from_cache[[paste0(seed$ref_area[i], "_", seed$scheme[i])]]
  } else {
    TBD
  }
}, character(1))

geo_cols <- c(
  "code", "name_en", "definition_en", "status", "version_added",
  "replaced_by", "notes", "ref_area", "scheme", "parent", "source_id",
  "geom_layer", "valid_from", "valid_to"
)
geo <- geo[, geo_cols]

write_std_csv(geo, file.path(out_root, "metadata", "codelists", "CL_GEO.csv"))

cat(
  "build_geo_codelists: wrote", nrow(scheme), "CL_GEO_SCHEME rows and",
  nrow(geo), "CL_GEO rows\n"
)
