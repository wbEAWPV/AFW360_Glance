# WP10 verifier report
Branch: transition/wp10-content-v1

## Files written        (path, and rows or bytes)
- pipeline/acceptance/wp10_content.R (438 lines)
- .docs/transition/reports/WP10-verifier-v1.md (this file)

## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)
- WP10.A1: PASS - rows=8, keys_ok=TRUE, exactly_one=TRUE, files_exist=TRUE, content_ok=TRUE (about/SEN file=SEN/about.md; about/GNB and messages/GNB bodies=TBD)
- WP10.A2: PASS - bad_fields=0, linebreak_bodies=0, bad_md=none (content/TEXT.csv fields and content/text/**/*.md checked for `<`, `{python}`, `Markdown(`, `#|`)
- WP10.A3: PASS - about.md (1532 chars normalized) equals data_raw/text/About_SEN.txt (1532 chars normalized)
- WP10.A4: PASS - source=dashboard; SEN titles/bodies from index.qmd's first `## Row Messages` block match content/TEXT.csv exactly after whitespace normalization; `##` placeholder counts match; GNB titles from the second block match content/TEXT.csv GNB titles
- WP10.A5: PASS - sha256(assets/figures/SEN/SEN_FISCAL_EQUITY.png) == sha256(data_raw/figures/Fiscal Equity SEN.png) == FIGURES.csv sha256 (9842d034ab862046343e74cb3a32a1b160524134b69f8ea39e24e284953f270a); alt_text_en length=471 (>40)
- WP10.A6: PASS - SURVEYS.csv has SEN_EHCVM_2021 and GNB_EHCVM_2021; SEN row has sample_hh=7100, npl_value=519.8, fieldwork_start=2021-11, fieldwork_end=2022-09, producer_agency=ANSD, npl_currency=XOF; both rows time_period=2021, status=DRAFT
- WP10.A7: PASS - TEXT.csv, FIGURES.csv, SURVEYS.csv headers match contract/csv_headers.csv exactly, in order; every required (R) column is filled (TBD counted as filled) in each file
- WP10.A8: PASS - `pipeline/build_content.R --out-root <tmp>` reproduces content/TEXT.csv, content/text/SEN/about.md, assets/figures/SEN/SEN_FISCAL_EQUITY.png and metadata/registries/FIGURES.csv byte for byte; `pipeline/bootstrap/build_surveys.R --out-root <tmp>` reproduces metadata/surveys/SURVEYS.csv byte for byte; pipeline/tests/testthat/test-content.R passes with 0 failures and 0 errors

## Deviations           (what the card said, what you did, why)
- The card's acceptance checks reference numeric/structural facts (row counts, field values) rather than tolerances from contract/expected_counts.csv. I confirmed contract/expected_counts.csv has no WP10.* rows, so the script compares directly against the literal values given on the card (e.g. 7100, 519.8, 2021-11, 2022-09, ANSD, XOF; the 8-row key table) instead of calling `expected()`/`meets()`. This matches the skeleton's intent ("expected numbers come from contract/expected_counts.csv") applied to the fact that WP10 has none registered there.
- WP10.A2's ".md file" scope was read as the .md files WP10 owns (content/text/**/*.md), not every .md file in the repository, since that is the only markdown WP10's card and owned-outputs list describe. This also makes the check immune to matching the acceptance script's own source by construction (it only ever reads content/TEXT.csv and content/text/**/*.md, never pipeline/acceptance/).
- WP10.A1's "content" sub-checks (file=SEN/about.md; body=TBD for about/GNB and the three messages/GNB rows) go slightly beyond the literal check-ID sentence ("exactly one of body and file, and the referenced file exists") to also verify the specific values named in the Steps table's "Content" column, since that table is what "the keys of the table above" in A1 refers to. This is a faithful reading, not an invented requirement.

## Questions            (contract doubts, and anything only the user can decide)
None.

## Failures to fix   (numbered; for each: the check ID, the exact command or comparison, expected against actual. Write "None" on PASS.)
None.
