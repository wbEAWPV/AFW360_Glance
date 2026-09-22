# WP08 patch agent report
Branch: transition/wp08-plans-p1

## Files written        (path, and rows or bytes)
- `pipeline/tests/testthat/helper-data-fixture.R` (98 lines) — `make_data_fixture()` now writes the manifest in long `key`,`value` form (16 rows, 2 columns) instead of one wide row of 16 named columns.
- `pipeline/tests/testthat/test-plan.R` (266 lines) — updated the `"make_data_fixture writes a data file and manifest for GNB"` test to assert the long form (`names(manifest) == c("key","value")`, `nrow == 16`, values looked up via a `key`→`value` vector) instead of the old wide-row assertions.

## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)
- WP08.A1: PASS — `SERIES_PLAN` rows=91, triage MAP rows=91, fields match, ids unique and id-shaped.
- WP08.A2: PASS — `TAB_PLAN` rows=8, columns and rows match `contract/tab_plan.csv` + `status=DRAFT`.
- WP08.A3: PASS — both plan files' headers match `csv_headers.csv`.
- WP08.A4: PASS — SEN rows=3003, GNB rows=2366, both unique keys, no empty cells.
- WP08.A5: PASS — `SEX`/`AGE` `_Z` rule, `POP_HH_SH.HE_COUNT_0`/`QUINT` and `POV_HC.POVLINE_PL420.PPP_2021` rows all correct.
- WP08.A6: PASS — per-cut row counts match for both countries.
- WP08.A7: PASS — unit tests pass, `build_plans.R` reproduces both files byte for byte.
- WP08.A8: FAIL — `pipeline/acceptance/wp08_plans.R` (lines ~293-298) hard-codes `manifest_ok <- setequal(names(mf), keys16)` with `nrow(mf) == 1`, i.e. it still expects the old, wrong wide-row manifest. This check itself embeds the pre-existing bug; see Deviations/Questions. Not edited, per the rule against editing acceptance scripts.
- Full suite (`testthat::test_dir('pipeline/tests/testthat', stop_on_failure = TRUE)`): 152 PASS, 0 FAIL, 0 WARN, 0 SKIP.

## Deviations           (what the card said, what you did, why)
- Input item 1 (WP12's report) and input item 2 (WP13's report): both said `make_data_fixture()` writes the manifest wide, while the contract and `ctx.R` expect long `key,value` form. Confirmed against the authorities named in my input:
  - `contract/csv_headers.csv` row for `AFW360_HH_<ISO3>_<YEAR>_manifest.csv` defines exactly two columns, `key` (position 1) and `value` (position 2), one row per one of the 16 keys.
  - `pipeline/R/ctx.R`'s `build_ctx()` reads `man_df[[1]]` as keys and `man_df[[2]]` as values via `setNames(as.character(man_df[[2]]), as.character(man_df[[1]]))`, which only works for the long form.
  - `pipeline/tests/testthat/test-ctx.R` (WP08 does not own it, read only to confirm) builds its own manifest fixture the same long way (`data.frame(key=c(...), value=c(...))`), confirming this is the established convention, not a guess.
  This makes WP12 and WP13 correct: WP08's `helper-data-fixture.R` was wrong, not their files. Fixed `helper-data-fixture.R` to write the 16 keys as long rows, and updated the one WP08-owned test that asserted the old wide shape (`test-plan.R`). No other file was touched; per COMMON.md, `data_raw/`, other packages' files and `.docs/transition/**` (besides this report) were left alone.
- Consequence found while verifying: `pipeline/acceptance/wp08_plans.R`'s WP08.A8 check itself hard-codes the old wide-row assumption (`nrow(mf) == 1`, `setequal(names(mf), keys16)`), so it now fails against the corrected, contract-compliant helper. This is an acceptance-script bug, not a WP08 code bug — I did not edit the script, per the overriding rule; see Questions.
- Rerun note: wave-3 test files (WP11-14) are not present on this branch (`transition/main` at wave 2; the card's step 3 already notes wave-3 metadata files don't exist here either), so I could not execute their described local manifest-rewrite workarounds directly. Ran the full currently-present suite instead (152 PASS, 0 FAIL) to confirm no regression from the fix; `test-ctx.R`'s own manifest fixture (long form) continues to pass unchanged.

## Questions             (contract doubts, and anything only the user can decide)
- `pipeline/acceptance/wp08_plans.R` WP08.A8 (lines ~293-298) checks the manifest as one wide row of 16 named columns (`manifest_ok <- setequal(names(mf), keys16)` after `nrow(mf) == 1`), which contradicts `contract/csv_headers.csv` (manifest file = `key`,`value` columns, 16 rows) and `pipeline/R/ctx.R::build_ctx()` (reads column 1 as key, column 2 as value). Now that `make_data_fixture()` is contract-compliant, WP08.A8 fails. The orchestrator should route a patch to the verifier to rewrite this check to read the manifest as `key`/`value` rows (e.g. `setequal(mf$key, keys16)`, `nrow(mf) == 16`, and look up `n_rows`/`precision`/etc. by `key`) rather than by column name. I did not edit the script myself.

## Changelog line       (implementers only: the card's line, adjusted if needed)
None (patch agent; card's changelog line unchanged: "SERIES_PLAN, TAB_PLAN, and the required-row generator.")
