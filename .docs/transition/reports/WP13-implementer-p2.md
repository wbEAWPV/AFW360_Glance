# WP13 patch agent report
Branch: transition/wp13-validator-rules-p2

## Files written
- `pipeline/tests/testthat/test-validate-rules.R` (427 -> 409 lines; 6 insertions, 24 deletions)

## Checks
- WP13.A1: PASS (errors=0; total findings=48, rows=726)
- WP13.A2: PASS (AGG_SUM/AGG_BRACKET/SUM_TO_1_QUAL/SUM_TO_1_BRK/MONOTONE/RANGE_0_1 each triggered as expected)
- WP13.A3: PASS (COICOP 0.97 no-finding; POV_NUM k=6 3130000/3120000 no-finding)
- WP13.A4: PASS (deviation==tolerance passes; tolerance+0.001*scale fails)
- WP13.A5: PASS (AGG_SKIPPED/no ERROR after delete; CLOSURE_PARTIAL/no ERROR for partial plan)
- WP13.A6: PASS (vc_rule_* found=9, all empty on empty ctx=TRUE; testthat files=15 failed=0 error=FALSE)
- `pipeline/acceptance/wp13_validator-rules.R --root .`: **All checks passed.**
- `testthat::test_file('pipeline/tests/testthat/test-validate-rules.R')`: 15/15 test blocks pass, 0 failed, 0 error (includes the p1 scale-recycling regression test, test #10, unchanged and passing).

## Deviations

Input item -> what was done:

1. "The wave-3 integrator's line ... 4/15 files failed" -> Verified the cause myself (see below), then fixed it. After the fix, both the acceptance script and `test_file()` report 15/15 passing, 0 failures.

2. "Verify [the scout's finding] yourself" -> Built one fixture with `make_data_fixture()` in a temp directory outside git (via `Rscript` against the worktree). Confirmed the helper now writes the manifest as 16 rows x 2 cols in long key/value form (`key`,`value` header; `precision` = `ROUNDED_2DP` at row 8), exactly as WP08's fix and the helper's own header comment (lines 53-59) describe. Then applied the test file's own `fix_manifest_format()` to that correct manifest and reproduced the scout's exact corruption: the 16x2 long-form manifest collapsed to a 2x2 manifest with rows `key/dataflow` and `value/AFW360_HH`, discarding `precision` and every other field. This matches the scout's BEFORE/AFTER evidence exactly, confirming the workaround is now actively harmful against the fixed helper.

3. "If [the manifest] is long key/value form, remove the dead workaround and its call site so your tests use the manifest as the helper writes it, and correct any stale comment that still describes the manifest as wide." -> Removed `fix_manifest_format()` (was lines 59-68) and its single call site inside `make_rules_root()` (was line 79). Replaced the stale doc comment above it (which asserted `make_data_fixture()` "writes its manifest as one row of named columns") with a short comment on `make_rules_root()` itself, stating that `make_data_fixture()` already writes the contract's long key/value form and that `build_ctx()` reads it directly -- no rewrite needed. No other reference to `fix_manifest_format` existed anywhere in `pipeline/` outside this file (checked with `grep -rn`); `test-validate-core.R`'s unrelated `.fix_manifest_format()` belongs to WP11 and was left untouched.

4. "Do not weaken or delete a test to get a pass." -> No test assertion was changed, weakened, or removed. Only the now-dead manifest-rewriting helper and its call were deleted; every `test_that()` block and its expectations are unchanged.

5. "Note on your own history: [p1's `.vc_h_for()` scale-recycling fix] ... must survive this patch untouched." -> Confirmed by inspection (`grep -n "vc_h_for\|ifelse(precision\|scale\[1\]" pipeline/R/validate_rules.R`) and by `git diff --stat`, which shows only `test-validate-rules.R` touched. `pipeline/R/validate_rules.R` is unmodified. The p1 regression test ("a data file with more than one series' scale gives each row its own h, not the first row's", test-validate-rules.R) is untouched and passing.

## Questions
None.

## Changelog line
Not applicable (patch agent, not implementer).
