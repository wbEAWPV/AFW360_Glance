# WP08 verifier report
Branch: transition/wp08-plans-v1

## Files written        (path, and rows or bytes)
- `pipeline/acceptance/wp08_plans.R` (307 lines, 16,682 bytes): the acceptance script, one `check()` per WP08.A1-A8.
- `.docs/transition/reports/WP08-verifier-v1.md`: this report.

## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)
- WP08.A1 PASS: SERIES_PLAN rows=91, triage MAP rows=91, series_id/INDICATOR/MEASURE_QUALS/DEFINING_BREAKDOWN match the triage row-for-row, series_id unique and matches `^[A-Z0-9_.]+$`, nrow meets `SERIES.COUNT`.
- WP08.A2 PASS: TAB_PLAN (8 rows) equals `contract/tab_plan.csv` column-for-column and row-for-row with `status = "DRAFT"` appended; nrow meets `META.TAB_PLAN`.
- WP08.A3 PASS: `names()` of both SERIES_PLAN.csv and TAB_PLAN.csv equal the header order in `csv_headers.csv`.
- WP08.A4 PASS: with `meta` built from the contract seeds, `required_rows(meta,"SEN","2021")` = 3003 rows (meets `DATA.SEN.ROWS`), `required_rows(meta,"GNB","2021")` = 2366 rows (meets `GNB.MAPPED_CELLS`); both have a unique 18-column key and no empty cell in the 18 key columns.
- WP08.A5 PASS: SEX/AGE = `_Z` exactly on the 3003+2366 rows where the indicator's stat_unit != IND; the SEN row of `POP_HH_SH.HE_COUNT_0` under cut `QUINT` has `COMP_BREAKDOWN_1` starting `QUINT_` and `COMP_BREAKDOWN_2 = HE_COUNT_0`; the SEN row of `POV_HC.POVLINE_PL420.PPP_2021` under cut `TOTAL` has `MEASURE_QUAL_1 = POVLINE_PL420`, `MEASURE_QUAL_2 = PPP_2021`.
- WP08.A6 PASS: per-cut-id row counts equal `n_series (91) x cell_count` for both countries, using cell counts independently computed from the contract (`CL_COMP_BREAKDOWN`, `CL_GEO`, `TAB_PLAN.urbanisation`) which also match the card's literal numbers (TOTAL 1, URB 3, HHH_SEX 2, HHH_AGE 2, QUINT 5, ADM1 14/9, ZONES 6, AEZ 4); ZONES absent for GNB and AEZ absent for SEN, as required.
- WP08.A7 PASS: `testthat::test_dir(..., filter="plan")` ran 5 tests in `test-plan.R`, 0 failed, 0 errored; `build_plans.R --out-root <tempdir>` exits 0 and both output files are byte-identical to the committed `metadata/plans/SERIES_PLAN.csv` and `TAB_PLAN.csv` (compared via git blobs).
- WP08.A8 PASS: `make_data_fixture(tmp_root, ref_area="GNB", series_ids=c("POV_HC.POVLINE_PL420.PPP_2021","POP_HH_SH.HE_COUNT_0"))` on a seed-built temp root wrote a 52-row data file with the 26 DSD_COLUMNS in order, and a manifest (the one other file beside the data file) with exactly the 16 specified keys and `n_rows = 52`.

Verifier focus (by hand, not in the committed script): built an independent, from-scratch re-expansion of the required rows for GNB directly from SERIES_PLAN/TAB_PLAN/the contract codelists (its own cross-product, exclusion and slot-sort logic, not calling `required_rows()`), and compared its 18-column key set against `required_rows(meta,"GNB","2021")`'s key set. Both are 2366 rows, all keys unique, and the two sets are exactly equal (0 keys only in the manual expansion, 0 keys only in the actual output). No defect found.

## Deviations           (what the card said, what you did, why)
- The card's Read list covers `pipeline/R/io.R`, `codes.R`, `constants.R` (signatures only) but not `pipeline/tests/testthat/helper-temp-root.R`. WP08.A8's target, `make_data_fixture()` (in `helper-data-fixture.R`), calls `edit_csv()` at runtime, which is defined in `helper-temp-root.R` — a shared wave-1 test helper, not owned by WP08, that testthat normally sources alongside every other `helper-*.R` file in the directory. I looked at only its function-signature line (`edit_csv <- function(path, fn)`), the same way the card allows for io.R/codes.R/constants.R, and had the acceptance script source the whole file at run time so `make_data_fixture()` resolves. I did not read the WP08 implementer's own `helper-data-fixture.R`, `plan.R`, `build_plans.R` or `test-plan.R` before writing the script.
- `load_metadata()`'s exact directory-scanning convention is not covered by "signatures only," and WP08.A8 needs a real temp root with codelist CSVs it can find. Rather than reading its body, I black-box-tested it on a synthetic throwaway fixture (`metadata/codelists/CL_TEST.csv`, `metadata/plans/SOME_PLAN.csv` in a scratch tempdir, not part of the committed script) and confirmed it indexes CSVs recursively by file basename regardless of subfolder. I then used `metadata/codelists/` as the subfolder for the seed codelists in WP08.A8; this is consistent with that confirmed behavior.
- For WP08.A1-A7, `meta` is built as an in-memory list directly from the contract seeds (codes.csv, geo_codes.csv, label_triage.csv) plus the branch's own `metadata/plans/*.csv`, per the card's step 3, rather than via `load_metadata()` reading a directory — the codelist files it would need don't exist on this branch yet.

## Questions            (contract doubts, and anything only the user can decide)
None.

## Changelog line       (implementers only: the card's line, adjusted if needed)
None.

## Failures to fix   (numbered; for each: the check ID, the exact command or comparison, expected
                      against actual. Write "None" on PASS.)
None.
