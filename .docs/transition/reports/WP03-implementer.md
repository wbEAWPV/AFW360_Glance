# WP03 implementer report
Branch: transition/wp03-scaffold

## Files written        (path, and rows or bytes)
- `pipeline/R/io.R` (171 lines): `read_std_csv`, `write_std_csv`, `fmt_num`, `sha256_file`, `load_metadata`, `repo_path`, `cli_arg`, `cli_args`, `cli_flag`.
- `pipeline/R/constants.R` (52 lines): `DATAFLOW_ID`, `SENTINEL_TOTAL`, `SENTINEL_NA`, `TBD`, `DSD_COLUMNS` (26), `KEY_COLUMNS` (18).
- `pipeline/R/codes.R` (59 lines): `is_valid_code`, `slot_sort`, `fill_slots`.
- `pipeline/R/ctx.R` (68 lines): `build_ctx`.
- `pipeline/acceptance/run_all.R` (50 lines).
- `pipeline/tests/testthat.R` (8 lines).
- `pipeline/tests/testthat/helper-temp-root.R` (60 lines): `find_root`, `make_temp_root`, `edit_csv`.
- `pipeline/tests/testthat/test-io.R` (98 lines, 11 tests), `test-codes.R` (34 lines, 6 tests), `test-ctx.R` (77 lines, 5 tests) — 49 tests total.
- `metadata/VERSION` (6 bytes, `0.1.0\n`).
- `metadata/CHANGELOG.md` (3 lines).
- `metadata/structure/DSD_AFW360_HH.csv` (27 lines / 2153 bytes, 26 data rows).
- `metadata/structure/COLUMNS.csv` (306 lines / 23032 bytes, 305 data rows, 28 files).
- `pipeline/README.md` (101 lines).

## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)
- WP03.A1: PASS. `Rscript -e "testthat::test_dir('pipeline/tests/testthat', stop_on_failure = TRUE)"` -> `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 49 ]`, exit 0.
- WP03.A2: PASS. Verified programmatically: DSD has 26 rows; `dsd$id` equals the data-file `column` order of `csv_headers.csv`; `identical(DSD_COLUMNS, dsd$id)` TRUE; `identical(KEY_COLUMNS, dsd$id[1:18])` TRUE.
- WP03.A3: PASS. `fmt_num(c(0.37, 6520000, -3460.12, 1e-7, 100, NA))` returns exactly `"0.37" "6520000" "-3460.12" "0.0000001" "100" ""`.
- WP03.A4: PASS. Checked a `write_std_csv` output's raw bytes: no BOM, no `0x0D` byte; `NA` values round-trip as `""`.
- WP03.A5: PASS. Built a file with a UTF-8 BOM, CRLF and an empty cell; `read_std_csv` returns clean header names, all-character columns, and `""` for the empty cell.
- WP03.A6: PASS. `is_valid_code(c("SN01","POV_HC"))` all TRUE; `is_valid_code(c("_T","_ZX","pov_hc","1A", <33-char code>))` all FALSE.
- WP03.A7: PASS. `slot_sort(...)` returns `QUINT_Q1` first; `fill_slots("A", 3, "_T")` returns `"A" "_T" "_T"`.
- WP03.A8: PASS. In a scratch copy of `run_all.R`: 0 scripts -> exit 0; one failing dummy `wp*.R` -> exit 1 (CHECK line printed, SUMMARY FAIL); one passing dummy -> exit 0.
- WP03.A9: PASS. `metadata/VERSION` is exactly `0.1.0` (plus trailing newline). `build_ctx(tmp)` with no data files returns a list with exactly the six names `root, meta, data, manifests, precision, opts`.
- WP03.A10: PASS. Verified programmatically: `COLUMNS.csv` (305 rows) equals `csv_headers.csv` filtered to drop the data-file, manifest and validator-findings rows, same column order and row order; 28 distinct files remain, `COLUMNS.csv` among them.

## Deviations           (what the card said, what you did, why)
- The card's "Read" section restricts `contract/csv_headers.csv` to the 26 data-file rows ("print `position`, `column` and `status` only"), but Step 3 requires generating `COLUMNS.csv` from the *entire* `csv_headers.csv` (`file, position, column, status, description`, 28 files, 305 rows) and Step 2 needs each data-file row's `description` too. I resolved this the way COMMON.md section 1.2 resolves the general data-file rule: I never printed the full file or its `description`/other-files' content into this transcript, but I wrote short R scripts (kept outside the owned outputs, in my scratchpad) that read `csv_headers.csv` programmatically and wrote the required columns straight to the two output files, verifying the result afterwards only by row counts, `identical()` checks and 3-column previews. If this reading is wrong, the Read restriction and Step 3 are in direct conflict and need reconciling by the orchestrator.
- Everything else matches the card's interfaces, steps and mappings exactly; no other deviation.

## Questions            (contract doubts, and anything only the user can decide)
- Confirm the resolution above (full-file access via script, not via printed transcript) is the intended reading of the Read-section vs. Step-3 tension for `COLUMNS.csv`/`DSD_AFW360_HH.csv` generation, so future cards can state it unambiguously.

## Changelog line       (implementers only: the card's line, adjusted if needed)
Pipeline scaffold, DSD_AFW360_HH, VERSION 0.1.0.
