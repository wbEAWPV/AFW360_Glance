# WP05 verifier report
Branch: transition/wp05-geography-v1

## Files written        (path, and rows or bytes)
- `pipeline/acceptance/wp05_geography.R` (acceptance script, 8 check() calls: WP05.A1-A8)
- `.docs/transition/reports/WP05-verifier-v1.md` (this report)

## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)
- WP05.A1 PASS: SEN gpkg layers=adm0,adm1, adm0=1, adm1=14; GNB gpkg layers=adm0,adm1, adm0=1, adm1=9. Matches GEOM.SEN.ADM0/ADM1 and GEOM.GNB.ADM0/ADM1 in `contract/expected_counts.csv`.
- WP05.A2 PASS: for each of SEN/adm0, SEN/adm1, GNB/adm0, GNB/adm1 the feature `geo_code` set equals the `CL_GEO` codes for that (ref_area, scheme), one feature per code, and every feature's `ref_area`/`scheme` match.
- WP05.A3 PASS: all four layers report EPSG:4326 and `st_is_valid()` is TRUE for every feature under `sf_use_s2(FALSE)`.
- WP05.A4 PASS: `CL_GEO` has 35 rows whose (code, ref_area, scheme, name_en, source_id, geom_layer) are identical to `contract/geo_codes.csv` in the same order; `CL_GEO_SCHEME` has the 6 expected rows (SEN ADM0/ADM1/ZONES, GNB ADM0/ADM1/AEZ) with has_geometry Y/Y/N/Y/Y/N, partition=Y, nests_in empty.
- WP05.A5 PASS: `GEO_SOURCES.csv` has 2 rows; the recorded sha256 for each equals the sha256 of the committed `.gpkg` file on disk (SEN and GNB both match).
- WP05.A6 PASS: headers of `CL_GEO_SCHEME.csv`, `CL_GEO.csv`, `GEO_SOURCES.csv` match `contract/csv_headers.csv` exactly; every required (R) column is filled in all three files; the literal cell value `TBD` occurs only in `valid_from` (CL_GEO) and `licence`/`attribution` (GEO_SOURCES) — no other column contains a bare `TBD` cell.
- WP05.A7 PASS: `pipeline/bootstrap/build_geo_codelists.R --out-root <tempdir>` reproduces `CL_GEO_SCHEME.csv` and `CL_GEO.csv` byte for byte (md5 match). `pipeline/build_geo.R --out-root <tempdir>` reproduces the same layers, the same `geo_code` sets and counts, and every rebuilt feature is `st_equals_exact()` to the committed feature with the same `geo_code` at tolerance 1e-9, for both countries and both layers.
- WP05.A8 PASS: for every one of the 25 geometry units (SEN adm0=1, adm1=14; GNB adm0=1, adm1=9), the gpkg polygon area (planar, `sf_use_s2(FALSE)`) matches the area of the corresponding source-shapefile polygon after `st_make_valid()` to within 0.1%; observed max difference across all units was 0.000000%.
- Ownership check (by hand): `git diff --name-only transition/main...transition/wp05-geography` lists `.docs/transition/reports/WP05-implementer.md`, `geo/boundaries/GNB_CODAB_V01.gpkg`, `geo/boundaries/SEN_CODAB_v02.gpkg`, `metadata/codelists/CL_GEO.csv`, `metadata/codelists/CL_GEO_SCHEME.csv`, `metadata/registries/GEO_SOURCES.csv`, `pipeline/R/geo.R`, `pipeline/bootstrap/build_geo_codelists.R`, `pipeline/bootstrap/text/geo_schemes_text.csv`, `pipeline/build_geo.R`, `pipeline/tests/testthat/test-geo.R`. All are owned by WP05 in `contract/output_ownership.csv` (the `.gpkg`, codelist, registry and pipeline files by exact-path rows; `WP05-implementer.md` by the glob row `.docs/transition/reports/WPNN-implementer*.md`, owner `WPNN`, i.e. WP05's own report). No unowned path found. PASS.
- Verifier focus (by hand): read the raw shapefiles directly for A2/A8 (see Deviations); confirmed `st_is_valid()` is TRUE for SN01 and SN13 in the built `adm1` layer under `sf_use_s2(FALSE)` (both are FALSE under s2, as the card describes, but validity is checked under GEOS). PASS.

## Deviations           (what the card said, what you did, why)
- The card's "Read" section for WP05 lists only `packages/COMMON.md`, the WP05 card, `contract/geo_codes.csv`, and the header rows of `csv_headers.csv` for three files. It does not list `contract/expected_counts.csv`, yet WP05.A1 explicitly requires reading the `GEOM.*` rows of that file ("`GEOM.*` in `contract/expected_counts.csv`"), and the orchestrator instructions require expected numbers to be read from that file by check_id rather than hard-coded. I read only the four `GEOM.*` rows of `expected_counts.csv` (check_id, scope, quantity, expected, tolerance, source columns; values GEOM.SEN.ADM0=1, GEOM.SEN.ADM1=14, GEOM.GNB.ADM0=1, GEOM.GNB.ADM1=9, tolerance 0 each) to write WP05.A1 correctly. See Questions below.
- I read the raw shapefiles (`data_raw/shp/{sen,gnb}_admin{0,1}.shp`) beyond the card's literal "Read" list. This was directed by the card's own "Inputs" section (which names these exact files and fields) and by "Verifier focus" ("Read the raw shapefiles yourself for A2 and A8"), so I treat it as in scope rather than a deviation.
- I did not open the implementer's `pipeline/build_geo.R`, `pipeline/R/geo.R`, `pipeline/bootstrap/build_geo_codelists.R`, tests, or `.docs/transition/reports/WP05-implementer.md` at any point; the script was built from the card and contract only, and the card's "Verifier focus" does not direct reading the report, so it was never opened.

## Questions            (contract doubts, and anything only the user can decide)
- CONTRACT DOUBT: WP05's "Read" section omits `contract/expected_counts.csv`, but WP05.A1 cannot be written without it (the card names `GEOM.*` entries in that file and the process rules forbid hard-coding expected numbers). The card should list `contract/expected_counts.csv` (or at least the relevant `GEOM.*` rows) under "Read". I resolved this by reading only the four `GEOM.*` rows needed, which is consistent with COMMON.md's spirit (small, targeted reads) even though it is not literally on the card's list.

## Changelog line       (implementers only: the card's line, adjusted if needed)
None

## Failures to fix   (numbered; for each: the check ID, the exact command or comparison, expected against actual. Write "None" on PASS.)
None
