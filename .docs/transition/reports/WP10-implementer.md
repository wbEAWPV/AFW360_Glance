# WP10 implementer report
Branch: transition/wp10-content

## Files written        (path, and rows or bytes)

- `pipeline/R/content.R` — helpers `strip_message_wrappers()`, `parse_message_block()`, `extract_row_messages()`, `read_about_paragraphs()`.
- `pipeline/build_content.R` — writes `content/TEXT.csv`, `content/text/SEN/about.md`, `assets/figures/SEN/SEN_FISCAL_EQUITY.png`, `metadata/registries/FIGURES.csv`.
- `pipeline/tests/testthat/test-content.R` — 10 `test_that()` blocks for the content.R helpers.
- `pipeline/bootstrap/build_surveys.R` — checks `surveys_text.csv`'s header against the contract and writes `metadata/surveys/SURVEYS.csv`.
- `pipeline/bootstrap/text/surveys_text.csv` — 25 columns, 2 rows (SEN_EHCVM_2021, GNB_EHCVM_2021).
- `pipeline/bootstrap/text/figures_text.csv` — 7 columns, 1 row (SEN_FISCAL_EQUITY).
- `content/TEXT.csv` — 9 lines (1 header + 8 rows).
- `content/text/SEN/about.md` — 1538 bytes, 2 paragraphs.
- `assets/figures/SEN/SEN_FISCAL_EQUITY.png` — 102826 bytes, byte-identical copy of `data_raw/figures/Fiscal Equity SEN.png`.
- `metadata/registries/FIGURES.csv` — 2 lines (1 header + 1 row).
- `metadata/surveys/SURVEYS.csv` — 3 lines (1 header + 2 rows).

## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)

- WP10.A1: PASS — the 8 `TEXT.csv` rows have the exact (slot, ref_area, order) keys of the card's table; each row has exactly one of `body`/`file` non-empty; `content/text/SEN/about.md` (the one referenced file) exists.
- WP10.A2: PASS — `grep -nE '<|\{python\}|Markdown\(|#\|'` over `content/TEXT.csv` and `content/text/SEN/about.md` finds no match; `grepl("\n"/"\r", df$body)` is `FALSE` for every row.
- WP10.A3: PASS — `about.md` and `data_raw/text/About_SEN.txt`, each whitespace-normalized (collapse runs of whitespace, trim), are `identical()`.
- WP10.A4: PASS — `extract_row_messages()` run against the live `index.qmd` reproduces the SEN titles/bodies and GNB titles written to `TEXT.csv` exactly (`identical()` checked programmatically for all 3 pairs of each country); the `##`/`(Gini: ##)` placeholders survive in bodies 1 and 2.
- WP10.A5: PASS — `sha256_file()` of `assets/figures/SEN/SEN_FISCAL_EQUITY.png` equals that of the source PNG and equals the `sha256` cell in `FIGURES.csv`; `alt_text_en` is 471 characters.
- WP10.A6: PASS — SEN row contains `7100`, `519.8`, `2021-11`, `2022-09`, `ANSD`, `XOF`; both rows have `time_period = 2021` and `status = DRAFT`.
- WP10.A7: PASS — headers of all three files match `contract/csv_headers.csv` exactly (`identical(names(df), expected)`); every **R** column is non-empty on every row (`TBD` used where instructed).
- WP10.A8: PASS — `pipeline/build_content.R` and `pipeline/bootstrap/build_surveys.R`, each run twice with `--out-root <tempdir>`, produce byte-identical trees (`diff -rq`), and match the committed outputs byte for byte (`diff`/`cmp`). `Rscript pipeline/tests/testthat.R` reports `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 69 ]`.

## Deviations           (what the card said, what you did, why)

- The card's "Steps" describe only the `dashboard` branch in prose, but its own text ("With `MESSAGES_SOURCE: dashboard` ... With `files`, they come from ...") describes two branches, so `build_content.R` implements both (`get_messages()` dispatches on the `MESSAGES_SOURCE` constant, currently `"dashboard"` per the orchestrator's note). Only the `dashboard` branch is exercised by any check or test; the `files` branch is untested code and should be treated as unverified if ever switched on.
- Everything else follows the card as written.

## Questions            (contract doubts, and anything only the user can decide)

Per card step 3, every difference between `Messages_SEN.txt` and the Senegal `## Row Messages` block of `index.qmd` (not used, since `MESSAGES_SOURCE: dashboard`, but recorded for the record):

- Message 1 ("Poverty Patterns and Trends"): title and body are word-for-word identical in both sources.
- Message 2: **title differs** — `Messages_SEN.txt` has "Inequality"; `index.qmd` has "Drivers of Inequality". **Body differs substantially** — different sentence structure and order throughout. Two concrete factual divergences: `Messages_SEN.txt` states "(Gini: 36.0)" while `index.qmd` has the placeholder "(Gini: ##)"; `Messages_SEN.txt` qualifies the rural poverty rate as "(## percent in 2026)" while `index.qmd` has "(## percent)" with no year. Both versions cover the same substance (Dakar vs. other regions, rural vs. urban poverty drivers, Thiès/Diourbel), worded differently.
- Message 3 ("Constraints to Inclusive Growth"): title and body are word-for-word identical in both sources.

No question needs the user's decision beyond noting this divergence exists; `MESSAGES_SOURCE: dashboard` was applied as instructed.

## Changelog line       (implementers only: the card's line, adjusted if needed)

Text (TEXT.csv, about.md), figure registry, surveys.
