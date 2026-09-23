# WP02 implementer report (stage A)
Branch: transition/wp02-standard-v04

## Files written        (path, and rows or bytes)
- `.docs/data-standard.qmd` — edited in place (68 insertions, 30 deletions over the diff; file now 933 lines, was 910).
- `.docs/transition/reports/WP02-implementer-A.md` — this report.

## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)
- WP02.A1: PASS. `env -u QUARTO_R QUARTO_PYTHON="C:/WBG/Python313/python.exe" quarto render .docs/data-standard.qmd` succeeded twice (last run: "Output created: _site\index.html", no warnings). `.docs/_site/` and `.docs/.quarto/` deleted afterwards.
- WP02.A2: PASS. Subtitle is `"Draft v0.4 · Proposal: files are being created by the transition"`; `# Changes since v0.3 {#sec-changes-v04}` exists as the last section.
- WP02.A3: PASS. All 3 lines containing "Python" (intro, Tooling row, changes-table D1 row) also say "dashboard".
- WP02.A4: N/A for stage A (SERIES_PLAN/legacy-maps subsections and validator-findings columns are stage B's item 2–3).
- WP02.A5: PARTIAL (stage A scope only). Present: `SERIES_PLAN`, `LEGACY_COLUMNS`, `LEGACY_OVERRIDES`, `POP_HH_SH`, `POP_HE_SH`, `LEGACY_EMPTY`, `data_raw/`, `pipeline/`, `WITHHOLD`. Not yet present: `TBD`, `AGG_BRACKET`, `admits_se` — these come from gap resolutions (d), (h), (o), which are stage B's job.
- WP02.A6: PASS. The `POVLINE_PL300` row of @tbl-povlines no longer contains `PPP_2017`; @tbl-example-rows no longer has a `Departement` row.
- WP02.A7 (D-IDs only): PASS. `@tbl-changes-v04` names D1, D2, D3, D4, D5, D6, D9 and D11. Gap IDs (a)–(z), (aa) are stage B's rows, not yet present.
- WP02.A8: PASS. Extracted all `{#sec-…}`/`{#tbl-…}`/`{#lst-…}` IDs from `transition-base:.docs/data-standard.qmd` (85) and from the current file (87); `comm -23` shows zero IDs dropped. The 2 new IDs are `sec-changes-v04` and `tbl-changes-v04`.

## Deviations           (what the card said, what you did, why)
- Card item 10 said "Remove the old column list" (Annex 3), but the "keep every existing ID" rule and WP02.A8 require `{#sec-legacy-columns}` and `{#tbl-legacy-columns}` to survive. Resolved by keeping both headings and a one-row stub table ("(see `LEGACY_COLUMNS.csv`)") instead of deleting the section — the mapping list itself is gone, the anchors remain valid. Flagging this as a genuine tension between the two instructions rather than a clear resolution I was given.
- The initial render produced 4 "Unable to resolve crossref" warnings because my new changes-table cells used `@sec-…` crossref syntax against `.unnumbered` Annex sections, which Quarto/pandoc-crossref cannot number. Fixed by switching those four cells to the document's existing convention for such sections, `[Annex N](#id)` plain links (already used elsewhere in the file). Re-rendered clean with no warnings.
- Added brief illustrative sub-items under the new `data_raw/` and `pipeline/` listing (subfolder names, entry-point order) beyond the card's one-line instruction, using only D2's "110 files"/five-subfolder text, CLAUDE.md's already-known current layout, and the card's own exact entry-point list/order — no invented facts.

## Questions            (contract doubts, and anything only the user can decide)
- None beyond the Annex-3 tension noted above, which I resolved rather than blocking on.

## Changelog line       (implementers only: the card's line, adjusted if needed)
"Data standard v0.4: R tooling, SERIES_PLAN, legacy maps, three share codes, tolerances." — unchanged from the card; stage B still owes SERIES_PLAN/legacy-maps subsections and tolerances text.
