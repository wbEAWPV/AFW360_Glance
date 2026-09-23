# WAVE3 integration report (follow-up run)
Branch: transition/main

## Merged (package, branch, merge commit)
- WP11, transition/wp11-validator-core-v5, 4eb1289
- WP12, transition/wp12-validator-coverage-v2, 79fe1a3
- WP13, transition/wp13-validator-rules-v3, 2c54937

(This is the follow-up integration for wave 3. WP03, WP08 and WP11-WP16 had already been merged
onto transition/main in the prior run, commit 09591ec. This run re-merges fresh, fixed versions of
WP11, WP12 and WP13 only, per the orchestrator's package list.)

## Conflicts
None. All three merges were clean (no conflicting hunks in metadata/CHANGELOG.md,
.docs/transition/STATUS.md, or any other file).

## Checks (each check of step 3 with PASS or FAIL)
- run_all.R (all acceptance scripts, wp01-wp16): PASS - exit 0, every SUMMARY line PASS.
- testthat::test_dir('pipeline/tests/testthat', stop_on_failure = TRUE): PASS -
  `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 409 ]`.
- convert_legacy.R --country ALL, reproduce data/ byte for byte: PASS - 4/4 files
  (AFW360_HH_GNB_2021.csv, AFW360_HH_GNB_2021_manifest.csv, AFW360_HH_SEN_2021.csv,
  AFW360_HH_SEN_2021_manifest.csv) byte-identical to the committed data/ tree.
- validate.R --root . --out .docs/transition/reports/FINAL-validation-findings.csv: PASS -
  ran to completion, ERROR 0 / WARN 115 / INFO 8 (123 findings total).
- reconcile.R --root . --out .docs/transition/reports/FINAL-reconciliation.md --csv
  .docs/transition/reports/FINAL-reconciliation-cells.csv: PASS - RECONCILIATION: PASS,
  6871/6871 cells result=OK (0 ORPHAN, 0 MISMATCH).

### Validation findings: table(check_id, severity)
```
                       INFO WARN
  CODES.DRAFT             0   42
  META.TBD                0   42
  RULE.AGG_SKIPPED        0   27
  RULE.CLOSURE_PARTIAL    6    0
  TEXT.TBD                0    4
  VALUE.N                 2    0
```
Totals: ERROR 0, WARN 115, INFO 8.

Note: the prior run (09591ec) reported WARN 109; this run reports WARN 115. Per orchestrator
note (d), this is expected: WP11's branch fixes pipeline/validate.R so each findings group is
capped exactly once (previously a shared `.vc_bind` naming collision between WP11's and WP12's
modules caused some groups to be double-capped, producing two SUMMARY rows and undercounting).
This is the fix working, not a regression.

### Reconciliation: table(result)
```
  OK 
6871
```
No ORPHAN or MISMATCH rows.

## Findings by owner
None. No check failed.

## Status changes
- WP11: MERGED, transition/wp11-validator-core-v2 (PASS, 2, 2026-09-22) ->
  transition/wp11-validator-core-v5 (PASS, 5, 2026-09-23).
- WP12: MERGED, transition/wp12-validator-coverage-v1 (PASS, 1, 2026-09-22) ->
  transition/wp12-validator-coverage-v2 (PASS, 2, 2026-09-23).
- WP13: MERGED, transition/wp13-validator-rules-v2 (PASS, 2, 2026-09-22) ->
  transition/wp13-validator-rules-v3 (PASS, 3, 2026-09-23).

## Changelog lines added
None. WP11, WP12 and WP13 each already carry their changelog line in
metadata/CHANGELOG.md under "## 0.1.0 (unreleased)", added during the prior integration run.
Each of the three merged branches' own reports confirm the line is unchanged from the base
implementer report (WP11-verifier-v5.md, WP12-verifier-v2.md and WP13-verifier-v3.md all say
"None" under "Changelog line", and the patch reports say the same or "unchanged"), so no new
line was appended and no duplicate was created.
