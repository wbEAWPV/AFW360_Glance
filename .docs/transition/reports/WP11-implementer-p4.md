# WP11 patch p4 — A1 scoped to WP11's own check modules

**Date.** 2026-09-23
**Branch.** `transition/wp11-validator-core-p4`, from `transition/wp11-validator-core-p3` (edb097e), with `dev/eb` merged in.
**Mode.** FINDINGS (card correction authorised by the user during wave 3).
**Made by.** The orchestrator directly, at the user's explicit instruction, not by a patch agent. WP11 had already used its three patch attempts.

## Summary

WP11's card check A1 read "on the clean fixture, `validate.R` exits 0 with 0 `ERROR`". The user
corrected it to ask for 0 `ERROR` from WP11's own modules — `STRUCT`, `CODES` and `META` — in the
grammar A5 already used. This branch brings WP11's own unit test into line with the corrected card.
No check module changed; WP11's three modules were never at fault.

## Why the card changed

`validate.R` dispatches to every validator module. When A1 was written, WP11's three modules were
the only ones; WP12's `validate_coverage.R`, WP13's `validate_rules.R` and WP14's `validate_assets.R`
reached the same entry point only at the wave-3 merge (09591ec). A1 then began to hold WP11
accountable for findings from three modules it does not own and cannot fix.

The findings are not defects. They are properties of WP08's test fixture, which its own card puts
out of scope word for word — "Subtracting withheld cells; any validator check; `CL_INDICATOR`":

| Finding | Cause in `make_data_fixture()` |
|---|---|
| `COVER.SURVEY` | The manifest hard-codes `survey_id = "TBD"` and no `SURVEYS.csv` row is written, so the lookup can never match. |
| `COVER.WITHHELD_PRESENT` | Every row of `required_rows()` is emitted; withheld cells are not subtracted. The helper's own header comment says so: "That is the coverage check's job (WP12)." |
| `RULE.SUM_TO_1_BRK`, `RULE.SUM_TO_1_QUAL` | `OBS_VALUE` is one constant (default `0.5`) on every row, so any breakdown without exactly two categories cannot sum to 1 (`QUINT` has five). |

WP11's verifier v3 measured 0 `ERROR` from `STRUCT`, `CODES` and `META` on that fixture and on the
real metadata, and both of its mutation probes were caught. That the whole validator is clean is
proven on the real data by the wave-3 integrator: `validate.R` exits 0 with `ERROR` 0.

The card change itself is commit 00e61fc on `dev/eb`, because `.docs/transition/packages/**` is
marked frozen in `output_ownership.csv`: "no agent edits it. A change needs the user and a new plan
commit on dev/eb." That commit is merged into this branch so the card and the test change together
and are never out of step.

## Changes

| Path | Change |
|---|---|
| `pipeline/tests/testthat/test-validate-core.R` | The A1 test now runs `validate.R` on the clean fixture the card defines (the three named `series_ids`, via `.small_fixture()`) instead of the full one, and asserts 0 `ERROR` from `STRUCT`, `CODES` and `META` instead of 0 `ERROR` overall and exit 0. `.small_fixture()` gained an optional `include =` argument so the temp root can carry `pipeline/`. The expected non-zero exit is wrapped in `suppressWarnings()`. A comment records the reason and the card commit. |

Merged in from `dev/eb` (00e61fc), not authored here:

| Path | Change |
|---|---|
| `.docs/transition/packages/WP11.md` | A1 scoped to `STRUCT`, `CODES` and `META`, with the fixture's known properties stated. |

## Checks run

- `testthat::test_file('pipeline/tests/testthat/test-validate-core.R')`: 27 expectations pass, 0 fail,
  0 warnings. Before this patch it was 1 test / 2 expectations failing plus 1 warning.
- `parse()` on the edited file: clean.
- The test asserts on WP11's modules only; the fixture's `COVER` and `RULE` findings are left to
  stand, and belong to WP12 and WP13.

## Deviations

- This patch was made by the orchestrator rather than a patch agent, at the user's explicit
  instruction, because WP11's three patch attempts were spent. Verification is unaffected: a fresh
  WP11 verifier v4 rebuilds the acceptance script from the corrected card and re-runs everything.
- A6 ("the unit tests pass") is unchanged and was not part of the user's decision. All four validator
  cards (WP11, WP12, WP13, WP14) carry that identical sentence, and each card's line 17 names the one
  test file that package owns; WP12's, WP13's and WP14's verifiers all scoped it to their own file.
  WP11's v3 verifier alone read it as the whole test directory, which made WP11 accountable for
  WP12's and WP13's still-unmerged test files. The v4 verifier is given that evidence and decides the
  scope itself.

## Questions

- A defect in WP13's `validate_rules.R`, found by WP11's verifier v3 and recorded by the user's
  decision for WP17's audit rather than patched now: `vc_rule_sum_to_1_qual()` caps findings once per
  `SUM_TO_1_OVER:<VAR>` argument inside `.vc_closure_walk()` and then caps the combined result again,
  so one file can carry more than one "SUMMARY: N findings in total, 20 shown" row for the same
  `check_id`. It affects the findings report only, never a verdict.

## Changelog line

- `pipeline/tests/testthat/test-validate-core.R`: the A1 test asserts 0 `ERROR` from `STRUCT`, `CODES`
  and `META` on the card's clean fixture, matching the card correction in 00e61fc.
