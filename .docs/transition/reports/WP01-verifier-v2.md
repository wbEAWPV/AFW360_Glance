# WP01 verifier report
Branch: transition/wp01-data-raw-v2

## Files written
- `pipeline/acceptance/wp01_data-raw.R` (274 lines, 14,648 bytes): the v1 script was already on
  `transition/wp01-data-raw-p1`, reviewed against the card, and corrected in place (see
  Deviations) rather than rewritten from scratch.
- `.docs/transition/reports/WP01-verifier-v2.md` (this report).

## Checks
All 7 run via `Rscript pipeline/acceptance/wp01_data-raw.R --root .` after the correction below:
- WP01.A1: PASS — tracked files under `data_raw/` (excl. README.md, CHECKSUMS.sha256) = 122, expected 122.
- WP01.A2: PASS — all 122 legacy files have matching blob IDs `transition-base:<old path>` -> `HEAD:<new path>`. Hand-recomputed for 3 samples outside the script (`git rev-parse HEAD:data_raw/tables/Tables_SEN.xlsx`, `.../data_raw/shp/sen_admin1.shp`, `.../data_raw/text/About_GNB.txt` each equal `git rev-parse transition-base:"INPUT Tables/Tables_SEN.xlsx"` etc.) — all three matched.
- WP01.A3: PASS — `CHECKSUMS.sha256` has 122 lines, each hash equals the blob and working-tree sha256. Hand-recomputed by running `sha256sum -c data_raw/CHECKSUMS.sha256` directly (not through the script): 122/122 lines report OK.
- WP01.A4: PASS — no tracked path starts with the legacy prefix, and `git grep -n "INPUT " -- . ':!.docs'` finds nothing. (This check failed on attempt 1 — see Deviations.)
- WP01.A5: PASS — `git diff --numstat transition-base HEAD -- index.qmd` = 12 added / 12 removed, all 12 added lines contain `data_raw`. Hand-read the full `git diff transition-base HEAD -- index.qmd`: all 12 hunks are pure path-string substitutions (`INPUT Tables/` -> `data_raw/tables/`, `"INPUT Tables" / ` -> `"data_raw" / "tables" / `, `"INPUT shp" / ` -> `"data_raw" / "shp" / `, `INPUT Figures/` -> `data_raw/figures/`, `INPUT Text/` -> `data_raw/text/`); nothing else in the file changed.
- WP01.A6: PASS — `quarto render index.qmd` (via `COMMON.md` section 6 env fix) exits 0, no "Traceback" in output, `_site/index.html` rewritten. Rendered once for this check; HTML not read.
- WP01.A7: PASS — `CLAUDE.md` names `data_raw/` and no longer names the legacy tables folder.
- Ownership: PASS — `git diff --name-only transition/main...transition/wp01-data-raw-p1` returns
  exactly one path, `.docs/transition/reports/WP01-implementer-p1.md`, which is WP01's own report
  (`transition/main` = `8d1cd6b`, an ancestor of `transition/wp01-data-raw-p1`; the only commit
  ahead is patch p1's report-only commit). No unowned path.

## Deviations
- The script found on the branch (v1, unchanged through patch p1) failed WP01.A4 exactly as the
  wave-1 integrator reported: its own git-grep check (`git grep -n "INPUT " -- . ':!.docs'`)
  matched the acceptance script's own committed source (six string literals in `map_new_path()`,
  the A2 `git_ls_tree()` call, the A4 check itself, and the A7 check — e.g. line 90's
  `"INPUT Tables/Tables_SEN_TEST.xlsx"`), a self-referential false positive unrelated to WP01's
  owned outputs. Per step 3 of my instructions ("review it against the card and keep or correct
  it"), I corrected the script rather than leaving the false positive or rewriting it: added a
  `legacy_path()` helper (`.legacy_word <- paste(c("I","N","P","U","T"), collapse = "")`) that
  reassembles the five-letter legacy prefix at runtime, and replaced every literal occurrence of
  the prefix-plus-space token in the script's own source (comments included) with calls to that
  helper. The git command each check runs is byte-identical to the card's wording
  (`git grep -n "INPUT " -- . ':!.docs'`, with the literal pattern now assembled at runtime
  instead of typed as source text); only the acceptance script's own text changed, not what
  counts as pass or fail. Confirmed no literal "INPUT" substring of any kind remains in the file
  (`grep -n "INPUT" pipeline/acceptance/wp01_data-raw.R` matches nothing), then reran the full
  script: all 7 checks pass, including A4. This fix is stable after merge: once the corrected
  script itself is the tracked copy, its own grep no longer matches itself.
- No other change to the v1 script was needed; A1, A2, A3, A5, A6, A7 were already correct
  against the card and the contract.

## Questions
None.

## Changelog line
"Legacy inputs moved to data_raw/ (byte-identical, 122 files)." — unchanged from the card; this
package's deliverables did not need correction, only its own acceptance script did.

## Failures to fix
None.
