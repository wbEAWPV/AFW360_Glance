# WP09 verifier report
Branch: transition/wp09-legacy-maps-v1

## Files written        (path, and rows or bytes)
- `pipeline/acceptance/wp09_legacy-maps.R` (405 lines, 19271 bytes)
- `.docs/transition/reports/WP09-verifier-v1.md` (this report)

## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)
- WP09.A1: PASS — LEGACY_LABELS.csv has 179 rows (matches `META.LEGACY_LABELS`); every (sheet, label) pair found in both raw workbooks (373 pairs after expanding `*` rows to National/ADM 1/ZAE) matches exactly one LEGACY_LABELS row, byte for byte.
- WP09.A2: PASS — LEGACY_COLUMNS.csv has 73 rows (matches `META.LEGACY_COLUMNS`); every (ref_area, sheet, column) triple in both raw workbooks matches exactly one row; every `GEO` on ADM 1/ZAE rows equals the code from `geo_codes.csv`; `estimateSAB` (GNB, ADM 1) maps to `GW08`; every `URBANISATION` and `COMP_BREAKDOWN` on National rows equals `legacy_national_columns.csv`.
- WP09.A3: PASS — the 91 `MAP` rows' `series_id` set equals the triage's 91 `MAP` `series_id`s exactly; `scale` matches the triage's value as a number for all 91; no cell of LEGACY_LABELS.csv contains scientific notation (checked with a digit-e-sign-digit pattern, which correctly ignores prose like "trade+transport").
- WP09.A4: PASS — the 4 rows with a `duplicate_of` or `assert_rule` (L031, L060, L063, L072) all target the `series_id` of a `MAP` row; each rule (2 `EQUALS`, 2 `ONE_MINUS`) was evaluated on the raw workbook cells of both SEN and GNB across National/ADM 1/ZAE (59 paired cells per rule) and holds within its tolerance (max deviation 0 for the three tol=0 rules, and exactly 0.02 — within `tol=0.02` — for the `ONE_MINUS` non-food-share rule).
- WP09.A5: PASS — LEGACY_OVERRIDES.csv has 12 rows, equal to `legacy_overrides.csv` row for row on `ref_area, sheet, column, legacy_label, action, reason`; every seed row (WITHHOLD and COMMENT) targets at least one cell that exists in the raw workbooks; expanding the WITHHOLD rows (with wildcards restricted to `MAP`-action labels) gives 98 distinct cells, matching `GNB.WITHHELD_CELLS`.
- WP09.A6: PASS — independently simulating "apply the three files to the raw workbooks" (own loop over `label_triage.csv` + `legacy_overrides.csv` + the raw workbooks, not the implementer's script) gives SEN = 3003 rows all non-empty (matches `DATA.SEN.ROWS`), GNB = 2268 rows (matches `GNB.DATA.ROWS`) of which 2229 non-empty (matches `GNB.DATA.ROWS.A`) and 39 empty (matches `GNB.DATA.ROWS.O`).
- WP09.A7: PASS — the headers of all three files equal `csv_headers.csv`; running `build_legacy_maps.R --root . --out-root <tempdir>` exits 0 and reproduces all three files byte for byte (identical md5sum) against the committed ones.

## Deviations           (what the card said, what you did, why)
- The card's A3 check reads "No cell of the file contains `e+`". A literal substring search for `e+` false-positives on ordinary prose in the `notes` column (row 90: "...trade+transport <= services..."). I implemented the check as a scientific-notation pattern (a digit immediately followed by `e`/`E`, then `+`/`-`, then a digit), which is what the surrounding CSV rule ("never scientific, `1000000` not `1e+06`") is actually about, and which correctly passes on the "trade+transport" row while still catching real scientific notation. This is a spelling-out of the check's intent, not a loosened check: I verified by hand that the only `e+` substring in the file is that one prose occurrence.

## Questions            (contract doubts, and anything only the user can decide)
None.

## Changelog line       (implementers only: the card's line, adjusted if needed)
None (verifier report).

## Failures to fix
None.
