# WP15 verifier report
Branch: transition/wp15-converter-v1

## Files written        (path, and rows or bytes)
- `pipeline/acceptance/wp15_converter.R` (475 lines, 23,569 bytes) -- the acceptance script, one `check()` per card check ID (WP15.A1-WP15.A12).
- `.docs/transition/reports/WP15-verifier-v1.md` (this file).

## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)
- WP15.A1: PASS -- both `data/AFW360_HH_SEN_2021.csv` and `data/AFW360_HH_GNB_2021.csv` headers equal `metadata/structure/DSD_AFW360_HH.csv`'s `id` column, in order (26 columns).
- WP15.A2: PASS -- SEN has 3003 rows (matches `DATA.SEN.ROWS`), all `OBS_STATUS = A`.
- WP15.A3: PASS -- GNB has 2268 rows (matches `GNB.DATA.ROWS`), 2229 `A` (`GNB.DATA.ROWS.A`), 39 `O` (`GNB.DATA.ROWS.O`).
- WP15.A4: PASS -- the 18-column key is unique and non-empty in both files.
- WP15.A5: PASS -- an independent rebuild of every mapped cell from `LEGACY_LABELS`, `LEGACY_COLUMNS`, `SERIES_PLAN`, `SURVEYS` and the two codelists (slot-sorted breakdowns/qualifiers, `_T`/`_Z` padding, own reader, no `pipeline/R/` sourced) traced all 5232 `A` rows (3003 SEN + 2229 GNB) back to their workbook cells; every `OBS_VALUE / scale` equals the source cell within 1e-9, and the key sets match exactly (no extra or missing `A` rows on either side).
- WP15.A6: PASS -- every `O` row's `OBS_COMMENT` starts with `LEGACY_EMPTY:`; the withheld-key set independently rebuilt from `LEGACY_OVERRIDES` (98 GNB cells: 91 from the `estimateCapital`/`*` wildcard plus 7 more `Cultivated area (ha)` cells) is disjoint from both output files; the 4 cells matched by a `COMMENT` override (3 SEN, 1 GNB) all carry the expected `obs_comment` text, appended after the `LEGACY_EMPTY:` prefix where the cell is also empty.
- WP15.A7: PASS -- for every row in both files, `SEX` and `AGE` equal `_Z` exactly when the row's `INDICATOR`'s `CL_INDICATOR.stat_unit` is not `IND`, and `_T` otherwise (checked against every row, not a sample).
- WP15.A8: PASS -- both manifests have the 16 keys in the specified order; `dataflow`, `dsd_version`/`metadata_version` (= `metadata/VERSION` = 0.1.0), `ref_area`, `time_period`, `source_type`, `survey_id`, `precision = ROUNDED_2DP`, `n_rows` and `status = DRAFT` all match their sources.
- WP15.A9: PASS -- two fresh runs of `Rscript pipeline/convert_legacy.R --root . --country ALL --timestamp 2026-01-01T00:00:00Z --out-root <tempdir>` produced byte-identical files to each other and to the four committed blobs at `HEAD` (`git cat-file blob`).
- WP15.A10: PASS -- the four committed blobs contain no `[0-9][eE][+-][0-9]` scientific-notation pattern, no cell equal to the literal string `NA`, no BOM, no CR byte.
- WP15.A11: PASS -- with comment lines stripped, `pipeline/convert_legacy.R` and `pipeline/R/convert_tables.R` contain no `estimate`, no legacy label text (checked against all 179 `LEGACY_LABELS.legacy_label` values), no sheet name (`National`, `ADM 1`, `ZAE`, `Departement` -- outside the one allowed documented sheet-wildcard constant, which this implementation does not in fact use), and no `SEN`/`GNB` token outside the `--country SEN|GNB[|ALL]` usage lines. In practice neither file contains any of these literals at all -- the implementation derives everything from the metadata plans.
- WP15.A12: PASS -- in a temporary copy of `pipeline/`, `metadata/`, `content/` and `data_raw/tables/Tables_SEN.xlsx` with one `MAP` row's `legacy_label` altered, `Rscript pipeline/convert_legacy.R --root <tempcopy> --country SEN --out-root <tempdir>` exits non-zero and its output names the now-unmapped original label text.

## Deviations           (what the card said, what you did, why)
- The card's WP15.A11 allows "a documented constant that expands the sheet wildcard from the distinct `sheet` values of `LEGACY_COLUMNS` with `action = MAP`" as an exception to the no-sheet-name rule. The acceptance script implements this exception (excluding from the sheet-name search any code line that contains `National`, `ADM 1` and `ZAE` together but not `Departement`) so the check stays correct if a future revision of the converter adds such a constant. In the current implementation this exception is not exercised (no sheet names appear in the code at all), which was confirmed by inspecting `pipeline/R/convert_tables.R` and `pipeline/convert_legacy.R` directly after the script was written.
- WP15.A11's country-code exclusion is implemented as: any code line containing the literal substring `SEN|GNB` is treated as the usage line and excluded before searching the remainder for a standalone `SEN`/`GNB` token. This matches the card's CLI signature (`--country SEN|GNB|ALL`) exactly; the implementer's two usage lines both contain that substring.

## Questions             (contract doubts, and anything only the user can decide)
None.

## Changelog line       (implementers only: the card's line, adjusted if needed)
None (verifier report).

## Failures to fix   (numbered; for each: the check ID, the exact command or comparison, expected
                     against actual. Write "None" on PASS.)
None.
