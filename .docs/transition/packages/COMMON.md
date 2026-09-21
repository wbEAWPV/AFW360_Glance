# Rules for every agent

Every implementer, verifier, patch agent and integrator reads this file and its own card, in that order. Together they are your whole brief.

## 1. Context budget

Your session must stay under 100,000 tokens. At 150,000 it is lost. These rules keep it small, and they are not optional.

1. **Read only what your card's "Read" section lists.** Do not open `plan.qmd`, `decisions.qmd`, other cards, or the whole data standard. If you think you need something that is not listed, that is a gap in the card: report it (section 8).
2. **Never read a data file whole.** This covers every `.csv` over 40 rows, every `.xlsx`, `.html`, `.gpkg`, and anything under `reports/`. Look at data through R and print only what you need:
   ```
   Rscript -e 'x <- read.csv(".docs/transition/contract/codes.csv", colClasses="character", na.strings=NULL); print(x[x$codelist=="CL_SEX", 1:5])'
   ```
   Print at most 30 rows and 8 columns at a time. Use `nrow()`, `table()` and `head()`, never a whole data frame.
3. **Keep command output short.** Pipe anything long through `2>&1 | tail -n 40`. Load packages with `suppressPackageStartupMessages()`. Compare files with a script that prints counts and the first 5 differences, never with a raw diff of a large file.
4. **Stop rather than loop.** If the same error survives 3 fix attempts, or you pass about 50 tool calls, stop. Commit what works, and report `PARTIAL` with exactly what is left. The orchestrator sends a fresh agent to continue.

## 2. Ownership

- Write only the paths your card lists under "Owned outputs", plus your report. `contract/output_ownership.csv` is the authoritative list.
- The acceptance script named in a card's header is written by the **verifier**, from the card's acceptance checks. An implementer never writes or sees it, and proves the checks in its own way.
- If a step seems to need another path, or the card, the contract and the inputs disagree, **stop and report it**. Do not invent a convention, and do not work around it.
- Never edit `.docs/transition/**` (except your report), never edit another package's files, and never edit anything under `data_raw/`.
- Agents do not fix defects in the inputs. They register them.

## 3. CSV rules

Every CSV the pipeline writes:

- is UTF-8 without a byte-order mark, with LF line endings and one header row;
- has exactly the columns of `contract/csv_headers.csv` for that file, in that order;
- writes a missing value as an empty string, never `NA`;
- writes numbers in fixed notation, never scientific (`1000000`, not `1e+06`), with at most 10 decimals and no trailing zeros;
- separates multi-valued fields with one space;
- has no line breaks inside a cell.

Every reader reads all columns as character, strips a byte-order mark, and accepts CRLF. Write through `write_std_csv()` and read through `read_std_csv()` from `pipeline/R/io.R` (they exist from wave 2 on). Acceptance scripts do not use them; they carry their own reader.

To see your file's columns:

```
Rscript -e 'h <- read.csv(".docs/transition/contract/csv_headers.csv", colClasses="character"); print(h[h$file=="CL_GEO.csv", c("position","column","status")], row.names=FALSE)'
```

Column status is **R** (required), **C** (required when relevant) or **O** (optional).

## 4. Codes and status

- A code is uppercase ASCII letters, digits and `_`, starts with a letter, and has at most 32 characters: `^[A-Z][A-Z0-9_]{0,31}$`.
- `_T` (total) and `_Z` (not applicable) are reserved. They never appear in a codelist, and no code starts with them.
- Every row this transition creates has `status = DRAFT` and `version_added = 0.1.0`. Nothing becomes `ACTIVE` without the user.
- `TBD` is allowed in a required **text** column on a `DRAFT` row when the value cannot be known from the inputs. It is never allowed in a coded column. Do not invent facts to avoid `TBD`.
- Look up a category's variable through its `var_code` column, never by parsing the code's prefix.

## 5. R code

- All code goes under `pipeline/`. Use base R and the installed packages: readxl, dplyr, tidyr, readr, stringr, purrr, sf, digest, testthat, checkmate, cli, jsonlite. Do not install anything.
- Every script takes `--root <repo root>` (default `.`), is run from the repo root, and never uses an absolute path. It finds shared code with `source(file.path(root, "pipeline", "R", "io.R"))`.
- Every script that generates files also takes `--out-root <dir>` (default: the root). It reads inputs under `--root` and writes outputs under `--out-root` at the same relative paths. This lets a check rebuild into a temporary directory and compare.
- Generated files are deterministic: the same inputs give byte-identical output. Sort rows, and never write the current time unless the card says so.
- Match text from the workbooks byte for byte. Headers carry accents (`Bafatá`, `Gabú`), labels carry `–` and `≥`, and one sheet is named `ADM 1` with a space. Never retype them; read them.
- Read workbooks with `readxl::read_excel(path, sheet, col_types = "text")`. The first column is `indicator`; every other column is a data column. A cell is empty when it is `NA` or blank after `trimws()`.
- Write tests with testthat under `pipeline/tests/testthat/`. Build fixtures in a temporary directory inside the test, with `make_temp_root()` and `edit_csv()` from `helper-temp-root.R`. Do not commit fixture trees.

## 6. Environment on this machine

- Use the Bash tool (Git Bash) for every command.
- R: `Rscript` is on the PATH (R 4.5.2).
- Quarto needs two fixes, because `QUARTO_R` points to a broken path and the default Python has no geopandas. Always render like this, and delete render outputs you do not own:
  ```
  env -u QUARTO_R QUARTO_PYTHON="C:/WBG/Python313/python.exe" quarto render <file>
  ```
- `.gitattributes` pins CSV, R, Markdown and Quarto files to LF, and marks `data_raw/**` as binary. Do not change it.
- If `Rscript`, `git` or `quarto` cannot start at all, report `BLOCKED` with the exact command and message. Do not work around it.

## 7. Git

- Your prompt names your branch. Create it as the prompt says, and commit only on it.
- Never push. Never switch to, commit on, or merge into `dev/eb` or `master`. Only an integrator commits on `transition/main`.
- The tag `transition-base` marks the commit the transition started from. Compare against it when you need "before the transition". Do not compare against `transition/main`, which moves.
- Commit subjects are fixed, so that the git log alone shows the state of the transition:
  - implementer: `WPNN: implement - <summary>` (WP00: `WP00: implement - STATUS: DONE` or `STATUS: BLOCKED`)
  - verifier: `WPNN: verify v<K> - VERDICT: PASS` or `WPNN: verify v<K> - VERDICT: FAIL`
  - patch agent: `WPNN: patch p<K> - <summary>`
  - integrator: `W<N>: integrate - <summary>`
- Write your report first, then commit everything in one commit (`git add -A`), then run `git switch --detach` so that no worktree keeps the branch locked.
- End commit messages with the Co-Authored-By trailer your harness provides.

## 8. Report and final message

Write your report to the path in your prompt, with these headings and nothing else. Write "None" under a heading with nothing to say.

```
# WPNN <role> report
Branch: <branch>
## Files written        (path, and rows or bytes)
## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)
## Deviations           (what the card said, what you did, why)
## Questions            (contract doubts, and anything only the user can decide)
## Changelog line       (implementers only: the card's line, adjusted if needed)
```

Your final message to the orchestrator is plain text of at most 120 words. It starts with one status line:

- implementers and patch agents: `STATUS: DONE`, `STATUS: PARTIAL` or `STATUS: BLOCKED`;
- verifiers: `VERDICT: PASS` or `VERDICT: FAIL`;
- integrators: `STATUS: INTEGRATED`, `STATUS: FINDINGS` or `STATUS: BLOCKED` (defined in the integrator's prompt).

Then give the branch name, what passed, and any failure, deviation or question, precisely enough to act on without opening your report.
