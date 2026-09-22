# WP05 implementer report
Branch: transition/wp05-geography

## Files written        (path, and rows or bytes)
- `pipeline/bootstrap/text/geo_schemes_text.csv` — 6 rows (SEN ADM0/ADM1/ZONES, GNB ADM0/ADM1/AEZ)
- `pipeline/bootstrap/build_geo_codelists.R` — bootstrap script, `--root`/`--out-root`
- `metadata/codelists/CL_GEO_SCHEME.csv` — 6 rows, 12 columns
- `metadata/codelists/CL_GEO.csv` — 35 rows, 14 columns
- `pipeline/R/geo.R` — `read_admin_layer()`, `make_boundary_layer()`
- `pipeline/build_geo.R` — build script, `--root`/`--out-root`
- `geo/boundaries/SEN_CODAB_v02.gpkg` — layers `adm0` (1 feature), `adm1` (14 features)
- `geo/boundaries/GNB_CODAB_V01.gpkg` — layers `adm0` (1 feature), `adm1` (9 features)
- `metadata/registries/GEO_SOURCES.csv` — 2 rows, 16 columns
- `pipeline/tests/testthat/test-geo.R` — 9 test_that blocks, 28 expectations, all pass

## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)
- WP05.A1: PASS — `st_layers()` on both GeoPackages shows exactly `adm0`,`adm1`; SEN 1+14, GNB 1+9 features.
- WP05.A2: PASS — per layer, `geo_code` set equals `CL_GEO` codes for that (ref_area, scheme), one feature per code; every feature's `ref_area`/`scheme` checked uniform and correct.
- WP05.A3: PASS — `st_crs(x)$epsg == 4326` and `all(st_is_valid(x))` (GEOS, `sf_use_s2(FALSE)`) for all 4 layers.
- WP05.A4: PASS — `CL_GEO[,c(code,ref_area,scheme,name_en,source_id,geom_layer)]` is `identical()` to `geo_codes.csv`; `CL_GEO_SCHEME` has the 6 rows with `has_geometry` Y for ADM0/ADM1, N for ZONES/AEZ.
- WP05.A5: PASS — `GEO_SOURCES` has 2 rows; each `sha256` column value equals `sha256_file()` of the committed `.gpkg`.
- WP05.A6: PASS — headers of all three files match `csv_headers.csv` order exactly; every R column filled; `TBD` appears only in `CL_GEO.valid_from` (10 rows, the zone/AEZ codes) and `GEO_SOURCES.licence`/`attribution`.
- WP05.A7: PASS — rebuilt both scripts into a temp `--out-root`: `CL_GEO_SCHEME.csv` and `CL_GEO.csv` are byte-identical (`cmp`) to committed; `GEO_SOURCES.csv` identical on every column except `sha256` (expected, GPKG bytes carry a timestamp); every rebuilt feature is `st_equals_exact()` to the committed feature with the same `geo_code` at tolerance 1e-9, for both layers of both GeoPackages.
- WP05.A8: PASS — for every unit in all 4 layers, `st_area()` of the rebuilt (assigned-CRS, `st_make_valid`d) polygon vs. `st_make_valid(st_read(source_shapefile))` differs by 0% (max observed diff 0%, well under the 0.1% tolerance).

## Deviations           (what the card said, what you did, why)
None. Followed the card's steps and rules as written.

## Questions            (contract doubts, and anything only the user can decide)
None. `geo_codes.csv` and the three headers matched the shapefiles with no gaps; SN01/SN13 validity behaved exactly as the card predicted (SN01 invalid only under S2, SN13 invalid under GEOS as delivered, both valid after `st_make_valid` under GEOS).

## Changelog line       (implementers only: the card's line, adjusted if needed)
Geography: 6 schemes, 35 units, 2 GeoPackages.
