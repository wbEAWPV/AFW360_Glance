# WP13 verifier report
Branch: transition/wp13-validator-rules-v2

## Files written        (path, and rows or bytes)
- pipeline/acceptance/wp13_validator-rules.R (392 lines; inherited unchanged from transition/wp13-validator-rules-p1 after review against the card — no correction was needed).
- .docs/transition/reports/WP13-verifier-v2.md (this report).

## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)
- WP13.A1: PASS. `errors=0 (total findings=48, rows=726)` on the consistent fixture (POV_NUM x2, POV_HC x2, 13 COICOP, 5 HE_COUNT).
- WP13.A2: PASS. All six mutations gave exactly their check_id and nothing else at ERROR severity: `RULE.AGG_SUM=TRUE(n=1); RULE.AGG_BRACKET=TRUE(n=6); RULE.SUM_TO_1_QUAL=TRUE(n=1); RULE.SUM_TO_1_BRK=TRUE(n=1); RULE.MONOTONE=TRUE(n=1); RULE.RANGE_0_1=TRUE(n=1)`.
- WP13.A3: PASS. `COICOP 0.97 no-finding=TRUE; POV_NUM k=6 3130000/3120000 no-finding=TRUE` — this is the exact case v1 failed on (scale-recycling bug); it now passes with p1's fix.
- WP13.A4: PASS. `deviation==tolerance passes=TRUE; tolerance+0.001*scale fails=TRUE`.
- WP13.A5: PASS. `agg_skipped=TRUE no_error_after_delete=TRUE closure_partial=TRUE no_error_partial_plan=TRUE`.
- WP13.A6: PASS. `vc_rule_* found=9 all-empty-on-empty-ctx=TRUE; testthat files=15 failed=0 error=FALSE`.

Full run: `Rscript pipeline/acceptance/wp13_validator-rules.R --root .` → "All checks passed." exit status 0.

## Deviations           (what the card said, what you did, why)
- The script hardcodes the card's own literal fixture numbers (0.97, 3130000/3120000, 35000, 0.065, 0.001×scale, 1.2, 1.3, etc.) rather than reading them from `contract/expected_counts.csv`, because that file holds none of the values a rules-tolerance check needs — see Questions.
- I found the acceptance script already committed on `transition/wp13-validator-rules-p1` (inherited by branching from it, per the task's step 1). I reviewed it line by line against the card and kept it verbatim: it covers exactly WP13.A1–A6 with the card's ID spelling, sources only `pipeline/R/{constants,codes,io,ctx,plan,validate_rules}.R` (all of which the checks are directly about: validate_rules.R is under test; the rest is the plumbing `build_ctx()`/`required_rows()`/`fmt_num()` it needs to build ctx and fixtures) plus the non-`pipeline/R/` test helper `helper-temp-root.R`, and writes only under `tempfile()`-created directories (confirmed by reading `make_temp_root()`). No correction was needed.
- WP13.A5's second half (closure partial) is built by restricting `SERIES_PLAN` to 4 of the 5 `HE_COUNT` categories on a temp copy, rather than reproducing the real `EMP_STATUS` case verbatim from the card's prose example. The card names `EMP_STATUS` only as illustration of "partial variable" under `SUM_TO_1_OVER_BRK`; `CLOSURE_PARTIAL` is described as a generic plan-vs-`CL_COMP_BREAKDOWN` mechanism, and no real data exists yet for this wave (WP15 is concurrent), so any indicator's plan can exercise it. I agree this is a faithful implementation of the check's intent.

## Questions            (contract doubts, and anything only the user can decide)
- CONTRACT DOUBT (carried over from the v1 verifier, still true): `contract/expected_counts.csv` has zero rows for any `WP13.*` check_id, and its schema (`check_id, scope, quantity, expected, tolerance, source`) is built for flat workbook/row counts (cells, distinct labels, rows by OBS_STATUS, etc.) from earlier waves — nothing shaped like a rule's tolerance formula. WP13's card itself is the only place these numbers appear (e.g. "a POV_NUM parent of 3130000 with 6 children that sum to 3120000 passes (tolerance 35000)"), and WP13's own "Read" section never lists `contract/expected_counts.csv`. I did not add fabricated rows to that file (forbidden: `.docs/transition/**` is not mine to edit) and did not bend a check to force a contract read that doesn't fit. I independently re-derived both boundary tolerances from `LEGACY_LABELS.scale` (POV_NUM = 1000000, CONS_SH.COICOP = 1) and the card's h/tolerance formulas, and confirmed them against the real metadata (below), so I'm confident the hardcoded literals are correct, not a workaround.

## Verifier focus (by hand)
- AGG_SUM case, POV_NUM.POVLINE_PL300.PPP_2021, cut ZONES: `required_rows()` on real metadata gives k=6 children (confirmed via `table(TAB_PLAN$cut_id)`: TOTAL/URB/HHH_SEX/HHH_AGE/QUINT/ADM1/ZONES/AEZ = 8 cuts). `LEGACY_LABELS$scale` for both POV_NUM series = 1000000. h = 0.005 × 1000000 = 5000; tolerance = (k+1)×h = 7×5000 = 35000, matching the card. I built independent fixtures (not reusing the acceptance script's helper functions) with parent 3130000 and children summing to exactly 3130000−35000=3095000, then to 3130000−35001=3094999, and called `vc_rule_agg_sum(ctx)` directly: 0 ERROR rows at the exact boundary, 1 ERROR row `sum=3094999 parent=3130000 deviation=35001 tolerance=35000` one unit over. Confirms the pass/fail boundary exactly.
- Closure case, CONS_SH SUM_TO_1_QUAL over 13 COICOP categories: scale=1, h=0.005, tolerance=13×0.005=0.065. Independent fixture (own code, not the acceptance script's): a cell summing to exactly 1.065 gives 0 ERROR rows; a cell at 1.066 gives 1 ERROR row with `RULE.SUM_TO_1_QUAL`. Confirms the pass/fail boundary exactly.
- No defect found in either case.

## Ownership check
`git diff --name-only transition/main...transition/wp13-validator-rules-p1`:
- `pipeline/R/validate_rules.R` — owned by WP13 (output_ownership.csv row 99).
- `pipeline/tests/testthat/test-validate-rules.R` — owned by WP13 (row 100).
- `pipeline/acceptance/wp13_validator-rules.R` — matches the glob `pipeline/acceptance/wpNN_*.R`, owner VER (row 121).
- `.docs/transition/reports/WP13-implementer.md`, `.docs/transition/reports/WP13-implementer-p1.md` — match glob `.docs/transition/reports/WPNN-implementer*.md`, owner WPNN=WP13 (row 123).
- `.docs/transition/reports/WP13-verifier-v1.md` — matches glob `.docs/transition/reports/WPNN-verifier-v*.md`, owner VER (row 122).

All six changed paths are owned by WP13 or VER (this package's acceptance script/report roles). No unowned path found.

## Changelog line       (implementers only: the card's line, adjusted if needed)
None (verifier report).

## Failures to fix   (numbered; for each: the check ID, the exact command or comparison, expected against actual. Write "None" on PASS.)
None.
