# WP13 verifier report
Branch: transition/wp13-validator-rules-v3

## Files written
- pipeline/acceptance/wp13_validator-rules.R (already on the branch from the v1 verifier; reviewed and corrected, not rewritten from scratch; ~373 lines)
- .docs/transition/reports/WP13-verifier-v3.md (this report)

## Checks
- WP13.A1: PASS - `Rscript pipeline/acceptance/wp13_validator-rules.R --root .` -> `errors=0 (total findings=48, rows=726)` on the consistent fixture (POV_NUM x2, POV_HC x2, 13 CONS_SH.COICOP_*, 5 POP_HH_SH.HE_COUNT_*, every cut simultaneously self-consistent).
- WP13.A2: PASS - each of the six mutations gave exactly its check_id: `RULE.AGG_SUM=TRUE(n=1); RULE.AGG_BRACKET=TRUE(n=6); RULE.SUM_TO_1_QUAL=TRUE(n=1); RULE.SUM_TO_1_BRK=TRUE(n=1); RULE.MONOTONE=TRUE(n=1); RULE.RANGE_0_1=TRUE(n=1)`. (AGG_BRACKET's n=6 is one finding per one series' 6 non-TOTAL cuts, all correctly RULE.AGG_BRACKET - not a bug.)
- WP13.A3: PASS - COICOP cell summing to 0.97 gives no RULE.SUM_TO_1_QUAL finding (tolerance 13 x 0.005 x 1 = 0.065); a POV_NUM parent of 3130000 with the SEN ZONES cut's real k=6 children summing to 3120000 gives no RULE.AGG_SUM finding (tolerance (6+1) x 0.005 x 1e6 = 35000). k=6 was confirmed against the real TAB_PLAN/SERIES_PLAN, not assumed.
- WP13.A4: PASS - a deviation of exactly the tolerance (0.065 on a COICOP cell) passes; tolerance + 0.001 x scale (0.066) fails with a RULE.SUM_TO_1_QUAL ERROR.
- WP13.A5: PASS (after correcting the second case - see Deviations) - deleting one POV_NUM child gives `WARN RULE.AGG_SKIPPED` and no ERROR for that parent/cut; the real POP_SH.EMP_STATUS_EMPLOYED series (genuinely partial: CL_COMP_BREAKDOWN has 2 EMP_STATUS categories but SERIES_PLAN defines a series for only 1) gives `INFO RULE.CLOSURE_PARTIAL` and no ERROR.
- WP13.A6: PASS - all 9 `vc_rule_*` functions return zero rows on a ctx built with `data_files = character(0)`; `test_dir(..., filter = "validate-rules")` -> 15/15 tests passed, 0 failed, 0 errors (this independently reproduces the "15/15" the p2 report claims, from a script that does not read that report).

Full run: `Rscript pipeline/acceptance/wp13_validator-rules.R --root .` -> "All checks passed." (exit 0).

Verifier focus (by hand, independent of the acceptance script's own cases): built two fresh fixtures directly against `pipeline/R/validate_rules.R`'s functions.
- AGG_SUM, `POV_NUM.POVLINE_PL420.PPP_2021`, cut `HHH_AGE` (k=2, confirmed against the real plan), parent=5,000,000, scale=1e6 (confirmed in LEGACY_LABELS), precision ROUNDED_2DP: h = 0.005 x 1e6 = 5000, tolerance = (k+1) x h = 15000. A deviation of exactly 15000 gave 0 `RULE.AGG_SUM` ERROR findings; 16000 (tolerance + 0.001 x scale) gave 1, with message `sum=5016000 parent=5000000 deviation=16000 tolerance=15000` - the boundary matches the hand computation exactly.
- Closure, `SUM_TO_1_OVER_BRK` over `POP_HH_SH.HE_COUNT_*` (k=5, scale=1): h = 0.005, tolerance = k x h = 0.025. A group sum deviating by exactly 0.025 gave 0 `RULE.SUM_TO_1_BRK` findings; 0.026 gave 1.
- Read `pipeline/R/validate_rules.R` (in scope once the acceptance script was written) to confirm the p1 scale-recycling fix is still in place: `.vc_scale_for(scale_map, rr$series_id)` and `rr$.scale <- scale` (line 259-266) compute one scale value per row from each row's own `series_id`, and `.vc_h_for()` carries an explicit comment on why `precision`'s test must be `rep_len()`-expanded to `scale`'s length before `ifelse()`, naming the exact bug ("recycled across every row instead of multiplying each row's own scale"). `vc_rule_agg_sum` uses `parent$.h` (per-series) and `.vc_closure_walk` uses `grp_rows$.scale[1]`/`grp_rows$.h[1]` (per-group's own row) - neither is a fixed first-row-of-the-whole-table value. `pipeline/tests/testthat/test-validate-rules.R` (line 264) still carries the two-series regression test asserting `h == 5000`, POV_NUM's own scale, not CONS_SH's.

## Deviations
- The acceptance script was already on the branch (written by the v1 verifier). Reviewing it against the card, its WP13.A5 second case simulated a partial closure by restricting `POP_HH_SH.HE_COUNT`'s `SERIES_PLAN` to 4 of its 5 categories via a `restrict_series_plan()` helper, with a comment saying this stood in for "the real EMP_STATUS data" because CLOSURE_PARTIAL is "a generic... mechanism, not indicator-specific." I checked the real metadata (`table()`/`head()` via R, all within the card's "Read" section): `CL_COMP_BREAKDOWN` carries two EMP_STATUS categories (`EMP_STATUS_EMPLOYED`, `EMP_STATUS_NOT_EMPLOYED`), but `SERIES_PLAN` defines a series for only `POP_SH.EMP_STATUS_EMPLOYED`, and `POP_SH`'s `CL_INDICATOR.checks` includes `SUM_TO_1_OVER_BRK`. So the real EMP_STATUS closure is already, genuinely partial - no plan mutation needed at all - directly matching the card's literal wording ("The partial variable EMP_STATUS gives INFO RULE.CLOSURE_PARTIAL and no ERROR"). I replaced the HE_COUNT-restriction simulation with a direct fixture for the real `POP_SH.EMP_STATUS_EMPLOYED` series (flat value 0.5, trivially satisfying its other checks, RANGE_0_1 and AGG_BRACKET) and removed the now-unused `restrict_series_plan()` helper, its explanatory comment, and the stale `edit_csv()` mention in the sourcing comment. The corrected script still passes. After making this change I read `pipeline/tests/testthat/test-validate-rules.R` (in scope once the script was written) and found its own WP13.A5 test already uses `POP_SH.EMP_STATUS_EMPLOYED` the same way, which confirms the correction rather than having motivated it.
- No other change was made. The rest of the pre-existing script matches the card: it writes the data-file manifest in the contract's long key/value form (checked against `contract/csv_headers.csv` and `ctx.R`'s `build_ctx()`, which is exactly the format WP08's fixture fix and WP13's own p2 patch are about), sources only `pipeline/R/{constants,codes,io,ctx,plan,validate_rules}.R` plus the plain `helper-temp-root.R` (in scope - every check is about `validate_rules.R`'s functions), and writes only under `tempdir()` via `make_temp_root()`.
- The script hard-codes tolerance numbers (0.065, 35000, 0.005 x scale, etc.) instead of reading them from `contract/expected_counts.csv`. This is not a gap: I confirmed `expected_counts.csv` has no `WP13.*` rows at all - WP13's tolerances are algorithmic parameters fixed by the card's own formulas (`h = 0.005 x scale`, `(k+1) x h`, `k x h`), not contract-sourced facts about the data, and every scale/k value the script (and my own hand checks) used was cross-checked against the real metadata via R rather than invented.
- No check in this script greps the repository, so the "must not match the script's own source" rule has nothing to bite on here.

## Questions
None.

## Changelog line
None.

## Failures to fix
None.
