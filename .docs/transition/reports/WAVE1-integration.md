# Wave 1 integration report

## Merged

| Package | Branch | Merge commit |
|---|---|---|
| WP01 | transition/wp01-data-raw-v1 | 54c01cc |
| WP02 | transition/wp02-standard-v04-v1 | 1544b60 |
| WP03 | transition/wp03-scaffold-v1 | b206747 |

WP00 was already committed directly on `transition/main` (commit `2b87d07`, no branch to merge) and is marked MERGED alongside the wave-1 run per the card's instruction.

## Conflicts

None. All three merges (`git merge --no-ff`) completed with no conflicts.

## Checks

| Check | Result |
|---|---|
| `Rscript pipeline/acceptance/run_all.R --root .` | FAIL — `wp01_data-raw.R` SUMMARY: FAIL (exit 1) on check WP01.A4; `wp02_standard-v04.R` PASS; `wp03_scaffold.R` PASS |
| `Rscript -e "testthat::test_dir('pipeline/tests/testthat', stop_on_failure = TRUE)"` | PASS — `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 49 ]` |
| `Rscript .docs/transition/contract/check_contract.R --root .` | PASS — all 27 contract checks passed, "All contract checks passed." |
| `sha256sum -c data_raw/CHECKSUMS.sha256 \| grep -vc ': OK$'` | PASS — printed `0` |
| `env -u QUARTO_R QUARTO_PYTHON="C:/WBG/Python313/python.exe" quarto render index.qmd` | PASS — "Output created: _site\index.html", all 30 cells executed, no error |

## Findings by owner

**WP01 — acceptance check WP01.A4 FAIL (owner: WP01, from the acceptance script's file name `wp01_data-raw.R`).**

The check asserts that a tracked path starting with `"INPUT "` does not exist (0 found — true) AND that `git grep -n "INPUT " -- . ':!.docs'` exits 1 (no match). It got exit 0 instead: the grep matches the acceptance script's own source code, `pipeline/acceptance/wp01_data-raw.R`, which legitimately contains the literal string `"INPUT Tables/…"`, `"INPUT shp/"`, `"INPUT Text/"`, `"INPUT Figures/"` etc. as string literals inside `map_new_path()` (lines 90–95, 115) and inside the check's own code and comments (lines 164, 167, 168, 174, 241, 246). All 13 grep hits are in this one file; none are in a moved data file or in `index.qmd`/`CLAUDE.md` (WP01.A1, A2, A3, A5, A6, A7 all PASS, confirming the actual move is correct). This is a self-referential false positive in the acceptance script's own design (it does not exclude its own path from the tree-wide grep), not a defect in WP01's implementation. First failing example: `WP01.A4 FAIL tracked paths starting 'INPUT ' = 0; git grep exit=0 (1 expected = no match; first match: pipeline/acceptance/wp01_data-raw.R:90:  if (identical(old, "INPUT Tables/Tables_SEN_TEST.xlsx")) return(paste0("data_raw/scratch/", base)))`. Count: 1 failing check id (WP01.A4), 13 matching grep lines, all in the same file.

## Status changes

- WP00: TODO -> MERGED, branch `transition/main`, verdict `STATUS: DONE`, attempts 1, date 2026-09-22.
- WP01: TODO -> MERGED, branch `transition/wp01-data-raw-v1`, verdict PASS, attempts 1, date 2026-09-22.
- WP02: TODO -> MERGED, branch `transition/wp02-standard-v04-v1`, verdict PASS, attempts 1, date 2026-09-22.
- WP03: TODO -> MERGED, branch `transition/wp03-scaffold-v1`, verdict PASS, attempts 1, date 2026-09-22.
- Gate G0: PENDING -> DONE, date 2026-09-22, record `reports/GATE-G0.md`.
- `.docs/transition/decisions.qmd`: hard cases H1–H14 and H17 set from `DEFAULT.` to `CONFIRMED.`, with user note `Recommended` (15 sections). H15, H16, H18, H19 unchanged (already `DECIDED`).

## Changelog lines added

Appended to `metadata/CHANGELOG.md` under "## 0.1.0 (unreleased)":

- Legacy inputs moved to data_raw/ (byte-identical, 122 files).
- Data standard v0.4: R tooling, SERIES_PLAN, legacy maps, three share codes, tolerances.
- Pipeline scaffold, DSD_AFW360_HH, VERSION 0.1.0.

`metadata/VERSION` was not changed (stays `0.1.0`).
