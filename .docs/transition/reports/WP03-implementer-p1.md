# WP03 patch p1 — COLUMNS.csv status for `scale`

**Date.** 2026-09-22
**Branch.** `transition/wp03-scaffold-p1`, from `transition/main` (34634a1), with `dev/eb` merged in.
**Mode.** FINDINGS (contract correction authorised by the user during wave 3).
**Made by.** The orchestrator directly, at the user's explicit instruction, not by a patch agent.

## Summary

`metadata/structure/COLUMNS.csv` is generated from `.docs/transition/contract/csv_headers.csv` and
must match it row for row, including the `status` field (checked by WP03.A10). The user corrected
three `status` values in the contract from `R` to `C`, so this package's generated copy is brought
back into agreement: the `LEGACY_LABELS.csv,6,scale` row now carries `C`.

`N_OBS` and `N_POP` also changed in the contract, but they are rows of the data file
`AFW360_HH_<ISO3>_<YEAR>.csv`, which WP03's card excludes from `COLUMNS.csv`. They therefore do not
appear here and needed no change.

## Why the contract changed

Each of the three columns documents, in its own `description`, when it is legitimately empty:

- `scale` — "empty on rows that are not MAP";
- `N_OBS` / `N_POP` — "except legacy ROUNDED_2DP files, where it is empty".

Sibling columns with identical "required when X" grammar already used `C` (`series_id`,
`duplicate_of`, `assert_rule` in the same file; `STD_ERR`, `CI_LOWER`, `CI_UPPER` in the data file),
so `R` was the outlier on these three. The validator reads `status` from `COLUMNS.csv` and enforces
`R` as non-empty (`req_cols <- spec$column[spec$status == "R"]`), which made it report 21
`META.REQUIRED` errors against the 88 non-MAP rows of `LEGACY_LABELS.csv`, where `scale` is correctly
empty. WP11's patch agent and its verifier independently identified the marker, not the data or the
check, as the fault.

The contract change itself is commit c321d51 on `dev/eb`, because
`.docs/transition/contract/csv_headers.csv` is marked frozen in `output_ownership.csv`: "no agent
edits it. A change needs the user and a new plan commit on dev/eb." That commit is merged into this
branch so that the two files change together and are never out of step.

## Changes

| Path | Change |
|---|---|
| `metadata/structure/COLUMNS.csv` | Row 287, `LEGACY_LABELS.csv,6,scale`: `status` `R` → `C`. One cell; nothing else touched. |

Merged in from `dev/eb` (c321d51), not authored here:

| Path | Change |
|---|---|
| `.docs/transition/contract/csv_headers.csv` | Rows 37, 38, 315: `status` `R` → `C` for `N_OBS`, `N_POP`, `scale`. |

## Checks run

- Every row of `COLUMNS.csv` still exists verbatim in `csv_headers.csv` on the composite key
  `file+position+column+status+description` (WP03.A10's comparison): 305 of 305 rows match, 28 files.
- `COLUMNS.csv` status counts after the change: R 210, C 55, O 40.
- `csv_headers.csv` status counts after the change: R 235, C 62, O 41.

## Deviations

- This patch was made by the orchestrator rather than a patch agent, at the user's explicit
  instruction. Verification is unaffected: a fresh WP03 verifier re-runs the acceptance script,
  and WP11's re-verification is what proves the 21 `META.REQUIRED` errors are gone.
- No generator script exists for `COLUMNS.csv` (WP03's card specifies a few lines of R, kept outside
  the owned outputs), so the file was edited in place, exactly as the contract row now reads.

## Questions

None.

## Changelog line

- `metadata/structure/COLUMNS.csv`: `scale` marked `C` (required when relevant), matching the
  contract correction in c321d51.
