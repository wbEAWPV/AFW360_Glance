# WP12 verifier report
Branch: transition/wp12-validator-coverage-v1

## Files written        (path, and rows or bytes)
- pipeline/acceptance/wp12_validator-coverage.R (270 lines)
- .docs/transition/reports/WP12-verifier-v1.md (this file)

## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)
- WP12.A1: PASS — clean GNB fixture (series AGR_CULT_AREA + EN_ELEC_ACCESS, 43 rows, withheld cells removed): 0 ERROR findings from all 11 `vc_cover_*`/`vc_value_*` functions.
- WP12.A2: PASS — all 9 mutations gave exactly their stated check_id and no other ERROR check_id: row deleted → COVER.MISSING; row added with an unplanned COMP_BREAKDOWN_1 → COVER.EXTRA; a withheld row added back → COVER.WITHHELD_PRESENT; manifest n_rows changed → COVER.MANIFEST; manifest survey_id="XXX" → COVER.SURVEY; EN_ELEC_ACCESS share set to 1.3 → VALUE.RANGE; a value "1e-3" → VALUE.NUMERIC; an O row given a value → VALUE.STATUS_EMPTY; an A row emptied → VALUE.STATUS_EMPTY; an O row with an empty comment → VALUE.LEGACY_EMPTY.
- WP12.A3: PASS — on the real metadata: `withheld_rows(meta,"GNB","2021")` = 98 rows (contract GNB.WITHHELD_CELLS = 98, tol 0); `withheld_rows(meta,"SEN","2021")` = 0 rows; `nrow(required_rows(meta,"GNB","2021")) - 98` = 2268 (contract GNB.DATA.ROWS = 2268, tol 0).
- WP12.A4: PASS — with `ctx$data` empty (`build_ctx(root, character(0))`), all 11 functions returned 0 rows and none errored.
- WP12.A5: PASS — `testthat::test_dir(pipeline/tests/testthat, filter="validate-coverage")` ran 18 tests in test-validate-coverage.R: 0 failed, 0 errored.

Command used: `Rscript pipeline/acceptance/wp12_validator-coverage.R --root .` — full run: all 5 checks PASS, exit status 0.

## Verifier focus
Rebuilt the withheld key set for GNB independently (without calling `withheld_rows()`) and compared it to `withheld_rows(meta, "GNB", "2021")`'s actual output:

1. Read the raw workbook `data_raw/tables/Tables_GNB.xlsx` (sheets National, ADM 1, ZAE) directly with `readxl::read_excel`. Confirmed all 8 columns named in `metadata/plans/LEGACY_OVERRIDES.csv`'s GNB `action=WITHHOLD` rows exist verbatim in the real sheets: National has `estimateCapital`, `estimateTotal`, `estimateRural`, `estimateMale_HH`, `estimateOlder_HH`, `estimateQ4`; ADM 1 has `estimateQuinara`; ZAE has `estimateZonas_Costeiras_do_Sul`.
2. From `metadata/plans/LEGACY_LABELS.csv`, counted 91 rows with `sheet="*"` and `action="MAP"`, all with distinct `series_id` values — this is the independent "91 mapped labels" set the wildcard-label WITHHOLD row (National, estimateCapital, label=`*`) applies to.
3. From `metadata/codelists/geo_codes.csv`, confirmed `GW07` → name "Quinara", `legacy_column estimateQuinara`, and `GW_AEZ02` → name "Zonas Costeiras do Sul", `legacy_column estimateZonas_Costeiras_do_Sul`, matching the two geo-coded LEGACY_OVERRIDES rows.
4. Called `withheld_rows(load_metadata(root), "GNB", "2021")` (98 rows) only to compare against, not to derive my set. Its 91 rows with `URBANISATION="CAP", GEO="_T"` have `series_id` values that are set-equal to the 91 MAP-label series from step 2 (`setdiff` both directions = 0 — exact key-set match, not just a count match). Its remaining 7 rows are, one for one: `cut_id=TOTAL` (National Total), `cut_id=URB, URBANISATION=R` (National Rural), `cut_id=HHH_SEX, COMP_BREAKDOWN_1=HHH_SEX_M` (National Male_HH), `cut_id=HHH_AGE, COMP_BREAKDOWN_1=HHH_AGE_GE35` (National Older_HH), `cut_id=QUINT, COMP_BREAKDOWN_1=QUINT_Q4` (National Q4), `cut_id=ADM1, GEO=GW07` (Quinara), `cut_id=AEZ, GEO=GW_AEZ02` (Zonas Costeiras do Sul) — each matching one of the 7 column-specific LEGACY_OVERRIDES rows for `AGR_CULT_AREA` ("Cultivated area (ha)").

No mismatch found. `withheld_rows()`'s key set is exactly the set the raw workbook and LEGACY_OVERRIDES.csv imply. No defect.

## Ownership check
`git diff --name-only transition/main...transition/wp12-validator-coverage` lists 4 paths:
- `.docs/transition/reports/WP12-implementer.md` — owned by `WPNN` under the glob `.docs/transition/reports/WPNN-implementer*.md` (output_ownership.csv row 123), i.e. WP12's own report.
- `pipeline/R/validate_coverage.R` — owned by WP12 (row 96).
- `pipeline/R/validate_values.R` — owned by WP12 (row 97).
- `pipeline/tests/testthat/test-validate-coverage.R` — owned by WP12 (row 98).

All 4 paths are owned by WP12 or are its own report. No unowned path. PASS.

## Deviations             (what the card said, what you did, why)
- The card's Step 2 says "delete the withheld rows from the fixture file to get a clean start" using `make_data_fixture()`. I did this, but I did **not** keep the manifest that `make_data_fixture()` writes: I wrote my own manifest in the contract's key/value shape instead (see Questions below), with `survey_id="GNB_EHCVM_2021"` (a real row in `metadata/surveys/SURVEYS.csv`) rather than the helper's default `"TBD"`, because `COVER.SURVEY`'s rule requires a real match for a clean (0-ERROR) baseline, and `"TBD"` is not a `survey_id` in `SURVEYS.csv`.
- WP12.A2 is a single check_id on the card covering 9 mutations; I implemented it as one `check("WP12.A2", ...)` call whose evidence string reports all 9 sub-results, rather than inventing 9 separate check IDs not on the card.
- Function names (`vc_cover_<check>`, `vc_value_<check>`) are built programmatically from each `check_id` (lower-cased suffix) per the card's Interface section, rather than typed out, since the card does not give a literal name list; this matched the implementer's actual names on the first run.

## Questions             (contract doubts, and anything only the user can decide)
CONTRACT DOUBT: `pipeline/tests/testthat/helper-data-fixture.R` (WP08, wave 2, already merged — not owned by WP12) writes each fixture's `<stem>_manifest.csv` as a **wide** one-row table with the 16 manifest keys as column names (`dataflow,dsd_version,...,notes` as headers, one data row). `.docs/transition/contract/csv_headers.csv` defines that file's columns as `key,value` (2 columns, R/R) — a **long**, one-row-per-key shape — and `pipeline/R/ctx.R`'s `build_ctx()` parses manifests assuming exactly that long shape (`man_df[[1]]` = keys, `man_df[[2]]` = values). Empirically, feeding `build_ctx()` a manifest written by `make_data_fixture()` as-is collapses all 16 keys into one bogus entry (name = the `dataflow` value, e.g. `"AFW360_HH"`; value = the `dsd_version` value, e.g. `"TBD"`), so `ctx$manifests[[key]]` never contains any of the real 16 keys and `ctx$precision[key]` always falls back to `"EXACT"` regardless of what precision was written. Any wave-3 package that builds a fixture with `make_data_fixture()` and feeds it straight to `build_ctx()` gets a manifest `COVER.MANIFEST` cannot pass (all 16 keys "missing") and a precision `VALUE.N`/`VALUE.LEGACY_EMPTY` cannot read correctly. I worked around this in my own acceptance script by writing manifests myself in the contract's `key,value` shape (see Deviations) rather than editing the shared helper, since fixing a deliverable is not a verifier's job. This is not a WP12 defect — WP12's own files were not touched to investigate whether `test-validate-coverage.R` hit the same issue — but it is a real mismatch between two already-merged, shared pieces of infrastructure (`helper-data-fixture.R` vs. `ctx.R`/`csv_headers.csv`) that every wave-3 verifier building fixtures this way will meet.

## Changelog line
None (verifiers do not write one; see COMMON.md section 8).

## Failures to fix   (numbered; for each: the check ID, the exact command or comparison, expected against actual. Write "None" on PASS.)
None.
