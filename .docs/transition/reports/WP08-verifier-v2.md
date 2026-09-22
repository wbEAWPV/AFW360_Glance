# WP08 verifier report
Branch: transition/wp08-plans-v2

## Files written
- `pipeline/acceptance/wp08_plans.R` (313 lines, 17108 bytes) -- already present on the branch from `WP08: verify v1`; reviewed against the card and corrected (see Deviations). Not a new file.
- `.docs/transition/reports/WP08-verifier-v2.md` -- this report.

## Checks
- WP08.A1: PASS -- SERIES_PLAN rows=91 (matches SERIES.COUNT=91 and triage MAP rows=91), series_id/INDICATOR/MEASURE_QUALS/DEFINING_BREAKDOWN equal the triage's, series_id unique and code-shaped.
- WP08.A2: PASS -- TAB_PLAN rows=8, columns and row content equal `contract/tab_plan.csv` plus `status=DRAFT`, count matches META.TAB_PLAN=8.
- WP08.A3: PASS -- SERIES_PLAN and TAB_PLAN headers equal `csv_headers.csv`.
- WP08.A4: PASS -- `required_rows(meta,"SEN","2021")` = 3003 rows (= DATA.SEN.ROWS), `required_rows(meta,"GNB","2021")` = 2366 rows (= GNB.MAPPED_CELLS); both have a unique 18-column key and no empty cell.
- WP08.A5: PASS -- SEX/AGE are `_Z` exactly for non-IND `stat_unit` rows; `POP_HH_SH.HE_COUNT_0`/QUINT rows have `COMP_BREAKDOWN_1` starting `QUINT_` and `COMP_BREAKDOWN_2=HE_COUNT_0`; `POV_HC.POVLINE_PL420.PPP_2021`/TOTAL row has `MEASURE_QUAL_1=POVLINE_PL420`, `MEASURE_QUAL_2=PPP_2021`.
- WP08.A6: PASS -- per-cut row counts equal series count (91) x cut cell count, computed independently from `codes.csv`/`geo_codes.csv` (not by re-deriving from `required_rows()`'s own logic): TOTAL 91, URB 273, HHH_SEX 182, HHH_AGE 182, QUINT 455, ADM1 1274 (SEN)/819 (GNB), ZONES 546 (SEN only), AEZ 364 (GNB only); no AEZ rows for SEN, no ZONES rows for GNB.
- WP08.A7: PASS -- `test-plan.R`'s 5 tests pass (0 failed, 0 errors); `build_plans.R --out-root <tempdir>` reproduces `metadata/plans/SERIES_PLAN.csv` and `TAB_PLAN.csv` byte for byte against the committed blobs at HEAD.
- WP08.A8: PASS (after correction) -- `make_data_fixture()` on a seed-built temporary root with `series_ids=c("POV_HC.POVLINE_PL420.PPP_2021","POP_HH_SH.HE_COUNT_0")`, `ref_area="GNB"` writes a 52-row data file with the 26 DSD columns in order, and a manifest in `key,value` long form (16 rows, one per key of `csv_headers.csv`'s `AFW360_HH_<ISO3>_<YEAR>_manifest.csv`) whose `n_rows` value is `52`.

Verifier focus (by hand, not in the script): wrote an independent expansion of `required_rows(meta, "GNB", "2021")` from the card's "Required rows" rules and `codes.csv`/`geo_codes.csv`/`label_triage.csv` only (never reading `pipeline/R/plan.R`'s source), then sourced `plan.R` to get the real function's output. Both key sets have exactly 2366 unique 18-column keys; `setdiff()` in both directions is empty -- no discrepancy. No defect found.

Ownership check (by hand): `git diff --name-only transition/main...transition/wp08-plans-p1` lists 3 paths -- `pipeline/tests/testthat/helper-data-fixture.R` and `pipeline/tests/testthat/test-plan.R`, both owned `WP08` in `output_ownership.csv`; and `.docs/transition/reports/WP08-implementer-p1.md`, matched by the glob row `.docs/transition/reports/WPNN-implementer*.md` (owner `WPNN`, i.e. that package's own implementer/patch report). No unowned path.

## Deviations
- The card says "If a later attempt finds the script already on the branch, review it against the card and keep or correct it." The v1 script's WP08.A8 block read the fixture's manifest as one wide row (`nrow(mf)==1`, `mf$n_rows`), which no longer matches `contract/csv_headers.csv`'s `key,value` long form for `AFW360_HH_<ISO3>_<YEAR>_manifest.csv` (2 columns, 16 rows) now that `helper-data-fixture.R` was patched (p1) to write that form. Running the unmodified script reproduced exactly the failure the p1 patch agent reported: `CHECK WP08.A8 FAIL ... (16 keys=FALSE) ... FALSE`. Corrected the check to read the manifest as `key`/`value` rows, assert 16 distinct keys matching the card's list, and read `n_rows` from the row where `key=="n_rows"`. Re-ran: all 8 checks PASS, including WP08.A8. This is the "CONTRACT DOUBT" scenario resolved per plan.qmd's rule (machine-readable `contract/csv_headers.csv` wins over the old wide-row assumption); the card's own prose never specified a wide-row form, so no card/contract conflict to report -- the v1 script's assumption was simply stale relative to the corrected deliverable.

## Questions
None.

## Changelog line
None (verifier report; not applicable).

## Failures to fix
None.
