# WP06 implementer report
Branch: transition/wp06-breakdowns-qualifiers
## Files written        (path, and rows or bytes)
- `pipeline/bootstrap/build_breakdowns_qualifiers.R` (6,676 bytes)
- `pipeline/bootstrap/text/breakdowns_qualifiers_text.csv` (121 data rows + header, 20,338 bytes)
- `metadata/codelists/CL_BRK_VAR.csv` (13 data rows, 3,703 bytes)
- `metadata/codelists/CL_COMP_BREAKDOWN.csv` (60 data rows, 9,909 bytes)
- `metadata/codelists/CL_QUAL_VAR.csv` (6 data rows, 1,634 bytes)
- `metadata/codelists/CL_QUALIFIER.csv` (42 data rows, 6,246 bytes)

## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)
- WP06.A1: PASS. For each of the 4 files, `setequal(code, seed$code)` is TRUE, and the structural columns (`var_code`, `parent`, `order`, `slot_order`, `describes`, `applies_to_units`, `partition`, `requires`/`requires_qual`, `valid_with`, `value`) match the seed row for row, with `value` and `slot_order` compared as numbers.
- WP06.A2: PASS. Every `CL_COMP_BREAKDOWN.var_code` exists in `CL_BRK_VAR.code` and every category code starts with `<var_code>_`; same for `CL_QUALIFIER` against `CL_QUAL_VAR`.
- WP06.A3: PASS. `slot_order` has no duplicates within `CL_BRK_VAR` (10-85) or `CL_QUAL_VAR` (10-50).
- WP06.A4: PASS. `CL_BRK_VAR.requires_qual` tokens (`POVLINE`, `PPP`) resolve to `CL_QUAL_VAR` codes; `CL_QUAL_VAR.requires` token (`PPP`) resolves to `CL_QUAL_VAR`; `CL_QUALIFIER.valid_with` tokens other than `_Z` (`PPP_2017`, `PPP_2021`) resolve to `CL_QUALIFIER`; `CL_COMP_BREAKDOWN.parent` is empty on every row (matches the seed, so vacuously satisfied).
- WP06.A5: PASS. `applies_to_units` tokens found are only `IND`, `HH`, `HE`.
- WP06.A6: PASS. Max code length 23; every code matches `^[A-Z][A-Z0-9_]{0,31}$`.
- WP06.A7: PASS. Headers of all 4 files equal `csv_headers.csv` (position and column name); every **R** column is filled on every row; the literal string `TBD` appears only in `CL_BRK_VAR.universe` (rows `EMP_ISIC`, `EMP_FORMAL`).
- WP06.A8: PASS. `POVLINE_PL215/365/685` carry `value` 2.15/3.65/6.85 with `valid_with = PPP_2017`; `POVLINE_PL300/420/830` carry 3.00/4.20/8.30 with `valid_with = PPP_2021`; `POVLINE_PL300.valid_with` is `PPP_2021` only.
- WP06.A9: PASS. Rebuilt with `--out-root <tempdir>`; `cmp` shows all 4 output files byte-identical to the committed copies.

## Deviations           (what the card said, what you did, why)
- `pipeline/README.md`'s layout diagram (not part of this card's "Read" list, seen only incidentally) shows a top-level `bootstrap/` directory rather than `pipeline/bootstrap/`. The card explicitly owns `pipeline/bootstrap/build_breakdowns_qualifiers.R` and `pipeline/bootstrap/text/breakdowns_qualifiers_text.csv`, and a grep of the other WPxx cards shows several also reference `pipeline/bootstrap/...`, so I followed the card and put everything under `pipeline/bootstrap/`. Flagging in case that README diagram needs a later fix.
- The text seed's repetitive rows (ISIC A-U section titles, COICOP 01-13 division titles, deciles D01-D10, quintiles Q1-Q5) were generated with a short R script run once from the scratchpad (not committed, per "do not type them"); the resulting static CSV is the committed artifact, as the card calls it "a text file that you write".
- Caught and fixed my own bug before finishing: an early draft of the text-seed generator dropped one positional argument for 4 of the 6 `CL_QUAL_VAR` rows (`WELFARE`, `PPP`, `COICOP`, `FI`), leaving `owner` empty. Switched those calls to named arguments, regenerated, and reran the build; verified via A7 that all required columns are now filled.

## Questions            (contract doubts, and anything only the user can decide)
- None blocking. `EMP_ISIC`'s true universe (H5) and `EMP_FORMAL`'s universe (H6) remain genuinely unresolved in the inputs, as the card anticipates; recorded as `universe = TBD` with the open point stated in `definition_en` and `notes`, per the card's own guidance ("Where the inputs do not settle it, say so in the definition; do not invent a rule"). Same treatment for `HHH_AGE`'s cutoff (H17) and `QUINT`'s ranking/weighting decision, per the verifier focus.

## Changelog line       (implementers only: the card's line, adjusted if needed)
Breakdown (13) and qualifier (6) variables with categories.
