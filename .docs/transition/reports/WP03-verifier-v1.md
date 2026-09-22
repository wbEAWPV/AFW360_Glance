# WP03 verifier report
Branch: transition/wp03-scaffold-v1
## Files written        (path, and rows or bytes)
- pipeline/acceptance/wp03_scaffold.R (10 check() calls, WP03.A1-WP03.A10)
- .docs/transition/reports/WP03-verifier-v1.md (this report)

## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)
- WP03.A1: PASS - `testthat::test_dir('pipeline/tests/testthat', stop_on_failure = TRUE)` exits 0; tail shows `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 49 ]`.
- WP03.A2: PASS - DSD_AFW360_HH.csv has 26 rows (matches contract row META.DSD, expected 26); its `id` column equals the data-file columns of csv_headers.csv in order; DSD_COLUMNS equals it; KEY_COLUMNS is the first 18.
- WP03.A3: PASS - `fmt_num(c(0.37, 6520000, -3460.12, 1e-7, 100, NA))` returns `"0.37" "6520000" "-3460.12" "0.0000001" "100" ""`.
- WP03.A4: PASS - a `write_std_csv` output has no BOM, no CR byte, and the NA cell reads back as `""`.
- WP03.A5: PASS - `read_std_csv` on a file with a BOM, CRLF and an empty cell returns all-character columns, a clean header (`a`,`b`), and `""` for the empty cell.
- WP03.A6: PASS - `is_valid_code` accepts `SN01`, `POV_HC`; rejects `_T`, `_ZX`, `pov_hc`, `1A`, and a 33-character code.
- WP03.A7: PASS - `slot_sort(...)` returns `QUINT_Q1` first; `fill_slots("A", 3, "_T")` returns `A _T _T`.
- WP03.A8: PASS - in a temporary copy, `run_all.R` exits 0 with no scripts (0) and non-zero with a dummy failing script (1).
- WP03.A9: PASS - `metadata/VERSION` is exactly `0.1.0`; `build_ctx(root)` (no data files) returns a list with exactly the six names `root, meta, data, manifests, precision, opts`.
- WP03.A10: PASS - `COLUMNS.csv` has the columns `file, position, column, status, description`; every row matches a row of `csv_headers.csv`; for each file kept, all its rows are present in the same position order; the data file (`AFW360_HH_<ISO3>_<YEAR>.csv`) is excluded; `COLUMNS.csv` is included among its own 28 kept files; 3 files are excluded in total.

## Deviations           (what the card said, what you did, why)
- WP03.A10's "28 files remain" figure is not present in `contract/expected_counts.csv` (no `META.*`/`WP03.*` row for it), so the acceptance script checks it structurally (row-for-row subset equality between COLUMNS.csv and csv_headers.csv, per-file order preserved, data file excluded, COLUMNS.csv self-included, exactly 3 files excluded) rather than only trusting one hard-coded count, and uses the literal 28 from the card text since no contract entry exists to source it from.
- WP03.A1 runs `testthat::test_dir` against the absolute path of `pipeline/tests/testthat` (via `file.path(root, ...)`) instead of `setwd()`-ing into `root` and using the literal relative path from the card. This is the same test directory and the same call; it avoids mutating the acceptance script's working directory. No functional difference observed (49/49 tests pass either way; verified the resolved path is the intended directory).

## Questions            (contract doubts, and anything only the user can decide)
None.

## Changelog line       (implementers only: the card's line, adjusted if needed)
None (verifier report).

## Failures to fix   (numbered; for each: the check ID, the exact command or comparison, expected
                      against actual. Write "None" on PASS.)
None.
