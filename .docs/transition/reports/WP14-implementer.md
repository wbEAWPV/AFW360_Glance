# WP14 implementer report
Branch: transition/wp14-validator-assets-text

## Files written
- `pipeline/R/validate_assets.R` (397 lines) — `vc_asset_file_missing`, `vc_asset_sha256`, `vc_asset_layers`, `vc_asset_crs`, `vc_asset_geo_code`, `vc_asset_missing_geometry`, `vc_asset_duplicate_feature`, `vc_asset_invalid_geometry`, `vc_asset_name_mismatch`.
- `pipeline/R/validate_text.R` (258 lines) — `vc_text_body_file`, `vc_text_file_missing`, `vc_text_linebreak`, `vc_text_html`, `vc_text_reference`, `vc_text_tbd`.
- `pipeline/tests/testthat/test-validate-assets-text.R` (287 lines, 39 expectations) — one `test_that()` per WP14.A1/A2/A4 case plus two for the 20-per-file cap.
- `.docs/transition/reports/WP14-implementer.md` (this file).

## Checks
- WP14.A1: PASS. `vc_asset_*`/`vc_text_*` run on an unmodified `make_temp_root()` copy give 0 ERROR findings (`test-validate-assets-text.R`, "an unmodified temp copy has zero ERROR findings"). Verified independently on the real repo root too (see WP14.A3).
- WP14.A2: PASS, all 9 mutations, each compared against the always-present baseline (see Deviations): byte-appended GPKG -> `ASSET.SHA256` only; `geo_code` set to `SN99` -> `ASSET.GEO_CODE` only; one ADM1 feature removed -> `ASSET.MISSING_GEOMETRY` only (row_key `code=SN05`); feature duplicated -> `ASSET.DUPLICATE_FEATURE` only; bow-tie polygon -> `ASSET.INVALID_GEOMETRY` only; figure file deleted -> `ASSET.FILE_MISSING` only; `TEXT` row with both `body` and `file` -> `TEXT.BODY_FILE` only; `about.md` deleted -> `TEXT.FILE_MISSING` only; `<b>x</b>` in a body -> `TEXT.HTML` only. Also added (not required, but exercised for confidence): `ASSET.NAME_MISMATCH`, `ASSET.CRS`, `TEXT.LINEBREAK`, `TEXT.REFERENCE` mutations, each isolated to its own check_id.
- WP14.A3: PASS. Ran all 15 functions against the real repository root (`build_ctx(".")`): 0 ERROR, exactly 4 `WARN TEXT.TBD` findings (`content/TEXT.csv`, the GNB `about` row and the three GNB `messages` rows, all `body = TBD`). No asset defects to list.
- WP14.A4: PASS. Test "a has_geometry = N scheme produces no finding" points a SEN `ZONES` (`has_geometry = N`) `CL_GEO` row's `source_id`/`geom_layer` at a real boundary source/layer that does not contain its code, and confirms no finding is produced — proving the `has_geometry` flag, not feature presence, silences the check.
- WP14.A5: PASS. `Rscript pipeline/tests/testthat.R` -> `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 180 ]` (my 39 plus the 141 from wave-1/2 packages already in the tree).

## Deviations
- Card step 2 gives the bow-tie construction as `st_polygon(list(rbind(...)))`. The real `adm1` layers' geometry column type is `MULTIPOLYGON` (confirmed via `sf::st_layers()`), and GDAL's GeoPackage writer rejects a `POLYGON` written into a `MULTIPOLYGON` column (`Error: Not a matrix`, from `sf:::CPL_write_ogr`). I wrapped the same bow-tie ring as `st_multipolygon(list(list(rbind(...))))` instead, which writes and reads back invalid (`st_is_valid()` FALSE) as intended. No other file was touched.
- "gives exactly its check_id" (WP14.A2) is read as: the set of check_ids present after the mutation, minus the set present on an unmodified `make_temp_root()` copy, equals exactly that one check_id — not that the mutated run's findings are empty otherwise. This is necessary because the real content already carries 4 `WARN TEXT.TBD` findings (2 GNB text rows are genuinely `TBD`), which are present in every run regardless of the mutation under test. Every WP14.A2 test in my file computes and subtracts this baseline explicitly.
- The `SN99` geo_code mutation renames a *copy* of an existing feature (original left untouched), not the original feature itself. Renaming the original's own code would make its real code simultaneously "missing" its geometry (per `ASSET.MISSING_GEOMETRY`'s join-based rule, which the separate "one ADM1 feature removed" case requires), so the same single mutation cannot cleanly test `ASSET.GEO_CODE` in isolation if it also strips a valid code from the layer. Copying-then-renaming avoids this: the real code stays present (no `MISSING_GEOMETRY`), the copy's code is invalid and unique (`GEO_CODE` fires, no `DUPLICATE_FEATURE`).
- Row-key/file conventions chosen where the card's four `row_key` categories don't name an exact case: `ASSET.SHA256`/`ASSET.LAYERS` use the `GEO_SOURCES`/`FIGURES` row's identifying column (`source_id=`/`figure_id=`) since they are fundamentally about a registry row; `ASSET.CRS` uses `layer=<layer>` (a layer-level finding, not tied to one feature); `ASSET.MISSING_GEOMETRY` uses `code=<code>` (the `CL_GEO` row's identifying column, per the general spec's own `code=URB` example) with `file` pointed at the boundary GeoPackage the code should have appeared in. `TEXT.HTML`/`TEXT.REFERENCE` findings about a referenced Markdown file's own content (not the CSV row) use an empty `row_key` (category: "a whole file").

## Questions
None — the real repository's assets and text passed every ERROR-level check with no defects to register.

## Changelog line
Validator: asset and text checks.
