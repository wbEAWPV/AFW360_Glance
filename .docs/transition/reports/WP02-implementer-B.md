# WP02 implementer report (stage B)
Branch: transition/wp02-standard-v04

## Files written        (path, and rows or bytes)
- `.docs/data-standard.qmd` — edited in place (145 insertions, 12 deletions over the diff; file now 1081 lines, was 948 before this stage).
- `.docs/transition/reports/WP02-implementer-B.md` — this report.

## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)
- WP02.A1: PASS. `env -u QUARTO_R QUARTO_PYTHON="C:/WBG/Python313/python.exe" quarto render .docs/data-standard.qmd` succeeded ("Output created: _site\index.html"), no warnings (grepped render output for `warn|error|unable`, zero matches). `.docs/_site/` and `.docs/.quarto/` deleted afterwards.
- WP02.A2: PASS. Subtitle unchanged from stage A (`"Draft v0.4 · Proposal: files are being created by the transition"`); `{#sec-changes-v04}` exists.
- WP02.A3: PASS. All 3 lines containing "Python" also contain "dashboard" (checked with grep; caught and fixed one new line that mentioned Python without dashboard, by rewording it to "dashboard chunk wrappers").
- WP02.A4: PASS. Between `{#sec-series-plan}` and the next `##` heading, all 7 `SERIES_PLAN.csv` columns from `csv_headers.csv` (`series_id, ref_area, INDICATOR, MEASURE_QUALS, DEFINING_BREAKDOWN, status, notes`) appear backticked. Between `{#sec-legacy-maps}` and `# What a producer delivers`, all columns of `LEGACY_LABELS.csv` (8), `LEGACY_COLUMNS.csv` (9) and `LEGACY_OVERRIDES.csv` (8) appear backticked. The 5 validator-findings columns (`check_id, severity, file, row_key, message`) appear backticked in the validation-section intro paragraph.
- WP02.A5: PASS. All of `SERIES_PLAN`, `LEGACY_COLUMNS`, `LEGACY_OVERRIDES`, `POP_HH_SH`, `POP_HE_SH`, `LEGACY_EMPTY`, `TBD`, `AGG_BRACKET`, `admits_se`, `data_raw/`, `pipeline/`, `WITHHOLD` appear (grep -c > 0 for each).
- WP02.A6: PASS (unchanged from stage A, re-verified). `POVLINE_PL300`'s row in @tbl-povlines carries only `PPP_2021`; no row of @tbl-example-rows contains "Departement".
- WP02.A7: PASS. All of D1, D2, D3, D4, D5, D6, D9, D11 and gap IDs (a)–(z) and (aa) — 35 IDs total — appear exactly once each as a row in `@tbl-changes-v04` (verified with a per-ID grep against the table's text block).
- WP02.A8: PASS. Extracted all `{#sec-…}`/`{#tbl-…}`/`{#lst-…}` IDs from `transition-base:.docs/data-standard.qmd` (85) and the current file (93); `comm -23` shows zero dropped. The 8 new IDs are `sec-changes-v04`, `tbl-changes-v04` (stage A) plus `sec-series-plan`, `tbl-series-plan`, `sec-legacy-maps`, `tbl-legacy-labels`, `tbl-legacy-columns-csv`, `tbl-legacy-overrides` (this stage).

## Deviations           (what the card said, what you did, why)
- Gap (e)'s standard reference says "R code location is unspecified... lines 19, 768, 848", and stage A already fully applied D1 (the same lines) plus D11's `pipeline/` layout (the card calls this "the pipeline/ layout of D2", but the actual layout addition landed under D11 in stage A's changes table, not D2 — D2 covers only `data_raw/`). Since the rule was "check that the text is there, add only what the gap's resolution says beyond the decision," I treated D1+D11 together as "the decision" for gap (e), verified their text was present, added only the one thing gap (e)'s resolution names that neither covers — `pipeline/README.md` in @lst-layout — and gave gap (e)'s changes-table row the sections of both D1 and D11's layout addition (@sec-idea, @sec-layout, @sec-validation, @tbl-decisions). Flagging the D2-vs-D11 mismatch in the card's own text as a minor inaccuracy, not a blocker.
- `SERIES_PLAN.csv`'s gap-(b) resolution text in decisions.qmd uses lowercase `qualifiers`/`defining_breakdown`; I used the contract's actual column names `MEASURE_QUALS`/`DEFINING_BREAKDOWN` throughout, per the gaps table's own note that "where they differ from `contract/csv_headers.csv`, the contract file is authoritative."
- Several gaps ((g) SURVEYS.status, (o) admits_se) specify that a column is added but not its exact allowed values. I reused the codelist convention already established elsewhere in the standard (`DRAFT`/`ACTIVE`/`DEPRECATED`, and Y/N) rather than inventing new vocabulary, to avoid stating unbacked facts.
- Gaps without an explicit "standard reference" line number in the gaps table (k, n, s, t, u, v, w, x, z, aa) were each placed in the section that already discusses the same concept (e.g. (t)'s `var_code` rule under `CL_COMP_BREAKDOWN`, (u)'s geometry engine under `sec-geo-storage`'s Hygiene bullet), which is the natural reading of "the section its standard reference points to" when no line number is given.

## Questions            (contract doubts, and anything only the user can decide)
- None beyond the gap-(e)/D2-vs-D11 section mismatch noted above, which I resolved rather than blocking on.

## Changelog line       (implementers only: the card's line, adjusted if needed)
"Data standard v0.4: R tooling, SERIES_PLAN, legacy maps, three share codes, tolerances." — unchanged from the card; matches what stages A and B together delivered.
