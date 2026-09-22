# WP04 verifier report
Branch: transition/wp04-small-codelists-v1
## Files written        (path, and rows or bytes)
- `pipeline/acceptance/wp04_small-codelists.R` (221 lines, 10173 bytes)
- `.docs/transition/reports/WP04-verifier-v1.md` (this report)
## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)
- WP04.A1: PASS -- all ten codelists' code sets match `contract/codes.csv` (55 rows total, no duplicates, no extras, none missing).
- WP04.A2: PASS -- all ten files' headers match `contract/csv_headers.csv` for that file, in order (7 common columns; `parent` added for `CL_URBANISATION`; `admits_se` added for `CL_STATISTIC`; `iso2`/`currency`/`wb_region` added for `CL_AREA`).
- WP04.A3: PASS -- every code in the ten files matches `^[A-Z][A-Z0-9_]{0,31}$` and none starts with `_T` or `_Z`.
- WP04.A4: PASS -- `name_en`, `definition_en`, `status`, `version_added` filled on every row; `status` = `DRAFT` and `version_added` = `0.1.0` on all 55 rows; no `definition_en` is `TBD`.
- WP04.A5: PASS -- every non-blank `parent` in `CL_URBANISATION` is a code of that file; `CAP` and `OU` both have `parent = U`.
- WP04.A6: PASS -- `CL_AREA` has `SEN` (`iso2=SN, currency=XOF, wb_region=AFW`) and `GNB` (`iso2=GW, currency=XOF, wb_region=AFW`); `CL_STATISTIC.admits_se` is `Y` or `N` on all 7 rows.
- WP04.A7: PASS -- committed blobs at `HEAD` for the ten codelists plus `pipeline/bootstrap/text/small_codelists_text.csv` have no BOM and no CR byte.
- WP04.A8: PASS -- `Rscript pipeline/bootstrap/build_small_codelists.R --root . --out-root <tempdir>` exits 0 and writes ten files byte-identical to the committed blobs at `HEAD`.

`Rscript pipeline/acceptance/wp04_small-codelists.R --root .` exits 0; all 8 checks PASS.
## Deviations           (what the card said, what you did, why)
- WP04.A1 was implemented as a stricter multiset comparison (equal length, no duplicate codes, in addition to set equality), not a literal mathematical-set comparison that would ignore duplicate rows. This is a strengthening, not a narrowing, of the literal check, and it found nothing wrong (each file has exactly the expected row count).
- WP04.A7's scope ("the committed blobs") is not itself restricted to "the ten codelists" the way A1-A6 are worded, so the script checks the ten codelist files plus the seed text file `pipeline/bootstrap/text/small_codelists_text.csv` (both are CSV outputs under COMMON.md's CSV rules). It does not check `build_small_codelists.R` (not a CSV) or the acceptance script itself (not a WP04 owned output).
- WP04.A6 is implemented literally: it checks `admits_se %in% c("Y","N")` on every `CL_STATISTIC` row, not that `INDEX` specifically is `N` and the rest `Y` (that per-code correctness is not stated in the check text). By hand, the actual file already has this right (`INDEX = N`, all others `Y`), noted under Questions for transparency, not as a failure.
## Questions            (contract doubts, and anything only the user can decide)
- No contract doubts. WP04.A6 as worded only requires `admits_se` to be a valid `Y`/`N` value per row, not that it matches the specific per-code meanings in the card's table (e.g. `INDEX` = `N`). The delivered file happens to satisfy the stricter reading too, so this did not affect the verdict, but a future card revision may want to state the per-code expectation explicitly if that precision matters for acceptance rather than only for by-hand review.
## Changelog line       (implementers only: the card's line, adjusted if needed)
None
## Failures to fix   (numbered; for each: the check ID, the exact command or comparison, expected against actual. Write "None" on PASS.)
None
