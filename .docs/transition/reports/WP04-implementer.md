# WP04 implementer report
Branch: transition/wp04-small-codelists

## Files written        (path, and rows or bytes)
- pipeline/bootstrap/build_small_codelists.R (112 lines, 3750 bytes)
- pipeline/bootstrap/text/small_codelists_text.csv (56 lines incl. header, 55 data rows, 3804 bytes)
- metadata/codelists/CL_SEX.csv (2 rows, 328 bytes)
- metadata/codelists/CL_AGE.csv (4 rows, 387 bytes)
- metadata/codelists/CL_URBANISATION.csv (4 rows, 295 bytes)
- metadata/codelists/CL_OBS_STATUS.csv (4 rows, 487 bytes)
- metadata/codelists/CL_THEME.csv (12 rows, 775 bytes)
- metadata/codelists/CL_UNIT.csv (12 rows, 753 bytes)
- metadata/codelists/CL_STAT_UNIT.csv (4 rows, 387 bytes)
- metadata/codelists/CL_STATISTIC.csv (7 rows, 412 bytes)
- metadata/codelists/CL_WEIGHT.csv (4 rows, 360 bytes)
- metadata/codelists/CL_AREA.csv (2 rows, 194 bytes)

## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)
- WP04.A1: PASS. For each of the 10 files, sorted `code` values equal the sorted `code` values in `contract/codes.csv` filtered to that codelist (checked with an R script comparing sets; identical for all ten).
- WP04.A2: PASS. Each file's header (via `names()`) equals the ordered `column` list for that file in `contract/csv_headers.csv`, checked programmatically for all ten files.
- WP04.A3: PASS. Every code in every output file matches `^[A-Z][A-Z0-9_]{0,31}$` and none starts with `_T` or `_Z` (checked with a regex sweep over all 55 rows).
- WP04.A4: PASS. `name_en`, `definition_en`, `status`, `version_added` are non-empty on every row; `status` is `DRAFT` and `version_added` is `0.1.0` everywhere; no `definition_en` equals `TBD` (checked programmatically).
- WP04.A5: PASS. Every non-empty `parent` in `CL_URBANISATION.csv` is a code of that file (`U`, `R`, `CAP`, `OU`); `CAP` and `OU` both have `parent = U`.
- WP04.A6: PASS. `CL_AREA.csv` has SEN: iso2=SN, currency=XOF, wb_region=AFW; GNB: iso2=GW, currency=XOF, wb_region=AFW. `CL_STATISTIC.admits_se` is `Y` on every row except `INDEX`, which is `N`.
- WP04.A7: PASS (pre-commit check on working-tree bytes; committed blobs match since files were written once and not re-edited). Read each file as raw bytes: no UTF-8 BOM (`EF BB BF`) prefix and no `0x0D` (CR) byte anywhere, for all ten files.
- WP04.A8: PASS. Ran `Rscript pipeline/bootstrap/build_small_codelists.R --root . --out-root <tempdir>` and compared each of the ten output files byte-for-byte (`readBin` + `identical()`) against the committed candidates: all ten identical.

## Deviations           (what the card said, what you did, why)
- The card's seed text file spec (step 1) lists columns `codelist, code, name_en, definition_en, notes, admits_se, iso2, currency, wb_region` — no `parent` column, even though `CL_URBANISATION.csv` needs one. Step 2 resolves this: "`parent` taken from the seed" refers to `contract/codes.csv` (which already carries `parent` for `CAP`/`OU`), not to the text file. Implemented exactly that way: the text file has no `parent` column, and `build_small_codelists.R` copies `parent` from `contract/codes.csv` only for `CL_URBANISATION`.
- `CL_OBS_STATUS` code `O`: per the card, the `LEGACY_EMPTY:` note about a legacy conversion marker goes in that code's `notes` column, not `definition_en`. Done as specified.
- Generated the seed text CSV via a temporary, uncommitted helper R script (using `write_std_csv()` from `pipeline/R/io.R` for correct UTF-8/LF/quoting) rather than typing the CSV by hand, to guarantee correct quoting of fields containing commas (e.g. the `CL_OBS_STATUS`/`CL_WEIGHT` definitions). Only the resulting CSV is an owned output; the generator script was not committed and is not part of the pipeline.
- `name_en`/`definition_en` wording beyond the literal words in the card's meaning table (e.g. CL_THEME's "Indicators about poverty.", CL_UNIT's "A count of households.") was composed by the implementer, since the card gives meanings, not verbatim label/definition text, and instructs "Give every code a real `name_en` and `definition_en` from the table above."

## Questions            (contract doubts, and anything only the user can decide)
None.

## Changelog line       (implementers only: the card's line, adjusted if needed)
Small codelists and CL_AREA (10 files).
