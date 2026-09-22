# WP01 patch report
Branch: transition/wp01-data-raw-p1

## Files written
- `.docs/transition/reports/WP01-implementer-p1.md` (this report). No other file was written; the finding traces to the acceptance script, which patch agents may not edit.

## Checks
- WP01.A1: PASS -- tracked files under `data_raw/` (excl. README.md, CHECKSUMS.sha256) = 122, expected 122.
- WP01.A2: PASS -- all 122 legacy files have matching blob IDs `transition-base:<old path>` -> `HEAD:<new path>`.
- WP01.A3: PASS -- `data_raw/CHECKSUMS.sha256` has 122 lines, all hashes match blob and working tree.
- WP01.A4: FAIL -- `git grep -n "INPUT " -- . ':!.docs'` exit=0 (match found), first match `pipeline/acceptance/wp01_data-raw.R:90`. Tracked paths starting `INPUT ` = 0 (that half of the check is clean).
- WP01.A5: PASS -- numstat added=12 deleted=12 on `index.qmd`; all 12 added lines contain `data_raw`.
- WP01.A6: PASS -- `quarto render index.qmd` exits 0, no "Traceback", `_site/index.html` rewritten.
- WP01.A7: PASS -- `CLAUDE.md` mentions `data_raw/`, no longer mentions `INPUT Tables/`.

## Deviations
- Input: "WP01: run_all.R - WP01.A4 - 1 - the check's own `git grep \"INPUT \"` matches the acceptance script's own source (`pipeline/acceptance/wp01_data-raw.R:90`), a self-referential false positive; the actual data move (WP01.A1/A2/A3/A5/A6/A7) all PASS." -- What I did: investigated only, changed nothing. I re-ran `git grep -n "INPUT " -- . ':!.docs'` directly and confirmed every match (lines 90-95, 115, 164, 168, 241, 246) is inside `pipeline/acceptance/wp01_data-raw.R` itself; no other tracked file outside `.docs/` contains the string. That script's `map_new_path()` function and its own comments/`sprintf` text must contain the literal `"INPUT Tables/"`, `"INPUT shp/"` etc. to implement the card's step-2 move table and to describe the check -- this is the check's own necessary source, not a leftover legacy reference. I confirmed with `git diff 32348ad HEAD -- pipeline/acceptance/wp01_data-raw.R` that the script is byte-identical to the version committed at WP01 v1 verification, where WP01.A4 PASSED (see `WP01-verifier-v1.md`). The only thing that changed is that the script is now a **tracked, committed** file (merged into `transition/main` by the integrator); at v1 it was still an uncommitted verifier work product on disk when it ran the check on itself, so `git grep` (which searches tracked files only) did not see it. The same script text therefore passes before its own commit and fails after -- a self-referential false positive built into the check's exclusion pattern (`':!.docs'` excludes the docs tree but not `pipeline/acceptance/`, the acceptance scripts' own directory). Per the card's contract (`pipeline/acceptance/wpNN_*.R` is owned by `VER`, not `WP01`) and the override rule "Do not edit an acceptance script," I made no code change. All of WP01's owned outputs (`data_raw/**`, `index.qmd`, `CLAUDE.md`, `.docs/input-tables-findings.qmd`) are correct and unchanged; checks A1/A2/A3/A5/A6/A7 prove the data move is intact.

## Questions
- The acceptance script's exclusion pathspec for WP01.A4 should probably also exclude `pipeline/acceptance/` (its own directory), e.g. `git grep -n "INPUT " -- . ':!.docs' ':!pipeline/acceptance'`, so the check does not fail on its own committed source. This needs a verifier patch agent for `pipeline/acceptance/wp01_data-raw.R`, not a WP01 change -- flagging for the orchestrator to route.

## Changelog line
None (patch report; card's changelog line unchanged from the implementer report).
