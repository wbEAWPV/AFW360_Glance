# WP13 verifier report
Branch: transition/wp13-validator-rules-v1

## Files written        (path, and rows or bytes)
- `pipeline/acceptance/wp13_validator-rules.R` (391 lines)
- `.docs/transition/reports/WP13-verifier-v1.md` (this file)

## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)
- WP13.A1: PASS. On a fully self-consistent 22-series fixture (POV_NUM x2, POV_HC x2, 13 plain
  CONS_SH.COICOP_*, 5 POP_HH_SH.HE_COUNT_*; 726 rows), `errors=0` across all discovered
  `vc_rule_*()` functions (48 non-ERROR findings present, which A1 does not constrain).
- WP13.A2: PASS. Each of the six targeted mutations gives exactly its check_id with severity
  ERROR and no other check_id at ERROR severity: `RULE.AGG_SUM=TRUE(n=1)`,
  `RULE.AGG_BRACKET=TRUE(n=6)`, `RULE.SUM_TO_1_QUAL=TRUE(n=1)`, `RULE.SUM_TO_1_BRK=TRUE(n=1)`,
  `RULE.MONOTONE=TRUE(n=1)`, `RULE.RANGE_0_1=TRUE(n=1)`.
- WP13.A3: **FAIL**. The COICOP-cell-sums-to-0.97 case passes as expected
  (`COICOP 0.97 no-finding=TRUE`). The POV_NUM-parent-3130000-with-6-children-summing-to-3120000
  case does **not** pass: `vc_rule_agg_sum` (via the discovered `vc_rule_*` set) reports
  `RULE.AGG_SUM` ERROR with `message: sum=3120000 parent=3130000 deviation=10000
  tolerance=0.035`. The card fixes this tolerance at 35000 (`(k+1) x h = 7 x 0.005 x 1,000,000`,
  scale from `LEGACY_LABELS.scale` for `POV_NUM.POVLINE_PL300.PPP_2021`, confirmed = 1000000 by
  direct lookup). The computed tolerance 0.035 = 7 x 0.005 x 1, i.e. `h` was computed with
  `scale = 1` (the "absent" default) instead of the series' real scale of 1,000,000. See
  Failures to fix below.
- WP13.A4: PASS. Using CONS_SH `SUM_TO_1_QUAL` (k=13, h=0.005, scale=1, tolerance=0.065): a
  deviation of exactly 0.065 passes (no finding), and tolerance + 0.001 x scale = 0.066 fails
  (`RULE.SUM_TO_1_QUAL` ERROR). This confirms the tolerance formula and the `<=` boundary are
  correct for a scale-1 series; only the scale lookup itself is broken (WP13.A3).
- WP13.A5: PASS. Deleting one POV_NUM child row from a consistent fixture gives
  `RULE.AGG_SKIPPED` WARN and no ERROR anywhere. A plan restricted to 4 of the 5
  `POP_HH_SH.HE_COUNT_*` categories (SERIES_PLAN edited on a temp copy only) gives
  `RULE.CLOSURE_PARTIAL` INFO and no ERROR anywhere. (This simulates "a partial variable" with
  HE_COUNT instead of the real EMP_STATUS data; see Deviations.)
- WP13.A6: PASS. With `ctx$data` empty (`build_ctx(tmp_root, data_files = character(0))`), every
  one of the 9 discovered `vc_rule_*()` functions returns zero rows. `testthat::test_dir(...,
  filter = "validate-rules")` runs 14 test file(s), 0 failed, 0 errored.

## Deviations           (what the card said, what you did, why)
- The card's Steps section (guidance for the implementer's own unit tests) sets POV_NUM child
  rows flat to 1,000,000 with "parent 1000000 x k". `required_rows()` gives POV_NUM six
  *different* non-TOTAL cuts with k = 2, 2, 3, 5, 6, 14 (ADM1=14, HHH_AGE=2, HHH_SEX=2, QUINT=5,
  URB=3, ZONES=6) for the same single TOTAL/parent row, so one flat child value and one k cannot
  satisfy AGG_SUM in all six cuts simultaneously. The acceptance script instead sets, per cut,
  `child = parent / k` (integer split, remainder absorbed by the last child), which reproduces
  AGG_SUM = 0 deviation in every cut at once and is provably consistent by construction. Other
  Steps-recipe values (POV_HC flat 0.2/0.4, CONS_SH flat 1/13, POP_HH_SH flat 1/5) reproduce
  exactly and were used as given.
- WP13.A5's "partial variable" half of the card names EMP_STATUS as the real-data example of an
  incomplete closure. The acceptance script instead builds a synthetic partial closure by
  restricting `POP_HH_SH.HE_COUNT_*` to 4 of its 5 categories in a temp copy of SERIES_PLAN
  (the same mechanism `make_data_fixture()`'s own `series_ids` argument uses). This exercises the
  same generic "plan vs `CL_COMP_BREAKDOWN`" mechanism the Rules section describes without
  depending on EMP_STATUS's real series ids, which are outside the card's Read list.
- `pipeline/tests/testthat/helper-data-fixture.R`'s `make_data_fixture()` writes the data
  manifest as one row with 16 columns (`dataflow, dsd_version, ..., notes`). But
  `contract/csv_headers.csv` fixes `AFW360_HH_<ISO3>_<YEAR>_manifest.csv` as a two-column
  `key,value` table, and `build_ctx()` (`pipeline/R/ctx.R`) reads it that way
  (`setNames(man_df[[2]], man_df[[1]])`). Reading a wide manifest through that logic produces a
  1-entry vector named after the *value* of column 1, so `"precision" %in% names(man_vec)` is
  always false and `ctx$precision` silently defaults to `"EXACT"` for any fixture written by
  `make_data_fixture()`. The acceptance script's own `write_fixture()` writes the contract's
  `key,value` shape instead of copying `make_data_fixture()`'s shape, so its tolerances are
  correctly ROUNDED_2DP. This is not a WP13 defect (`io.R`/`ctx.R` are WP03's, already merged;
  `helper-data-fixture.R` is WP08's, already merged), but see Questions: it likely means any
  WP11/WP12/WP14 unit test that relies on `make_data_fixture()` for a ROUNDED_2DP scenario is
  silently running under EXACT tolerances instead.
- `contract/expected_counts.csv` has no `WP13.*` rows (checked directly: 64 rows total, all
  `CELLS.*`, `LABELS.*`, `META.*`, `GEOM.*`, etc. from other cards; none match `^WP13`). WP13's
  acceptance checks are pass/fail assertions about which `check_id` a mutation produces, and the
  two checks with literal numbers (WP13.A3's 0.97/0.065 and 3130000/3120000/35000, WP13.A4's
  boundary) get those numbers directly from the card's own text, not from a lookup table. The
  script therefore never calls the skeleton's `expected()`/`meets()` helpers (kept, per the
  template, but unused). See Questions.

## Questions            (contract doubts, and anything only the user can decide)
- CONTRACT DOUBT: `contract/expected_counts.csv` has no rows for WP13 (or, by inspection, for any
  WP11-WP14 validator card), so the verifier instruction to "read expected numbers from
  contract/expected_counts.csv by check_id rather than hard-coding them" could not be followed
  for this package. WP13's numeric acceptance criteria live entirely in the card's own prose. If
  the transition wants these tolerance constants centralized in the contract instead, that needs
  a decision and a contract update; this report does not make that change.
- Worth the orchestrator's attention independent of this package's own verdict: the manifest
  shape mismatch described above (`make_data_fixture()` wide vs. `contract/csv_headers.csv` and
  `build_ctx()`'s long key/value expectation) means every wave-2/3 unit test built the way the
  cards suggest ("a data file from `make_data_fixture()`") is silently exercising EXACT-precision
  tolerances, not ROUNDED_2DP, unless a test works around it. This may be masking scale-dependent
  defects like the one below in other packages' own test suites, not just WP13's.

## Changelog line       (implementers only: the card's line, adjusted if needed)
None

## Failures to fix   (numbered; for each: the check ID, the exact command or comparison, expected
                      against actual. Write "None" on PASS.)
1. Check ID: WP13.A3.
   Command: `Rscript pipeline/acceptance/wp13_validator-rules.R --root .`
   Comparison: `vc_rule_agg_sum(ctx)` (discovered via `ls(pattern = "^vc_rule_")` on
   `pipeline/R/validate_rules.R`) on a fixture where series `POV_NUM.POVLINE_PL300.PPP_2021` has
   its TOTAL-cut (parent) row set to `3130000` and its ZONES-cut (k = 6) children set to
   `520000` each (sum `3120000`), on a data file whose manifest has `precision = ROUNDED_2DP`.
   `LEGACY_LABELS.scale` for that series is `1000000` (looked up directly from
   `meta$LEGACY_LABELS` in this repo).
   Expected (per WP13.md, "Tolerance" and WP13.A3): `h = 0.005 x scale = 0.005 x 1000000 = 5000`;
   `AGG_SUM` tolerance for a sum of `k` children `= (k + 1) x h = 7 x 5000 = 35000`; deviation
   `|3130000 - 3120000| = 10000 <= 35000 + 1e-9` -> no `RULE.AGG_SUM` finding (the card states
   this scenario "passes").
   Actual: one `RULE.AGG_SUM` ERROR finding, `message: sum=3120000 parent=3130000 deviation=10000
   tolerance=0.035`. `0.035 = 7 x 0.005 x 1`, i.e. `h` was computed with `scale = 1` (the value
   the card specifies only when a series has *no* `LEGACY_LABELS.scale` row) instead of the
   series' real scale of `1000000`. The tolerance is 1,000,000x too small, so a deviation the
   card says must pass is reported as an error.
