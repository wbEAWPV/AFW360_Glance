# WP01 verifier report
Branch: transition/wp01-data-raw-v1

## Files written
- `pipeline/acceptance/wp01_data-raw.R` (243 lines) -- the acceptance script, one `check()` per card check ID.
- `.docs/transition/reports/WP01-verifier-v1.md` (this report).

## Checks
- WP01.A1: PASS -- tracked files under `data_raw/` (excl. README.md, CHECKSUMS.sha256) = 122, expected 122 (contract `LEGACY.FILES`).
- WP01.A2: PASS -- all 122 legacy files at `transition-base:<old path>` have a blob ID identical to `HEAD:<new path>` (mapping built from the card's step-2 move table).
- WP01.A3: PASS -- `data_raw/CHECKSUMS.sha256` has 122 lines; every listed hash equals both the sha256 of the git blob and the sha256 of the working-tree file.
- WP01.A4: PASS -- no tracked path starts with `INPUT `; `git grep -n "INPUT " -- . ':!.docs'` exits 1 (no match).
- WP01.A5: PASS -- `git diff --numstat transition-base HEAD -- index.qmd` = 12 added / 12 removed; all 12 added lines contain `data_raw`.
- WP01.A6: PASS -- `quarto render index.qmd` (env `-u QUARTO_R`, `QUARTO_PYTHON=C:/WBG/Python313/python.exe`) exits 0, no "Traceback" in combined stdout/stderr, and rewrites `_site/index.html`. `_site/` is removed by the script again immediately after the check reads it.
- WP01.A7: PASS -- `CLAUDE.md` contains `data_raw/` and no longer contains `INPUT Tables/`.

## Deviations
- Expected numeric values for WP01.A1 and WP01.A3 (122) are not stored under check IDs "WP01.A1"/"WP01.A3" in `contract/expected_counts.csv`; they are stored under check_id `LEGACY.FILES`, whose `source` column is exactly the card's own count formula (`git ls-files 'INPUT Tables' 'INPUT shp' 'INPUT Text' 'INPUT Figures' dsf.qqqww map_test.png | wc -l`). The script looks this value up by that check_id rather than hard-coding 122. The "12" in WP01.A5 is not a contract-derived quantity (no matching row exists) -- it is part of the check's own wording on the card, so it is used literally there, the same way the check ID itself is literal.
- WP01.A6 requires an actual dashboard render, which (per COMMON.md section 6) writes `_site/index.html` inside the repo, not a temporary directory. The script performs the render, reads only exit status / log text / file existence and mtime (never the HTML content), then deletes `_site/` on exit -- so nothing persists in the repo past the script's run, consistent with COMMON.md's "delete render outputs you do not own."
- Building the script required quoting every git pathspec/arg containing a space with `shQuote(x, type = "cmd")`; plain `system2()` args with embedded spaces (e.g. `"INPUT Tables"`) are not auto-quoted on this Windows R and silently mis-parse into separate argv tokens. Not a card deviation, just an implementation note for future edits to this script.

## Questions
None.

## Changelog line
None (verifier report; not an implementer deliverable).

## Failures to fix
None.
