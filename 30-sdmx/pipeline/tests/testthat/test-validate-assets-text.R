# pipeline/tests/testthat/test-validate-assets-text.R
#
# Tests for pipeline/R/validate_assets.R and pipeline/R/validate_text.R
# (WP14). Each mutation test builds its own copy of the real
# metadata/content/geo/assets trees with make_temp_root(), mutates exactly
# one thing in it, and checks that the mutation introduces exactly its
# check_id (compared against the check_ids already present on an
# unmodified copy, since the real content has 4 TBD bodies that always
# give WARN TEXT.TBD).

root <- find_root()
source(file.path(root, "pipeline", "R", "ctx.R"))
source(file.path(root, "pipeline", "R", "validate_assets.R"))
source(file.path(root, "pipeline", "R", "validate_text.R"))

ASSET_CHECKS <- list(
  vc_asset_file_missing, vc_asset_sha256, vc_asset_layers, vc_asset_crs,
  vc_asset_geo_code, vc_asset_missing_geometry, vc_asset_duplicate_feature,
  vc_asset_invalid_geometry, vc_asset_name_mismatch
)

TEXT_CHECKS <- list(
  vc_text_body_file, vc_text_file_missing, vc_text_linebreak,
  vc_text_html, vc_text_reference, vc_text_tbd
)

run_all <- function(tmp) {
  ctx <- build_ctx(tmp)
  dplyr::bind_rows(lapply(c(ASSET_CHECKS, TEXT_CHECKS), function(f) f(ctx)))
}

fresh_root <- function() {
  make_temp_root(root, include = c("metadata", "content", "geo", "assets"))
}

set_sha256 <- function(tmp, source_id, gpkg_path) {
  edit_csv(file.path(tmp, "metadata", "registries", "GEO_SOURCES.csv"), function(df) {
    df$sha256[df$source_id == source_id] <- sha256_file(gpkg_path)
    df
  })
}

read_adm1 <- function(gpkg) {
  sf::sf_use_s2(FALSE)
  sf::st_read(gpkg, layer = "adm1", quiet = TRUE)
}

write_adm1 <- function(gpkg, lyr) {
  sf::st_write(lyr, gpkg, layer = "adm1", delete_layer = TRUE, quiet = TRUE)
}

# The check_ids present on an unmodified copy of the real content: exactly
# the 4 TBD bodies (WP14.A3).
BASELINE_IDS <- local({
  tmp <- fresh_root()
  sort(unique(run_all(tmp)$check_id))
})

expect_only_new_check_id <- function(tmp, id) {
  res <- run_all(tmp)
  new_ids <- setdiff(sort(unique(res$check_id)), BASELINE_IDS)
  testthat::expect_equal(new_ids, id)
}

# ---- WP14.A1 -------------------------------------------------------------

test_that("an unmodified temp copy has zero ERROR findings", {
  tmp <- fresh_root()
  res <- run_all(tmp)
  expect_equal(nrow(res[res$severity == "ERROR", , drop = FALSE]), 0)
})

test_that("an unmodified temp copy flags exactly the 4 TBD bodies", {
  expect_equal(BASELINE_IDS, "TEXT.TBD")
  tmp <- fresh_root()
  ctx <- build_ctx(tmp)
  res <- vc_text_tbd(ctx)
  expect_equal(nrow(res), 4)
  expect_true(all(res$severity == "WARN"))
})

# ---- WP14.A2: asset mutations --------------------------------------------

test_that("a byte appended to a GeoPackage gives exactly ASSET.SHA256", {
  tmp <- fresh_root()
  gpkg <- file.path(tmp, "geo", "boundaries", "SEN_CODAB_v02.gpkg")
  con <- file(gpkg, "ab")
  writeBin(as.raw(0), con)
  close(con)

  expect_only_new_check_id(tmp, "ASSET.SHA256")
})

test_that("a feature's geo_code set to SN99 gives exactly ASSET.GEO_CODE", {
  tmp <- fresh_root()
  gpkg <- file.path(tmp, "geo", "boundaries", "SEN_CODAB_v02.gpkg")
  lyr <- read_adm1(gpkg)
  extra <- lyr[lyr$geo_code == "SN05", ]
  extra$geo_code <- "SN99" # SN05's own feature is untouched, so it stays present
  write_adm1(gpkg, rbind(lyr, extra))
  set_sha256(tmp, "SEN_CODAB_v02", gpkg)

  expect_only_new_check_id(tmp, "ASSET.GEO_CODE")
})

test_that("one ADM1 feature removed gives exactly ASSET.MISSING_GEOMETRY", {
  tmp <- fresh_root()
  gpkg <- file.path(tmp, "geo", "boundaries", "SEN_CODAB_v02.gpkg")
  lyr <- read_adm1(gpkg)
  write_adm1(gpkg, lyr[lyr$geo_code != "SN05", ])
  set_sha256(tmp, "SEN_CODAB_v02", gpkg)

  res <- run_all(tmp)
  new_ids <- setdiff(sort(unique(res$check_id)), BASELINE_IDS)
  expect_equal(new_ids, "ASSET.MISSING_GEOMETRY")
  hit <- res[res$check_id == "ASSET.MISSING_GEOMETRY", ]
  expect_true(any(grepl("code=SN05", hit$row_key)))
})

test_that("a feature duplicated gives exactly ASSET.DUPLICATE_FEATURE", {
  tmp <- fresh_root()
  gpkg <- file.path(tmp, "geo", "boundaries", "SEN_CODAB_v02.gpkg")
  lyr <- read_adm1(gpkg)
  dup <- lyr[lyr$geo_code == "SN05", ]
  write_adm1(gpkg, rbind(lyr, dup))
  set_sha256(tmp, "SEN_CODAB_v02", gpkg)

  expect_only_new_check_id(tmp, "ASSET.DUPLICATE_FEATURE")
})

test_that("a bow-tie polygon gives exactly ASSET.INVALID_GEOMETRY", {
  tmp <- fresh_root()
  gpkg <- file.path(tmp, "geo", "boundaries", "SEN_CODAB_v02.gpkg")
  lyr <- read_adm1(gpkg)
  # The adm1 layer's geometry column is MULTIPOLYGON, so the bow-tie must
  # be wrapped as one too, or the GeoPackage writer rejects the mismatched
  # geometry subtype.
  bowtie <- sf::st_multipolygon(list(list(
    rbind(c(0, 0), c(1, 1), c(1, 0), c(0, 1), c(0, 0))
  )))
  i <- which(lyr$geo_code == "SN05")
  geom <- sf::st_geometry(lyr)
  geom[[i]] <- bowtie
  sf::st_geometry(lyr) <- geom
  write_adm1(gpkg, lyr)
  set_sha256(tmp, "SEN_CODAB_v02", gpkg)

  expect_only_new_check_id(tmp, "ASSET.INVALID_GEOMETRY")
})

test_that("a feature's name changed gives exactly ASSET.NAME_MISMATCH", {
  tmp <- fresh_root()
  gpkg <- file.path(tmp, "geo", "boundaries", "SEN_CODAB_v02.gpkg")
  lyr <- read_adm1(gpkg)
  lyr$name[lyr$geo_code == "SN05"] <- "Not Kaolack"
  write_adm1(gpkg, lyr)
  set_sha256(tmp, "SEN_CODAB_v02", gpkg)

  expect_only_new_check_id(tmp, "ASSET.NAME_MISMATCH")
  res <- run_all(tmp)
  expect_equal(res$severity[res$check_id == "ASSET.NAME_MISMATCH"], "WARN")
})

test_that("a layer not in EPSG:4326 gives exactly ASSET.CRS", {
  tmp <- fresh_root()
  gpkg <- file.path(tmp, "geo", "boundaries", "SEN_CODAB_v02.gpkg")
  lyr <- read_adm1(gpkg)
  lyr <- sf::st_transform(lyr, 3857)
  write_adm1(gpkg, lyr)
  set_sha256(tmp, "SEN_CODAB_v02", gpkg)

  expect_only_new_check_id(tmp, "ASSET.CRS")
})

test_that("the figure file deleted gives exactly ASSET.FILE_MISSING", {
  tmp <- fresh_root()
  file.remove(file.path(tmp, "assets", "figures", "SEN", "SEN_FISCAL_EQUITY.png"))

  expect_only_new_check_id(tmp, "ASSET.FILE_MISSING")
})

test_that("a has_geometry = N scheme produces no finding (WP14.A4)", {
  tmp <- fresh_root()
  # SEN's ZONES scheme has has_geometry = N. Point one of its codes at a
  # real source/layer that does not contain it, to prove it is the
  # has_geometry flag -- not the presence of a matching feature -- that
  # silences the check.
  edit_csv(file.path(tmp, "metadata", "codelists", "CL_GEO.csv"), function(df) {
    i <- which(df$ref_area == "SEN" & df$scheme == "ZONES")[1]
    df$source_id[i] <- "SEN_CODAB_v02"
    df$geom_layer[i] <- "adm1"
    df
  })

  res <- run_all(tmp)
  new_ids <- setdiff(sort(unique(res$check_id)), BASELINE_IDS)
  expect_equal(new_ids, character(0))
})

# ---- WP14.A2: text mutations ----------------------------------------------

test_that("a TEXT row with both body and file gives exactly TEXT.BODY_FILE", {
  tmp <- fresh_root()
  edit_csv(file.path(tmp, "content", "TEXT.csv"), function(df) {
    i <- which(df$slot == "about" & df$ref_area == "SEN")
    df$body[i] <- "Some body text."
    df
  })

  expect_only_new_check_id(tmp, "TEXT.BODY_FILE")
})

test_that("about.md deleted gives exactly TEXT.FILE_MISSING", {
  tmp <- fresh_root()
  file.remove(file.path(tmp, "content", "text", "SEN", "about.md"))

  expect_only_new_check_id(tmp, "TEXT.FILE_MISSING")
})

test_that("<b>x</b> in a body gives exactly TEXT.HTML", {
  tmp <- fresh_root()
  edit_csv(file.path(tmp, "content", "TEXT.csv"), function(df) {
    i <- which(df$slot == "messages" & df$ref_area == "SEN" & df$order == "1")
    df$body[i] <- "<b>x</b>"
    df
  })

  expect_only_new_check_id(tmp, "TEXT.HTML")
})

test_that("a body with a line break gives exactly TEXT.LINEBREAK", {
  tmp <- fresh_root()
  edit_csv(file.path(tmp, "content", "TEXT.csv"), function(df) {
    i <- which(df$slot == "messages" & df$ref_area == "SEN" & df$order == "1")
    df$body[i] <- "Line one.\nLine two."
    df
  })

  expect_only_new_check_id(tmp, "TEXT.LINEBREAK")
})

test_that("a {{...}} reference in a body gives exactly TEXT.REFERENCE", {
  tmp <- fresh_root()
  edit_csv(file.path(tmp, "content", "TEXT.csv"), function(df) {
    i <- which(df$slot == "messages" & df$ref_area == "SEN" & df$order == "1")
    df$body[i] <- "The rate is {{poverty_rate}} this year."
    df
  })

  expect_only_new_check_id(tmp, "TEXT.REFERENCE")
  res <- run_all(tmp)
  hit <- res[res$check_id == "TEXT.REFERENCE", ]
  expect_equal(hit$severity, "WARN")
  expect_true(grepl("\\{\\{poverty_rate\\}\\}", hit$message))
})

# ---- findings format: the 20-per-file cap ---------------------------------

test_that("more than 20 findings for one file are capped with a SUMMARY row", {
  df <- dplyr::bind_rows(lapply(1:25, function(i) {
    .af_finding(
      "ASSET.GEO_CODE", "ERROR", "geo/boundaries/X.gpkg",
      sprintf("layer=adm1 geo_code=SN%02d", i), "test finding"
    )
  }))
  capped <- .af_cap(df)
  expect_equal(nrow(capped), 21)
  summary_rows <- capped[capped$row_key == "", ]
  expect_equal(nrow(summary_rows), 1)
  expect_equal(summary_rows$check_id, "ASSET.GEO_CODE")
  expect_equal(summary_rows$severity, "ERROR")
  expect_true(grepl("^SUMMARY: 25 findings in total, 20 shown$", summary_rows$message))
})

test_that("findings for different files are capped independently", {
  df <- dplyr::bind_rows(
    lapply(1:5, function(i) {
      .tf_finding("TEXT.TBD", "WARN", "content/TEXT.csv", sprintf("order=%02d", i), "x")
    }),
    lapply(1:22, function(i) {
      .tf_finding("TEXT.HTML", "ERROR", "content/text/SEN/about.md", sprintf("line=%02d", i), "x")
    })
  )
  capped <- .tf_cap(df)
  expect_equal(nrow(capped[capped$file == "content/TEXT.csv", ]), 5)
  expect_equal(nrow(capped[capped$file == "content/text/SEN/about.md", ]), 21)
})
