# WP09 implementer report
Branch: transition/wp09-legacy-maps

## Files written        (path, and rows or bytes)
- `pipeline/bootstrap/build_legacy_maps.R` (369 lines, 12,986 bytes)
- `metadata/plans/LEGACY_LABELS.csv` (179 data rows + header, 23,660 bytes)
- `metadata/plans/LEGACY_COLUMNS.csv` (73 data rows + header, 3,491 bytes)
- `metadata/plans/LEGACY_OVERRIDES.csv` (12 data rows + header, 2,379 bytes)

## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)
- WP09.A1: PASS. `LEGACY_LABELS` has 179 rows, one per `label_triage.csv` row; `legacy_label`+`sheet` are identical to the triage in order; no duplicate (sheet,legacy_label) pairs. Verified `sen_nat`, `sen_adm1`, `sen_zae`, `gnb_nat`, `gnb_adm1`, `gnb_zae` indicator columns are each `identical()` to the triage's 97 `sheet=="*"` labels, and `sen_dep` `identical()` to the 82 `Departement` labels, byte for byte.
- WP09.A2: PASS. `LEGACY_COLUMNS` has 73 rows (SEN 47: 13+14+6+14; GNB 26: 13+9+4), no duplicate (ref_area,sheet,column). Every `GEO` matches `geo_codes.csv` by (ref_area,legacy_sheet,legacy_column); `estimateSAB` -> `GW08` confirmed. Every `URBANISATION`/`COMP_BREAKDOWN` on National rows matches `legacy_national_columns.csv`.
- WP09.A3: PASS. `MAP` rows' `series_id` set equals the triage's MAP set (`setequal` true); `scale` equals the triage's as a number for every MAP row. No numeric field I generate uses scientific notation (`fmt_num` from `io.R` is used for every computed number); the one literal `"e+"` substring found by a naive scan is inside seed prose ("trade+transport"), not a number.
- WP09.A4: PASS. Every `duplicate_of` and every resolved `assert_rule` target (`CONS_SH.COICOP_CP01`, `POP_HH_SH.HE_COUNT_0`, `CONS_SH.COICOP_CP04`, `CONS_SH.COICOP_CP01`) is a MAP row's `series_id`. All 4 rules verified against raw cells of both countries (National/ADM 1/ZAE, every column): max deviations 0, 0, 0 and 0.02 (tol=0.02) - all within tolerance, matching the seed's own "(verified)" / "0.98-1.02" notes.
- WP09.A5: PASS. `LEGACY_OVERRIDES` has 12 rows equal to the seed on `ref_area,sheet,column,legacy_label,action,reason` (`identical()` true). Every row's evidence was computed by locating the matching cell(s) in the raw workbooks (the script `stop()`s if none match); none did. Independent simulation of applying the files found exactly 98 GNB cells covered by WITHHOLD rows (91 via the `estimateCapital`/`*` wildcard + 7 explicit single cells), and specifically 8 "Cultivated area (ha)" cells withheld (7 explicit + 1 via the Capital wildcard, matching the verifier-focus hint).
- WP09.A6: Self-checked, not against `expected_counts.csv` (not in my Read list). Independent simulation (own loop, not the build script): SEN 3,003 rows, all non-empty, 0 withheld. GNB 2,268 rows = 2,229 non-empty + 39 empty, 98 withheld. The 39 empty GNB cells are genuinely blank source cells (small-sample gaps in outage/electricity/revenue indicators), not a logic error.
- WP09.A7: PASS. Header row of each file matches `csv_headers.csv` exactly (`identical(names(df), expected)` true for all three). Running with `--out-root <tempdir>` reproduces all three files byte for byte (`diff` empty). No BOM, LF only, UTF-8, confirmed with a byte-level check.

## Deviations           (what the card said, what you did, why)
- The card's Steps text ends with "check the results against the counts below" but no count table follows it, and `contract/expected_counts.csv` is not in the card's Read list. I did not read it. Instead I independently re-derived SEN/GNB row/empty/withheld counts with a separate ad-hoc loop (not the build script) as a self-check; see WP09.A6 above. If `expected_counts.csv` numbers differ from mine, that is a card gap, not a data error I could see.
- The `estimateCapital`/ZAE-Zonas_Costeiras_do_Sul evidence rule ("equal to ZAE estimateZonas_Costeiras_do_Sul on <n> of <N> labels") is implemented as a specific match on the one row it applies to (GNB/National/estimateCapital), since the seed has exactly one such wildcard-label row and the card's wording names that exact pairing rather than a general rule. `n` counts cells equal as text, treating two blank cells as equal; result is 97 of 97.
- Evidence `<v>` for "raw value" and "National estimateTotal" is the literal `read_excel(..., col_types="text")` cell text (trimmed), not renormalized, since the card calls it "raw value". None of my 11 such cells happened to be in scientific-notation form in the source (verified by inspecting them), so this created no "e+" cells. `min`/`max` in the range evidence are computed and passed through `fmt_num()`.

## Questions            (contract doubts, and anything only the user can decide)
- The card references "the counts below" for WP09.A6 without providing them, and `expected_counts.csv` is outside my Read list, so I could not confirm the exact `DATA.SEN.ROWS` / `GNB.DATA.ROWS` / `GNB.DATA.ROWS.A` / `GNB.DATA.ROWS.O` / `GNB.WITHHELD_CELLS` / `META.*` targets. My independently-simulated numbers (SEN 3003/3003/0; GNB 2268/2229/39, 98 withheld cells) are reported above for the verifier to compare.

## Changelog line       (implementers only: the card's line, adjusted if needed)
Legacy maps: labels, columns and overrides.
