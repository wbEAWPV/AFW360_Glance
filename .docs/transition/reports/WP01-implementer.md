# WP01 implementer report
Branch: transition/wp01-data-raw

## Files written        (path, and rows or bytes)
- `data_raw/**` (122 files): moved from `INPUT Tables/`, `INPUT shp/`, `INPUT Text/`, `INPUT Figures/`, `dsf.qqqww` and `map_test.png` via `git mv`, byte-identical (see Checks, WP01.A2/A3).
- `data_raw/README.md`: 32 lines, 1343 bytes.
- `data_raw/CHECKSUMS.sha256`: 122 lines, 11857 bytes, sorted by path, LF only, no BOM.
- `index.qmd`: 12 lines added / 12 removed (the 12 path references listed in the card).
- `CLAUDE.md`: 6 lines added / 6 removed (Layout section paths, one sentence added to the working rule).
- `.docs/input-tables-findings.qmd`: 2 lines added (a one-line note after the frontmatter; its own body paths were left untouched, since they document the original `INPUT Tables/` locations for the record).

## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)
- WP01.A1: PASS — `git ls-files 'data_raw/**' | grep -vE '(README\.md|CHECKSUMS\.sha256)$' | wc -l` = 122.
- WP01.A2: PASS — script compared `git rev-parse transition-base:<old path>` to `git rev-parse :<new path>` for all 122 mappings (from the card's table plus the 110 shp files); 0 mismatches.
- WP01.A3: PASS — `CHECKSUMS.sha256` has 122 lines; each hash was computed from `git cat-file blob :<path>`, and `sha256sum -c data_raw/CHECKSUMS.sha256` reports 122/122 `OK` against the working tree.
- WP01.A4: PASS — `git ls-files | grep "^INPUT "` finds nothing; `git grep -n "INPUT " -- . ':!.docs'` finds nothing (exit 1).
- WP01.A5: PASS — `git diff --cached --numstat transition-base -- index.qmd` (transition-base and transition/main are identical for index.qmd, so this equals the eventual `transition-base HEAD` diff) shows `12 12 index.qmd`; every added line contains `data_raw` (checked directly).
- WP01.A6: PASS — `env -u QUARTO_R QUARTO_PYTHON="C:/WBG/Python313/python.exe" quarto render index.qmd` exited 0 twice (baseline and post-move), wrote `_site/index.html` both times, no "Traceback" in the output. `_site/` was deleted afterwards (not an owned output).
- WP01.A7: PASS — `CLAUDE.md` names `data_raw/` (Layout section and working rule) and no longer contains `INPUT Tables/` (or any `INPUT ` string).

Step-9 render comparison (not part of the acceptance script, reported per the card): a Python script loaded the baseline `_site/index.html` (rendered before any change) and the post-move `_site/index.html`, stripped HTML tags from both, replaced the old path strings with the new ones in the baseline (plain forms on the raw HTML for attribute values such as `<img src="INPUT Figures/...">`, and the quote-wrapped forms on the tag-stripped text for the Python source chunks split across syntax-highlighting spans; no `INPUT%20...` encoded form was present in either file, so that branch was a no-op), and compared. Result: tag-stripped text equal = **True**; `<img>` count baseline = new = **8**; no differing fragments. The dashboard's rendered content is unchanged except for the 12 path strings.

## Deviations           (what the card said, what you did, why)
- The card's step 3 says that after `git checkout -- data_raw`, `git status --porcelain data_raw` (path-scoped) "shows only renames (R), and nothing modified." On this machine (git 2.55.0.windows.2), scoping `git status --porcelain` to `data_raw` alone shows those entries as `A` (added), not `R`, because git cannot pair a rename when the deleted (old-path) side is excluded by the pathspec — this is a display-only quirk of restricted rename detection, not a content issue. The unscoped `git status --porcelain` (no pathspec) correctly shows all 122 entries as `R` with zero `M` entries, which is what WP01.A2/A3 actually verify.
- `git checkout -- data_raw` initially left 6 of the 122 files (`data_raw/text/About.txt`, `About_SEN.txt`, `Messages_GNB.txt`, `Messages_SEN.txt`, `data_raw/scratch/Messages_SEN.txt2`, `data_raw/scratch/dsf.qqqww`) with CRLF-converted bytes from their pre-move checkout, even though `.gitattributes` correctly marks `data_raw/** -text` (confirmed with `git check-attr`). This looks like a stat-cache skip-if-unchanged optimization in `git checkout -- <path>` after a plain-rename `git mv` (the file's mtime/size looked "already matching" to git, so it wasn't rewritten). Fixed by deleting those 6 files and re-running `git checkout --` on them individually, which rewrote them correctly; verified afterwards that `sha256sum -c data_raw/CHECKSUMS.sha256` reports 122/122 `OK`.
- The card's step 7 draft implied CLAUDE.md would say the inputs were moved from their original `INPUT *` locations; that literal wording contains the reserved substring `INPUT ` and would have failed WP01.A4 (`git grep -n "INPUT " -- . ':!.docs'`). Reworded to "moved from their original per-type folders" — same meaning, no `INPUT ` substring.
- The first draft of `data_raw/README.md` (a file this card owns, outside `.docs`) named the old folders literally (`` `INPUT Tables/` ``, `` `INPUT shp/` `` etc.), which also matched WP01.A4's grep and would have failed it. Caught this myself before finishing by re-running the exact A4 command against the committed tree; reworded the sentence to "their original per-type folders at the repository root" and amended the single implementer commit (rather than adding a second commit) so the branch still carries exactly one `WP01: implement -` commit, per COMMON.md section 8.
- Card step 7 also lists "path mentions in the known issues" to update; the Known issues section has none (it only names bare filenames like `Tables_SEN.xlsx`, `Messages_<ISO3>.txt`, with no `INPUT` directory prefix), so nothing there needed changing.

## Questions            (contract doubts, and anything only the user can decide)
None.

## Changelog line       (implementers only: the card's line, adjusted if needed)
Legacy inputs moved to data_raw/ (byte-identical, 122 files).
