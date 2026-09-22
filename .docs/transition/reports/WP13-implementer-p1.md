# WP13 patch report
Branch: transition/wp13-validator-rules-p1

## Files written
- `pipeline/R/validate_rules.R` (901 lines; +9/-1) -- fixed `.vc_h_for()`.
- `pipeline/tests/testthat/test-validate-rules.R` (426 lines; +41) -- added one regression test.
- `.docs/transition/reports/WP13-implementer-p1.md` (this report).

## Checks
- WP13.A1: PASS -- `errors=0 (total findings=48, rows=726)`.
- WP13.A2: PASS -- all six mutations give exactly their `check_id` (`RULE.AGG_SUM=TRUE(n=1); RULE.AGG_BRACKET=TRUE(n=6); RULE.SUM_TO_1_QUAL=TRUE(n=1); RULE.SUM_TO_1_BRK=TRUE(n=1); RULE.MONOTONE=TRUE(n=1); RULE.RANGE_0_1=TRUE(n=1)`).
- WP13.A3: PASS -- `COICOP 0.97 no-finding=TRUE; POV_NUM k=6 3130000/3120000 no-finding=TRUE` (was `FALSE` before the fix).
- WP13.A4: PASS -- `deviation==tolerance passes=TRUE; tolerance+0.001*scale fails=TRUE`.
- WP13.A5: PASS -- `agg_skipped=TRUE no_error_after_delete=TRUE closure_partial=TRUE no_error_partial_plan=TRUE`.
- WP13.A6: PASS -- `vc_rule_* found=9 all-empty-on-empty-ctx=TRUE; testthat files=15 failed=0 error=FALSE`.
- `Rscript pipeline/acceptance/wp13_validator-rules.R --root .`: all checks pass.

## Deviations
- Input item 1 (WP13.A3, `RULE.AGG_SUM` false positive with `tolerance=0.035` instead of `35000`): fixed. Root cause: `.vc_h_for(precision, scale)` (`pipeline/R/validate_rules.R`, was line 169-171) computed `ifelse(precision == "ROUNDED_2DP", 0.005 * scale, 0)`. `precision` is a single value per data file, while `scale` is a per-row vector (one value per required row, from `.vc_scale_for(scale_map, rr$series_id)`, called once per `(ref_area, time_period)` block covering every series in `SERIES_PLAN`, not just the series present in the fixture). `ifelse()`'s result takes the *shape of its `test` argument*: with `test` (`precision == "ROUNDED_2DP"`) of length 1, R's `ifelse` returns a length-1 result -- `0.005 * scale[1]` -- which then recycled the same single `h` across every row of that block, instead of multiplying each row's own scale. In the acceptance script's fixture (`new_temp_root()`, the full, unrestricted `SERIES_PLAN`), `scale[1]` came from whichever series `required_rows()` emits first, which has no `LEGACY_LABELS.scale` row (default 1) -- so `h = 0.005 * 1 = 0.005` for every row, including `POV_NUM.POVLINE_PL300.PPP_2021` (real scale `1000000`), giving `tolerance = 7 * 0.005 = 0.035` instead of `35000`. Fixed by recycling the `precision == "ROUNDED_2DP"` test to `scale`'s length before calling `ifelse()`, so every row's `h` uses its own scale. Verified: `.vc_series_scale()`/`.vc_scale_for()` themselves already resolved `1000000` correctly for that series when checked directly (`Rscript` probe against `metadata/plans/LEGACY_LABELS.csv`) -- the bug was purely in `.vc_h_for`'s vectorization, not in the scale lookup.
- Not in the input list, found while fixing: the existing unit test for this exact scenario (`WP13.A3: a POV_NUM parent of 3130000 with 6 children summing to 3120000 passes`, `pipeline/tests/testthat/test-validate-rules.R`) did not catch the bug, because `make_rules_root(series_ids = "POV_NUM.POVLINE_PL300.PPP_2021", ...)` restricts `SERIES_PLAN` to that one series, so `scale[1]` coincidentally *was* `POV_NUM`'s own scale. Added a new regression test, "a data file with more than one series' scale gives each row its own h, not the first row's", using two series with different scales (`POV_NUM.POVLINE_PL300.PPP_2021` = 1000000, `CONS_SH.COICOP_CP01` = 1) in the same fixture. Confirmed it fails (1 test failed) against the pre-fix `validate_rules.R` and passes against the fix.

## Questions
None.

## Changelog line
None (patch report; card's changelog line unchanged from the implementer report).
