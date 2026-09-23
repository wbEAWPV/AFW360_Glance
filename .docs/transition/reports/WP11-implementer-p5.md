# WP11 patch p5 — the cap is applied once, and the clean fixture is defined

**Date.** 2026-09-23
**Branch.** `transition/wp11-validator-core-p5`, from `transition/wp11-validator-core-p4` (757531b), with `dev/eb` merged in.
**Mode.** FINDINGS (both items decided by the user during wave 3).
**Made by.** The orchestrator directly, at the user's explicit instruction. WP11's patch attempts were spent.

## Summary

Two findings from WP11's verifier v4, both resolved:

1. **WP11.A1 failed on the card's own clean fixture** with 21 `META.REFERENCE` errors. The fixture
   was under-specified, not wrong. Fixed on the card, not in code.
2. **One check's findings were capped twice**, producing two `SUMMARY` rows for the same
   `check_id` and file and showing 19 findings instead of 20. Fixed in `pipeline/validate.R`.

## Finding 1 — the clean fixture

`make_data_fixture(series_ids = ...)` reduces `metadata/plans/SERIES_PLAN.csv` to the requested
series but leaves `metadata/plans/LEGACY_LABELS.csv` whole, orphaning 88 `series_id` references.
`META.REFERENCE` reports them correctly. WP11's own test helper `.small_fixture()` had always
trimmed the second file by hand, with a comment explaining why, but the card never said to — so an
acceptance script built from the card alone could not reproduce the clean fixture, and v4's did not.

The card now defines it: step 2 and A1 say both plan files are trimmed (dev/eb 6d23f48). The shared
helper was deliberately left alone: `test-plan.R`, `test-validate-coverage.R` and
`test-validate-rules.R` all call `make_data_fixture()` with `series_ids` and do not trim, and WP13's
reads `LEGACY_LABELS.csv` for scale and tolerance lookups, so changing the helper would have moved
three other packages' fixtures under them.

## Finding 2 — the double cap

**Mechanism.** The modules are sourced into one environment, alphabetically:
`assets, codes, coverage, metadata, rules, structure, text, values`. `validate_structure.R` (WP11)
defines `.vc_bind` without capping; `validate_values.R` (WP12) defines a function of the same name
that caps internally. `values` is sourced last, so its definition wins. R resolves free variables at
call time, so WP11's `vc_meta_reference()`, which ends in `.vc_bind(out)`, silently ran WP12's
capping version: its 88 findings arrived at `validate.R` already reduced to 20 rows plus a
`SUMMARY: 88 findings in total, 20 shown`. `validate.R` then capped that 21-row group again. The
`SUMMARY` row's `row_key` is `""`, which sorts before every real key, so it survived the second cap
and displaced the twentieth finding.

This was never specific to WP11: any check of any module whose group exceeds 20 findings for one
file is capped twice the same way, on real data as much as on a fixture. It also only appears when
all four modules load, which is why every package passed in isolation.

**Fix.** `pipeline/validate.R` now leaves a group alone when it already carries a `SUMMARY` row.
That corrects the output for all four packages in one place and keeps the module's own message,
which holds the true total (88) that `validate.R` can no longer recover once the rows behind it are
gone. The cap rule on the WP11–WP14 cards — "keep the first 20 in `row_key` order, and add one
finding ... `SUMMARY: <n> findings in total, 20 shown`" — is satisfied exactly once.

## Changes

| Path | Change |
|---|---|
| `pipeline/validate.R` | The cap skips a group that already contains a `SUMMARY` row (`.has_summary_row()`). A comment records the mechanism and why the module's own total is kept. |
| `pipeline/tests/testthat/test-validate-core.R` | New regression test: with `LEGACY_LABELS.csv` untrimmed, `META.REFERENCE` yields 88 findings, and the findings file must hold exactly one `SUMMARY` row and 20 real rows for that `check_id` and file. |

Merged in from `dev/eb` (6d23f48), not authored here:

| Path | Change |
|---|---|
| `.docs/transition/packages/WP11.md` | Step 2 and A1 define the clean fixture as both plan files trimmed. |

## Checks run

- `testthat::test_file('pipeline/tests/testthat/test-validate-core.R')`: 30 expectations pass, 0 fail,
  0 warnings.
- The regression test was run against `validate.R` as it stood at p4, by swapping that file in and
  re-running the same test file. It fails there exactly as predicted — `nrow(summaries)` 2 against 1,
  and 19 real rows against 20 — and passes with the fix. The file was restored afterwards.

## Deviations

- Both changes were made by the orchestrator rather than a patch agent, at the user's explicit
  instruction, because WP11's patch attempts were spent. Verification is unaffected: a fresh WP11
  verifier v5 rebuilds the acceptance script from the corrected card and re-runs everything.
- The fix makes `validate.R` tolerant of a pre-capped group rather than stopping modules from
  capping. The underlying fault is that several modules define private helpers of the same name in
  one shared environment, so which implementation runs depends on filename order. That is recorded
  below for WP17 rather than fixed here, because it spans WP11–WP14 and two of those packages have
  no patch attempts left.

## Questions

- **For WP17's audit.** `validate_structure.R` (WP11), `validate_coverage.R` and `validate_values.R`
  (WP12) and `validate_rules.R` (WP13) each define private helpers of the same names — `.vc_bind`,
  `.vc_apply_cap`, `.vc_cap` — in one environment, and `validate_values.R`'s header says the
  duplication is "on purpose". Alphabetical sourcing decides which definition every module ends up
  calling. It is a silent hazard for anyone who adds a module or renames a file, and it is what
  produced the double cap.
- **Also for WP17's audit**, recorded earlier: in WP13's `validate_rules.R`,
  `vc_rule_sum_to_1_qual()` caps once per `SUM_TO_1_OVER:<VAR>` argument inside `.vc_closure_walk()`
  and then caps the combined result again. The `validate.R` fix above keeps that from reaching the
  findings file as a second `SUMMARY` row, but the inner double cap is still there.

## Changelog line

- `pipeline/validate.R`: a findings group that a module already capped is no longer capped a second
  time, so each `check_id` and file carries exactly one `SUMMARY` row and the full 20 findings.
