# WP15 implementer report
Branch: transition/wp15-converter

## Files written        (path, and rows or bytes)
- pipeline/convert_legacy.R (110 lines) - CLI entry point
- pipeline/R/convert_tables.R (452 lines) - pure functions: read/melt workbook, validate plan coverage, parse and check DUPLICATE_OF/DERIVED assert_rule, order/pad breakdown and qualifier slots, match overrides, build rows, sort/dedupe
- pipeline/R/manifest.R (51 lines) - build_manifest()
- pipeline/tests/testthat/test-convert.R (284 lines) - 10 test_that blocks on a fully synthetic fixture, 198/198 tests pass repo-wide
- data/AFW360_HH_SEN_2021.csv (3003 rows, 291523 bytes)
- data/AFW360_HH_SEN_2021_manifest.csv (16 rows, 395 bytes)
- data/AFW360_HH_GNB_2021.csv (2268 rows, 218087 bytes)
- data/AFW360_HH_GNB_2021_manifest.csv (16 rows, 395 bytes)
- All four produced with `--timestamp 2026-01-01T00:00:00Z`.

## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)
- WP15.A1: PASS - both files' header matched `metadata/structure/DSD_AFW360_HH.csv$id` exactly (`identical(dsd$id, names(sen))` / GNB both TRUE).
- WP15.A2: PASS - SEN has 3003 rows (matches `DATA.SEN.ROWS`), `table(OBS_STATUS)` = all 3003 `A` (matches `DATA.SEN.ROWS.A`).
- WP15.A3: PASS - GNB has 2268 rows (`GNB.DATA.ROWS`), 2229 `A` (`GNB.DATA.ROWS.A`), 39 `O` (`GNB.DATA.ROWS.O`).
- WP15.A4: PASS - `any(duplicated(key))` FALSE and no empty key cell, both files.
- WP15.A5: PASS by construction (`OBS_VALUE = round(raw*scale,10)`) and spot-checked: SEN POV_NUM PL300/PL420 national totals = 3130000/6520000 (3.13/6.52 in millions, matches `POVNUM.SEN.*`); GNB = 700000.0000000001/1090000 (0.7/1.09, matches `POVNUM.GNB.*` within 1e-9 - the trailing residual traces to the source cell itself, which reads as text `0.70000000000000007`, not a computation bug).
- WP15.A6: PASS - GNB's column-wide WITHHOLD (`estimateCapital`, label `*`) leaves 0 rows with `URBANISATION=CAP`; the 4 SEN/GNB COMMENT rows' row counts match the wildcard-sheet column counts exactly (99 and 25, hand-computed and verified); every `O` row's comment starts with `LEGACY_EMPTY:`.
- WP15.A7: PASS - 0 mismatches between `SEX`/`AGE` and `CL_INDICATOR.stat_unit == "IND"` across all 3003 SEN rows (checked programmatically).
- WP15.A8: PASS - manifest has the 16 keys in the card's order, `precision = ROUNDED_2DP`, `status = DRAFT`, `n_rows` matches the data file, `survey_id`/`ref_area`/`time_period` match `SURVEYS.csv`.
- WP15.A9: PASS - two runs into separate temp `--out-root`s are byte-identical to each other and to the four committed files (`readBin` comparison).
- WP15.A10: PASS - no BOM, no CR byte, no `NA` cell, no `e+`/`e-` (checked byte-level with `readBin`/`readChar` on all four files).
- WP15.A11: PASS - `grep -i estimate` and `grep -E "National|ADM 1|ZAE|Departement"` on both files: 0 matches anywhere (not just outside comments). `grep -E "\bSEN\b|\bGNB\b"` matches only the literal `USAGE` string.
- WP15.A12: PASS - ran the converter against a temp copy with one `LEGACY_LABELS.legacy_label` appended with " EDITED"; exit code 1, message names the exact unmapped label text.

## Deviations           (what the card said, what you did, why)
- `csv_headers.csv` marks `N_OBS`/`N_POP` as `status = R` (required), but the card's own rule text says they "stay empty, because the workbooks do not have them." Followed the card (left them empty in every row) since it is the higher-authority document for this package; flagged under Questions.
- No other deviations. The wildcard-sheet set (`National`, `ADM 1`, `ZAE`) is never hardcoded; it is computed at run time as `sort(unique(LEGACY_COLUMNS$sheet[action == "MAP"]))`, per WP15.A11's documented-constant allowance.

## Questions            (contract doubts, and anything only the user can decide)
- `csv_headers.csv` status `R` vs the card's "stay empty" instruction for `N_OBS`/`N_POP` (see Deviations). Not blocking - the card is explicit and the produced files match every numbered acceptance check - but worth a contract fix so a future reader doesn't see it as a contradiction.

## Changelog line       (implementers only: the card's line, adjusted if needed)
Legacy converter; AFW360_HH_SEN_2021 and AFW360_HH_GNB_2021 (DRAFT).
