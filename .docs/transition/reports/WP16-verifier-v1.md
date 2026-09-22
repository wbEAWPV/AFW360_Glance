# WP16 verifier report
Branch: transition/wp16-reconcile-v1

## Files written
- `pipeline/acceptance/wp16_reconcile.R` (263 lines)
- `.docs/transition/reports/WP16-verifier-v1.md` (this report)

## Checks
- WP16.A1: PASS -- on a temp root loaded with data files built from the converted-cell rows of `expected_rows()`, `pipeline/reconcile.R` exits 0; cells.csv holds 4349 SEN rows (expect `CELLS.SEN_National+CELLS.SEN_ADM1+CELLS.SEN_ZAE+CELLS.SEN_Departement` = 4349) and 2522 GNB rows (expect `CELLS.GNB_National+CELLS.GNB_ADM1+CELLS.GNB_ZAE` = 2522); every result is `OK` and none is `ORPHAN`.
- WP16.A2: PASS -- converted cells: SEN 3003 (= `DATA.SEN.ROWS`), GNB 2268 (= `GNB.DATA.ROWS`); withheld cells: GNB 98 (= `GNB.WITHHELD_CELLS`); duplicate+derived+skipped on the three sheets: SEN 198, GNB 156, both matching the arithmetic `(three-sheet CELLS.* total) - converted (- withheld for GNB)` computed from `expected_counts.csv` check IDs.
- WP16.A3: PASS -- all six mutations (changed value, deleted row, duplicated row, row added for a withheld cell, row with an unplanned key, O row given a value) produced exit 1 and, respectively, `MISMATCH`, `MISSING_ROW`, `DUPLICATE_ROW`, `WITHHELD_PRESENT`, a report mentioning `ORPHAN`, and `MISMATCH`.
- WP16.A4: PASS -- cells.csv header is exactly `ref_area, sheet, legacy_label, column, class, result, source_value, data_value, row_key` (the card's literal list) and has 6871 rows = SEN 4349 + GNB 2522 total source cells.
- WP16.A5: PASS -- `pipeline/reconcile.R`, `pipeline/R/reconcile.R` and `pipeline/tests/testthat/test-reconcile.R` contain no reference to `convert_tables`, `convert_legacy` or `required_rows`, and neither does their git log (`git log -p` on those three paths); `testthat::test_dir(..., filter="reconcile")` ran 11 tests, 0 failed, 0 warnings.

## Deviations
- **Fixture generation for A1-A3.** The card's Read section restricts `LEGACY_LABELS`/`LEGACY_COLUMNS`/`LEGACY_OVERRIDES`/`SERIES_PLAN`/`SURVEYS` to `head()`/`nrow()`, which rules out reimplementing the full key-building algorithm for ~6871 cells inside the acceptance script. Step 2 of the card explicitly assigns that independent check to the verifier instead ("The verifier tests `expected_rows()` against the raw workbook"), separate from the implementer's own self-consistency tests. I followed that split: the acceptance script sources `pipeline/R/reconcile.R` only to call `source_cells()`/`expected_rows()` and build a self-consistent input fixture (the same method Step 3 describes: "data files ... generated from `expected_rows()`"); every PASS/FAIL verdict is then read back off the compiled CLI's own `report.md`/`cells.csv`, compared against `contract/expected_counts.csv`, never against `expected_rows()`'s return value directly. The independent check of `expected_rows()` itself against the raw workbook is the hand-run "Verifier focus" below.
- **WP16.A2's "198"/"156".** `expected_counts.csv` only carries these numbers embedded in the text-valued rows `SOURCE.SEN.ACCOUNTING`/`SOURCE.GNB.ACCOUNTING` ("3201 = 3003 + 198"), not as clean numeric check IDs. The script instead derives them arithmetically from `CELLS.SEN_National`+`CELLS.SEN_ADM1`+`CELLS.SEN_ZAE` minus `DATA.SEN.ROWS` (and the GNB equivalent minus `GNB.WITHHELD_CELLS` too), all looked up by check_id, so nothing is hard-coded.
- **WP16.A4's column list.** Taken verbatim from the card's prose (line 64), not from `contract/csv_headers.csv`, which has no entry for this reconciliation CSV.
- **WP16.A5 grep scope.** Scoped the "neither the code" grep to WP16's three owned files rather than the whole repo, since `.docs/transition/packages/WP16.md` itself names `required_rows`/`convert_tables`/`convert_legacy` in its prose and would false-positive a repo-wide grep. The acceptance script's own path is never in the grep target list, so no self-match immunity was needed, but the script still documents why.

## Questions
None.

## Verifier focus
20 converted cells were sampled (stratified across both countries and all three mapped sheets -- National, ADM 1, ZAE; the Departement sheet has no converted cells, all its columns are column-level `SKIP`). For each, I re-read the raw cell from the workbook with `readxl::read_excel(..., col_types="text")` independently of `expected_rows()`, and independently rebuilt its expected key by hand from `LEGACY_COLUMNS` (GEO/URBANISATION/breakdown), `LEGACY_LABELS` (series_id), `SERIES_PLAN` (INDICATOR/qualifiers/defining breakdown), and `CL_INDICATOR.stat_unit` (SEX/AGE). All 20 matched `expected_rows()` exactly: raw value, GEO/URBANISATION, INDICATOR, and SEX/AGE. Breakdown- and qualifier-slot ordering was checked separately for three multi-dimension cases (`HHH_AGE_LT35`+`HEO_SEX_F`, `COICOP_CP01`+`ACQ_PURCH`, `HHH_SEX_M`) against `CL_BRK_VAR.slot_order`/`CL_QUAL_VAR.slot_order`; all placed in the correct slot. Independence from the converter's code (A5) is confirmed structurally (no `convert_tables`/`convert_legacy`/`required_rows` reference anywhere in WP16's code or its git log). No defect found.

## Ownership check
`git diff --name-only transition/main...transition/wp16-reconcile` lists four paths:
- `pipeline/R/reconcile.R` -- owned by WP16 (`contract/output_ownership.csv` row 113)
- `pipeline/reconcile.R` -- owned by WP16 (row 112)
- `pipeline/tests/testthat/test-reconcile.R` -- owned by WP16 (row 114)
- `.docs/transition/reports/WP16-implementer.md` -- WP16's own report

No unowned path.

## Changelog line
None.

## Failures to fix
None.
