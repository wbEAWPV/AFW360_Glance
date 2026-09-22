# WAVE3 integration report

Branch: transition/main

## Merged

| Package | Branch | Merge commit |
|---|---|---|
| WP03 | transition/wp03-scaffold-v2 | 18042c5 |
| WP08 | transition/wp08-plans-v2 | 16c6525 |
| WP11 | transition/wp11-validator-core-v2 | 47a445c |
| WP12 | transition/wp12-validator-coverage-v1 | ffc6109 |
| WP13 | transition/wp13-validator-rules-v2 | 6450ec7 |
| WP14 | transition/wp14-validator-assets-text-v1 | 8b2eddd |
| WP15 | transition/wp15-converter-v1 | 6ef3185 |
| WP16 | transition/wp16-reconcile-v1 | d82ec37 |

All eight branches ended with their own `WPNN: verify vK - VERDICT: PASS` commit and merged with
`git merge --no-ff` in the order listed above.

## Conflicts

None. Every merge above applied cleanly (the `ort` strategy reported no conflicting hunks); the
metadata/CHANGELOG.md / STATUS.md dual-side rule was never invoked because no merge touched them
(both files are integrator-only and were edited after all eight merges, not by any package branch).

## Checks

| Step | Check | Result |
|---|---|---|
| 3a | `Rscript pipeline/acceptance/run_all.R --root .` | **FAIL** — 12/16 scripts PASS (WP01, WP02, WP04-WP10, WP14-WP16); 4/16 FAIL (WP03, WP11, WP12, WP13) |
| 3b | `Rscript -e "testthat::test_dir('pipeline/tests/testthat', stop_on_failure = TRUE)"` | **FAIL** — halted after 8 failures + 1 warning in `test-validate-core.R`, per `stop_on_failure = TRUE`; later files not reached by this run |
| 3c-i | `Rscript pipeline/convert_legacy.R --root . --country ALL --timestamp 2026-01-01T00:00:00Z --out-root <tempdir>` | **PASS** — all 4 files (`AFW360_HH_SEN_2021.csv`, `AFW360_HH_SEN_2021_manifest.csv`, `AFW360_HH_GNB_2021.csv`, `AFW360_HH_GNB_2021_manifest.csv`) byte-identical to `data/` (`cmp` on each, 0 differences); same file listing in both directories |
| 3c-ii | `Rscript pipeline/validate.R --root . --out .docs/transition/reports/FINAL-validation-findings.csv` | **PASS** — exit 0, ERROR: 0, WARN: 109, INFO: 8 (see table below) |
| 3c-iii | `Rscript pipeline/reconcile.R --root . --out .docs/transition/reports/FINAL-reconciliation.md --csv .docs/transition/reports/FINAL-reconciliation-cells.csv` | **PASS** — exit 0, `RECONCILIATION: PASS`, every (country, sheet) result is `OK`, no `ORPHAN`, no `MISMATCH` |

### validate.R findings: table(check_id, severity)

117 rows total, all WARN or INFO, 0 ERROR:

| check_id | INFO | WARN |
|---|---|---|
| CODES.DRAFT | 0 | 42 |
| META.TBD | 0 | 42 |
| RULE.AGG_SKIPPED | 0 | 21 |
| RULE.CLOSURE_PARTIAL | 6 | 0 |
| TEXT.TBD | 0 | 4 |
| VALUE.N | 2 | 0 |

This confirms the CONTRACT-FIX gate's outcome on the merged tree: 0 `META.REQUIRED` errors on
`LEGACY_LABELS.csv` (the 21 pre-fix errors are gone), and 0 ERROR rows of any kind from
`pipeline/validate.R` against the real repository data.

### Acceptance-script failure detail (3a)

- **WP03.A1** FAIL (`wp03_scaffold.R`) — runs `testthat::test_dir('pipeline/tests/testthat',
  stop_on_failure = TRUE)` as its own check; log tail: `...rror_ids(findings)\` to equal
  "CODES.SEX_AGE_UNIT".` — the same interaction described under WP11.A6 below, reached because
  `test-validate-core.R` sorts before the suite's other broken files.
- **WP11.A1** FAIL (`wp11_validator-core.R`) — `exit=1 ERROR rows=112 (STRUCT=0 CODES=21 META=0)
  ids=CODES.DRAFT|COVER.MANIFEST|RULE.AGG_SUM|RULE.SUM_TO_1_BRK|RULE.SUM_TO_1_QUAL|VALUE.N`, run
  against the script's own fixture (not the real root — WP11.A5, run against the real root in the
  same script, PASSES with `0 ERROR from STRUCT/CODES/META`).
- **WP11.A6** FAIL (`wp11_validator-core.R`) — runs the identical command as step 3b:
  `testthat::test_dir exit=1; last lines: Lengths differ: 2 is not 1 / ── 10. Failure
  ('test-validate-core.R:213:3'): MEASURE_QUAL_2 of a POVLINE_PL420 / Expected \`.error_ids(findings)\`
  to equal "CODES.VALID_WITH". / Differences: / Lengths differ: 2 is not 1 / ... and 41 more /
  Maximum number of 10 failures reached ... Error: ! Test failures. Execution halted`.
- **WP12.A5** FAIL (`wp12_validator-coverage.R`) — `18 test(s) in test-validate-coverage.R: 33
  failed, 0 errored` (filtered run of that file alone; not a cascade from WP11's file).
- **WP13.A6** FAIL (`wp13_validator-rules.R`) — `vc_rule_* found=9 all-empty-on-empty-ctx=TRUE;
  testthat files=15 failed=4 error=FALSE` (filtered run of `test-validate-rules.R` alone; not a
  cascade from WP11's file).

## Findings by owner

Every failure above is an acceptance-script or unit-test failure; `validate.R` produced 0 ERROR
findings (nothing to attribute under META/CODES/COVER/VALUE/RULE/ASSET/TEXT ownership), and
`reconcile.R` produced 0 non-OK results. Ownership assigned per the integrator brief (acceptance
script -> package in its file name; test file -> owner in `contract/output_ownership.csv`):

| Owner | Check | Count | Example |
|---|---|---|---|
| WP03 | 3a acceptance script `wp03_scaffold.R`, check WP03.A1 | 1 script FAIL | `WP03.A1 FAIL exit=1 log_tail=...CODES.SEX_AGE_UNIT` |
| WP11 | 3a acceptance script `wp11_validator-core.R`, checks WP11.A1 and WP11.A6 | 2 checks FAIL | `WP11.A1`: 112 ERROR rows on its own fixture, ids CODES.DRAFT / COVER.MANIFEST / RULE.AGG_SUM / RULE.SUM_TO_1_BRK / RULE.SUM_TO_1_QUAL / VALUE.N; `WP11.A6`: `testthat::test_dir` exit 1 |
| WP11 | 3b unit tests, file `pipeline/tests/testthat/test-validate-core.R` (owner: WP11 per `contract/output_ownership.csv`) | 8 FAILUREs + 1 WARNING, run halted at "Maximum number of 10 failures reached" | `test-validate-core.R:213:3`: `Expected .error_ids(findings) to equal "CODES.VALID_WITH"` / `Lengths differ: 2 is not 1`; earlier examples at `:138:3` (`STRUCT.EMPTY_KEY`) and `:146:3` (`STRUCT.DUPLICATE_KEY`) |
| WP12 | 3a acceptance script `wp12_validator-coverage.R`, check WP12.A5 | 1 check FAIL, 33 of 18 test-block assertions failed in `test-validate-coverage.R` (owner: WP12) | `18 test(s) in test-validate-coverage.R: 33 failed, 0 errored` |
| WP13 | 3a acceptance script `wp13_validator-rules.R`, check WP13.A6 | 1 check FAIL, 4 of 15 test files failed (`test-validate-rules.R`, owner: WP13) | `vc_rule_* found=9 all-empty-on-empty-ctx=TRUE; testthat files=15 failed=4 error=FALSE` |

No validator-finding-owner (STRUCT/CODES/META -> WP11; COVER/VALUE -> WP12; RULE -> WP13;
ASSET/TEXT -> WP14) or reconciliation-failure-owner (WP15/WP16) findings apply: `validate.R`'s
117 findings are all WARN/INFO (0 ERROR), and `reconcile.R` reported 0 non-OK results.

None of these four failures is an ownership violation (no branch was skipped or `--abort`-ed; every
listed branch merged cleanly), so this is not a BLOCKED condition.

## Status changes

All eight packages set to `MERGED` in `.docs/transition/STATUS.md`, each carrying its own
pre-merge verify verdict (which is independent of the integration-time failures found above):

| WP | State | Latest branch | Verdict | Attempts | Updated |
|---|---|---|---|---|---|
| WP03 | MERGED | transition/wp03-scaffold-v2 | PASS | 2 | 2026-09-22 |
| WP08 | MERGED | transition/wp08-plans-v2 | PASS | 2 | 2026-09-22 |
| WP11 | MERGED | transition/wp11-validator-core-v2 | PASS | 2 | 2026-09-22 |
| WP12 | MERGED | transition/wp12-validator-coverage-v1 | PASS | 1 | 2026-09-22 |
| WP13 | MERGED | transition/wp13-validator-rules-v2 | PASS | 2 | 2026-09-22 |
| WP14 | MERGED | transition/wp14-validator-assets-text-v1 | PASS | 1 | 2026-09-22 |
| WP15 | MERGED | transition/wp15-converter-v1 | PASS | 1 | 2026-09-22 |
| WP16 | MERGED | transition/wp16-reconcile-v1 | PASS | 1 | 2026-09-22 |

No gate row was added or changed (CONTRACT-FIX is not G0/G1/G2; see
`.docs/transition/reports/GATE-CONTRACT-FIX.md`). G2 remains PENDING.

## Changelog lines added

Appended to `metadata/CHANGELOG.md` under "## 0.1.0 (unreleased)":

- `metadata/structure/COLUMNS.csv`: `scale` marked `C` (required when relevant), matching the
  contract correction in c321d51. (WP03 patch p1)
- Validator core: structure, codes and metadata checks. (WP11)
- Validator: coverage and value checks. (WP12)
- Validator: aggregation, closure, monotonicity and range rules with ROUNDED_2DP tolerances. (WP13)
- Validator: asset and text checks. (WP14)
- Legacy converter; AFW360_HH_SEN_2021 and AFW360_HH_GNB_2021 (DRAFT). (WP15)
- Independent reconciliation tool. (WP16)

WP08's patch report (`WP08-implementer-p1.md`) explicitly states no new changelog line ("card's
changelog line unchanged"), so none was added for it.
