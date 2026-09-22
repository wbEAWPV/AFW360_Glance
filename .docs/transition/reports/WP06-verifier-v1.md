# WP06 verifier report
Branch: transition/wp06-breakdowns-qualifiers-v1

## Files written        (path, and rows or bytes)
- `pipeline/acceptance/wp06_breakdowns-qualifiers.R` (268 lines): standalone acceptance script, one `check()` call per WP06.A1-A9.
- `.docs/transition/reports/WP06-verifier-v1.md` (this report).

## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)
- WP06.A1 PASS: for each of the four files, code set and structural columns (var_code, parent, order, slot_order, describes, applies_to_units, partition, requires/requires_qual, valid_with, value) equal the seed's; value/slot_order compared as numbers. CL_BRK_VAR 13 codes, CL_COMP_BREAKDOWN 60, CL_QUAL_VAR 6, CL_QUALIFIER 42 - all match seed and expected_counts.csv (META.CL_BRK_VAR etc.).
- WP06.A2 PASS: every CL_COMP_BREAKDOWN and CL_QUALIFIER row's `var_code` exists in its variable file, and its code starts with `<var_code>_` (60 and 42 rows checked).
- WP06.A3 PASS: `slot_order` has no duplicates within CL_BRK_VAR or within CL_QUAL_VAR.
- WP06.A4 PASS: every `requires_qual` (CL_BRK_VAR -> CL_QUAL_VAR), `requires` (CL_QUAL_VAR -> CL_QUAL_VAR), `valid_with` other than `_Z` (CL_QUALIFIER -> CL_QUALIFIER) and `parent` (CL_COMP_BREAKDOWN -> CL_COMP_BREAKDOWN) value resolves to a code in the right file.
- WP06.A5 PASS: `applies_to_units` tokens are all in {IND, HH, HE, PLOT} (only HE, HH, IND used).
- WP06.A6 PASS: all 121 codes across the four files are <=32 characters and match `^[A-Z][A-Z0-9_]{0,31}$`.
- WP06.A7 PASS: each file's header equals `csv_headers.csv`; every **R** column is filled; `TBD` (word-boundary match) appears only in the `universe` column.
- WP06.A8 PASS: POVLINE_PL215/365/685 = 2.15/3.65/6.85 with `valid_with = PPP_2017`; POVLINE_PL300/420/830 = 3.00/4.20/8.30 with `valid_with = PPP_2021`; POVLINE_PL300's `valid_with` is exactly `PPP_2021` (no other token).
- WP06.A9 PASS: `Rscript pipeline/bootstrap/build_breakdowns_qualifiers.R --root . --out-root <tempdir>` reproduces all four `metadata/codelists/*.csv` files byte for byte (md5sum match).

## Deviations           (what the card said, what you did, why)
None. The script was written from the card and `contract/codes.csv` / `contract/csv_headers.csv` / `contract/expected_counts.csv` only, before opening any implementer file.

## Questions            (contract doubts, and anything only the user can decide)
None.

## Changelog line       (implementers only: the card's line, adjusted if needed)
N/A (verifier report).

## Failures to fix
None.
