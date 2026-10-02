root <- find_root()
source(file.path(root, "pipeline", "R", "geo.R"))

suppressPackageStartupMessages(library(sf))

sen_adm0 <- file.path(root, "data_raw", "shp", "sen_admin0.shp")
sen_adm1 <- file.path(root, "data_raw", "shp", "sen_admin1.shp")
gnb_adm0 <- file.path(root, "data_raw", "shp", "gnb_admin0.shp")
gnb_adm1 <- file.path(root, "data_raw", "shp", "gnb_admin1.shp")

test_that("read_admin_layer rejects an unknown level", {
  expect_error(read_admin_layer(sen_adm0, "adm2"), "adm0.*adm1")
})

test_that("read_admin_layer normalizes SEN fields (version field 'version')", {
  x <- read_admin_layer(sen_adm1, "adm1")
  expect_equal(names(x)[1:4], c("geo_code", "name", "valid_on", "version"))
  expect_equal(nrow(x), 14)
  expect_true(all(c("SN01", "SN13") %in% x$geo_code))
  expect_equal(x$name[x$geo_code == "SN13"], "Thiès")
  expect_true(all(x$version == "v02"))
  expect_equal(length(unique(x$valid_on)), 1)
})

test_that("read_admin_layer normalizes GNB fields (version field 'cod_versio')", {
  x <- read_admin_layer(gnb_adm1, "adm1")
  expect_equal(names(x)[1:4], c("geo_code", "name", "valid_on", "version"))
  expect_equal(nrow(x), 9)
  expect_true(all(x$version == "V_01"))
  expect_equal(x$name[x$geo_code == "GW08"], "Bissau")
})

test_that("read_admin_layer reads a single-feature adm0 layer", {
  x0 <- read_admin_layer(sen_adm0, "adm0")
  expect_equal(nrow(x0), 1)
  expect_equal(x0$geo_code, "SN")

  g0 <- read_admin_layer(gnb_adm0, "adm0")
  expect_equal(nrow(g0), 1)
  expect_equal(g0$geo_code, "GW")
})

test_that("make_boundary_layer keeps only geo_code/ref_area/scheme/name + geometry, sorted", {
  raw <- read_admin_layer(sen_adm1, "adm1")
  out <- make_boundary_layer(raw, "SEN", "ADM1")

  expect_equal(setdiff(names(out), attr(out, "sf_column")), c("geo_code", "ref_area", "scheme", "name"))
  expect_equal(out$geo_code, sort(raw$geo_code))
  expect_true(all(out$ref_area == "SEN"))
  expect_true(all(out$scheme == "ADM1"))
})

test_that("make_boundary_layer assigns EPSG:4326 without reprojecting", {
  raw <- read_admin_layer(sen_adm0, "adm0")
  out <- make_boundary_layer(raw, "SEN", "ADM0")
  expect_equal(st_crs(out)$epsg, 4326L)
  # Assigning, not reprojecting: the raw coordinates are unchanged.
  expect_equal(sf::st_bbox(out), sf::st_bbox(sf::st_set_crs(raw, 4326)))
})

test_that("make_boundary_layer fixes SN13 (invalid under GEOS as delivered) and keeps SN01 valid", {
  raw <- read_admin_layer(sen_adm1, "adm1")
  before <- stats::setNames(st_is_valid(raw), raw$geo_code)
  expect_false(before[["SN13"]])
  expect_true(before[["SN01"]])

  out <- make_boundary_layer(raw, "SEN", "ADM1")
  after <- stats::setNames(st_is_valid(out), out$geo_code)
  expect_true(all(after))
  expect_true(after[["SN01"]])
  expect_true(after[["SN13"]])
})

test_that("make_boundary_layer produces one feature per code with no duplicates", {
  raw <- read_admin_layer(gnb_adm1, "adm1")
  out <- make_boundary_layer(raw, "GNB", "ADM1")
  expect_equal(nrow(out), 9)
  expect_equal(length(unique(out$geo_code)), 9)
})
