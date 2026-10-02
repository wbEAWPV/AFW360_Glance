# 20-excel-sdmx-csv/tests/testthat/test-publish.R
#
# Tests for R/publish.R and publish.R on a temporary copy of the
# repository layout (the real destinations are never touched): an output
# folder equal to the published files publishes nothing, a changed file is
# reported and copied, and a GeoPackage rewritten with the same content
# (other bytes, other sha256) keeps the published file and hash.

root <- find_root()
source(stage_path(root, "code", "publish.R"))

#' A temporary stage whose destinations hold the real published files, and
#' an output folder holding a copy of them (as an unchanged rebuild would).
.publish_fixture <- function() {
  tmp <- make_temp_root(root, include = c("metadata", "data", "geo", "content", "assets"))
  out <- file.path(dirname(tmp), "output")
  for (k in seq_len(nrow(PUBLISH_MAP))) {
    folder <- PUBLISH_MAP$output[k]
    dest <- publish_destination(tmp, folder)
    if (!dir.exists(dest)) next
    files <- list.files(dest, recursive = TRUE)
    if (identical(folder, "data")) files <- files[grepl("^AFW360_HH_[^/]*[.]csv$", files)]
    if (identical(folder, "registries")) files <- intersect(files, c("GEO_SOURCES.csv", "FIGURES.csv"))
    for (f in files) {
      dir.create(dirname(file.path(out, folder, f)), recursive = TRUE, showWarnings = FALSE)
      file.copy(file.path(dest, f), file.path(out, folder, f))
    }
  }
  list(tmp = tmp, out = out)
}

test_that("an output equal to the published files publishes nothing", {
  fx <- .publish_fixture()
  on.exit(unlink(dirname(fx$tmp), recursive = TRUE), add = TRUE)
  plan <- publish_plan(fx$tmp, fx$out)
  expect_gt(nrow(plan), 0)
  expect_true(all(plan$status == "unchanged"), info = paste(plan$rel[plan$status != "unchanged"], collapse = ", "))
  expect_setequal(unique(plan$output), PUBLISH_MAP$output)
})

test_that("a changed file is reported, copied, and then current", {
  fx <- .publish_fixture()
  on.exit(unlink(dirname(fx$tmp), recursive = TRUE), add = TRUE)
  f <- file.path(fx$out, "content", "TEXT.csv")
  edit_csv(f, function(df) {
    df$title[1] <- paste0(df$title[1], " (edited)")
    df
  })
  plan <- publish_plan(fx$tmp, fx$out)
  expect_equal(plan$rel[plan$status != "unchanged"], "TEXT.csv")
  publish_apply(plan)
  dest <- file.path(publish_destination(fx$tmp, "content"), "TEXT.csv")
  expect_identical(readBin(dest, "raw", file.info(dest)$size), readBin(f, "raw", file.info(f)$size))
  expect_true(all(publish_plan(fx$tmp, fx$out)$status == "unchanged"))
})

test_that("a GeoPackage with the same content keeps the published file and sha256", {
  fx <- .publish_fixture()
  on.exit(unlink(dirname(fx$tmp), recursive = TRUE), add = TRUE)
  gdir <- file.path(fx$out, "geo", "boundaries")
  g <- list.files(gdir, pattern = "[.]gpkg$", full.names = TRUE)[1]
  # Rewrite the GeoPackage layer by layer: same content, other bytes.
  layers <- sf::st_layers(g)$name
  data <- lapply(layers, function(l) sf::st_read(g, layer = l, quiet = TRUE))
  unlink(g)
  for (i in seq_along(layers)) sf::st_write(data[[i]], g, layer = layers[i], quiet = TRUE)
  edit_csv(file.path(fx$out, "registries", "GEO_SOURCES.csv"), function(df) {
    df$sha256[df$file == basename(g)] <- sha256_file(g)
    df
  })
  plan <- publish_plan(fx$tmp, fx$out)
  expect_true(all(plan$status == "unchanged"), info = paste(plan$rel[plan$status != "unchanged"], collapse = ", "))
  expect_identical(plan$how[plan$rel == basename(g) | plan$rel == file.path("boundaries", basename(g))], "content")
})

test_that("publish.R --check exits 1 when a destination differs and 0 once published", {
  fx <- .publish_fixture()
  on.exit(unlink(dirname(fx$tmp), recursive = TRUE), add = TRUE)
  copy_stage_code(root, fx$tmp)
  f <- file.path(fx$out, "registries", "FIGURES.csv")
  edit_csv(f, function(df) {
    df$notes[1] <- "edited"
    df
  })
  run <- function(...) {
    res <- suppressWarnings(system2(
      file.path(R.home("bin"), "Rscript"),
      shQuote(c(file.path(fx$tmp, "publish.R"), "--root", fx$tmp, "--out-root", fx$out, ...)),
      stdout = TRUE, stderr = TRUE
    ))
    s <- attr(res, "status")
    if (is.null(s)) 0L else s
  }
  expect_equal(run("--check"), 1L)
  expect_equal(run(), 0L)
  expect_equal(run("--check"), 0L)
})
