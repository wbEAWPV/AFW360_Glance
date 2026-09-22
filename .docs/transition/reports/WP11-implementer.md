# WP11 implementer report
Branch: transition/wp11-validator-core

## Files written

- `pipeline/validate.R` (125 lines, 4404 bytes)
- `pipeline/R/validate_structure.R` (114 lines, 3627 bytes)
- `pipeline/R/validate_codes.R` (456 lines, 16871 bytes)
- `pipeline/R/validate_metadata.R` (282 lines, 10526 bytes)
- `pipeline/tests/testthat/test-validate-core.R` (423 lines, 17054 bytes)

## Checks

- WP11.A1: PASS. Two tests cover this: (1) the small clean fixture (the
  three series named on the card) gives 0 `ERROR` from every `STRUCT.*`
  and `CODES.*` check; (2) `Rscript pipeline/validate.R` run as a real
  subprocess against a temp root holding the full, unfiltered fixture
  exits 0 with 0 `ERROR` in the findings file.
- WP11.A2: PASS. All 12 table mutations implemented, each asserted to give
  `ERROR` with exactly that `check_id` (and no other) when every `vc_*`
  check is run together: `STRUCT.HEADER`, `STRUCT.EMPTY_KEY`,
  `STRUCT.DUPLICATE_KEY`, `CODES.UNKNOWN`, `CODES.GEO_ADM0`,
  `CODES.BRK_SLOTS`, `CODES.SEX_AGE_UNIT`, `CODES.VALID_WITH`,
  `CODES.QUAL_DECLARED`, `META.CODE_SYNTAX`, `META.REFERENCE`,
  `META.TBD`. Also added 5 mutations of my own beyond the table, for the
  checks the table doesn't cover: `CODES.GEO_AREA`, `CODES.QUAL_SLOTS`,
  `CODES.BRK_UNIT`, `META.CODE_UNIQUE`, `META.HEADER` -- all isolate to
  exactly their check_id.
- WP11.A3: PASS. A temp root copies `metadata`, `content` and the whole
  `pipeline` tree, gets an extra `pipeline/R/validate_zzzcrash.R` defining
  a `vc_zzz_boom()` that calls `stop()`, and `validate.R --metadata-only`
  run as a subprocess exits 2, the findings file contains `ZZZ.CRASH`, and
  `META.TBD`/`META.REQUIRED` findings from the other checks are still
  present.
- WP11.A4: PASS. `validate.R --metadata-only` on the real repo, findings
  file header is exactly `check_id,severity,file,row_key,message`.
- WP11.A5: PASS with one reported metadata defect (see Questions).
  `validate.R --metadata-only` on the real, merged metadata gives ERRORs
  only from `META.REQUIRED` on `metadata/plans/LEGACY_LABELS.csv`; every
  other check (`STRUCT.*`, `CODES.*` -- vacuous with no data --,
  `META.HEADER`, `META.CODE_SYNTAX`, `META.CODE_UNIQUE`,
  `META.REFERENCE`, `META.SLOT_ORDER_TIE`) gives 0 `ERROR`. `META.TBD`
  gives only `WARN` (every row is `DRAFT`).
- WP11.A6: PASS. `Rscript pipeline/tests/testthat.R` from the repo root:
  `179 PASS, 0 FAIL, 0 WARN, 0 SKIP` (151 pre-existing + 28 from
  `test-validate-core.R`).

## Deviations

- The cap ("keep the first 20 findings per check_id+file, add one SUMMARY
  finding") is implemented once, centrally, in `validate.R` after
  collecting every check's output, rather than inside each `vc_*`
  function. The card states the cap once under "Findings format" (shared
  word-for-word by WP11-WP14) rather than under WP11's own checks, and
  `validate.R` already does the other whole-run post-processing (sorting,
  the summary line, exit code) -- centralizing keeps WP12/13/14's modules
  from each having to reimplement it. No check function on this card ever
  produces more than 20 findings for one file except `META.REQUIRED` on
  the real `LEGACY_LABELS.csv` defect below, which the real run confirms
  is capped correctly (21 rows: 20 + 1 SUMMARY).
- Severity: the card states severity explicitly only for `CODES.GEO_ADM0`
  ("Severity ERROR"), `CODES.DRAFT` (WARN/ERROR by manifest status),
  `META.TBD` (WARN/ERROR by row status) and `META.SLOT_ORDER_TIE` (always
  WARN). Every other check in "Checks to implement" is given `ERROR`,
  since WP11.A2's table requires `ERROR` (to reach exit 1) for every
  check_id it lists that has no stated exception, and the remaining
  unlisted checks (`CODES.GEO_AREA`, `CODES.QUAL_SLOTS`, `CODES.BRK_UNIT`,
  `META.HEADER`, `META.REQUIRED`, `META.CODE_UNIQUE`) are the same kind of
  hard structural/reference rule.
- `CODES.QUAL_DECLARED`/`CODES.VALID_WITH` test isolation: real
  `SERIES_PLAN.csv` currently has no series pairing the `POOR` breakdown
  (whose `requires_qual` is the only non-blank one) with an indicator, so
  a natural fixture row can't exercise the `requires_qual` bypass. The
  `CODES.VALID_WITH` test therefore also sets `COMP_BREAKDOWN_1` to
  `POOR_Y` on the target row (in addition to the `PPP_2017` mutation being
  asserted), so that row is granted `POVLINE`/`PPP` via
  `CL_BRK_VAR.requires_qual` and the test isolates `CODES.VALID_WITH` from
  `CODES.QUAL_DECLARED` (`POV_HC`'s own `qualifiers` field declares only
  `PPP_2021`, so an unadorned `PPP_2017` row would also trip
  `QUAL_DECLARED`). Commented in the test.
- `META.REFERENCE`'s rule list gives most source/target column pairs by
  name but says only "the codes in LEGACY_COLUMNS" for that file. I
  resolved that as its three coded columns (`GEO` -> `CL_GEO.code`,
  `URBANISATION` -> `CL_URBANISATION.code`, `COMP_BREAKDOWN` ->
  `CL_COMP_BREAKDOWN.code`) plus `cut_id` -> `TAB_PLAN.cut_id` (same name,
  same shape as a foreign key, and `TAB_PLAN.cut_id` is the only file with
  a matching primary key). `ref_area` is excluded, matching the pattern
  elsewhere on the card (e.g. `SERIES_PLAN.ref_area`, which can be `ALL`,
  is never asked to resolve against `CL_AREA`).
- Row_key for a metadata/content row: the card gives the identifying
  column(s) only for `CL_GEO_SCHEME` ("unique on ref_area plus code") and,
  by example, `LEGACY_COLUMNS` (`ref_area sheet column`). For every other
  file I picked the natural primary-key column(s) from
  `metadata/structure/COLUMNS.csv` (`code` for every `CL_*` file;
  `series_id` for `SERIES_PLAN`; `legacy_label`+`sheet` for
  `LEGACY_LABELS`; etc. -- see `.META_KEY_MAP` in
  `validate_metadata.R`), falling back to the first column when a file
  isn't in that map.

## Questions

- **Real metadata defect (WP11.A5)**: `metadata/plans/LEGACY_LABELS.csv`
  leaves the required (`R`) column `scale` empty on 88 rows -- 82 with
  `sheet=Departement` (e.g. `legacy_label="(max) con_1"`, `action=SKIP`)
  and 6 with `sheet=*` (`legacy_label` in `"Food consumption share"`,
  `"HH has internet access"`, `"HH owns a non-agric enterprise"`,
  `"Housing & utilities burden (COICOP 4 share of total cons.)"`,
  `"Non-food consumption share"`, `"wood_dist [ALL MISSING]"`). All have
  `action` other than `MAP`. This breaks `META.REQUIRED` (`scale` is `R`
  in `metadata/structure/COLUMNS.csv`). Not edited, per the working rule;
  `validate.R --metadata-only` on the real repo reports these 88 rows
  (capped to 20 + 1 SUMMARY, all under `check_id=META.REQUIRED`,
  `file=metadata/plans/LEGACY_LABELS.csv`).
- **Test-helper/contract mismatch (not a metadata defect, but blocks
  testing CODES.DRAFT's WARN branch and would silently miscount `--data`
  files' precision anywhere `ctx$manifests`/`ctx$precision` are read)**:
  `.docs/transition/contract/csv_headers.csv` fixes
  `AFW360_HH_<ISO3>_<YEAR>_manifest.csv` as two columns, `key` and
  `value`, one row per key -- matching `build_ctx()`'s own doc comment
  ("a named character vector (key to value) read from the
  `<stem>_manifest.csv` file"). But
  `pipeline/tests/testthat/helper-data-fixture.R`'s `make_data_fixture()`
  writes the manifest as one wide row (16 columns: `dataflow`,
  `dsd_version`, ..., `status`, `notes`). Read back through
  `build_ctx()`, that becomes a single, wrong key/value pair
  (`c(dataflow = "TBD")`, i.e. column 1's name to column 2's value), so
  `ctx$manifests[[stem]]["status"]` is always `NA` and `ctx$precision`
  always falls back to `"EXACT"` regardless of the fixture's real
  `precision`/`status`. I did not edit `helper-data-fixture.R` (a shared
  wave-2 test helper, not this card's file to fix); every test here that
  needs a working manifest repairs its own temp copy first
  (`.fix_manifest_format()` in `test-validate-core.R`, rewriting the one
  wide row into `key,value` rows). Worth fixing `helper-data-fixture.R` to
  match the contract so WP12-14's tests don't hit the same thing.

## Changelog line

Validator core: structure, codes and metadata checks.
