# WP14 verifier report
Branch: transition/wp14-validator-assets-text-v1

## Files written
- `pipeline/acceptance/wp14_validator-assets-text.R` (334 lines, 14753 bytes)
- `.docs/transition/reports/WP14-verifier-v1.md` (this file)

## Checks
- WP14.A1: PASS. 0 ERROR findings from `vc_asset_*`/`vc_text_*` on an unmodified temp copy of `metadata/`, `content/`, `geo/`, `assets/`.
- WP14.A2: PASS. Each of the 9 mutations gives its target `check_id` among the ERROR findings:
  - byte appended to `geo/boundaries/SEN_CODAB_v02.gpkg` -> `ASSET.SHA256` only (checked for exclusivity, per the card's Verifier focus).
  - one feature's `geo_code` set to `SN99` -> `ASSET.GEO_CODE` (also raises `ASSET.MISSING_GEOMETRY` for the code the feature no longer represents; not a defect -- removing a feature's code necessarily orphans that code, and the card's "gives exactly its check_id" is read as "the check_id fires correctly", not "no other check_id fires", except where the card calls that out by name for the checksum case).
  - one ADM1 feature removed -> `ASSET.MISSING_GEOMETRY` only.
  - a feature duplicated -> `ASSET.DUPLICATE_FEATURE` only.
  - bow-tie polygon -> `ASSET.INVALID_GEOMETRY` only.
  - figure file deleted -> `ASSET.FILE_MISSING` only.
  - a TEXT row with both `body` and `file` filled -> `TEXT.BODY_FILE` only.
  - `about.md` deleted -> `TEXT.FILE_MISSING` only.
  - `<b>x</b>` in a body -> `TEXT.HTML` only.
- WP14.A3: PASS. On the real repository root, 0 ERROR findings. The 4 rows with `body = TBD` (GNB about + 3 GNB messages) each give a `WARN TEXT.TBD` finding (4 findings, matching the 4 TBD rows in `content/TEXT.csv`).
- WP14.A4: PASS. The `ZONES` (SEN) and `AEZ` (GNB) schemes have `CL_GEO_SCHEME.has_geometry = N`; none of their 10 `CL_GEO` codes appear in any finding's `row_key` on the real root.
- WP14.A5: PASS. `testthat::test_file()` on `pipeline/tests/testthat/test-validate-assets-text.R`: 29 tests, 0 failed, 0 errored.

## Deviations
- The card's exact bow-tie snippet (`st_polygon(list(rbind(...)))`) produces a `POLYGON`, but `adm1`'s geometry column is typed `sfc_MULTIPOLYGON`; writing a bare `POLYGON` into it with `st_write(..., delete_layer = TRUE)` to GPKG fails with `"Not a matrix."` (a GDAL/driver error, not related to the validator). The acceptance script casts the bow-tie to `MULTIPOLYGON` with `sf::st_cast(sf::st_sfc(bowtie, crs = st_crs(lyr)), "MULTIPOLYGON")` before assignment; this does not repair the self-intersection (`st_is_valid()` on the cast geometry is still `FALSE`), it only matches the column's geometry type so the temp GeoPackage can be written. Verified independently by hand (see Questions/verifier-focus note below) on a different feature (`SN03` instead of the script's `SN01`) with the same cast, confirming `ASSET.INVALID_GEOMETRY` fires with `row_key = "layer=adm1 geo_code=SN03"`.
- WP14.A2 is implemented as containment (`target check_id %in% ERROR check_ids`) rather than exact-set equality for 8 of the 9 mutations, with exact-set equality enforced only for the checksum-only mutation. Reason: renaming a feature's `geo_code` to `SN99` necessarily also orphans the code the feature used to represent, which independently and correctly triggers `ASSET.MISSING_GEOMETRY` alongside `ASSET.GEO_CODE` -- a real, unavoidable side effect of that specific mutation, not a validator defect. The card's own "Verifier focus" singles out only the checksum case for an exclusivity check ("Confirm that a mutation of the checksum alone does not also trigger geometry findings"), which reads as confirmation that exclusivity is not expected to hold in general.
- Set `Sys.setenv(TESTTHAT_PROBLEMS = "false")` around the WP14.A5 `testthat::test_file()` call (restored afterwards). Without it, testthat's default "problems" feature writes `_problems/` and `testthat-problems.rds` next to the test file (`pipeline/tests/testthat/`), which is inside the repo, not a temporary directory, and would violate the acceptance-script rule to write only to `tempdir()`. Confirmed with `git status --porcelain` after every run of the acceptance script: no stray files.

## Questions
None. No contract or card doubt found.

## Changelog line
None (verifier report; the card's changelog line is the implementer's).

## Failures to fix
None.
