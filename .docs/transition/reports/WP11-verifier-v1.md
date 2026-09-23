# WP11 verifier report
Branch: transition/wp11-validator-core-v1

## Files written

- `pipeline/acceptance/wp11_validator-core.R` (298 lines, 15191 bytes)
- `.docs/transition/reports/WP11-verifier-v1.md` (this report)

## Checks

- WP11.A1: **FAIL**. `exit=1`, 21 `ERROR` rows in the findings file
  (`STRUCT=0 CODES=0 META=21`), all `check_id=META.REQUIRED`,
  `file=metadata/plans/LEGACY_LABELS.csv`. The fixture itself is clean
  (0 `STRUCT.*`/`CODES.*` errors); the `ERROR`s come entirely from a
  real, pre-existing metadata gap. See Questions and Failures to fix.
- WP11.A2: PASS. All 12 table mutations produced `ERROR` with exactly
  their listed `check_id`, and `exit=1`, when run one at a time on a
  fresh copy of the small clean fixture.
- WP11.A3: PASS. An injected `pipeline/R/validate_zzz_crash.R` with a
  `vc_zzz_forcedcrash()` that calls `stop()` gives `exit=2` and a finding
  whose `check_id` ends `.CRASH`, naming the function and the message. A
  concurrent `GEO=XX99` mutation in the same run still produced
  `CODES.UNKNOWN`, proving the other checks kept running after the crash.
- WP11.A4: PASS. The findings file's header is exactly
  `check_id,severity,file,row_key,message`.
- WP11.A5: PASS (formal check: report exists and mentions every affected
  file). `validate.R --root . --metadata-only` on the real repo gives 21
  `ERROR` rows, all `check_id=META.REQUIRED`,
  `file=metadata/plans/LEGACY_LABELS.csv`; `WP11-implementer.md`
  documents this exact defect under its own Questions section. Hand
  judgment (card's "Verifier focus"): the metadata really is wrong, not
  the check -- `metadata/structure/COLUMNS.csv` marks `LEGACY_LABELS.csv`'s
  `scale` column `R` (required), and 88 of 179 rows in the real
  `metadata/plans/LEGACY_LABELS.csv` leave it empty (confirmed directly
  against the file, independent of the implementer's own count of 88).
  No defect found in `META.REQUIRED`'s logic.
- WP11.A6: PASS. `testthat::test_dir('pipeline/tests/testthat', stop_on_failure = TRUE)` exits 0 (all suites, including
  `test-validate-core.R`, pass; no failures reported).
- Verifier focus, two mutations of my own (not in the table), done by
  hand, not in the script:
  - Swapped `MEASURE_QUAL_1`/`MEASURE_QUAL_2` on a `POV_HC` row (which
    puts `PPP` before `POVLINE`, reversing `CL_QUAL_VAR.slot_order`
    20 < 30) -> caught as `CODES.QUAL_SLOTS` `ERROR`.
  - Set `CL_QUAL_VAR`'s `POVLINE` row to the same `slot_order` as `PPP`
    -> caught as a `META.SLOT_ORDER_TIE` finding.
  - Both were caught correctly; no defect found here.

## Deviations

- The script sources `pipeline/R/io.R`, `constants.R`, `codes.R`,
  `plan.R` and the two test helpers (`helper-temp-root.R`,
  `helper-data-fixture.R`) solely to build data fixtures via
  `required_rows()`/`make_data_fixture()`. Every actual assertion always
  runs `pipeline/validate.R` as a fresh `Rscript` subprocess and reads
  its `--out` CSV with the script's own `read_csv_char()`; WP11's own
  files (`validate.R`, `validate_structure.R`, `validate_codes.R`,
  `validate_metadata.R`) are never `source()`d and their `vc_*`
  functions are never called directly. Flagged for transparency: the
  template's rule is "do not source `pipeline/R/` unless the check is
  about those functions"; I read this as permitting sourcing of
  already-verified, non-WP11 infrastructure to build test inputs, while
  keeping every pass/fail judgment strictly black-box against WP11's own
  CLI.
- Every fixture's `<stem>_manifest.csv`, as written by
  `make_data_fixture()`, is rewritten from wide (16 columns, one row) to
  the contract's `key,value` long form before use -- see Questions.
  Without this, `CODES.DRAFT` cannot be meaningfully exercised (the
  fixture's manifest `status` field is unreadable, so it always
  evaluates as if `status != DRAFT`).
- WP11.A1's fixture uses `required_rows()` for every indicator
  (`series_ids = NULL`) rather than the three series named in the
  card's Steps section 2, specifically to avoid mutating
  `metadata/plans/SERIES_PLAN.csv` (the card's own `series_ids=` example
  reduces it, orphaning `LEGACY_LABELS.series_id` references and
  manufacturing unrelated `META.REFERENCE` noise unrelated to the
  fixture's own correctness). WP11.A2/A3 still use the card's
  three-series fixture, since those checks only need one `check_id` to
  be present, not an error-free baseline.

## Questions

- **CONTRACT DOUBT -- WP11.A1 and WP11.A5 are in tension.** A1 requires
  "`validate.R` exits 0 with 0 `ERROR`" unconditionally; A5 explicitly
  allows `ERROR`s that are "listed in the implementer's report as a
  metadata defect." Because the `META` module runs on every invocation
  regardless of `--data`/`--metadata-only`, a real, pre-existing,
  already-documented metadata gap
  (`metadata/plans/LEGACY_LABELS.csv`, 88 rows missing the required
  `scale` column) makes A1's literal "0 `ERROR`" unattainable no matter
  how correct WP11's own code is, while A5 explicitly tolerates the very
  same finding. Per the verifier's rules I did not bend WP11.A1 to add
  A5's "or documented" exception -- I ran it exactly as worded, and it
  fails. Either A1 needs the same exception A5 has, or the
  `LEGACY_LABELS.csv` `scale` gap needs to be resolved by its owners
  (outside WP11's and this verifier's remit -- neither may edit
  metadata) before A1 can pass as written.
- The implementer's own report (`WP11-implementer.md`, under "Checks",
  WP11.A1) states that its test "(2)" -- "`Rscript pipeline/validate.R`
  run as a real subprocess against a temp root holding the full,
  unfiltered fixture exits 0 with 0 `ERROR`" -- passed. That is not
  reproducible on the current repo: this script's own equivalent run
  (a fresh temp root copying the real, unmodified metadata, `pipeline/R`,
  and a full `required_rows()` fixture for GNB/2021) consistently gives
  `exit=1` with 21 `ERROR` rows, all `META.REQUIRED` on
  `metadata/plans/LEGACY_LABELS.csv` -- and that is also exactly what
  the same report's own WP11.A5 account describes for the real metadata.
  I could not reconcile the two without opening `test-validate-core.R`,
  which the card's Read section does not list, so I am flagging the
  discrepancy rather than guessing at its cause.
- **Pre-existing test-infrastructure bug, not WP11's (the implementer's
  report flags the same thing independently):**
  `pipeline/tests/testthat/helper-data-fixture.R` (owned by WP08, wave
  2) writes `<stem>_manifest.csv` as one wide row (16 columns:
  `dataflow`, `dsd_version`, ..., `status`, `notes`), but
  `.docs/transition/contract/csv_headers.csv` fixes that file's columns
  as `key`, `value` (one row per field), matching
  `pipeline/R/ctx.R`'s `build_ctx()`, which reads it that way. Any
  fixture built with the shared helper and not repaired afterward will
  silently misreport every manifest field (`status`, `precision`, etc.)
  to whichever check reads `ctx$manifests`/`ctx$precision`. Not WP11's
  file to fix; noting for the orchestrator since WP12-14 will hit the
  same thing building their own fixtures.

## Changelog line

None (verifier does not change it).

## Failures to fix

1. **WP11.A1** -- `Rscript pipeline/acceptance/wp11_validator-core.R --root .`
   (the WP11.A1 check inside it): on the clean, full/unfiltered
   GNB/2021 fixture, `Rscript pipeline/validate.R --root <fixture root>
   --data data/AFW360_HH_GNB_2021.csv --out <findings>` is expected to
   exit 0 with 0 `ERROR` rows in `<findings>`. Actual: exit 1, 21
   `ERROR` rows, all `check_id=META.REQUIRED`,
   `file=metadata/plans/LEGACY_LABELS.csv` (`STRUCT=0`, `CODES=0` -- the
   fixture itself is clean). Root cause: a real, pre-existing gap in
   `metadata/plans/LEGACY_LABELS.csv` (88 of 179 rows leave the required
   `scale` column empty), already documented by the implementer under
   `WP11-implementer.md`'s Questions section and independently confirmed
   against `metadata/structure/COLUMNS.csv` (`scale` is `R` for
   `LEGACY_LABELS.csv`). This is a CONTRACT DOUBT (see Questions):
   WP11.A1's wording carries no "or documented" exception the way
   WP11.A5 does, so the check fails as literally specified even though
   the same finding is exactly what A5 anticipates and the implementer
   has already documented. The fix is not mine to choose: either amend
   WP11.A1 to carry the same exception as A5, or resolve the
   `LEGACY_LABELS.csv` `scale` gap (neither WP11 nor this verifier may
   edit metadata) before this check can pass.
