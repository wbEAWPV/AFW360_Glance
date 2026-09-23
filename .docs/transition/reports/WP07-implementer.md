# WP07 implementer report
Branch: transition/wp07-dictionary

## Files written        (path, and rows or bytes)

- `pipeline/bootstrap/build_indicators.R` -- 269 lines. Derives the mechanical columns from `.docs/transition/contract/label_triage.csv` (rows with `action == "MAP"`) and `.docs/transition/contract/codes.csv`, joins the hand-written text by `code`, and writes `metadata/codelists/CL_INDICATOR.csv`. Takes `--root` and `--out-root`.
- `pipeline/bootstrap/text/indicators_text.csv` -- 63 lines (header + 62 rows), 15 columns (`code, name_en, short_name_en, definition_en, universe_filter, numerator, higher_is, sdg_indicator, classification, related, related_note, source_questionnaire, source_vars, program, notes`).
- `metadata/codelists/CL_INDICATOR.csv` -- 63 lines (header + 62 rows), 37 columns matching `csv_headers.csv` for `CL_INDICATOR.csv`, sorted by `code`.

## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)

- WP07.A1: PASS. `code` set = the 62 distinct `INDICATOR` values of the triage's MAP rows (verified: `sort(unique(map_rows$INDICATOR))` has length 62, matches `INDICATOR.CODES` in `expected_counts.csv`).
- WP07.A2: PASS. Script asserts each mechanical column (`stat_unit, statistic, weight, ref_period, unit_measure, unit_denom, unit_time, price_basis, display_as, decimals, valid_min, valid_max`) is identical across a code's MAP rows and stops otherwise; it ran to completion, so all are consistent and copied verbatim.
- WP07.A3: PASS by construction, spot-checked. `qualifiers` built from `MEASURE_QUALS` (triage) + `var_code`/`order` (`CL_QUALIFIER`) + `slot_order` (`CL_QUAL_VAR`) in `codes.csv`. Verified output: `POV_HC`/`POV_NUM` = `POVLINE:POVLINE_PL300,POVLINE_PL420 PPP:PPP_2021` (matches the card's own example); `CONS_SH` = `COICOP:COICOP_CP01,...,COICOP_CP13 ACQ:ACQ_PURCH,ACQ_OWNPROD`; all other 59 codes = `_Z`.
- WP07.A4: PASS, spot-checked. All `checks` values built from the 5 rules; every token is in the given vocabulary. `EN_OUTAGE_DUR_CODE` = `RANGE_NONNEG` only (no `AGG_*` token, per the H8 exception). `CONS_SH` includes `SUM_TO_1_OVER:COICOP`; `POP_SH`/`POP_HH_SH`/`POP_HE_SH` include `SUM_TO_1_OVER_BRK`; `POV_HC`/`POV_NUM` include `MONOTONE_IN:POVLINE`.
- WP07.A5: PASS. Checked `theme`, `stat_unit`, `statistic`, `weight`, `unit_measure` against `CL_THEME`/`CL_STAT_UNIT`/`CL_STATISTIC`/`CL_WEIGHT`/`CL_UNIT` in `codes.csv` -- no invalid values. Every `related` code exists in the file's own `code` column.
- WP07.A6: PASS. Max `short_name_en` length is 22 (<=40). Every R-status column is non-empty (checked programmatically). `higher_is` in `{BETTER, WORSE, NEUTRAL}` only.
- WP07.A7: PASS. `names(CL_INDICATOR.csv) == csv_headers.csv`'s `CL_INDICATOR.csv` columns in position order (`identical()` TRUE). `status` is `DRAFT` on all 62 rows.
- WP07.A8: PASS. Rebuilt with `--out-root <tempdir>`; `diff` against the committed file reports no differences.

## Deviations           (what the card said, what you did, why)

- The card's "Read" section lists only `COMMON.md`, this card, the two named slices of `label_triage.csv`, and the `CL_INDICATOR.csv` rows of `csv_headers.csv` -- it does not list `contract/codes.csv`. But the card's own rules text requires `codes.csv` twice (`qualifiers`: "A code's variable comes from `var_code` in `contract/codes.csv`") and two acceptance checks (A3, A5) test against it directly; `pipeline/R/codes.R` (`slot_sort()`) also exists specifically to support this kind of derivation. Treating this as an unavoidable gap in the card rather than a blocker, I read `codes.csv` in small targeted slices (schema + the `CL_QUALIFIER`/`CL_QUAL_VAR`/`CL_THEME`/`CL_STAT_UNIT`/`CL_STATISTIC`/`CL_WEIGHT`/`CL_UNIT` rows needed), respecting the 30-row/8-column print limits, and used it in `build_indicators.R` and for my own verification. Flagging this per COMMON.md section 1.1 rather than guessing at the qualifiers/checks logic.
- I also read `MEASURE_QUALS` from `label_triage.csv` (not one of the two named column pairs) for the same reason: the qualifiers/checks rules are defined in terms of it, and there is no other way to know which series use a qualifier. I only read it for the small number of rows needed to confirm its format (COICOP/POVLINE/PPP indicators), not the full 91-row column.

## Questions            (contract doubts, and anything only the user can decide)

- Several triage `notes` carry values in columns whose `status` in `csv_headers.csv` looks coded rather than free text (e.g. `HE_COSTS`'s `unit_time` note says "TBD (token, DRAFT only)"). WP07 copies these mechanical values verbatim per the card's "out of scope: changing any code or mechanical value" rule, so `CL_INDICATOR.csv`'s `unit_time` for `HE_COSTS` may literally read `TBD` even though `unit_time` is a coded column (COMMON.md 4: "TBD is never allowed in a coded column"). This is a property of the triage input, not something I changed; flagging in case the user wants the triage itself corrected before it becomes ACTIVE.
- `HE_HH_OWNER`'s `related` only points to `POP_HH_SH` (one-directional), as the card states; I did not add a reciprocal `HE_HH_OWNER` entry to `POP_HH_SH`'s `related` since the card doesn't ask for it and `POP_HH_SH` has no hard case. Flagging in case the intent was a mutual pairing like H7/H9/H13.

## Changelog line       (implementers only: the card's line, adjusted if needed)

Indicator dictionary (CL_INDICATOR).
