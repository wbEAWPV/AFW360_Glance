# 20-excel-sdmx-csv/R/publish.R
#
# The publish step: compares the output folder of this stage (`output/`, or
# any `--out-root`) with the destinations its folders are copied to
# (PUBLISH_MAP in R/paths.R) and copies what differs. Only the files the
# builders wrote are considered; nothing at a destination is ever deleted,
# and nothing is ever written under the legacy inputs.
#
# A GeoPackage's bytes change on every build (SQLite page layout,
# timestamps), so GeoPackages are compared by content: the same layers,
# each with the same CRS, attributes and geometries (as WKB). A GeoPackage
# whose content is unchanged is not copied, and its row of GEO_SOURCES.csv
# keeps the published sha256 (the hash of the file that stays), so an
# unchanged rebuild publishes nothing.
#
# Depends on io.R (read_std_csv(), write_std_csv()) and paths.R.

#' Whether two GeoPackages hold the same content.
#'
#' @param a,b Paths to GeoPackages.
#' @return `TRUE` when both have the same layer names and, per layer, the
#'   same CRS, attribute table and geometries (WKB), else `FALSE`.
gpkg_same_content <- function(a, b) {
  if (!file.exists(a) || !file.exists(b)) return(FALSE)
  la <- sort(sf::st_layers(a)$name, method = "radix")
  lb <- sort(sf::st_layers(b)$name, method = "radix")
  if (!identical(la, lb)) return(FALSE)
  for (l in la) {
    da <- sf::st_read(a, layer = l, quiet = TRUE)
    db <- sf::st_read(b, layer = l, quiet = TRUE)
    if (!identical(sf::st_crs(da)$wkt, sf::st_crs(db)$wkt)) return(FALSE)
    ga <- unclass(sf::st_as_binary(sf::st_geometry(da)))
    gb <- unclass(sf::st_as_binary(sf::st_geometry(db)))
    if (!identical(ga, gb)) return(FALSE)
    if (!identical(sf::st_drop_geometry(da), sf::st_drop_geometry(db))) return(FALSE)
  }
  TRUE
}

.publish_same_bytes <- function(a, b) {
  file.exists(b) &&
    identical(readBin(a, "raw", file.info(a)$size), readBin(b, "raw", file.info(b)$size))
}

#' Plan the publish of an output folder.
#'
#' @param root The stage folder, or a `stage_paths` object.
#' @param out The output folder (layout of PUBLISH_MAP).
#' @return A data frame, one row per output file: `output` (the output
#'   folder), `rel` (path under it), `src` (the file to copy, which for
#'   GEO_SOURCES.csv may be a rewritten temporary copy), `dest`, `status`
#'   (`unchanged`, `changed` or `new`) and `how` (`bytes` or `content`).
publish_plan <- function(root, out) {
  rows <- list()
  raw_dir <- normalizePath(stage_dir(root, "data_raw"), winslash = "/", mustWork = FALSE)
  gpkg_same <- character(0) # file names of GeoPackages unchanged in content
  for (folder in PUBLISH_MAP$output) {
    src_dir <- file.path(out, folder)
    if (!dir.exists(src_dir)) next
    dest_dir <- publish_destination(root, folder)
    dest_norm <- normalizePath(dest_dir, winslash = "/", mustWork = FALSE)
    if (startsWith(paste0(dest_norm, "/"), paste0(raw_dir, "/"))) {
      stop("publish: destination ", dest_dir, " is under the legacy inputs", call. = FALSE)
    }
    files <- sort(list.files(src_dir, recursive = TRUE), method = "radix")
    for (rel in files) {
      src <- file.path(src_dir, rel)
      dest <- file.path(dest_dir, rel)
      gpkg <- grepl("[.]gpkg$", rel)
      status <- if (!file.exists(dest)) {
        "new"
      } else if (gpkg) {
        if (gpkg_same_content(src, dest)) "unchanged" else "changed"
      } else if (.publish_same_bytes(src, dest)) {
        "unchanged"
      } else {
        "changed"
      }
      if (gpkg && status == "unchanged") gpkg_same <- c(gpkg_same, basename(rel))
      rows[[length(rows) + 1]] <- data.frame(
        output = folder, rel = rel, src = src, dest = dest, status = status,
        how = if (gpkg) "content" else "bytes", stringsAsFactors = FALSE
      )
    }
  }
  plan <- if (length(rows) == 0) {
    data.frame(output = character(0), rel = character(0), src = character(0),
      dest = character(0), status = character(0), how = character(0), stringsAsFactors = FALSE)
  } else {
    do.call(rbind, rows)
  }

  # GEO_SOURCES.csv: keep the published sha256 of every GeoPackage that
  # stays, then compare again.
  i <- which(plan$output == "registries" & plan$rel == "GEO_SOURCES.csv")
  if (length(i) == 1 && file.exists(plan$dest[i]) && length(gpkg_same) > 0) {
    new <- read_std_csv(plan$src[i])
    old <- read_std_csv(plan$dest[i])
    keep <- new$file %in% gpkg_same & new$file %in% old$file
    new$sha256[keep] <- old$sha256[match(new$file[keep], old$file)]
    tmp <- tempfile("GEO_SOURCES_", fileext = ".csv")
    write_std_csv(new, tmp)
    plan$src[i] <- tmp
    plan$status[i] <- if (.publish_same_bytes(tmp, plan$dest[i])) "unchanged" else "changed"
    plan$how[i] <- "bytes, sha256 of unchanged GeoPackages kept"
  }
  plan
}

#' Copy the files of a plan whose status is not `unchanged`.
#'
#' @param plan The data frame from [publish_plan()].
#' @return The destinations written, invisibly.
publish_apply <- function(plan) {
  todo <- plan[plan$status != "unchanged", , drop = FALSE]
  for (k in seq_len(nrow(todo))) {
    dir.create(dirname(todo$dest[k]), recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(todo$src[k], todo$dest[k], overwrite = TRUE)) {
      stop("publish: could not copy ", todo$src[k], " to ", todo$dest[k], call. = FALSE)
    }
  }
  invisible(todo$dest)
}
