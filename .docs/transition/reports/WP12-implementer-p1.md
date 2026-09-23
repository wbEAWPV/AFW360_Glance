# WP12 patch agent report
Branch: transition/wp12-validator-coverage-p1
## Files written        (path, and rows or bytes)
- `pipeline/tests/testthat/test-validate-coverage.R` (380 lines before, 355 after): removed the dead `fix_manifest_long()` workaround (10 lines) and its one call site (1 line); rewrote the file header comment (was 11 lines describing a "KNOWN INFRASTRUCTURE MISMATCH", now 5 lines describing the manifest as long-form, matching what `make_data_fixture()` actually writes).

## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)
- WP12.A1: PASS — clean GNB fixture (43 rows): 0 ERROR findings.
- WP12.A2: PASS — all 9 mutations give exactly their expected `check_id` (COVER.MISSING, COVER.EXTRA, COVER.WITHHELD_PRESENT, VALUE.RANGE, VALUE.NUMERIC, VALUE.STATUS_EMPTY x2, VALUE.LEGACY_EMPTY, COVER.MANIFEST, COVER.SURVEY).
- WP12.A3: PASS — withheld GNB=98 (want 98), withheld SEN=0 (want 0), required-withheld GNB=2268 (want 2268).
- WP12.A4: PASS — empty ctx$data: 0 rows returned from every function.
- WP12.A5: PASS — 18 tests in test-validate-coverage.R: 0 failed, 0 errored.
- Full run of `pipeline/acceptance/wp12_validator-coverage.R --root .`: "All checks passed."
- `testthat::test_file('pipeline/tests/testthat/test-validate-coverage.R')`: 18/18 test_that blocks pass, 0 failures.

## Deviations           (what the card said, what you did, why)
- Integrator line "WP12: acceptance WP12.A5 - 1 - test-validate-coverage.R: 33/18 test-blocks failed": confirmed root cause myself before touching anything. Built a fresh GNB fixture with `make_data_fixture()` in a temp root (outside any test file) and inspected the manifest it wrote: 16 rows x 2 cols, `key`/`value` columns, e.g. `dataflow=AFW360_HH`, `precision=ROUNDED_2DP` — the contract's long key/value form, matching WP08's fix and contradicting the stale comment in my own test file that claimed the helper still wrote wide form. Re-ran the unmodified test file first and reproduced the reported failure pattern (37 ERROR findings on the "clean" fixture instead of 0, `COVER.MANIFEST` and other spurious check_ids polluting single-mutation tests) — consistent with a manifest whose `key`/`value` header was itself misread as 16 wide columns by `fix_manifest_long()`, destroying `status`, `precision`, `n_rows`, etc.
- Per the card's "Confirm the diagnosis" instruction: since the manifest is confirmed long-form, removed the dead `fix_manifest_long()` function (lines ~40-51) and its sole call site (in `build_clean_gnb_fixture()`), and corrected the stale file-header comment that described the manifest as wide and referenced a since-superseded "Questions" item. Kept `set_manifest()` unchanged, since it already assumes long form and was correct. No test was weakened or deleted — all 18 test_that blocks are unchanged in intent and now pass unmodified in body.
- Touched only `pipeline/tests/testthat/test-validate-coverage.R`, the one owned file affected. `pipeline/R/validate_coverage.R` and `pipeline/R/validate_values.R` needed no changes — they already read manifests via `build_ctx()`, which was never the problem.
- Did not edit `pipeline/tests/testthat/helper-data-fixture.R` (WP08's owned file, already fixed) or any acceptance script.

## Questions             (contract doubts, and anything only the user can decide)
None.

## Changelog line       (implementers only: the card's line, adjusted if needed)
None.
