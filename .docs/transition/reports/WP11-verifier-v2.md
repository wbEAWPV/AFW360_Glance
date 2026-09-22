# WP11 verifier report
Branch: transition/wp11-validator-core-v2

## Files written
- `pipeline/acceptance/wp11_validator-core.R` (299 lines) — found already committed on
  `transition/wp11-validator-core-p2` by the v1 verifier (commit e4002bf). Reviewed it
  line by line against WP11.md and COMMON.md; it correctly implements all six acceptance
  checks (one `check()` per card check ID, IDs spelled exactly), runs `pipeline/validate.R`
  only as a subprocess (never sources `validate.R`, `validate_structure.R`,
  `validate_codes.R` or `validate_metadata.R`), writes only under `tempfile()`/`tempdir()`,
  and reads no numeric value from `contract/expected_counts.csv` because that file has no
  `WP11.*` rows (confirmed: 0 matching rows of 64 total) — all six WP11 checks are
  existence/exit-code checks, so nothing needed to look up. Kept unmodified — 0 lines changed.
- `.docs/transition/reports/WP11-verifier-v2.md` (this file).

## Checks
- WP11.A1: PASS — `validate.R` on the full clean GNB/2021 fixture: exit=0, ERROR rows=0
  (STRUCT=0, CODES=0, META=0). Confirms the p2 patch agent's claim independently; the
  `LEGACY_LABELS.csv` `scale` R→C contract fix (c321d51 / db069ac) is effective and
  `vc_meta_required()` no longer flags the 88 non-MAP rows.
- WP11.A2: PASS — all 12 table mutations reproduced exactly, each giving exit=1 with its
  exact `check_id` among the ERROR rows: STRUCT.HEADER, STRUCT.EMPTY_KEY,
  STRUCT.DUPLICATE_KEY, CODES.UNKNOWN, CODES.GEO_ADM0, CODES.BRK_SLOTS,
  CODES.SEX_AGE_UNIT, CODES.VALID_WITH, CODES.QUAL_DECLARED, META.CODE_SYNTAX,
  META.REFERENCE, META.TBD (12/12 caught).
- WP11.A3: PASS — a check function that calls `stop()` (injected as
  `pipeline/R/validate_zzz_crash.R`, discovered by `validate.R`'s own
  `ls(pattern="^vc_")`/`validate_*.R` sourcing) gives exit=2 and one finding whose
  `check_id` ends `.CRASH` and whose message names both the function
  (`vc_zzz_forcedcrash`) and the `stop()` text; `CODES.UNKNOWN` (from a GEO=XX99 mutation
  applied in the same run) still appears among the ERRORs, proving the other checks kept
  running after the crash.
- WP11.A4: PASS — the findings CSV's columns are exactly
  `check_id,severity,file,row_key,message`, in that order.
- WP11.A5: PASS — `validate.R --metadata-only` on the real, committed metadata (this
  branch's actual root, not a copy) gives exit=0 with 0 ERROR rows from STRUCT, CODES or
  META. Nothing to judge under "is the metadata really wrong, or is the check" — there are
  no reported defects.
- WP11.A6: PASS — `testthat::test_dir("pipeline/tests/testthat", stop_on_failure=TRUE)`
  exits 0; all suites green (codes, content, ctx, geo, io, plan, validate-core).

### Verifier focus (by hand, not in the script)
Two mutations not in the card's table, run directly against `pipeline/validate.R` as a
subprocess (fixtures built the same way as the acceptance script's, then discarded):
1. Duplicated the `code="F"` row in `metadata/codelists/CL_SEX.csv` (a `META.CODE_UNIQUE`
   case not in the table) → exit=1, ERROR `META.CODE_UNIQUE`. Caught correctly.
2. Built the small GNB/2021 fixture, then edited its manifest's `status` field from
   `DRAFT` to `ACTIVE` (a `CODES.DRAFT` severity-escalation case not in the table, since
   every code in this transition is still `status=DRAFT`) → exit=1, `CODES.DRAFT` reported
   at severity `ERROR`. The same fixture left with manifest `status=DRAFT` instead reports
   `CODES.DRAFT` at severity `WARN`. Both severities match the card's rule exactly
   ("WARN when the file's manifest has status = DRAFT, and ERROR otherwise"). Caught
   correctly, both directions.

No defect found in either mutation.

### Ownership check (by hand)
`git diff --name-only transition/main...transition/wp11-validator-core-p2` lists 13 paths.
Checked each against `.docs/transition/contract/output_ownership.csv`:
- `pipeline/validate.R`, `pipeline/R/validate_structure.R`, `pipeline/R/validate_codes.R`,
  `pipeline/R/validate_metadata.R`, `pipeline/tests/testthat/test-validate-core.R` — owner
  `WP11` (rows 92-96), literal.
- `pipeline/acceptance/wp11_validator-core.R` — matches the `pipeline/acceptance/wpNN_*.R`
  glob, owner `VER`, "one acceptance script per package, written by that package's
  verifier" (row 122): this is WP11's own acceptance script by that convention.
- `.docs/transition/reports/WP11-implementer.md`, `WP11-implementer-p1.md`,
  `WP11-implementer-p2.md` — match the `WPNN-implementer*.md` glob, owner `WP11` (row 124).
- `.docs/transition/reports/WP11-verifier-v1.md` — matches the `WPNN-verifier-v*.md` glob
  (row 123): WP11's own prior verifier report.
- `.docs/transition/contract/csv_headers.csv`, `metadata/structure/COLUMNS.csv`,
  `.docs/transition/reports/WP03-implementer-p1.md` — the three named exceptions from the
  orchestrator's notes. Diffed the first two directly against `transition/main`: the only
  changes are exactly the three described cells (`AFW360_HH_<ISO3>_<YEAR>.csv,24,N_OBS`
  R→C; `...,25,N_POP` R→C; `LEGACY_LABELS.csv,6,scale` R→C in `csv_headers.csv`, and the
  matching `LEGACY_LABELS.csv,6,scale` R→C in `COLUMNS.csv`) — confirmed, nothing else
  changed in either file.

All 13 paths accounted for. No unowned path. Ownership check: PASS.

## Deviations
- The acceptance script was already present on the branch (written by the v1 verifier,
  commit e4002bf on `transition/wp11-validator-core-p2`). Per the prompt's instruction to
  "review it against the card and keep or correct it," I reviewed it in full against
  WP11.md and COMMON.md and found it correct: it exercises `validate.R` only via a fresh
  `Rscript` subprocess per check, never sources WP11's own `pipeline/R/validate_*.R` or
  `pipeline/validate.R`, and confines all writes to `tempfile()`/`tempdir()`. Kept
  unchanged.
- The script does source `pipeline/R/io.R`, `constants.R`, `codes.R` and `plan.R` (plus
  the two test helpers) to build synthetic data fixtures via `make_data_fixture()` /
  `required_rows()`. These are pre-existing, already-merged wave-1/2 shared infrastructure
  that WP11 does not own (confirmed against `output_ownership.csv`) and are not the
  functions the checks are about — the checks are about `pipeline/validate.R` and the
  `vc_*` modules, which are never sourced, only invoked as a subprocess. Building a fixture
  any other way would mean re-deriving `required_rows()`'s slot/qualifier/unit legality
  rules by hand inside the acceptance script, which the card's own "Steps" section directs
  implementers away from (it tells them to use exactly this fixture-building path for their
  unit tests). Read as intended: the "do not source pipeline/R/ unless the check is about
  those functions" rule is about not bypassing the CLI to call the checked module's
  internals directly, not about avoiding shared, already-merged, non-owned fixture
  infrastructure.
- The v1 verifier's script builds two different fixtures: a full one (`series_ids = NULL`)
  for WP11.A1, and a smaller three-series one (matching the card's Steps section 2 example)
  for WP11.A2/A3's mutations. Confirmed this is deliberate and documented in the script's
  own comments: trimming `SERIES_PLAN.csv` orphans `LEGACY_LABELS.series_id` references and
  manufactures unrelated `META.REFERENCE` noise, which would make WP11.A1's "0 ERROR"
  check fail for a reason unrelated to `validate.R`'s correctness. WP11.A2/A3 only assert
  that a mutation's specific `check_id` appears among the ERRORs, so that pre-existing
  noise does not affect them (confirmed directly in my own hand mutation 2 above, which hit
  the same small fixture and also showed unrelated `META.REFERENCE` noise alongside the
  correctly-caught `CODES.DRAFT`).

## Questions
None. No contract doubt found.

## Changelog line
None (verifier report; not an implementer changelog entry).

## Failures to fix
None.
