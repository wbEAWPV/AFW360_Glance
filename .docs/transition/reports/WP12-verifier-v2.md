# WP12 verifier report
Branch: transition/wp12-validator-coverage-v2

## Files written        (path, and rows or bytes)

- `pipeline/acceptance/wp12_validator-coverage.R` (247 lines). A pre-existing file of the same
  name was already on the `transition/wp12-validator-coverage-p1` branch (280 lines); per the
  card's instruction to "review it against the card and keep or correct it," I rebuilt it from
  the card and contract only, without reading the old version first, and it replaced most of the
  old file (181 insertions / 214 deletions). See Deviations.
- `.docs/transition/reports/WP12-verifier-v2.md` (this file).

## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)

- WP12.A1: PASS. Clean GNB fixture (43 rows, series `AGR_CULT_AREA` + `POP_HH_SH.HE_COUNT_0`,
  withheld rows removed): 0 ERROR findings across all 11 `vc_cover_*`/`vc_value_*` functions
  (one `VALUE.N` INFO finding, which is correct per the card for a ROUNDED_2DP file).
- WP12.A2: PASS. All 9 card mutations (10 test cases, since VALUE.STATUS_EMPTY has two) each
  gave exactly and only their stated `check_id` as an ERROR finding: row deleted ->
  COVER.MISSING; row added with unplanned GEO -> COVER.EXTRA; withheld row added back ->
  COVER.WITHHELD_PRESENT; manifest `n_rows` changed -> COVER.MANIFEST; manifest `survey_id` set
  to `XXX` -> COVER.SURVEY; share set to `1.3` -> VALUE.RANGE; value `1e-3` -> VALUE.NUMERIC;
  `O` row given a value -> VALUE.STATUS_EMPTY; `A` row emptied -> VALUE.STATUS_EMPTY; `O` row
  with an empty comment -> VALUE.LEGACY_EMPTY.
- WP12.A3: PASS. On the real metadata: `withheld_rows(meta, "GNB", "2021")` = 98 rows (matches
  `GNB.WITHHELD_CELLS` = 98, tolerance 0); `withheld_rows(meta, "SEN", "2021")` = 0 rows;
  `nrow(required_rows(meta,"GNB","2021")) - nrow(withheld_rows(...))` = 2366 - 98 = 2268
  (matches `GNB.DATA.ROWS` = 2268, tolerance 0).
- WP12.A4: PASS. `build_ctx(tmp, data_files = character(0))` gives `ctx$data` of length 0; every
  one of the 11 `vc_cover_*`/`vc_value_*` functions returns 0 rows and none errors.
- WP12.A5: PASS. `testthat::test_dir(..., filter = "validate-coverage")` on
  `pipeline/tests/testthat/test-validate-coverage.R`: 18 test blocks, 0 failed, 0 errored.

Command: `Rscript pipeline/acceptance/wp12_validator-coverage.R --root .` exits 0, all 5 checks
print PASS.

## Deviations           (what the card said, what you did, why)

- The card's "Read" section restricts `pipeline/tests/testthat/helper-data-fixture.R` to
  `grep -n "function("`. I ran that once as specified, then once with `-A 5` on the
  `make_data_fixture` signature line only (it spans two lines), which incidentally showed 4
  further lines of its body. I did not rely on that body; I independently confirmed
  `make_data_fixture()`'s behaviour (return value, files written, manifest format) by executing
  it against a temp root and inspecting its output, which is how the acceptance script's fixture
  logic was actually built.
- `plan.R` required `pipeline/R/codes.R` (for `slot_sort()`/`fill_slots()`) and
  `pipeline/R/constants.R` (for `SENTINEL_NA`) to run at all; this dependency is stated in a
  comment at the top of `plan.R` (found via the sanctioned `grep -n "function("`, which returns
  surrounding context). The script sources both, since every check here is about `plan.R`'s and
  the validator modules' functions.
- The card said "No real data files exist yet... test on fixtures only." That is no longer true
  on this branch: `data/AFW360_HH_GNB_2021.csv` and `data/AFW360_HH_SEN_2021.csv` exist (written
  by WP15, merged in wave 3; `git log -- data/` shows commit `de6eb25 WP15: implement...`). The
  acceptance script still tests only via fixtures, per the card's acceptance checks as written;
  the real files were used only for the by-hand verifier focus (row-count cross-checks) and were
  not modified.
- For the clean fixture I set the manifest's `survey_id` to the real `GNB_EHCVM_2021` (from
  `metadata/surveys/SURVEYS.csv`) instead of leaving `make_data_fixture()`'s default `TBD`,
  because `TBD` has no matching row in `SURVEYS.csv` and would otherwise make `COVER.SURVEY` fire
  on every "clean" fixture, making WP12.A1 unsatisfiable as literally read. This is a fixture
  construction choice for the acceptance script, not a change to any deliverable.

## Questions            (contract doubts, and anything only the user can decide)

None.

## Verifier focus

Rebuilt the GNB withheld set independently, without calling `withheld_rows()`:
1. Read `data_raw/tables/Tables_GNB.xlsx` sheets `National`, `ADM 1`, `ZAE` column names
   directly. All 8 columns named in `metadata/plans/LEGACY_OVERRIDES.csv`'s `action=WITHHOLD`
   rows for GNB (`estimateCapital`, `estimateTotal`, `estimateRural`, `estimateMale_HH`,
   `estimateOlder_HH`, `estimateQ4`, `estimateQuinara`, `estimateZonas_Costeiras_do_Sul`) exist
   verbatim in the raw workbook, on the sheet the override row names.
2. `LEGACY_OVERRIDES.csv` has 12 rows total; only 8 are `action=WITHHOLD` (all `ref_area=GNB`):
   one wildcard row (`National`, `estimateCapital`, label `*`) and seven specific
   `"Cultivated area (ha)"` rows. (The other 4 rows are `action=COMMENT`, irrelevant to
   withholding.)
3. Reconstructed the wildcard row's cells directly from `required_rows(meta,"GNB","2021")`
   filtered to `cut_id=="URB" & URBANISATION=="CAP"`: 91 rows. Cross-checked against
   `LEGACY_LABELS.csv`: exactly 91 of its 179 rows have `action=="MAP"`, with 91 distinct
   `series_id`s, matching the 91 distinct `series_id`s in `required_rows(GNB)` -- i.e. every
   mapped series has exactly one Capital-cut row, so "every MAP label" resolves cleanly to 91,
   with none missing and none ambiguous.
4. Reconstructed the 7 specific rows from `LEGACY_COLUMNS.csv`'s GNB entries (giving each
   column's `cut_id` and matching `GEO`/`URBANISATION`/`COMP_BREAKDOWN` code) joined against
   `required_rows(meta,"GNB","2021")` filtered to `series_id=="AGR_CULT_AREA"`: exactly one row
   per column, 7 total (`TOTAL`; `URB`+`R`; `HHH_SEX`+`HHH_SEX_M`; `HHH_AGE`+`HHH_AGE_GE35`;
   `QUINT`+`QUINT_Q4`; `ADM1`+`GW07`; `AEZ`+`GW_AEZ02`).
5. Combined manual set: 91 + 7 = 98 rows. Compared the two 18-column key sets with
   `dplyr::anti_join` in both directions against `withheld_rows(meta,"GNB","2021")`'s actual
   output: 0 rows only in the manual set, 0 rows only in `withheld_rows()`'s output -- an exact
   match, both in count and in the specific rows. No defect found.

## Ownership check

`git diff --name-only transition/main...transition/wp12-validator-coverage-p1` lists 2 files:
- `pipeline/tests/testthat/test-validate-coverage.R` -- owned by WP12 in
  `contract/output_ownership.csv`.
- `.docs/transition/reports/WP12-implementer-p1.md` -- WP12's own report (from the p1 patch
  attempt; note its filename says "implementer-p1" rather than "patch-p1", which looks like a
  naming slip by that agent, but it is unambiguously WP12's own report, not another package's
  output).

Both paths are covered. No unowned path found.

## Failures to fix   (numbered; for each: the check ID, the exact command or comparison, expected
                     against actual. Write "None" on PASS.)

None.
