# WP08 implementer report
Branch: transition/wp08-plans

## Files written        (path, and rows or bytes)
- `pipeline/bootstrap/build_plans.R` (53 lines)
- `metadata/plans/SERIES_PLAN.csv` (92 lines = header + 91 rows, 4456 bytes)
- `metadata/plans/TAB_PLAN.csv` (9 lines = header + 8 rows, 372 bytes)
- `pipeline/R/plan.R` (295 lines; `required_rows(meta, ref_area, time_period)`)
- `pipeline/tests/testthat/test-plan.R` (262 lines, 6 `test_that()` blocks)
- `pipeline/tests/testthat/helper-data-fixture.R` (78 lines; `make_data_fixture()`)

## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)
- WP08.A1: PASS. `SERIES_PLAN` has 91 rows, one per MAP row of `label_triage.csv`; `series_id`/`INDICATOR`/`MEASURE_QUALS`/`DEFINING_BREAKDOWN` joined and compared identical to the triage's MAP rows (R check, `identical()` true). `series_id` unique (91 of 91), matches `^[A-Z0-9_.]+$`, max length 31.
- WP08.A2: PASS. `TAB_PLAN` printed and compared by eye to `contract/tab_plan.csv` plus `status="DRAFT"` on all 8 rows — identical order and values.
- WP08.A3: PASS. R check: `SERIES_PLAN.csv`/`TAB_PLAN.csv` header vectors `identical()` to the ordered `column` values from `csv_headers.csv` for each file.
- WP08.A4: PASS. `required_rows(meta,"SEN","2021")` = 3003 rows, `required_rows(meta,"GNB","2021")` = 2366 rows, built from the seeds as in step 3. Both: 18-column key has 0 duplicates (`anyDuplicated`), no column of the 18 contains `""` (`test-plan.R`, test "unique, fully populated key").
- WP08.A5: PASS. `SEX`/`AGE` are `"_Z"` exactly on non-`IND` rows, `"_T"`/real codes otherwise (test "SEX/AGE become _Z..."). `POP_HH_SH.HE_COUNT_0` × `QUINT`: `COMP_BREAKDOWN_1` = `QUINT_Q1..Q5`, `COMP_BREAKDOWN_2` = `HE_COUNT_0` (verified for all 5 rows). `POV_HC.POVLINE_PL420.PPP_2021` × `TOTAL`: `MEASURE_QUAL_1`="POVLINE_PL420", `MEASURE_QUAL_2`="PPP_2021".
- WP08.A6: PASS. Per-cut counts (SEN): TOTAL 91, URB 273, HHH_SEX 182, HHH_AGE 182, QUINT 455, ADM1 1274, ZONES 546 — all equal 91 × the card's cell counts (1/3/2/2/5/14/6). GNB: ADM1 819, AEZ 364 — equal 91 × 9 and 91 × 4. `ZONES` absent from GNB, `AEZ` absent from SEN.
- WP08.A7: PASS. `Rscript pipeline/tests/testthat.R` → `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 103 ]`. `Rscript pipeline/bootstrap/build_plans.R --root . --out-root <tempdir>` then `diff` against the committed files: both byte-identical.
- WP08.A8: PASS. `make_data_fixture(tmp_root, ref_area="GNB", series_ids=c("POV_HC.POVLINE_PL420.PPP_2021","POP_HH_SH.HE_COUNT_0"))` on a seed-built temp root writes `AFW360_HH_GNB_2021.csv` with 52 rows and the 26 `DSD_COLUMNS` in order, and `AFW360_HH_GNB_2021_manifest.csv` with the 16 keys and `n_rows`="52" (test "make_data_fixture writes a data file and manifest for GNB").

## Deviations           (what the card said, what you did, why)
- The card's Read section does not list `pipeline/tests/testthat/helper-temp-root.R`, but COMMON.md section 5 and the card's own step 4 both name `make_temp_root()` and `edit_csv()` by function name as the fixture-building convention every package uses. I read that file (60 lines) to get their exact signatures, since without it I could not call them correctly. No other file outside the card's Read list was opened.
- `helper-data-fixture.R`'s manifest fields not fixed by the card (`dsd_version`, `metadata_version`, `survey_id`, `producer`, `program`, `software`, `run_timestamp`) are set to `"TBD"` (COMMON.md section 4: TBD is allowed in a required text column on a DRAFT row when the value cannot be known from the inputs — this helper has no way to know them). `notes` is left `""` as an optional annotation. `precision`, `status`, `source_type` are set exactly as the card specifies.
- `required_rows()`'s `excluded_breakdowns` rule (step 4 of "Required rows") is applied only to the cut's `comp_breakdowns` cells, not to `GEO`/`URBANISATION`/`SEX`/`AGE`, since the card's rule 3-4 sequence describes "cells" as built from the `comp_breakdowns` cross product specifically and `meta`'s only breakdown-relevant tables are `CL_BRK_VAR`/`CL_COMP_BREAKDOWN`. Tested explicitly (both a category-level and a variable-level exclusion) in the made-up two-cut plan.
- Sort order uses `method = "radix"` (byte/C-locale order) throughout, for determinism regardless of session locale (COMMON.md section 5, "byte-identical" requirement in A7).

## Questions            (contract doubts, and anything only the user can decide)
None.

## Changelog line       (implementers only: the card's line, adjusted if needed)
SERIES_PLAN, TAB_PLAN, and the required-row generator.
