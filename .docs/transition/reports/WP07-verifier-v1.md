# WP07 verifier report
Branch: transition/wp07-dictionary-v1

## Files written
- `pipeline/acceptance/wp07_dictionary.R` (245 lines, 11,853 bytes) — one `check()` per WP07.A1-A8, rebuilding expected values from `.docs/transition/contract/label_triage.csv` (MAP rows) and `.docs/transition/contract/codes.csv` (`CL_QUALIFIER`, `CL_QUAL_VAR`, `CL_THEME`, `CL_STAT_UNIT`, `CL_STATISTIC`, `CL_WEIGHT`, `CL_UNIT`), reading `expected_counts.csv` by `check_id` (`INDICATOR.CODES`), and rebuilding `metadata/codelists/CL_INDICATOR.csv` into a `tempdir()` for the byte-for-byte check. Does not source `pipeline/R/`.
- `.docs/transition/reports/WP07-verifier-v1.md` (this report)

## Checks
- WP07.A1: PASS — codes_match=TRUE no_dup=TRUE n=62 expected=62
- WP07.A2: PASS — all 12 mechanical columns (`stat_unit, statistic, weight, ref_period, unit_measure, unit_denom, unit_time, price_basis, display_as, decimals, valid_min, valid_max`) match the triage value for all 62 codes
- WP07.A3: PASS — `qualifiers` rebuilt from triage `MEASURE_QUALS` + `codes.csv` (`CL_QUALIFIER`/`CL_QUAL_VAR`) matches for all 62 codes
- WP07.A4: PASS — `checks` rebuilt from the 5-token rule matches for all 62 codes; 0 vocabulary violations
- WP07.A5: PASS — `theme`, `stat_unit`, `statistic`, `weight`, `unit_measure` are valid codes of `CL_THEME`/`CL_STAT_UNIT`/`CL_STATISTIC`/`CL_WEIGHT`/`CL_UNIT`; every `related` code exists in the file
- WP07.A6: PASS — `short_name_en` <= 40 chars for all rows; every required (R) column filled; `higher_is` in {BETTER, WORSE, NEUTRAL} for all rows
- WP07.A7: PASS — header matches `csv_headers.csv` (37 columns, in order); `status` is `DRAFT` on all 62 rows
- WP07.A8: PASS — `Rscript pipeline/bootstrap/build_indicators.R --root . --out-root <tempdir>` exits 0 and reproduces `metadata/codelists/CL_INDICATOR.csv` byte for byte (md5 match)

## Deviations
- The card's `checks` token rule (bullets 1-5) does not state what to write when zero tokens apply. Since `NONE` is listed in WP07.A4's vocabulary but assigned no rule of its own, the acceptance script treats an empty token set as `NONE`. This branch was not exercised by the real data (every indicator produced at least one token, including `EN_OUTAGE_DUR_CODE`, which got `RANGE_NONNEG` alone), so it did not affect the PASS verdict, but it is an inference, not a literal reading of the card.
- Two structural facts needed to write the script correctly were not spelled out in the card's Read section and were confirmed by inspecting schema only (column names / distinct `codelist` values, zero data rows read beyond what the Read section allows): (a) `contract/codes.csv` columns are `codelist, code, var_code, parent, order, slot_order, describes, applies_to_units, partition, requires, valid_with, value, status, notes`, with qualifier variables living in `codelist == "CL_QUAL_VAR"` (code, slot_order) and qualifier codes in `codelist == "CL_QUALIFIER"` (code, var_code, order); (b) the codelist names behind `theme/stat_unit/statistic/weight/unit_measure` are `CL_THEME/CL_STAT_UNIT/CL_STATISTIC/CL_WEIGHT/CL_UNIT` (not `CL_UNIT_MEASURE`). No row-level content of `label_triage.csv` beyond the columns the card names (`action`, `INDICATOR`, `legacy_label`, `hard_case`, `notes`, `MEASURE_QUALS`, and the 12 named mechanical columns) was read, other than the 15-row sample required by "Verifier focus" and a 3-row spot check (2 SHK rows + SP_HEALTH_COV) of the `notes` column to confirm the implementer's `LEGACY assumed` wording traces to the triage's own notes rather than being invented — both explicitly within the card's permitted `INDICATOR, notes` slice.

## Questions
CONTRACT DOUBT: the card's "Columns the script derives" table gives derivation rules for `universe_unit` (equals `stat_unit`) and `theme` (a lookup/prefix rule), but no acceptance-check ID tests that either rule was applied correctly. WP07.A6 only checks that these R columns are non-empty; WP07.A5 only checks that `theme`/`stat_unit` are *valid* codes of their codelists, not that they are the *correct* code for that indicator (e.g. that `POV_HC` got `theme=POV` specifically, or that `universe_unit` actually equals that row's own `stat_unit`). WP07.A2's "mechanical column equals the triage value" wording only fits the 12 columns literally "Copied from the triage"; it does not cover `universe_unit` or `theme`, which are derived, not copied. This looks like a gap in the card's acceptance checks. I did not bend WP07.A2 or WP07.A5 to cover it, and I spot-checked it by hand in this session (all 62 rows: `universe_unit == stat_unit` held for every row, and the 6 sampled `theme` values matched the card's rule) — but this is not enforced by any check() the merged suite will keep running, so a future regression on `theme`/`universe_unit` correctness would not be caught.

## Changelog line
None

## Failures to fix
None
